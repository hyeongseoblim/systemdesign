package com.jobstudy.curriculum

import com.jobstudy.common.LearningMode
import com.jobstudy.common.TopicArea
import jakarta.persistence.*
import org.hibernate.annotations.UuidGenerator
import java.time.LocalDate
import java.time.OffsetDateTime
import java.util.UUID

enum class CurriculumResolutionStatus {
    PENDING,
    MANUAL,
    AI_DRAFT,
    AI_PUBLISHED,
    SKIPPED,
}

@Entity
@Table(name = "curriculum_topics")
class CurriculumTopic(
    @Column(nullable = false) @Enumerated(EnumType.STRING)
    var area: TopicArea,

    @Column(nullable = false)
    var title: String,

    @Column(nullable = false) @Enumerated(EnumType.STRING)
    var mode: LearningMode = LearningMode.CONCEPT,

    @Column(name = "display_order", nullable = false)
    var displayOrder: Int = 0,

    @Column(nullable = false)
    var generated: Boolean = false,

    @Column(name = "generated_card_id")
    var generatedCardId: UUID? = null,

    @Column(name = "planned_date")
    var plannedDate: LocalDate? = null,

    @Column(name = "topic_key", nullable = false, unique = true)
    var topicKey: String,

    @Column(name = "resolution_status", nullable = false) @Enumerated(EnumType.STRING)
    var resolutionStatus: CurriculumResolutionStatus = CurriculumResolutionStatus.PENDING,

    @Column(name = "resolved_card_id")
    var resolvedCardId: UUID? = null,

    @Column(name = "supersedes_topic_key")
    var supersedesTopicKey: String? = null,
) {
    @Id @GeneratedValue @UuidGenerator
    var id: UUID? = null

    @Column(name = "created_at", nullable = false, updatable = false)
    var createdAt: OffsetDateTime = OffsetDateTime.now()

    fun resolveManually(cardId: UUID) {
        checkCanResolve(CurriculumResolutionStatus.MANUAL, cardId)
        resolutionStatus = CurriculumResolutionStatus.MANUAL
        resolvedCardId = cardId
        generated = true
        generatedCardId = cardId
    }

    fun resolveWithAi(cardId: UUID, published: Boolean) {
        val target = if (published) {
            CurriculumResolutionStatus.AI_PUBLISHED
        } else {
            CurriculumResolutionStatus.AI_DRAFT
        }
        checkCanResolve(target, cardId)
        resolutionStatus = target
        resolvedCardId = cardId
        generated = true
        generatedCardId = cardId
    }

    private fun checkCanResolve(target: CurriculumResolutionStatus, cardId: UUID) {
        val isIdempotent = resolutionStatus == target && resolvedCardId == cardId
        check(resolutionStatus == CurriculumResolutionStatus.PENDING || isIdempotent) {
            "Curriculum topic '$topicKey' is already resolved as $resolutionStatus"
        }
    }
}
