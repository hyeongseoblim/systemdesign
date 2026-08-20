package com.jobstudy.common.web

import com.jobstudy.card.CardNotFoundException
import com.jobstudy.card.SlugConflictException
import com.jobstudy.generation.claude.ClaudeRefusalException
import com.jobstudy.interview.InterviewBudgetExceededException
import com.jobstudy.interview.InterviewClosedException
import com.jobstudy.interview.InterviewNotFoundException
import com.jobstudy.interview.InterviewUnavailableException
import org.springframework.http.HttpStatus
import org.springframework.http.ProblemDetail
import org.springframework.web.bind.MethodArgumentNotValidException
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.RestControllerAdvice

/** RFC 7807 Problem Details 형식으로 에러 응답 통일 */
@RestControllerAdvice
class GlobalExceptionHandler {

    @ExceptionHandler(CardNotFoundException::class)
    fun handleNotFound(e: CardNotFoundException): ProblemDetail =
        ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, e.message ?: "Not found")

    @ExceptionHandler(SlugConflictException::class)
    fun handleConflict(e: SlugConflictException): ProblemDetail =
        ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, e.message ?: "Conflict")

    @ExceptionHandler(InterviewNotFoundException::class)
    fun handleInterviewNotFound(e: InterviewNotFoundException): ProblemDetail =
        ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, e.message ?: "Not found")

    @ExceptionHandler(InterviewClosedException::class)
    fun handleInterviewClosed(e: InterviewClosedException): ProblemDetail =
        ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, e.message ?: "Session already ended")

    /** API 키 미설정 등 기능 자체를 쓸 수 없는 상태 */
    @ExceptionHandler(InterviewUnavailableException::class)
    fun handleInterviewUnavailable(e: InterviewUnavailableException): ProblemDetail =
        ProblemDetail.forStatusAndDetail(
            HttpStatus.SERVICE_UNAVAILABLE,
            e.message ?: "Interview unavailable",
        )

    /** 턴 상한·일일 토큰 캡 초과 — 지금은 못 하지만 나중엔 가능하므로 429 */
    @ExceptionHandler(InterviewBudgetExceededException::class)
    fun handleInterviewBudget(e: InterviewBudgetExceededException): ProblemDetail =
        ProblemDetail.forStatusAndDetail(
            HttpStatus.TOO_MANY_REQUESTS,
            e.message ?: "Interview budget exceeded",
        )

    /** 안전 분류기 거절 — 재시도해도 같은 결과라 그대로 알린다 */
    @ExceptionHandler(ClaudeRefusalException::class)
    fun handleRefusal(e: ClaudeRefusalException): ProblemDetail =
        ProblemDetail.forStatusAndDetail(
            HttpStatus.UNPROCESSABLE_ENTITY,
            "요청이 거절되었습니다. 주제를 바꿔서 다시 시도해 주세요. (category=${e.category})",
        )

    @ExceptionHandler(MethodArgumentNotValidException::class)
    fun handleValidation(e: MethodArgumentNotValidException): ProblemDetail {
        val msg = e.bindingResult.fieldErrors.joinToString("; ") { "${it.field}: ${it.defaultMessage}" }
        return ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, msg)
    }
}
