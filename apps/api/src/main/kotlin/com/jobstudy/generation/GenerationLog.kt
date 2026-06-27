package com.jobstudy.generation

import com.jobstudy.common.TopicArea
import jakarta.persistence.*
import org.hibernate.annotations.UuidGenerator
import java.time.OffsetDateTime
import java.util.UUID

enum class GenerationOutcome { PUBLISHED, DRAFT, FAILED }

@Entity
@Table(name = "generation_logs")
class GenerationLog(
    @Column @Enumerated(EnumType.STRING)
    var area: TopicArea? = null,

    @Column(name = "topic_id")
    var topicId: UUID? = null,

    @Column(name = "card_id")
    var cardId: UUID? = null,

    @Column(name = "input_tokens", nullable = false)
    var inputTokens: Int = 0,

    @Column(name = "output_tokens", nullable = false)
    var outputTokens: Int = 0,

    @Column(name = "quality_score")
    var qualityScore: Short? = null,

    @Column(nullable = false) @Enumerated(EnumType.STRING)
    var outcome: GenerationOutcome,

    @Column(columnDefinition = "text")
    var error: String? = null,
) {
    @Id @GeneratedValue @UuidGenerator
    var id: UUID? = null

    @Column(name = "created_at", nullable = false, updatable = false)
    var createdAt: OffsetDateTime = OffsetDateTime.now()
}
