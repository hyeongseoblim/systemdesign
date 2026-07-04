package com.jobstudy.generation

import com.jobstudy.card.CardRepository
import com.jobstudy.card.CardSummaryResponse
import com.jobstudy.common.CardStatus
import org.springframework.data.domain.PageRequest
import org.springframework.web.bind.annotation.*

/**
 * 운영용 엔드포인트. Phase 4에서 인증(토큰)으로 보호 예정.
 * - 수동 생성 트리거(테스트/보충)
 * - draft 카드 검수 목록 (품질 게이트 2에서 보류된 카드)
 */
@RestController
@RequestMapping("/api/v1/admin")
class AdminController(
    private val generationService: CardGenerationService,
    private val cardRepository: CardRepository,
) {

    @PostMapping("/generate")
    fun generate(): BatchResult = generationService.runDailyBatch()

    @GetMapping("/drafts")
    fun drafts(@RequestParam(defaultValue = "20") limit: Int): List<CardSummaryResponse> =
        cardRepository
            .findByStatusOrderByCreatedAtDesc(CardStatus.DRAFT, PageRequest.of(0, limit.coerceIn(1, 100)))
            .map { CardSummaryResponse.from(it) }
}
