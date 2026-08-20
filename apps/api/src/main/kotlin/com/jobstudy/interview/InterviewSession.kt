package com.jobstudy.interview

import com.jobstudy.common.InterviewStatus
import com.jobstudy.common.TopicArea
import com.jobstudy.common.TurnRole
import com.jobstudy.generation.claude.ClaudeResult
import jakarta.persistence.*
import org.hibernate.annotations.UuidGenerator
import java.time.OffsetDateTime
import java.util.UUID

@Entity
@Table(name = "interview_sessions")
class InterviewSession(
    @Column(nullable = false) @Enumerated(EnumType.STRING)
    var area: TopicArea,

    @Column(nullable = false)
    var topic: String,

    @Column(nullable = false)
    var difficulty: Short = 3,

    var coach: String? = null,

    @Column(nullable = false) @Enumerated(EnumType.STRING)
    var status: InterviewStatus = InterviewStatus.ACTIVE,

    /** 카드 상세에서 면접을 연 경우의 출처. 탐색용이 아니라 기록용이라 raw UUID로 둔다. */
    @Column(name = "card_id")
    var cardId: UUID? = null,

    @OneToMany(mappedBy = "session", cascade = [CascadeType.ALL], orphanRemoval = true)
    @OrderBy("turnOrder ASC")
    var turns: MutableList<InterviewTurn> = mutableListOf(),
) {
    @Id @GeneratedValue @UuidGenerator
    var id: UUID? = null

    @Column(name = "feedback_md", columnDefinition = "text")
    var feedbackMd: String? = null

    @Column(name = "input_tokens", nullable = false)
    var inputTokens: Int = 0

    @Column(name = "output_tokens", nullable = false)
    var outputTokens: Int = 0

    @Column(name = "cache_read_tokens", nullable = false)
    var cacheReadTokens: Int = 0

    @Column(name = "started_at", nullable = false, updatable = false)
    var startedAt: OffsetDateTime = OffsetDateTime.now()

    @Column(name = "ended_at")
    var endedAt: OffsetDateTime? = null

    val isActive: Boolean get() = status == InterviewStatus.ACTIVE

    fun addTurn(role: TurnRole, content: String): InterviewTurn {
        val turn = InterviewTurn(
            role = role,
            content = content,
            turnOrder = turns.size.toShort(),
        )
        turn.session = this
        turns.add(turn)
        return turn
    }

    fun recordUsage(result: ClaudeResult) {
        inputTokens += result.inputTokens
        outputTokens += result.outputTokens
        cacheReadTokens += result.cacheReadTokens
    }

    fun complete(feedback: String) {
        feedbackMd = feedback
        status = InterviewStatus.COMPLETED
        endedAt = OffsetDateTime.now()
    }

    fun abandon() {
        status = InterviewStatus.ABANDONED
        endedAt = OffsetDateTime.now()
    }
}

@Entity
@Table(name = "interview_turns")
class InterviewTurn(
    @Column(nullable = false) @Enumerated(EnumType.STRING)
    var role: TurnRole,

    @Column(nullable = false, columnDefinition = "text")
    var content: String,

    @Column(name = "turn_order", nullable = false)
    var turnOrder: Short,
) {
    @Id @GeneratedValue @UuidGenerator
    var id: UUID? = null

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "session_id", nullable = false)
    lateinit var session: InterviewSession

    @Column(name = "created_at", nullable = false, updatable = false)
    var createdAt: OffsetDateTime = OffsetDateTime.now()
}
