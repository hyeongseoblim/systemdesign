package com.jobstudy.interaction

import org.springframework.data.jpa.repository.JpaRepository
import java.util.UUID

interface InteractionRepository : JpaRepository<Interaction, UUID> {

    fun findByCardIdAndQuestionId(cardId: UUID, questionId: UUID): Interaction?

    /** 북마크 행 (question_id IS NULL) */
    fun findByCardIdAndQuestionIdIsNull(cardId: UUID): Interaction?

    /** 카드의 모든 답변 행 */
    fun findByCardIdAndQuestionIdIsNotNull(cardId: UUID): List<Interaction>
}
