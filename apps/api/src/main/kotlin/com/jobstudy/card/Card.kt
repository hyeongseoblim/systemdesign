package com.jobstudy.card

import com.jobstudy.common.CardSource
import com.jobstudy.common.CardStatus
import com.jobstudy.common.LearningMode
import com.jobstudy.common.TopicArea
import jakarta.persistence.*
import org.hibernate.annotations.UuidGenerator
import java.time.OffsetDateTime
import java.util.UUID

@Entity
@Table(name = "cards")
class Card(
    @Column(nullable = false) @Enumerated(EnumType.STRING)
    var area: TopicArea,

    @Column(nullable = false) @Enumerated(EnumType.STRING)
    var mode: LearningMode,

    @Column(nullable = false)
    var title: String,

    @Column(nullable = false, unique = true)
    var slug: String,

    @Column(name = "content_md", nullable = false, columnDefinition = "text")
    var contentMd: String,

    @Column(columnDefinition = "text")
    var summary: String? = null,

    var coach: String? = null,

    @Column(nullable = false)
    var difficulty: Short = 1,

    @Column(nullable = false) @Enumerated(EnumType.STRING)
    var status: CardStatus = CardStatus.DRAFT,

    @Column(name = "quality_score")
    var qualityScore: Short? = null,

    @Column(nullable = false) @Enumerated(EnumType.STRING)
    var source: CardSource = CardSource.AI_GENERATED,

    @ElementCollection(fetch = FetchType.LAZY)
    @CollectionTable(name = "card_tags", joinColumns = [JoinColumn(name = "card_id")])
    @Column(name = "tag")
    var tags: MutableSet<String> = mutableSetOf(),

    @OneToMany(mappedBy = "card", cascade = [CascadeType.ALL], orphanRemoval = true)
    @OrderBy("displayOrder ASC")
    var questions: MutableList<CardQuestion> = mutableListOf(),

    @Column(name = "published_at")
    var publishedAt: OffsetDateTime? = null,
) {
    @Id @GeneratedValue @UuidGenerator
    var id: UUID? = null

    @Column(name = "created_at", nullable = false, updatable = false)
    var createdAt: OffsetDateTime = OffsetDateTime.now()

    /** draft → published 승격 (생성 시각 기록) */
    fun publish() {
        status = CardStatus.PUBLISHED
        publishedAt = OffsetDateTime.now()
    }

    fun addQuestion(q: CardQuestion) {
        q.card = this
        questions.add(q)
    }
}
