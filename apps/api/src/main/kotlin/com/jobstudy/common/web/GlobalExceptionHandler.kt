package com.jobstudy.common.web

import com.jobstudy.card.CardNotFoundException
import com.jobstudy.card.InvalidCardStateException
import com.jobstudy.card.SlugConflictException
import com.jobstudy.interaction.QuestionNotFoundException
import org.springframework.http.HttpStatus
import org.springframework.http.ProblemDetail
import org.springframework.web.bind.MethodArgumentNotValidException
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.RestControllerAdvice

/** RFC 7807 Problem Details 형식으로 에러 응답 통일 */
@RestControllerAdvice
class GlobalExceptionHandler {

    @ExceptionHandler(CardNotFoundException::class, QuestionNotFoundException::class)
    fun handleNotFound(e: RuntimeException): ProblemDetail =
        ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, e.message ?: "Not found")

    @ExceptionHandler(InvalidCardStateException::class)
    fun handleInvalidState(e: InvalidCardStateException): ProblemDetail =
        ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, e.message ?: "Invalid state")

    @ExceptionHandler(SlugConflictException::class)
    fun handleConflict(e: SlugConflictException): ProblemDetail =
        ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, e.message ?: "Conflict")

    @ExceptionHandler(MethodArgumentNotValidException::class)
    fun handleValidation(e: MethodArgumentNotValidException): ProblemDetail {
        val msg = e.bindingResult.fieldErrors.joinToString("; ") { "${it.field}: ${it.defaultMessage}" }
        return ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, msg)
    }
}
