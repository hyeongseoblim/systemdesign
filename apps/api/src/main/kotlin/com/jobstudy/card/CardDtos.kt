package com.jobstudy.card

import com.jobstudy.common.CardSource
import com.jobstudy.common.CardStatus
import com.jobstudy.common.LearningMode
import com.jobstudy.common.TopicArea
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import java.time.OffsetDateTime
import java.util.Base64
import java.util.UUID

/** 피드 카드 — 본문 제외, 모바일 카드에 보일 요약 정보 */
data class CardSummaryResponse(
    val id: UUID,
    val area: TopicArea,
    val mode: LearningMode,
    val title: String,
    val slug: String,
    val summary: String?,
    val coach: String?,
    val difficulty: Short,
    val tags: List<String>,
    val publishedAt: OffsetDateTime?,
) {
    companion object {
        fun from(c: Card) = CardSummaryResponse(
            id = c.id!!,
            area = c.area,
            mode = c.mode,
            title = c.title,
            slug = c.slug,
            summary = c.summary,
            coach = c.coach,
            difficulty = c.difficulty,
            tags = c.tags.toList(),
            publishedAt = c.publishedAt,
        )
    }
}

/** 카드 상세 — 본문 + 질문 포함 */
data class CardDetailResponse(
    val id: UUID,
    val area: TopicArea,
    val mode: LearningMode,
    val title: String,
    val slug: String,
    val summary: String?,
    val contentMd: String,
    val coach: String?,
    val difficulty: Short,
    val tags: List<String>,
    val status: CardStatus,
    val qualityScore: Short?,
    val source: CardSource,
    val questions: List<QuestionResponse>,
    val createdAt: OffsetDateTime,
    val publishedAt: OffsetDateTime?,
) {
    companion object {
        fun from(c: Card) = CardDetailResponse(
            id = c.id!!,
            area = c.area,
            mode = c.mode,
            title = c.title,
            slug = c.slug,
            summary = c.summary,
            contentMd = c.contentMd,
            coach = c.coach,
            difficulty = c.difficulty,
            tags = c.tags.toList(),
            status = c.status,
            qualityScore = c.qualityScore,
            source = c.source,
            questions = c.questions.map { QuestionResponse(it.id!!, it.question, it.displayOrder) },
            createdAt = c.createdAt,
            publishedAt = c.publishedAt,
        )
    }
}

data class QuestionResponse(val id: UUID, val question: String, val displayOrder: Short)

/** keyset 페이지 응답 — nextCursor가 null이면 마지막 페이지 */
data class FeedResponse(
    val items: List<CardSummaryResponse>,
    val nextCursor: String?,
)

/** 카드 수동 생성 요청 (MANUAL). AI 생성은 Phase 2의 내부 서비스 사용 */
data class CreateCardRequest(
    val area: TopicArea,
    val mode: LearningMode,
    @field:NotBlank @field:Size(max = 300) val title: String,
    @field:NotBlank @field:Size(max = 300) val slug: String,
    @field:NotBlank val contentMd: String,
    val summary: String? = null,
    val coach: String? = null,
    val difficulty: Short = 1,
    val tags: List<String> = emptyList(),
    val questions: List<String> = emptyList(),
    val publishNow: Boolean = false,
)

/** (publishedAt, id) 복합 커서를 base64 문자열로 인코딩/디코딩 */
object Cursor {
    fun encode(publishedAt: OffsetDateTime?, id: UUID): String {
        val raw = "${publishedAt?.toInstant()?.toEpochMilli() ?: 0}:$id"
        return Base64.getUrlEncoder().withoutPadding().encodeToString(raw.toByteArray())
    }

    fun decode(cursor: String?): Pair<OffsetDateTime, UUID>? {
        if (cursor.isNullOrBlank()) return null
        return runCatching {
            val raw = String(Base64.getUrlDecoder().decode(cursor))
            val (millis, idStr) = raw.split(":", limit = 2)
            val ts = OffsetDateTime.ofInstant(
                java.time.Instant.ofEpochMilli(millis.toLong()),
                java.time.ZoneOffset.UTC,
            )
            ts to UUID.fromString(idStr)
        }.getOrNull()
    }
}
