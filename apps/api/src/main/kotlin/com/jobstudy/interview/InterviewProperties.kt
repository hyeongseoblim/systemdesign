package com.jobstudy.interview

import org.springframework.boot.context.properties.ConfigurationProperties

/**
 * 면접 기능 설정. 카드 생성(app.generation)과 분리한다 — 같은 Claude API 를 쓰지만
 * 요구 특성(대화형 vs 배치)도, 비용 프로필도 다르다.
 */
@ConfigurationProperties(prefix = "app.interview")
data class InterviewProperties(
    /** 압박 질문의 품질이 곧 학습 가치라 대화형은 상위 모델을 쓴다. */
    val model: String = "claude-opus-5",

    /** thinking 이 기본 on 이고 max_tokens 가 thinking+응답을 함께 제한한다. */
    val maxTokens: Int = 16_000,

    /**
     * 면접관의 한 턴은 짧은 질문 하나다. 기본값(high)으로 매 턴 깊게 생각하면
     * 출력 토큰이 낭비된다. 턴은 낮게, 마지막 총평만 높게 간다.
     */
    val turnEffort: String = "medium",
    val feedbackEffort: String = "high",

    /** 세션당 턴 상한 — 45분 면접이 보통 15~25턴이라 그 위로 넉넉히 둔 폭주 방지선. */
    val maxTurnsPerSession: Int = 40,

    /** 일일 토큰 캡. 생성 파이프라인과 별도 예산으로 관리한다. */
    val dailyTokenLimit: Long = 300_000,
)
