package com.jobstudy.generation

import com.jobstudy.card.CardDetailResponse
import com.jobstudy.card.CardRepository
import com.jobstudy.card.CardService
import com.jobstudy.card.CardSummaryResponse
import com.jobstudy.common.CardStatus
import org.springframework.data.domain.PageRequest
import org.springframework.web.bind.annotation.*
import java.util.UUID

/**
 * 운영용 엔드포인트 (X-Admin-Token 필수 — AdminAuthFilter).
 * - 수동 생성 트리거(테스트/보충)
 * - draft 검수: 목록 조회 → 승격(publish) 또는 반려(archive)
 */
@RestController
@RequestMapping("/api/v1/admin")
class AdminController(
    private val generationService: CardGenerationService,
    private val cardRepository: CardRepository,
    private val cardService: CardService,
) {

    @PostMapping("/generate")
    fun generate(): BatchResult = generationService.runDailyBatch()

    @GetMapping("/drafts")
    fun drafts(@RequestParam(defaultValue = "20") limit: Int): List<CardSummaryResponse> =
        cardRepository
            .findByStatusOrderByCreatedAtDesc(CardStatus.DRAFT, PageRequest.of(0, limit.coerceIn(1, 100)))
            .map { CardSummaryResponse.from(it) }

    /** draft 검토 후 게시 승격 */
    @PostMapping("/cards/{id}/publish")
    fun publish(@PathVariable id: UUID): CardDetailResponse = cardService.publishDraft(id)

    /** 반려 — ARCHIVED 전환 */
    @PostMapping("/cards/{id}/archive")
    fun archive(@PathVariable id: UUID): CardDetailResponse = cardService.archive(id)
}
