package com.jobstudy.card

import com.jobstudy.common.CardStatus
import com.jobstudy.common.LearningMode
import com.jobstudy.common.TopicArea
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.time.OffsetDateTime
import java.util.UUID

interface CardRepository : JpaRepository<Card, UUID> {

    fun findBySlug(slug: String): Card?

    /**
     * 피드 조회 — keyset(cursor) 페이지네이션.
     * cursor(publishedAt, id)가 null이면 첫 페이지(최신부터).
     * area/mode가 null이면 전체.
     */
    @Query(
        """
        SELECT c FROM Card c
        WHERE c.status = com.jobstudy.common.CardStatus.PUBLISHED
          AND (:area IS NULL OR c.area = :area)
          AND (:mode IS NULL OR c.mode = :mode)
          AND (
                :cursorPublishedAt IS NULL
             OR c.publishedAt < :cursorPublishedAt
             OR (c.publishedAt = :cursorPublishedAt AND c.id < :cursorId)
          )
        ORDER BY c.publishedAt DESC, c.id DESC
        """
    )
    fun findFeed(
        @Param("area") area: TopicArea?,
        @Param("mode") mode: LearningMode?,
        @Param("cursorPublishedAt") cursorPublishedAt: OffsetDateTime?,
        @Param("cursorId") cursorId: UUID?,
        pageable: Pageable,
    ): List<Card>

    fun findByStatusOrderByCreatedAtDesc(status: CardStatus, pageable: Pageable): List<Card>
}
