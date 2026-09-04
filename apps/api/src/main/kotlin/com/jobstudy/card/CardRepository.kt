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
     * 피드 첫 페이지 — 최신부터. area/mode가 null이면 전체.
     *
     * 커서 조건까지 한 쿼리에 `:cursor IS NULL OR ...` 로 합치면 PostgreSQL이
     * null timestamptz 파라미터의 타입을 추론하지 못해(could not determine data type)
     * 실패한다. 커서 유무로 쿼리를 분리한다.
     */
    @Query(
        """
        SELECT c FROM Card c
        WHERE c.status = com.jobstudy.common.CardStatus.PUBLISHED
          AND (:area IS NULL OR c.area = :area)
          AND (:mode IS NULL OR c.mode = :mode)
          AND (:difficulty IS NULL OR c.difficulty = :difficulty)
        ORDER BY c.publishedAt DESC, c.id DESC
        """
    )
    fun findFeedFirstPage(
        @Param("area") area: TopicArea?,
        @Param("mode") mode: LearningMode?,
        @Param("difficulty") difficulty: Short?,
        pageable: Pageable,
    ): List<Card>

    /** 피드 다음 페이지 — keyset(cursor) 페이지네이션, (publishedAt, id) 커서 이후. */
    @Query(
        """
        SELECT c FROM Card c
        WHERE c.status = com.jobstudy.common.CardStatus.PUBLISHED
          AND (:area IS NULL OR c.area = :area)
          AND (:mode IS NULL OR c.mode = :mode)
          AND (:difficulty IS NULL OR c.difficulty = :difficulty)
          AND (
                c.publishedAt < :cursorPublishedAt
             OR (c.publishedAt = :cursorPublishedAt AND c.id < :cursorId)
          )
        ORDER BY c.publishedAt DESC, c.id DESC
        """
    )
    fun findFeedAfter(
        @Param("area") area: TopicArea?,
        @Param("mode") mode: LearningMode?,
        @Param("difficulty") difficulty: Short?,
        @Param("cursorPublishedAt") cursorPublishedAt: OffsetDateTime,
        @Param("cursorId") cursorId: UUID,
        pageable: Pageable,
    ): List<Card>

    /** 랜덤 피드는 필터링된 후보만 읽고 Service에서 요청 시드로 안정적으로 섞는다. */
    @Query(
        """
        SELECT c FROM Card c
        WHERE c.status = com.jobstudy.common.CardStatus.PUBLISHED
          AND (:area IS NULL OR c.area = :area)
          AND (:mode IS NULL OR c.mode = :mode)
          AND (:difficulty IS NULL OR c.difficulty = :difficulty)
        """
    )
    fun findShuffledFeedCandidates(
        @Param("area") area: TopicArea?,
        @Param("mode") mode: LearningMode?,
        @Param("difficulty") difficulty: Short?,
    ): List<Card>

    fun findByStatusOrderByCreatedAtDesc(status: CardStatus, pageable: Pageable): List<Card>
}
