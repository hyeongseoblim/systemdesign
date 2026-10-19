package com.jobstudy.interaction

import com.jobstudy.card.CardNotFoundException
import com.jobstudy.card.CardRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.OffsetDateTime
import java.util.UUID

class QuestionNotFoundException(cardId: UUID, questionId: UUID) :
    RuntimeException("Question $questionId not found on card $cardId")

data class AnswerResponse(val questionId: UUID, val answer: String?, val updatedAt: OffsetDateTime)
data class InteractionsResponse(val bookmarked: Boolean, val answers: List<AnswerResponse>)
data class SaveAnswerRequest(val answer: String?)
data class BookmarkResponse(val bookmarked: Boolean)

@Service
class InteractionService(
    private val interactionRepository: InteractionRepository,
    private val cardRepository: CardRepository,
) {

    @Transactional(readOnly = true)
    fun getForCard(cardId: UUID): InteractionsResponse {
        requireCard(cardId)
        val bookmarked = interactionRepository.findByCardIdAndQuestionIdIsNull(cardId)?.bookmarked ?: false
        val answers = interactionRepository.findByCardIdAndQuestionIdIsNotNull(cardId)
            .map { AnswerResponse(it.questionId!!, it.answer, it.updatedAt) }
        return InteractionsResponse(bookmarked, answers)
    }

    @Transactional
    fun saveAnswer(cardId: UUID, questionId: UUID, answer: String?): AnswerResponse {
        val card = cardRepository.findById(cardId).orElseThrow { CardNotFoundException(cardId) }
        if (card.questions.none { it.id == questionId }) {
            throw QuestionNotFoundException(cardId, questionId)
        }
        val row = interactionRepository.findByCardIdAndQuestionId(cardId, questionId)
            ?: Interaction(cardId = cardId, questionId = questionId)
        row.answer = answer
        row.touch()
        val saved = interactionRepository.save(row)
        return AnswerResponse(saved.questionId!!, saved.answer, saved.updatedAt)
    }

    @Transactional
    fun toggleBookmark(cardId: UUID): BookmarkResponse {
        requireCard(cardId)
        val row = interactionRepository.findByCardIdAndQuestionIdIsNull(cardId)
            ?: Interaction(cardId = cardId, questionId = null)
        row.bookmarked = !row.bookmarked
        row.touch()
        return BookmarkResponse(interactionRepository.save(row).bookmarked)
    }

    private fun requireCard(cardId: UUID) {
        if (!cardRepository.existsById(cardId)) throw CardNotFoundException(cardId)
    }
}
