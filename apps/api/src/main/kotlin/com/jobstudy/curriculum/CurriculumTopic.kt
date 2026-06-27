package com.jobstudy.curriculum

import com.jobstudy.common.LearningMode
import com.jobstudy.common.TopicArea
import jakarta.persistence.*
import org.hibernate.annotations.UuidGenerator
import java.time.LocalDate
import java.time.OffsetDateTime
import java.util.UUID

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
) {
    @Id @GeneratedValue @UuidGenerator
    var id: UUID? = null

    @Column(name = "created_at", nullable = false, updatable = false)
    var createdAt: OffsetDateTime = OffsetDateTime.now()

    fun markGenerated(cardId: UUID) {
        generated = true
        generatedCardId = cardId
    }
}
