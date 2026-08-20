package com.jobstudy.common.web

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.mock.web.MockHttpServletResponse

class AdminAuthFilterTest {

    private val filter = AdminAuthFilter("admin-secret")

    @Test
    fun `rejects unauthenticated card write`() {
        val request = MockHttpServletRequest("POST", "/api/v1/cards")
        val response = MockHttpServletResponse()
        var chainCalled = false

        filter.doFilter(request, response) { _, _ -> chainCalled = true }

        assertEquals(401, response.status)
        assertFalse(chainCalled)
    }

    @Test
    fun `allows public card read and authenticated card write`() {
        val readRequest = MockHttpServletRequest("GET", "/api/v1/cards")
        val readResponse = MockHttpServletResponse()
        var readChainCalled = false
        filter.doFilter(readRequest, readResponse) { _, _ -> readChainCalled = true }

        val writeRequest = MockHttpServletRequest("POST", "/api/v1/cards")
        writeRequest.addHeader("X-Admin-Token", "admin-secret")
        val writeResponse = MockHttpServletResponse()
        var writeChainCalled = false
        filter.doFilter(writeRequest, writeResponse) { _, _ -> writeChainCalled = true }

        assertTrue(readChainCalled)
        assertTrue(writeChainCalled)
    }
}
