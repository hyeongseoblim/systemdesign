package com.jobstudy.curriculum

import com.jobstudy.common.LearningMode
import com.jobstudy.common.TopicArea
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.util.UUID

class CurriculumTopicTest {

    @Test
    fun `manual card resolves pending topic and keeps legacy fields in sync`() {
        val topic = topic()
        val cardId = UUID.randomUUID()

        topic.resolveManually(cardId)

        assertEquals(CurriculumResolutionStatus.MANUAL, topic.resolutionStatus)
        assertEquals(cardId, topic.resolvedCardId)
        assertTrue(topic.generated)
        assertEquals(cardId, topic.generatedCardId)
    }

    @Test
    fun `ai result distinguishes draft and published states`() {
        val draftTopic = topic("system-design-102")
        val publishedTopic = topic("system-design-103")

        draftTopic.resolveWithAi(UUID.randomUUID(), published = false)
        publishedTopic.resolveWithAi(UUID.randomUUID(), published = true)

        assertEquals(CurriculumResolutionStatus.AI_DRAFT, draftTopic.resolutionStatus)
        assertEquals(CurriculumResolutionStatus.AI_PUBLISHED, publishedTopic.resolutionStatus)
    }

    @Test
    fun `resolved topic cannot be overwritten by another card`() {
        val topic = topic()
        topic.resolveManually(UUID.randomUUID())

        val error = assertThrows(IllegalStateException::class.java) {
            topic.resolveWithAi(UUID.randomUUID(), published = true)
        }

        assertTrue(error.message!!.contains("already resolved"))
    }

    private fun topic(key: String = "system-design-101") = CurriculumTopic(
        area = TopicArea.SYSTEM_DESIGN,
        title = "테스트 주제",
        mode = LearningMode.CONCEPT,
        displayOrder = 101,
        topicKey = key,
    )
}
