package com.jobstudy.common.web

import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.HttpStatus
import org.springframework.stereotype.Component
import org.springframework.web.filter.OncePerRequestFilter
import java.nio.charset.StandardCharsets.UTF_8
import java.security.MessageDigest

/**
 * 운영 쓰기 경로 보호 — X-Admin-Token 헤더 검증.
 * ADMIN_TOKEN 미설정 시 쓰기 엔드포인트를 전면 차단(안전 기본값).
 */
@Component
class AdminAuthFilter(
    @Value("\${app.admin.token:}") private val adminToken: String,
) : OncePerRequestFilter() {

    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        filterChain: FilterChain,
    ) {
        if (requiresAdminToken(request)) {
            val provided = request.getHeader("X-Admin-Token")
            val validToken = adminToken.isNotBlank() &&
                provided != null &&
                MessageDigest.isEqual(
                    adminToken.toByteArray(UTF_8),
                    provided.toByteArray(UTF_8),
                )
            if (!validToken) {
                response.status = HttpStatus.UNAUTHORIZED.value()
                response.contentType = "application/json"
                response.writer.write("""{"detail":"admin token required"}""")
                return
            }
        }
        filterChain.doFilter(request, response)
    }

    private fun requiresAdminToken(request: HttpServletRequest): Boolean {
        if (request.requestURI.startsWith("/api/v1/admin")) return true

        // 카드 조회는 공개지만, 생성/수정/삭제는 운영자만 할 수 있다.
        val isCardPath = request.requestURI.startsWith("/api/v1/cards")
        val isReadOnlyMethod = request.method in setOf("GET", "HEAD", "OPTIONS")
        return isCardPath && !isReadOnlyMethod
    }
}
