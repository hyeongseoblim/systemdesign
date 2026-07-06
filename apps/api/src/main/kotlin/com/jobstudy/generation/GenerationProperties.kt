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
        val model: String = "claude-sonnet-4-6",
        val version: String = "2023-06-01",
        val maxTokens: Int = 4096,
        val readTimeoutSeconds: Long = 180,
    )
}
