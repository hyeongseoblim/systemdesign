package com.jobstudy.generation

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "app.generation")
data class GenerationProperties(
    val enabled: Boolean = true,
    val cron: String = "0 0 9 * * *",
    val zone: String = "Asia/Seoul",
    val dailyCardLimit: Int = 3,
    val dailyTokenLimit: Long = 200_000,
    val qualityThreshold: Int = 70,
    val claude: Claude = Claude(),
) {
    data class Claude(
        val baseUrl: String = "https://api.anthropic.com",
        val apiKey: String = "",
        /** 카드 생성·검증(야간 배치). 지연시간이 무관하고 호출량이 많아 Sonnet. */
        val model: String = "claude-sonnet-5",
        val version: String = "2023-06-01",
        val maxTokens: Int = 4096,
        val connectTimeoutSeconds: Long = 10,
        /** Opus 는 thinking 이 켜져 있어 한 턴이 분 단위로 갈 수 있다. 넉넉히 잡는다. */
        val readTimeoutSeconds: Long = 180,
        /** 429·529·5xx·타임아웃에 한해 지수 백오프로 재시도하는 횟수 */
        val maxRetries: Int = 3,
    )
    // 면접(대화형) 설정은 app.interview 로 분리 — InterviewProperties 참고
}
