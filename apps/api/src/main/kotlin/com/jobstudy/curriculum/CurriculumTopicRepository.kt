package com.jobstudy.curriculum

import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.JpaRepository
import java.util.UUID

interface CurriculumTopicRepository : JpaRepository<CurriculumTopic, UUID> {

    /** 품질 게이트 1 — 아직 생성 안 된 주제를 순서대로 (중복 방지) */
    fun findByGeneratedFalseOrderByDisplayOrderAsc(pageable: Pageable): List<CurriculumTopic>

    fun countByGeneratedFalse(): Long
}
