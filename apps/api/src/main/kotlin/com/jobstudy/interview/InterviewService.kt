package com.jobstudy.interview

import com.jobstudy.common.TurnRole
import com.jobstudy.generation.GenerationPrompts
import com.jobstudy.generation.claude.ClaudeClient
import com.jobstudy.generation.claude.ClaudeMessage
import com.jobstudy.generation.claude.ClaudeResult
import org.slf4j.LoggerFactory
import org.springframework.data.domain.PageRequest
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

class InterviewNotFoundException(id: UUID) : RuntimeException("Interview session not found: $id")
class InterviewClosedException(id: UUID) : RuntimeException("Interview session already ended: $id")
class InterviewUnavailableException(message: String) : RuntimeException(message)
class InterviewBudgetExceededException(message: String) : RuntimeException(message)

@Service
class InterviewService(
    private val sessions: InterviewSessionRepository,
    private val claude: ClaudeClient,
    private val props: InterviewProperties,
) {
    private val log = LoggerFactory.getLogger(javaClass)

    /** 세션을 열고 면접관의 첫 문제까지 받아온다. */
    @Transactional
    fun start(req: StartInterviewRequest): InterviewDetailResponse {
        requireAvailable()
        val session = InterviewSession(
            area = req.area,
            topic = req.topic.trim(),
            difficulty = req.difficulty,
            coach = GenerationPrompts.coachFor(req.area),
            cardId = req.cardId,
        )
        sessions.save(session)

        val result = ask(
            session = session,
            messages = listOf(ClaudeMessage("user", InterviewPrompts.opening())),
            effort = props.turnEffort,
        )
        session.addTurn(TurnRole.INTERVIEWER, result.text.trim())
        session.recordUsage(result)

        return InterviewDetailResponse.from(sessions.save(session))
    }

    /** 후보자 답변을 붙이고 면접관의 후속 질문을 받아온다. */
    @Transactional
    fun answer(id: UUID, req: AnswerRequest): InterviewDetailResponse {
        requireAvailable()
        val session = load(id)
        if (!session.isActive) throw InterviewClosedException(id)
        if (session.turns.size >= props.maxTurnsPerSession) {
            throw InterviewBudgetExceededException(
                "이 세션의 턴 상한(${props.maxTurnsPerSession})에 도달했습니다. 면접을 종료하고 피드백을 받으세요.",
            )
        }

        session.addTurn(TurnRole.CANDIDATE, req.answer.trim())

        val result = ask(session, conversationOf(session.turns), props.turnEffort)
        session.addTurn(TurnRole.INTERVIEWER, result.text.trim())
        session.recordUsage(result)

        return InterviewDetailResponse.from(sessions.save(session))
    }

    /**
     * 면접을 종료하고 3축 피드백을 생성한다.
     * 대화 전체가 이미 캐시돼 있으므로 마지막 user 턴 하나만 새 입력으로 붙는다.
     * 총평은 면접 전체를 종합하는 유일한 턴이라 effort 를 올린다.
     */
    @Transactional
    fun finish(id: UUID): InterviewDetailResponse {
        requireAvailable()
        val session = load(id)
        if (!session.isActive) throw InterviewClosedException(id)

        val messages = conversationOf(session.turns) +
            ClaudeMessage("user", InterviewPrompts.feedbackRequest())
        val result = ask(session, messages, props.feedbackEffort)
        session.recordUsage(result)
        session.complete(result.text.trim())

        log.info(
            "Interview {} completed: turns={} in={} out={} cacheRead={}",
            id, session.turns.size, session.inputTokens, session.outputTokens, session.cacheReadTokens,
        )
        return InterviewDetailResponse.from(sessions.save(session))
    }

    /** 피드백 없이 세션을 버린다. */
    @Transactional
    fun abandon(id: UUID): InterviewDetailResponse {
        val session = load(id)
        if (session.isActive) session.abandon()
        return InterviewDetailResponse.from(sessions.save(session))
    }

    @Transactional(readOnly = true)
    fun detail(id: UUID): InterviewDetailResponse = InterviewDetailResponse.from(load(id))

    @Transactional(readOnly = true)
    fun list(limit: Int): List<InterviewSummaryResponse> =
        sessions.findAllByOrderByStartedAtDesc(PageRequest.of(0, limit.coerceIn(1, 50)))
            .map { InterviewSummaryResponse.from(it) }

    // ── 내부 ──

    private fun load(id: UUID): InterviewSession =
        sessions.findWithTurnsById(id) ?: throw InterviewNotFoundException(id)

    private fun ask(
        session: InterviewSession,
        messages: List<ClaudeMessage>,
        effort: String,
    ): ClaudeResult =
        claude.converse(
            system = InterviewPrompts.system(session.area, session.topic, session.difficulty),
            messages = messages,
            model = props.model,
            maxTokens = props.maxTokens,
            effort = effort,
        )

    /** API 키 + 일일 토큰 예산을 함께 확인한다. */
    private fun requireAvailable() {
        if (!props.enabled) {
            throw InterviewUnavailableException(
                "API 면접은 비활성화되었습니다. STUDY WITH JOB의 무료 ChatGPT 웹 면접을 이용하세요.",
            )
        }
        if (!claude.isConfigured()) {
            throw InterviewUnavailableException(
                "ANTHROPIC_API_KEY 가 설정되지 않아 면접을 진행할 수 없습니다.",
            )
        }
        val usedToday = sessions.sumTokensSince(startOfTodayUtc())
        if (usedToday >= props.dailyTokenLimit) {
            log.warn("[interview] 일일 토큰 한도 도달: {} / {}", usedToday, props.dailyTokenLimit)
            throw InterviewBudgetExceededException(
                "오늘의 면접 토큰 한도(${props.dailyTokenLimit})를 모두 사용했습니다. 내일 다시 시도하세요.",
            )
        }
    }

    private fun startOfTodayUtc(): OffsetDateTime =
        LocalDate.now(ZoneOffset.UTC).atStartOfDay().atOffset(ZoneOffset.UTC)

    companion object {
        /**
         * 저장된 턴을 Anthropic messages 배열로 복원한다. 순수 함수라 단독으로 테스트한다.
         *
         * opening()은 프롬프트 스캐폴딩이라 DB에 저장하지 않지만, 첫 메시지는 반드시 user 여야 하고
         * 이후 user/assistant 가 번갈아야 하므로 매번 맨 앞에 다시 끼워 넣는다.
         * 이 위치와 내용이 매 요청 동일해야 캐시 접두사가 유지된다.
         */
        internal fun conversationOf(turns: List<InterviewTurn>): List<ClaudeMessage> =
            listOf(ClaudeMessage("user", InterviewPrompts.opening())) +
                turns.map {
                    val role = if (it.role == TurnRole.INTERVIEWER) "assistant" else "user"
                    ClaudeMessage(role, it.content)
                }
    }
}
