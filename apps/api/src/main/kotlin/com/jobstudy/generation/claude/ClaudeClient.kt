package com.jobstudy.generation.claude

import com.fasterxml.jackson.annotation.JsonIgnoreProperties
import com.fasterxml.jackson.annotation.JsonProperty
import com.jobstudy.generation.GenerationProperties
import org.slf4j.LoggerFactory
import org.springframework.http.client.JdkClientHttpRequestFactory
import org.springframework.stereotype.Component
import org.springframework.web.client.RestClient
import java.net.http.HttpClient
import java.time.Duration

/** Claude 호출 결과 — 본문 텍스트 + 토큰 사용량 */
data class ClaudeResult(
    val text: String,
    val inputTokens: Int,
    val outputTokens: Int,
)

class ClaudeApiException(message: String, cause: Throwable? = null) : RuntimeException(message, cause)

@Component
class ClaudeClient(props: GenerationProperties) {

    private val log = LoggerFactory.getLogger(javaClass)
    private val claude = props.claude

    // LLM 생성은 느릴 수 있어 read timeout을 넉넉히. 무한 대기는 배치 스레드를 영구 블로킹시키므로 금지.
    private val restClient = RestClient.builder()
        .baseUrl(claude.baseUrl)
        .requestFactory(
            JdkClientHttpRequestFactory(
                HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build()
            ).apply { setReadTimeout(Duration.ofSeconds(claude.readTimeoutSeconds)) }
        )
        .build()

    fun isConfigured(): Boolean = claude.apiKey.isNotBlank()

    /** Anthropic Messages API 호출. system + 단일 user 메시지. */
    fun complete(system: String, user: String, maxTokens: Int = claude.maxTokens): ClaudeResult {
        if (!isConfigured()) throw ClaudeApiException("ANTHROPIC_API_KEY not configured")

        val request = MessageRequest(
            model = claude.model,
            maxTokens = maxTokens,
            system = system,
            messages = listOf(Message("user", user)),
        )

        val response = try {
            restClient.post()
                .uri("/v1/messages")
                .header("x-api-key", claude.apiKey)
                .header("anthropic-version", claude.version)
                .header("content-type", "application/json")
                .body(request)
                .retrieve()
                .body(MessageResponse::class.java)
        } catch (e: Exception) {
            throw ClaudeApiException("Claude API call failed: ${e.message}", e)
        } ?: throw ClaudeApiException("Claude API returned empty body")

        val text = response.content.firstOrNull { it.type == "text" }?.text
            ?: throw ClaudeApiException("Claude response had no text content")

        return ClaudeResult(
            text = text,
            inputTokens = response.usage?.inputTokens ?: 0,
            outputTokens = response.usage?.outputTokens ?: 0,
        )
    }

    // ── Anthropic API DTOs ──
    data class MessageRequest(
        val model: String,
        @JsonProperty("max_tokens") val maxTokens: Int,
        val system: String,
        val messages: List<Message>,
    )

    data class Message(val role: String, val content: String)

    @JsonIgnoreProperties(ignoreUnknown = true)
    data class MessageResponse(
        val content: List<ContentBlock> = emptyList(),
        val usage: Usage? = null,
    )

    @JsonIgnoreProperties(ignoreUnknown = true)
    data class ContentBlock(val type: String = "text", val text: String? = null)

    @JsonIgnoreProperties(ignoreUnknown = true)
    data class Usage(
        @JsonProperty("input_tokens") val inputTokens: Int = 0,
        @JsonProperty("output_tokens") val outputTokens: Int = 0,
    )
}
