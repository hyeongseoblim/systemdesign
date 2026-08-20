package com.jobstudy.generation.claude

import com.fasterxml.jackson.annotation.JsonIgnoreProperties
import com.fasterxml.jackson.annotation.JsonInclude
import com.fasterxml.jackson.annotation.JsonProperty
import com.jobstudy.generation.GenerationProperties
import org.slf4j.LoggerFactory
import org.springframework.http.client.SimpleClientHttpRequestFactory
import org.springframework.stereotype.Component
import org.springframework.web.client.ResourceAccessException
import org.springframework.web.client.RestClient
import org.springframework.web.client.RestClientResponseException
import java.time.Duration

/** Claude 호출 결과 — 본문 텍스트 + 토큰 사용량 */
data class ClaudeResult(
    val text: String,
    val inputTokens: Int,
    val outputTokens: Int,
    /** 캐시에서 읽은 입력 토큰. 정가의 약 1/10로 과금된다. */
    val cacheReadTokens: Int = 0,
    /** 캐시에 새로 쓴 입력 토큰. 정가의 약 1.25배로 과금된다. */
    val cacheWriteTokens: Int = 0,
)

/** 대화 한 턴. role 은 Anthropic 규약대로 "user" 또는 "assistant". */
data class ClaudeMessage(val role: String, val text: String)

class ClaudeApiException(message: String, cause: Throwable? = null) : RuntimeException(message, cause)

/** 안전 분류기가 요청을 거절한 경우 (HTTP 200 + stop_reason=refusal) */
class ClaudeRefusalException(val category: String?) :
    RuntimeException("Claude declined the request (category=$category)")

@Component
class ClaudeClient(props: GenerationProperties) {

    private val log = LoggerFactory.getLogger(javaClass)
    private val claude = props.claude

    // 타임아웃을 안 걸면 응답이 없을 때 스레드가 무한정 붙잡힌다.
    // 읽기 타임아웃은 넉넉해야 한다 — Opus 는 thinking 이 켜져 있어 한 턴이 분 단위로 갈 수 있다.
    private val restClient = RestClient.builder()
        .baseUrl(claude.baseUrl)
        .requestFactory(
            SimpleClientHttpRequestFactory().apply {
                setConnectTimeout(Duration.ofSeconds(claude.connectTimeoutSeconds))
                setReadTimeout(Duration.ofSeconds(claude.readTimeoutSeconds))
            },
        )
        .build()

    fun isConfigured(): Boolean = claude.apiKey.isNotBlank()

    /**
     * 단발성 호출 — 카드 생성/검증용. system + user 메시지 하나.
     * 재사용될 접두사가 없으므로 프롬프트 캐싱을 걸지 않는다.
     */
    fun complete(system: String, user: String, maxTokens: Int = claude.maxTokens): ClaudeResult =
        send(
            system = system,
            messages = listOf(ClaudeMessage("user", user)),
            model = claude.model,
            maxTokens = maxTokens,
            cache = false,
        )

    /**
     * 멀티턴 대화 — 면접 세션용. Messages API는 stateless라 매 턴 전체 히스토리를 재전송한다.
     *
     * 그대로 두면 턴이 늘수록 입력 토큰이 누적되므로 프롬프트 캐싱을 건다. 브레이크포인트는 두 곳:
     *  1) system 블록 — 면접관 페르소나·진행 규칙. 세션 내내 불변이라 매 턴 캐시 히트.
     *  2) messages 의 마지막 블록 — 직전까지의 대화 전체가 다음 요청의 캐시 접두사가 된다.
     * 캐싱은 접두사 완전 일치라, 히스토리를 중간에서 수정하면 그 뒤가 전부 무효화된다.
     */
    fun converse(
        system: String,
        messages: List<ClaudeMessage>,
        model: String,
        maxTokens: Int = claude.maxTokens,
        effort: String? = null,
    ): ClaudeResult {
        require(messages.isNotEmpty()) { "messages must not be empty" }
        return send(system, messages, model, maxTokens, cache = true, effort = effort)
    }

    private fun send(
        system: String,
        messages: List<ClaudeMessage>,
        model: String,
        maxTokens: Int,
        cache: Boolean,
        effort: String? = null,
    ): ClaudeResult {
        if (!isConfigured()) throw ClaudeApiException("ANTHROPIC_API_KEY not configured")

        val request = buildRequest(system, messages, model, maxTokens, cache, effort)

        val response = withRetry {
            restClient.post()
                .uri("/v1/messages")
                .header("x-api-key", claude.apiKey)
                .header("anthropic-version", claude.version)
                .apply {
                    if (supportsFallback(model)) header("anthropic-beta", FALLBACK_BETA)
                }
                .header("content-type", "application/json")
                .body(request)
                .retrieve()
                .body(MessageResponse::class.java)
        } ?: throw ClaudeApiException("Claude API returned empty body")

        // 거절은 에러가 아니라 200 + stop_reason=refusal 로 온다. content 를 읽기 전에 먼저 확인.
        if (response.stopReason == "refusal") {
            log.warn("Claude refused request: category={}", response.stopDetails?.category)
            throw ClaudeRefusalException(response.stopDetails?.category)
        }

        val text = response.content.firstOrNull { it.type == "text" }?.text
            ?: throw ClaudeApiException("Claude response had no text content")

        val usage = response.usage
        return ClaudeResult(
            text = text,
            inputTokens = usage?.inputTokens ?: 0,
            outputTokens = usage?.outputTokens ?: 0,
            cacheReadTokens = usage?.cacheReadInputTokens ?: 0,
            cacheWriteTokens = usage?.cacheCreationInputTokens ?: 0,
        )
    }

    /**
     * 재시도 가능한 실패(429 rate limit, 529 overloaded, 5xx, 네트워크·타임아웃)에 지수 백오프.
     *
     * 면접 중에는 한 턴 실패가 곧 대화 흐름 단절이라 재시도 가치가 크다.
     * 4xx(429 제외)는 요청 자체가 잘못된 것이라 재시도하지 않는다 — 몇 번을 보내도 같다.
     *
     * 주의: 호출부가 트랜잭션 안이라 재시도만큼 커넥션 점유 시간도 늘어난다.
     * 혼자 쓰는 규모에서는 문제없지만, 동시 사용자가 생기면 호출을 트랜잭션 밖으로 빼야 한다.
     */
    private fun <T> withRetry(block: () -> T): T {
        val maxAttempts = claude.maxRetries + 1
        var lastError: Exception? = null

        repeat(maxAttempts) { attempt ->
            val isLast = attempt == maxAttempts - 1
            try {
                return block()
            } catch (e: RestClientResponseException) {
                val status = e.statusCode.value()
                if (!isRetryableStatus(status) || isLast) {
                    throw ClaudeApiException("Claude API call failed (HTTP $status): ${e.message}", e)
                }
                lastError = e
                val waitMs = retryAfterMs(e) ?: backoffMs(attempt)
                log.warn(
                    "Claude API {} — {}ms 후 재시도 ({}/{})",
                    status, waitMs, attempt + 1, claude.maxRetries,
                )
                sleep(waitMs)
            } catch (e: ResourceAccessException) {
                // 타임아웃·연결 실패
                if (isLast) throw ClaudeApiException("Claude API unreachable: ${e.message}", e)
                lastError = e
                val waitMs = backoffMs(attempt)
                log.warn(
                    "Claude API 연결 실패 ({}) — {}ms 후 재시도 ({}/{})",
                    e.message, waitMs, attempt + 1, claude.maxRetries,
                )
                sleep(waitMs)
            } catch (e: Exception) {
                throw ClaudeApiException("Claude API call failed: ${e.message}", e)
            }
        }
        throw ClaudeApiException("Claude API retries exhausted", lastError)
    }

    /** 429(rate limit) · 529(overloaded) · 5xx 는 잠시 뒤 성공할 수 있다 */
    private fun isRetryableStatus(status: Int): Boolean = status == 429 || status >= 500

    /** 429 응답의 retry-after 헤더를 우선 존중한다 */
    private fun retryAfterMs(e: RestClientResponseException): Long? =
        e.responseHeaders?.getFirst("retry-after")
            ?.toLongOrNull()
            ?.let { (it * 1000).coerceAtMost(MAX_BACKOFF_MS) }

    /** 1s → 2s → 4s … (상한 적용). 지터를 섞어 동시 재시도가 겹치지 않게 한다. */
    private fun backoffMs(attempt: Int): Long {
        val base = (1000L shl attempt).coerceAtMost(MAX_BACKOFF_MS)
        return base + (0..500).random()
    }

    private fun sleep(ms: Long) {
        try {
            Thread.sleep(ms)
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
            throw ClaudeApiException("Interrupted while retrying Claude API", e)
        }
    }

    /**
     * 요청 본문 조립. 캐시 브레이크포인트 배치가 이 기능의 비용을 좌우해서 별도 함수로 뺐다.
     * 렌더 순서는 tools → system → messages 이므로, system 에 건 브레이크포인트가
     * 앞쪽 전부를, 마지막 메시지에 건 브레이크포인트가 그 시점까지의 대화 전체를 덮는다.
     */
    internal fun buildRequest(
        system: String,
        messages: List<ClaudeMessage>,
        model: String,
        maxTokens: Int,
        cache: Boolean,
        effort: String? = null,
    ): MessageRequest {
        val lastIndex = messages.lastIndex
        return MessageRequest(
            model = model,
            maxTokens = maxTokens,
            outputConfig = effort?.let { OutputConfig(effort = it) },
            system = listOf(TextBlock(text = system, cacheControl = cacheIf(cache))),
            messages = messages.mapIndexed { i, m ->
                Message(
                    role = m.role,
                    content = listOf(
                        TextBlock(text = m.text, cacheControl = cacheIf(cache && i == lastIndex)),
                    ),
                )
            },
            // 안전 분류기가 거절하면 같은 요청을 대체 모델로 재실행한다. 지원 모델에서만 유효.
            fallbacks = if (supportsFallback(model)) "default" else null,
        )
    }

    /**
     * 면접은 후보자가 답을 고민하는 사이 턴 간격이 기본 TTL(5분)을 넘기기 쉽다.
     * 1시간 TTL은 쓰기가 1.25배 → 2배로 오르지만 읽기는 그대로 1/10이라,
     * 호출이 3회를 넘으면 이득이다. 한 세션은 보통 10턴 이상이다.
     */
    private fun cacheIf(enabled: Boolean): CacheControl? =
        if (enabled) CacheControl(ttl = "1h") else null

    private fun supportsFallback(model: String): Boolean =
        FALLBACK_MODELS.any { model.startsWith(it) }

    // ── Anthropic API DTOs ──
    @JsonInclude(JsonInclude.Include.NON_NULL)
    data class MessageRequest(
        val model: String,
        @JsonProperty("max_tokens") val maxTokens: Int,
        val system: List<TextBlock>,
        val messages: List<Message>,
        @JsonProperty("output_config") val outputConfig: OutputConfig? = null,
        val fallbacks: String? = null,
    )

    /** effort 는 top-level 이 아니라 output_config 안에 들어간다. low|medium|high|xhigh|max */
    data class OutputConfig(val effort: String)

    @JsonInclude(JsonInclude.Include.NON_NULL)
    data class TextBlock(
        val type: String = "text",
        val text: String,
        @JsonProperty("cache_control") val cacheControl: CacheControl? = null,
    )

    @JsonInclude(JsonInclude.Include.NON_NULL)
    data class CacheControl(val type: String = "ephemeral", val ttl: String? = null)

    data class Message(val role: String, val content: List<TextBlock>)

    @JsonIgnoreProperties(ignoreUnknown = true)
    data class MessageResponse(
        val content: List<ContentBlock> = emptyList(),
        val usage: Usage? = null,
        @JsonProperty("stop_reason") val stopReason: String? = null,
        @JsonProperty("stop_details") val stopDetails: StopDetails? = null,
    )

    @JsonIgnoreProperties(ignoreUnknown = true)
    data class ContentBlock(val type: String = "text", val text: String? = null)

    @JsonIgnoreProperties(ignoreUnknown = true)
    data class StopDetails(val category: String? = null, val explanation: String? = null)

    @JsonIgnoreProperties(ignoreUnknown = true)
    data class Usage(
        @JsonProperty("input_tokens") val inputTokens: Int = 0,
        @JsonProperty("output_tokens") val outputTokens: Int = 0,
        @JsonProperty("cache_read_input_tokens") val cacheReadInputTokens: Int = 0,
        @JsonProperty("cache_creation_input_tokens") val cacheCreationInputTokens: Int = 0,
    )

    private companion object {
        const val FALLBACK_BETA = "server-side-fallback-2026-07-01"
        val FALLBACK_MODELS = listOf("claude-opus-5", "claude-fable-5")

        /** 백오프 상한 — 이보다 오래 기다릴 바엔 사용자에게 실패를 알리는 편이 낫다 */
        const val MAX_BACKOFF_MS = 16_000L
    }
}
