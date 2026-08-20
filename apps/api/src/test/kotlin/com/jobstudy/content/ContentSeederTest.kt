package com.jobstudy.content

import com.jobstudy.card.CardService
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test
import org.mockito.Mockito.mock

class ContentSeederTest {

    private val seeder = ContentSeeder(mock(CardService::class.java))

    @Test
    fun `parses optional topic key from frontmatter`() {
        val request = seeder.parse(
            """
            ---
            area: SYSTEM_DESIGN
            mode: CONCEPT
            title: "LSM-Tree vs B+Tree"
            slug: system-design-16-lsm-vs-btree
            topicKey: system-design-101
            difficulty: 4
            questions: ["언제 LSM-Tree를 선택하는가?"]
            ---
            # 본문
            비교 내용
            """.trimIndent(),
        )

        assertEquals("system-design-101", request?.topicKey)
        assertEquals("system-design-16-lsm-vs-btree", request?.slug)
    }

    @Test
    fun `keeps topic key optional for independent cards`() {
        val request = seeder.parse(
            """
            ---
            area: CS
            mode: CONCEPT
            title: "독립 카드"
            slug: cs-independent-card
            ---
            # 본문
            내용
            """.trimIndent(),
        )

        assertNull(request?.topicKey)
    }
}
