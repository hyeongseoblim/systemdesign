package com.jobstudy.interview

import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.EntityGraph
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.time.OffsetDateTime
import java.util.UUID

interface InterviewSessionRepository : JpaRepository<InterviewSession, UUID> {

    /** 대화 복원용 — 턴을 함께 로드해 N+1을 피한다. */
    @EntityGraph(attributePaths = ["turns"])
    fun findWithTurnsById(id: UUID): InterviewSession?

    fun findAllByOrderByStartedAtDesc(pageable: Pageable): List<InterviewSession>

    /**
     * 일일 예산 게이트용 — 오늘 시작된 세션들의 토큰 합계.
     * 캐시에서 읽은 토큰은 정가의 약 1/10이라 예산 계산에서 제외한다.
     * 자정을 넘긴 세션은 시작일 기준으로 잡히는데, 예산 가드로는 충분한 근사다.
     */
    @Query(
        """
        SELECT COALESCE(SUM(s.inputTokens + s.outputTokens), 0)
        FROM InterviewSession s
        WHERE s.startedAt >= :since
        """
    )
    fun sumTokensSince(@Param("since") since: OffsetDateTime): Long
}
