package com.jobstudy.common.web

import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RestController

@RestController
class HealthController {
    @GetMapping("/api/v1/health")
    fun health(): Map<String, String> = mapOf("status" to "UP")
}
