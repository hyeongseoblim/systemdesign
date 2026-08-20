package com.jobstudy.interview

import com.jobstudy.common.InterviewStatus
import com.jobstudy.common.TopicArea
import com.jobstudy.common.TurnRole
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import java.time.OffsetDateTime
import java.util.UUID

data class StartInterviewRequest(
    val area: TopicArea,
    @field:NotBlank @field:Size(max = 300) val topic: String,
    @field:Min(1) @field:Max(5) val difficulty: Short = 3,
    /** 카드 상세에서 시작한 경우의 출처 (선택) */
    val cardId: UUID? = null,
)

data class AnswerRequest(
    @field:NotBlank @field:Size(max = 20_000) val answer: String,
)

data class TurnResponse(
    val id: UUID,
    val role: TurnRole,
    val content: String,
    val turnOrder: Short,
    val createdAt: OffsetDateTime,
)

/** 세션 목록용 요약 — 대화 본문 제외 */
data class InterviewSummaryResponse(
    val id: UUID,
    val area: TopicArea,
    val topic: String,
    val difficulty: Short,
    val coach: String?,
    val status: InterviewStatus,
    val turnCount: Int,
    val startedAt: OffsetDateTime,
    val endedAt: OffsetDateTime?,
) {
    companion object {
        fun from(s: InterviewSession) = InterviewSummaryResponse(
            id = s.id!!,
            area = s.area,
            topic = s.topic,
            difficulty = s.difficulty,
            coach = s.coach,
            status = s.status,
            turnCount = s.turns.size,
            startedAt = s.startedAt,
            endedAt = s.endedAt,
        )
    }
}

/** 세션 상세 — 전체 대화 + (종료 시) 피드백 */
data class InterviewDetailResponse(
    val id: UUID,
    val area: TopicArea,
    val topic: String,
    val difficulty: Short,
    val coach: String?,
    val status: InterviewStatus,
    val cardId: UUID?,
    val turns: List<TurnResponse>,
    val feedbackMd: String?,
    val usage: UsageResponse,
    val startedAt: OffsetDateTime,
    val endedAt: OffsetDateTime?,
) {
    companion object {
        fun from(s: InterviewSession) = InterviewDetailResponse(
            id = s.id!!,
            area = s.area,
            topic = s.topic,
            difficulty = s.difficulty,
            coach = s.coach,
            status = s.status,
            cardId = s.cardId,
            turns = s.turns.map {
                TurnResponse(it.id!!, it.role, it.content, it.turnOrder, it.createdAt)
            },
            feedbackMd = s.feedbackMd,
            usage = UsageResponse(s.inputTokens, s.outputTokens, s.cacheReadTokens),
            startedAt = s.startedAt,
            endedAt = s.endedAt,
        )
    }
}

/** 토큰 사용량. cacheRead 비중이 높을수록 캐싱이 잘 먹고 있다는 뜻. */
data class UsageResponse(
    val inputTokens: Int,
    val outputTokens: Int,
    val cacheReadTokens: Int,
)
