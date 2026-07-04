package com.jobstudy.card

import com.jobstudy.common.LearningMode
import com.jobstudy.common.TopicArea
import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*
import java.net.URI
import java.util.UUID

@RestController
@RequestMapping("/api/v1/cards")
class CardController(
    private val cardService: CardService,
) {

    @GetMapping
    fun feed(
        @RequestParam(required = false) area: TopicArea?,
        @RequestParam(required = false) mode: LearningMode?,
        @RequestParam(required = false) cursor: String?,
        @RequestParam(defaultValue = "20") limit: Int,
    ): FeedResponse = cardService.feed(area, mode, cursor, limit)

    @GetMapping("/{id}")
    fun detail(@PathVariable id: UUID): CardDetailResponse = cardService.detail(id)

    @PostMapping
    fun create(@Valid @RequestBody req: CreateCardRequest): ResponseEntity<CardDetailResponse> {
        val created = cardService.create(req)
        return ResponseEntity.created(URI.create("/api/v1/cards/${created.id}")).body(created)
    }
}
