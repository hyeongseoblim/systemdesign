package com.jobstudy.card

import com.jobstudy.common.CardSource
import com.jobstudy.common.LearningMode
import com.jobstudy.common.TopicArea
import org.springframework.data.domain.PageRequest
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.UUID

class CardNotFoundException(id: UUID) : RuntimeException("Card not found: $id")
class SlugConflictException(slug: String) : RuntimeException("Slug already exists: $slug")

@Service
class CardService(
    private val cardRepository: CardRepository,
) {

    @Transactional(readOnly = true)
    fun feed(area: TopicArea?, mode: LearningMode?, cursor: String?, limit: Int): FeedResponse {
        val pageSize = limit.coerceIn(1, 50)
        val decoded = Cursor.decode(cursor)
        // limit+1 조회로 다음 페이지 존재 여부 판단
        val rows = cardRepository.findFeed(
            area = area,
            mode = mode,
            cursorPublishedAt = decoded?.first,
            cursorId = decoded?.second,
            pageable = PageRequest.of(0, pageSize + 1),
        )
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
        return CardDetailResponse.from(cardRepository.save(card))
    }
}
