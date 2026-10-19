package com.jobstudy.interaction

import jakarta.persistence.*
import org.hibernate.annotations.UuidGenerator
import java.time.OffsetDateTime
import java.util.UUID

/**
 * 학습 상호작용.
 * question_id 가 있으면 해당 질문에 대한 답변 행, NULL 이면 카드 북마크 행.
 */
@Entity
@Table(name = "interactions")
class Interaction(
    @Column(name = "card_id", nullable = false)
    var cardId: UUID,

    @Column(name = "question_id")
    var questionId: UUID? = null,

    @Column(columnDefinition = "text")
    var answer: String? = null,

    @Column(nullable = false)
    var bookmarked: Boolean = false,

    @Column(name = "last_viewed_at")
    var lastViewedAt: OffsetDateTime? = null,
) {
    @Id @GeneratedValue @UuidGenerator
    var id: UUID? = null

    @Column(name = "updated_at", nullable = false)
    var updatedAt: OffsetDateTime = OffsetDateTime.now()

    fun touch() {
        updatedAt = OffsetDateTime.now()
    }
}
