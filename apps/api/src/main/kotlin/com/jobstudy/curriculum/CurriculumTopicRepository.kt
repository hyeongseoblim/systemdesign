package com.jobstudy.curriculum

import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.JpaRepository
import java.util.UUID

interface CurriculumTopicRepository : JpaRepository<CurriculumTopic, UUID> {

    /** 품질 게이트 1 — 수동·AI 어느 쪽에서도 아직 해결하지 않은 주제를 순서대로 조회 */
    fun findByResolutionStatusOrderByDisplayOrderAscIdAsc(
        resolutionStatus: CurriculumResolutionStatus,
        pageable: Pageable,
    ): List<CurriculumTopic>

    fun countByResolutionStatus(resolutionStatus: CurriculumResolutionStatus): Long

    fun findByTopicKey(topicKey: String): CurriculumTopic?
}
