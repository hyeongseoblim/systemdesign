package com.jobstudy.common

/** 학습 영역 — CLAUDE.md의 7개 코치 영역 */
enum class TopicArea {
    SYSTEM_DESIGN,
    LOGISTICS,
    BACKEND_DEV,
    BACKEND_ARCHITECTURE,
    DATABASE,
    INFRA,
    CS,
}

/** 학습 모드 — 기존 슬래시 커맨드 4종 계승 */
enum class LearningMode {
    CONCEPT,
    DESIGN,
    INTERVIEW,
    REVIEW,
}

/** 카드 상태. 사용자에게는 PUBLISHED만 노출 */
enum class CardStatus {
    DRAFT,
    PUBLISHED,
    ARCHIVED,
}

/** 카드 출처 */
enum class CardSource {
    AI_GENERATED,
    MANUAL,
}
