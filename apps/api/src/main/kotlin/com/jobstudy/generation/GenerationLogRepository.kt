package com.jobstudy.generation

import com.jobstudy.common.CardStatus
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.time.OffsetDateTime
import java.util.UUID

interface GenerationLogRepository : JpaRepository<GenerationLog, UUID> {

    /** 품질 게이트 3 — 당일 PUBLISHED/DRAFT 카드 수 (FAILED 제외) */
    @Query(
        """
        SELECT COUNT(g) FROM GenerationLog g
        WHERE g.createdAt >= :since AND g.outcome <> com.jobstudy.generation.GenerationOutcome.FAILED
        """
    )
    fun countCardsSince(@Param("since") since: OffsetDateTime): Long

    /** 품질 게이트 3 — 당일 누적 토큰(입력+출력) */
    @Query(
        """
        SELECT COALESCE(SUM(g.inputTokens + g.outputTokens), 0) FROM GenerationLog g
        WHERE g.createdAt >= :since
        """
    )
    fun sumTokensSince(@Param("since") since: OffsetDateTime): Long
}
