package com.jobstudy.card

import jakarta.persistence.*
import org.hibernate.annotations.UuidGenerator
import java.util.UUID

@Entity
@Table(name = "card_questions")
class CardQuestion(
    @Column(nullable = false, columnDefinition = "text")
    var question: String,

    @Column(name = "display_order", nullable = false)
    var displayOrder: Short = 0,
) {
    @Id @GeneratedValue @UuidGenerator
    var id: UUID? = null

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "card_id", nullable = false)
    var card: Card? = null
}
