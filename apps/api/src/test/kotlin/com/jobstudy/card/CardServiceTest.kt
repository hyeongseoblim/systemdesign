package com.jobstudy.card

import com.jobstudy.common.CardSource
import com.jobstudy.common.LearningMode
import com.jobstudy.common.TopicArea
import com.jobstudy.curriculum.CurriculumResolutionStatus
import com.jobstudy.curriculum.CurriculumTopic
import com.jobstudy.curriculum.CurriculumTopicRepository
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import org.mockito.Mockito.any
import org.mockito.Mockito.mock
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import java.util.UUID

class CardServiceTest {

    private val cardRepository = mock(CardRepository::class.java)
    private val topicRepository = mock(CurriculumTopicRepository::class.java)
    private val service = CardService(cardRepository, topicRepository)

    @Test
    fun `creating manual card with topic key resolves curriculum in same service call`() {
        val cardId = UUID.randomUUID()
        val topic = CurriculumTopic(
            area = TopicArea.SYSTEM_DESIGN,
            title = "LSM-Tree vs B+Tree 저장 엔진",
            mode = LearningMode.CONCEPT,
            displayOrder = 101,
            topicKey = "system-design-101",
        )
        `when`(cardRepository.findBySlug("system-design-16-lsm-vs-btree")).thenReturn(null)
        `when`(cardRepository.save(any(Card::class.java))).thenAnswer { invocation ->
            invocation.getArgument<Card>(0).also { it.id = cardId }
        }
        `when`(topicRepository.findByTopicKey("system-design-101")).thenReturn(topic)

        val result = service.create(
            CreateCardRequest(
                area = TopicArea.SYSTEM_DESIGN,
                mode = LearningMode.CONCEPT,
                title = "LSM-Tree vs B+Tree",
                slug = "system-design-16-lsm-vs-btree",
                contentMd = "# 본문",
                publishNow = true,
                topicKey = "system-design-101",
            ),
        )

        assertEquals(cardId, result.id)
        assertEquals(CardSource.MANUAL, result.source)
        assertEquals(CurriculumResolutionStatus.MANUAL, topic.resolutionStatus)
        assertEquals(cardId, topic.resolvedCardId)
        verify(topicRepository).save(topic)
    }

    @Test
    fun `existing manual card can receive topic link idempotently`() {
        val cardId = UUID.randomUUID()
        val card = Card(
            area = TopicArea.SYSTEM_DESIGN,
            mode = LearningMode.CONCEPT,
            title = "LSM-Tree vs B+Tree",
            slug = "system-design-16-lsm-vs-btree",
            contentMd = "# 본문",
            source = CardSource.MANUAL,
        ).also { it.id = cardId }
        val topic = CurriculumTopic(
            area = TopicArea.SYSTEM_DESIGN,
            title = "LSM-Tree vs B+Tree 저장 엔진",
            displayOrder = 101,
            topicKey = "system-design-101",
        )
        `when`(cardRepository.findBySlug(card.slug)).thenReturn(card)
        `when`(topicRepository.findByTopicKey(topic.topicKey)).thenReturn(topic)

        service.linkExistingManualCard(card.slug, topic.topicKey)
        service.linkExistingManualCard(card.slug, topic.topicKey)

        assertEquals(CurriculumResolutionStatus.MANUAL, topic.resolutionStatus)
        assertEquals(cardId, topic.resolvedCardId)
    }
}
