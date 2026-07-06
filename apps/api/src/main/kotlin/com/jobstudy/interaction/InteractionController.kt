package com.jobstudy.interaction

import org.springframework.web.bind.annotation.*
import java.util.UUID

@RestController
@RequestMapping("/api/v1/cards/{cardId}")
class InteractionController(
    private val interactionService: InteractionService,
) {

    @GetMapping("/interactions")
    fun interactions(@PathVariable cardId: UUID): InteractionsResponse =
        interactionService.getForCard(cardId)

    @PutMapping("/answers/{questionId}")
    fun saveAnswer(
        @PathVariable cardId: UUID,
        @PathVariable questionId: UUID,
        @RequestBody req: SaveAnswerRequest,
    ): AnswerResponse = interactionService.saveAnswer(cardId, questionId, req.answer)

    @PostMapping("/bookmark")
    fun toggleBookmark(@PathVariable cardId: UUID): BookmarkResponse =
        interactionService.toggleBookmark(cardId)
}
