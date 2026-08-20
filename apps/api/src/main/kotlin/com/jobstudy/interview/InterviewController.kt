package com.jobstudy.interview

import jakarta.validation.Valid
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*
import java.net.URI
import java.util.UUID

@RestController
@RequestMapping("/api/v1/interviews")
class InterviewController(
    private val interviewService: InterviewService,
) {

    @GetMapping
    fun list(@RequestParam(defaultValue = "20") limit: Int): List<InterviewSummaryResponse> =
        interviewService.list(limit)

    @PostMapping
    fun start(@Valid @RequestBody req: StartInterviewRequest): ResponseEntity<InterviewDetailResponse> {
        val created = interviewService.start(req)
        return ResponseEntity.created(URI.create("/api/v1/interviews/${created.id}")).body(created)
    }

    @GetMapping("/{id}")
    fun detail(@PathVariable id: UUID): InterviewDetailResponse = interviewService.detail(id)

    @PostMapping("/{id}/answers")
    fun answer(
        @PathVariable id: UUID,
        @Valid @RequestBody req: AnswerRequest,
    ): InterviewDetailResponse = interviewService.answer(id, req)

    /** 면접 종료 + 피드백 생성 */
    @PostMapping("/{id}/finish")
    fun finish(@PathVariable id: UUID): InterviewDetailResponse = interviewService.finish(id)

    /** 피드백 없이 중단 */
    @PostMapping("/{id}/abandon")
    fun abandon(@PathVariable id: UUID): InterviewDetailResponse = interviewService.abandon(id)
}
