package com.jobstudy.content

import com.jobstudy.card.CardService
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.mockito.Mockito.mock
import org.springframework.core.io.support.PathMatchingResourcePatternResolver

class ContentContractTest {

    private val seeder = ContentSeeder(mock(CardService::class.java))

    @Test
    fun `all content resources satisfy the publishable card contract`() {
        val violations = mutableListOf<String>()
        val slugs = mutableSetOf<String>()
        val topicKeys = mutableSetOf<String>()
        val activeCurriculumKeys = loadActiveCurriculumKeys()
        val resources = PathMatchingResourcePatternResolver()
            .getResources("classpath*:content/*.md")

        resources.forEach { resource ->
            val name = resource.filename ?: "(unknown)"
            val raw = resource.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
            val request = seeder.parse(raw)
            if (request == null) {
                violations += "$name: frontmatter 또는 본문 파싱 실패"
                return@forEach
            }

            if (!slugs.add(request.slug)) violations += "$name: 중복 slug '${request.slug}'"
            if (request.topicKey != null && !topicKeys.add(request.topicKey)) {
                violations += "$name: 중복 topicKey '${request.topicKey}'"
            }
            if (request.difficulty !in 1..5) violations += "$name: difficulty는 1~5"
            if (request.tags.size !in 2..6) violations += "$name: tags는 2~6개"
            if (request.questions.size != 3) violations += "$name: questions는 정확히 3개"
            if (!raw.contains("```mermaid")) violations += "$name: Mermaid 다이어그램 없음"
            val hasNonMermaidCode = CODE_BLOCK.findAll(raw).any { it.groupValues[1] != "mermaid" }
            if (!hasNonMermaidCode) violations += "$name: Mermaid 외 언어 지정 코드블록 없음"
            if (!TABLE_ROW.containsMatchIn(raw)) violations += "$name: Markdown 표 없음"
            if (!CALLOUT.containsMatchIn(raw)) violations += "$name: callout 없음"
            if (request.topicKey != null && !TOPIC_KEY.matches(request.topicKey)) {
                violations += "$name: topicKey 형식은 '<area>-<3자리 순서>'"
            }
            if (request.topicKey != null && request.topicKey !in activeCurriculumKeys) {
                violations += "$name: 존재하지 않거나 제거된 curriculum topicKey '${request.topicKey}'"
            }
        }

        assertTrue(
            violations.isEmpty(),
            violations.joinToString(prefix = "콘텐츠 계약 위반:\n", separator = "\n"),
        )
    }

    private fun loadActiveCurriculumKeys(): Set<String> {
        val resolver = PathMatchingResourcePatternResolver()
        val deletedSql = resolver.getResource("classpath:db/migration/V3__curriculum_dedup.sql")
            .inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
        val deletedBlock = deletedSql.substringAfter("AND title IN (").substringBefore(");")
        val deletedTitles = SQL_STRING.findAll(deletedBlock).map { it.groupValues[1] }.toSet()

        return listOf("V2__generation.sql", "V4__curriculum_year_plan.sql")
            .flatMap { migration ->
                val sql = resolver.getResource("classpath:db/migration/$migration")
                    .inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                CURRICULUM_ROW.findAll(sql).map { match ->
                    SeededTopic(
                        area = match.groupValues[1],
                        title = match.groupValues[2],
                        displayOrder = match.groupValues[3].toInt(),
                    )
                }.toList()
            }
            .filterNot { it.title in deletedTitles }
            .map { "${it.area.lowercase().replace('_', '-')}-${it.displayOrder.toString().padStart(3, '0')}" }
            .toSet()
    }

    private data class SeededTopic(val area: String, val title: String, val displayOrder: Int)

    companion object {
        private val TABLE_ROW = Regex("(?m)^\\|.+\\|$")
        private val CALLOUT = Regex("(?m)^> \\*\\*.+")
        private val CODE_BLOCK = Regex("(?m)^```([A-Za-z0-9_+-]+)\\s*$")
        private val TOPIC_KEY = Regex("[a-z]+(?:-[a-z]+)*-[0-9]{3}")
        private val SQL_STRING = Regex("'([^']*)'")
        private val CURRICULUM_ROW = Regex(
            """\(gen_random_uuid\(\),\s*'([A-Z_]+)',\s*'([^']*)',\s*'[A-Z]+',\s*(\d+),""",
        )
    }
}
