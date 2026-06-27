package com.jobstudy.generation

import org.slf4j.LoggerFactory
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component

@Component
class GenerationScheduler(
    private val props: GenerationProperties,
    private val generationService: CardGenerationService,
) {
    private val log = LoggerFactory.getLogger(javaClass)

    /** 매일 설정된 시각에 데일리 배치 실행 */
    @Scheduled(cron = "\${app.generation.cron}", zone = "\${app.generation.zone}")
    fun dailyBatch() {
        if (!props.enabled) {
            log.info("[generation] 비활성화 상태 — 배치 건너뜀")
            return
        }
        log.info("[generation] 데일리 배치 시작")
        val result = generationService.runDailyBatch()
        log.info("[generation] 배치 완료: $result")
    }
}
