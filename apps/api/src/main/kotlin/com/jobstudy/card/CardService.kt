package com.jobstudy.card

import com.jobstudy.common.CardSource
import com.jobstudy.common.LearningMode
import com.jobstudy.common.TopicArea
import com.jobstudy.curriculum.CurriculumTopicRepository
import org.springframework.data.domain.PageRequest
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.security.MessageDigest
import java.util.UUID

class CardNotFoundException(id: UUID) : RuntimeException("Card not found: $id")
class SlugConflictException(slug: String) : RuntimeException("Slug already exists: $slug")

@Service
class CardService(
    private val cardRepository: CardRepository,
    private val topicRepository: CurriculumTopicRepository,
) {

    @Transactional(readOnly = true)
    fun feed(
        area: TopicArea?,
        mode: LearningMode?,
        difficulty: Short?,
        shuffleSeed: Int?,
        cursor: String?,
        limit: Int,
    ): FeedResponse {
        val pageSize = limit.coerceIn(1, 50)
        val shuffledCursor = ShuffleCursor.decode(cursor)
        val effectiveSeed = shuffledCursor?.seed ?: shuffleSeed
        if (effectiveSeed != null) {
            return shuffledFeed(area, mode, difficulty, effectiveSeed, shuffledCursor?.offset ?: 0, pageSize)
        }

        val decoded = Cursor.decode(cursor)
        // limit+1 조회로 다음 페이지 존재 여부 판단
        val pageable = PageRequest.of(0, pageSize + 1)
        val rows = if (decoded == null) {
            cardRepository.findFeedFirstPage(area, mode, difficulty, pageable)
        } else {
            cardRepository.findFeedAfter(area, mode, difficulty, decoded.first, decoded.second, pageable)
        }
        val hasNext = rows.size > pageSize
        val page = if (hasNext) rows.subList(0, pageSize) else rows
        val nextCursor = if (hasNext) {
            val last = page.last()
            Cursor.encode(last.publishedAt, last.id!!)
        } else null
        return FeedResponse(
            items = page.map { CardSummaryResponse.from(it) },
            nextCursor = nextCursor,
        )
    }

    private fun shuffledFeed(
        area: TopicArea?,
        mode: LearningMode?,
        difficulty: Short?,
        seed: Int,
        offset: Int,
        pageSize: Int,
    ): FeedResponse {
        val candidates = cardRepository.findShuffledFeedCandidates(area, mode, difficulty)
        val ordered = candidates
            .map { card -> stableShuffleKey(seed, card.id!!) to card }
            .sortedWith(compareBy<Pair<String, Card>> { it.first }.thenBy { it.second.id })
            .map { it.second }
        val safeOffset = offset.coerceIn(0, ordered.size)
        val page = ordered.drop(safeOffset).take(pageSize)
        val nextOffset = safeOffset + page.size
        return FeedResponse(
            items = page.map { CardSummaryResponse.from(it) },
            nextCursor = if (nextOffset < ordered.size) ShuffleCursor.encode(seed, nextOffset) else null,
        )
    }

    private fun stableShuffleKey(seed: Int, id: UUID): String =
        MessageDigest.getInstance("SHA-256")
            .digest("$seed:$id".toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }

    @Transactional(readOnly = true)
    fun detail(id: UUID): CardDetailResponse {
        val card = cardRepository.findById(id).orElseThrow { CardNotFoundException(id) }
        return CardDetailResponse.from(card)
    }

    @Transactional
    fun create(req: CreateCardRequest): CardDetailResponse {
        if (cardRepository.findBySlug(req.slug) != null) throw SlugConflictException(req.slug)
        val card = Card(
            area = req.area,
            mode = req.mode,
            title = req.title,
            slug = req.slug,
            contentMd = req.contentMd,
            summary = req.summary,
            coach = req.coach,
            difficulty = req.difficulty,
            source = CardSource.MANUAL,
            tags = req.tags.toMutableSet(),
        )
        req.questions.forEachIndexed { i, q ->
            card.addQuestion(CardQuestion(question = q, displayOrder = i.toShort()))
        }
        if (req.publishNow) card.publish()
        val saved = cardRepository.save(card)
        req.topicKey?.let { resolveTopicManually(it, saved.id!!) }
        return CardDetailResponse.from(saved)
    }

    /** 시더가 기존 slug를 다시 만났을 때 새 topicKey 연결만 안전하게 보강한다. */
    @Transactional
    fun linkExistingManualCard(slug: String, topicKey: String) {
        val card = cardRepository.findBySlug(slug) ?: throw IllegalArgumentException("Card not found by slug: $slug")
        require(card.source == CardSource.MANUAL) { "Only MANUAL cards can resolve a topic manually: $slug" }
        resolveTopicManually(topicKey, card.id!!)
    }

    private fun resolveTopicManually(topicKey: String, cardId: UUID) {
        val topic = topicRepository.findByTopicKey(topicKey)
            ?: throw IllegalArgumentException("Curriculum topic not found: $topicKey")
        topic.resolveManually(cardId)
        topicRepository.save(topic)
    }
}
