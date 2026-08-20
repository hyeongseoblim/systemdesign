package com.jobstudy.interview

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.springframework.boot.context.properties.EnableConfigurationProperties
import org.springframework.boot.test.context.ConfigDataApplicationContextInitializer
import org.springframework.boot.test.context.runner.ApplicationContextRunner
import org.springframework.context.annotation.Configuration

/**
 * application.yml 의 `app.interview.*` 키가 InterviewProperties 에 실제로 바인딩되는지 확인한다.
 *
 * 설정 키 오타는 컴파일도 되고 기동도 되면서 조용히 기본값으로 떨어진다.
 * 예를 들어 `turn-effort` 를 `turnEffort` 로 쓰면 매 턴 effort 가 high 로 돌아가
 * 의도한 비용 절감이 통째로 사라지는데, 아무 에러도 나지 않는다.
 *
 * DB 없이 도는 테스트라 Postgres 가 없는 환경에서도 설정 회귀를 잡을 수 있다.
 */
class InterviewPropertiesBindingTest {

    @Configuration
    @EnableConfigurationProperties(InterviewProperties::class)
    class TestConfig

    private val runner = ApplicationContextRunner()
        .withInitializer(ConfigDataApplicationContextInitializer())
        .withUserConfiguration(TestConfig::class.java)

    @Test
    fun `application_yml 의 면접 설정이 그대로 바인딩된다`() {
        runner.run { ctx ->
            val props = ctx.getBean(InterviewProperties::class.java)

            assertEquals(false, props.enabled)
            // 대화형은 상위 모델
            assertEquals("claude-opus-5", props.model)
            // 턴은 낮게, 총평만 깊게 — 이게 뒤집히면 매 턴 thinking 비용이 새어나간다
            assertEquals("medium", props.turnEffort)
            assertEquals("high", props.feedbackEffort)
            // thinking + 응답을 함께 담을 여유
            assertEquals(16_000, props.maxTokens)
            // 폭주 방지선
            assertEquals(40, props.maxTurnsPerSession)
            assertEquals(300_000L, props.dailyTokenLimit)
        }
    }

    @Test
    fun `환경변수로 덮어쓸 수 있다`() {
        runner
            .withPropertyValues(
                "app.interview.turn-effort=low",
                "app.interview.daily-token-limit=1000",
            )
            .run { ctx ->
                val props = ctx.getBean(InterviewProperties::class.java)
                assertEquals("low", props.turnEffort)
                assertEquals(1000L, props.dailyTokenLimit)
                // 덮어쓰지 않은 값은 유지
                assertEquals("high", props.feedbackEffort)
            }
    }

    @Test
    fun `effort 값이 API 가 받는 범위 안에 있다`() {
        val valid = setOf("low", "medium", "high", "xhigh", "max")
        runner.run { ctx ->
            val props = ctx.getBean(InterviewProperties::class.java)
            assertTrue(props.turnEffort in valid, "turnEffort=${props.turnEffort}")
            assertTrue(props.feedbackEffort in valid, "feedbackEffort=${props.feedbackEffort}")
        }
    }
}
