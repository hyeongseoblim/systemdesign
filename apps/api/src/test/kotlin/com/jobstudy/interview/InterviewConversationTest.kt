package com.jobstudy.interview

import com.jobstudy.common.TurnRole
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * 저장된 턴 → Anthropic messages 복원 로직.
 *
 * 여기가 틀리면 두 가지로 터진다. 첫 메시지가 user 가 아니거나 role 이 안 번갈면 API 가 400 을
 * 뱉고, opening() 위치나 내용이 요청마다 달라지면 캐시 접두사가 깨져 조용히 요금만 오른다.
 * 후자는 에러가 안 나서 더 위험하다.
 */
class InterviewConversationTest {

    private fun turn(role: TurnRole, content: String, order: Int) =
        InterviewTurn(role = role, content = content, turnOrder = order.toShort())

    /** 면접관 질문 → 후보자 답변이 n번 반복된 세션 */
    private fun turns(pairs: Int): List<InterviewTurn> =
        (0 until pairs).flatMap { i ->
            listOf(
                turn(TurnRole.INTERVIEWER, "질문 $i", i * 2),
                turn(TurnRole.CANDIDATE, "답변 $i", i * 2 + 1),
            )
        }

    @Test
    fun `첫 메시지는 항상 user 이고 opening 프롬프트다`() {
        val messages = InterviewService.conversationOf(emptyList())

        assertEquals(1, messages.size)
        assertEquals("user", messages.first().role)
        assertEquals(InterviewPrompts.opening(), messages.first().text)
    }

    @Test
    fun `role 이 user 와 assistant 로 번갈아 나온다`() {
        val messages = InterviewService.conversationOf(turns(3))

        // opening(user) + [질문(assistant), 답변(user)] × 3
        assertEquals(
            listOf("user", "assistant", "user", "assistant", "user", "assistant", "user"),
            messages.map { it.role },
        )
    }

    @Test
    fun `INTERVIEWER 는 assistant, CANDIDATE 는 user 로 매핑된다`() {
        val messages = InterviewService.conversationOf(
            listOf(
                turn(TurnRole.INTERVIEWER, "설계해 보세요", 0),
                turn(TurnRole.CANDIDATE, "요구사항부터 확인하겠습니다", 1),
            ),
        )

        assertEquals("assistant" to "설계해 보세요", messages[1].role to messages[1].text)
        assertEquals("user" to "요구사항부터 확인하겠습니다", messages[2].role to messages[2].text)
    }

    @Test
    fun `턴 순서가 저장된 순서 그대로 보존된다`() {
        val messages = InterviewService.conversationOf(turns(4))

        // opening 을 제외한 나머지가 저장 순서와 일치해야 한다
        assertEquals(
            turns(4).map { it.content },
            messages.drop(1).map { it.text },
        )
    }

    @Test
    fun `opening 은 저장되지 않지만 매번 같은 위치 같은 내용으로 주입된다`() {
        // 캐시 접두사 유지의 핵심 — 턴이 늘어도 앞부분이 바이트 단위로 동일해야 한다
        val short = InterviewService.conversationOf(turns(1))
        val long = InterviewService.conversationOf(turns(5))

        assertEquals(short.first(), long.first())
        // 짧은 대화 전체가 긴 대화의 접두사여야 캐시가 재사용된다
        assertEquals(short, long.take(short.size))
    }

    @Test
    fun `마지막 턴이 후보자 답변이면 마지막 메시지도 user 다`() {
        // finish() 는 여기에 user 턴(피드백 요청)을 하나 더 붙인다.
        // 연속 user 는 API 가 허용하므로 문제되지 않지만, 마지막이 assistant 인 경우와
        // 구분해서 알고 있어야 한다.
        val afterAnswer = InterviewService.conversationOf(turns(2))
        assertEquals("user", afterAnswer.last().role)

        val afterQuestion = InterviewService.conversationOf(
            turns(2) + turn(TurnRole.INTERVIEWER, "다음 질문", 4),
        )
        assertEquals("assistant", afterQuestion.last().role)
    }

    @Test
    fun `opening 프롬프트에는 휘발성 값이 없다`() {
        // 시각·랜덤값이 끼면 매 요청 접두사가 달라져 캐시가 전혀 안 잡힌다
        val a = InterviewPrompts.opening()
        Thread.sleep(5)
        val b = InterviewPrompts.opening()

        assertEquals(a, b)
        assertTrue(a.isNotBlank())
    }
}
