package com.jobstudy.generation.claude

import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.jobstudy.generation.GenerationProperties
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * 프롬프트 캐싱은 틀려도 에러가 나지 않는다 — 조용히 캐시가 안 잡히고 요금만 오른다.
 * 브레이크포인트 배치를 테스트로 고정해 둔다.
 */
class ClaudeClientRequestTest {

    private val client = ClaudeClient(GenerationProperties())

    /** Spring Boot 가 쓰는 매퍼와 동일하게 Kotlin 모듈을 등록해야 @JsonProperty 가 먹는다 */
    private val mapper = jacksonObjectMapper()

    private fun conversation() = listOf(
        ClaudeMessage("user", "면접을 시작하세요"),
        ClaudeMessage("assistant", "결제 시스템을 설계해 보세요"),
        ClaudeMessage("user", "먼저 요구사항부터 확인하겠습니다"),
    )

    @Test
    fun `대화형 요청은 system과 마지막 메시지에만 캐시 브레이크포인트를 건다`() {
        val req = client.buildRequest(
            system = "당신은 면접관이다",
            messages = conversation(),
            model = "claude-opus-5",
            maxTokens = 16_000,
            cache = true,
        )

        // system 은 세션 내내 불변이라 항상 캐시 대상
        assertNotNull(req.system.single().cacheControl)
        assertEquals("1h", req.system.single().cacheControl?.ttl)

        // 마지막 메시지에만 브레이크포인트 — 앞쪽에 걸면 브레이크포인트 4개 한도를 금방 넘긴다
        val marked = req.messages.map { it.content.single().cacheControl != null }
        assertEquals(listOf(false, false, true), marked)
    }

    @Test
    fun `단발성 요청은 캐시 브레이크포인트를 걸지 않는다`() {
        val req = client.buildRequest(
            system = "카드를 생성하라",
            messages = listOf(ClaudeMessage("user", "주제: Rate Limiter")),
            model = "claude-sonnet-5",
            maxTokens = 4096,
            cache = false,
        )

        assertNull(req.system.single().cacheControl)
        assertNull(req.messages.single().content.single().cacheControl)
    }

    @Test
    fun `대화 순서와 role은 그대로 보존된다`() {
        val req = client.buildRequest("s", conversation(), "claude-opus-5", 100, cache = true)

        assertEquals(listOf("user", "assistant", "user"), req.messages.map { it.role })
        assertEquals(
            conversation().map { it.text },
            req.messages.map { it.content.single().text },
        )
    }

    @Test
    fun `fallbacks는 지원 모델에서만 붙는다`() {
        val opus = client.buildRequest("s", conversation(), "claude-opus-5", 100, cache = true)
        val sonnet = client.buildRequest("s", conversation(), "claude-sonnet-5", 100, cache = true)

        assertEquals("default", opus.fallbacks)
        assertNull(sonnet.fallbacks) // 미지원 모델에 보내면 400
    }

    @Test
    fun `cache_control이 없으면 필드 자체가 직렬화에서 빠진다`() {
        val json = mapper.writeValueAsString(
            client.buildRequest("s", conversation(), "claude-sonnet-5", 100, cache = false),
        )

        // null 로 내보내면 API가 거부할 수 있어 반드시 생략돼야 한다
        assertFalse(json.contains("cache_control"), "cache_control 필드가 남아 있음: $json")
        assertFalse(json.contains("\"fallbacks\""), "fallbacks 필드가 남아 있음: $json")
        assertTrue(json.contains("\"max_tokens\":100"), "snake_case 매핑이 깨짐: $json")
    }

    @Test
    fun `캐시를 켜면 ttl 1시간이 직렬화된다`() {
        val json = mapper.writeValueAsString(
            client.buildRequest("s", conversation(), "claude-opus-5", 100, cache = true),
        )

        assertTrue(json.contains("""{"type":"ephemeral","ttl":"1h"}"""), json)
    }
}
