package com.jobstudy.common.web

import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.HttpStatus
import org.springframework.stereotype.Component
import org.springframework.web.filter.OncePerRequestFilter

/**
 * admin 경로(/api/v1/admin 이하) 보호 — X-Admin-Token 헤더 검증.
 * ADMIN_TOKEN 미설정 시 admin 엔드포인트를 전면 차단(안전 기본값).
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
        if (request.requestURI.startsWith("/api/v1/admin")) {
            val provided = request.getHeader("X-Admin-Token")
            if (adminToken.isBlank() || provided != adminToken) {
                response.status = HttpStatus.UNAUTHORIZED.value()
                response.contentType = "application/json"
                response.writer.write("""{"detail":"admin token required"}""")
                return
            }
        }
        filterChain.doFilter(request, response)
    }
}
