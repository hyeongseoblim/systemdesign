package com.jobstudy.generation

import com.fasterxml.jackson.databind.JsonNode
import com.fasterxml.jackson.databind.ObjectMapper
import com.jobstudy.card.Card
import com.jobstudy.card.CardQuestion
import com.jobstudy.card.CardRepository
import com.jobstudy.common.CardSource
import com.jobstudy.curriculum.CurriculumTopic
import com.jobstudy.curriculum.CurriculumTopicRepository
import com.jobstudy.generation.claude.ClaudeClient
import org.slf4j.LoggerFactory
import org.springframework.data.domain.PageRequest
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.text.Normalizer
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.Locale

data class BatchResult(
    val attempted: Int,
    val published: Int,
    val drafted: Int,
    val failed: Int,
    val skippedReason: String? = null,
)

@Service
class CardGenerationService(
    private val props: GenerationProperties,
    private val claude: ClaudeClient,
    private val cardRepository: CardRepository,
    private val topicRepository: CurriculumTopicRepository,
    private val logRepository: GenerationLogRepository,
    private val objectMapper: ObjectMapper,
) {
    private val log = LoggerFactory.getLogger(javaClass)

    /** 데일리 배치 — 품질 게이트 3종을 모두 적용 */
    fun runDailyBatch(): BatchResult {
        if (!claude.isConfigured()) {
            log.warn("[generation] ANTHROPIC_API_KEY 미설정 — 배치 건너뜀")
            return BatchResult(0, 0, 0, 0, "claude not configured")
        }

        val since = startOfTodayUtc()
        val alreadyToday = logRepository.countCardsSince(since)
        val remaining = (props.dailyCardLimit - alreadyToday).toInt()
        if (remaining <= 0) {
            return BatchResult(0, 0, 0, 0, "daily card limit reached")
        }

        // 품질 게이트 1 — 미생성 주제만 선택
        val topics = topicRepository.findByGeneratedFalseOrderByDisplayOrderAsc(PageRequest.of(0, remaining))
        if (topics.isEmpty()) return BatchResult(0, 0, 0, 0, "no pending topics")

        var published = 0; var drafted = 0; var failed = 0; var attempted = 0
        for (topic in topics) {
            // 품질 게이트 3 — 토큰 예산 캡
            if (logRepository.sumTokensSince(since) >= props.dailyTokenLimit) {
                log.warn("[generation] 일일 토큰 한도 도달 — 배치 중단")
                break
            }
            attempted++
            when (generateOne(topic).outcome) {
                GenerationOutcome.PUBLISHED -> published++
                GenerationOutcome.DRAFT -> drafted++
                GenerationOutcome.FAILED -> failed++
            }
        }
        return BatchResult(attempted, published, drafted, failed)
    }

    /** 단일 주제 생성 — 생성 → 자가검증(게이트2) → 저장. 각 시도를 로그로 남김 */
    @Transactional
    fun generateOne(topic: CurriculumTopic): GenerationLog {
        var inTok = 0; var outTok = 0
        try {
            // 1) 생성
            val gen = claude.complete(
                GenerationPrompts.generationSystem(topic.area),
                GenerationPrompts.generationUser(topic.title, topic.mode),
            )
            inTok += gen.inputTokens; outTok += gen.outputTokens
            val draft = objectMapper.readTree(extractJson(gen.text))

            // 2) 자가 검증 (품질 게이트 2)
            val verify = claude.complete(
                GenerationPrompts.verificationSystem(),
                GenerationPrompts.verificationUser(topic.title, draft["contentMd"].asText("")),
            )
            inTok += verify.inputTokens; outTok += verify.outputTokens
            val score = objectMapper.readTree(extractJson(verify.text))["score"].asInt(0)

            // 3) 카드 빌드 + 임계치에 따라 publish / draft
            val card = buildCard(topic, draft, score)
            if (score >= props.qualityThreshold) card.publish()
            val saved = cardRepository.save(card)
            topic.markGenerated(saved.id!!)
            topicRepository.save(topic)

            val outcome = if (score >= props.qualityThreshold) GenerationOutcome.PUBLISHED else GenerationOutcome.DRAFT
            log.info("[generation] '${topic.title}' → $outcome (score=$score)")
            return logRepository.save(GenerationLog(
                area = topic.area, topicId = topic.id, cardId = saved.id,
                inputTokens = inTok, outputTokens = outTok,
                qualityScore = score.toShort(), outcome = outcome,
            ))
        } catch (e: Exception) {
            log.error("[generation] '${topic.title}' 실패: ${e.message}")
            return logRepository.save(GenerationLog(
                area = topic.area, topicId = topic.id,
                inputTokens = inTok, outputTokens = outTok,
                outcome = GenerationOutcome.FAILED, error = e.message,
            ))
        }
    }

    private fun buildCard(topic: CurriculumTopic, json: JsonNode, score: Int): Card {
        val title = json["title"].asText(topic.title)
        val card = Card(
            area = topic.area,
            mode = topic.mode,
            title = title,
            slug = slugify(title),
            contentMd = json["contentMd"].asText(""),
            summary = json["summary"]?.asText(),
            coach = GenerationPrompts.coachFor(topic.area),
            difficulty = json["difficulty"]?.asInt(1)?.coerceIn(1, 5)?.toShort() ?: 1,
            source = CardSource.AI_GENERATED,
            qualityScore = score.toShort(),
            tags = json["tags"]?.mapNotNull { it.asText(null) }?.toMutableSet() ?: mutableSetOf(),
        )
        json["questions"]?.forEachIndexed { i, q ->
            q.asText(null)?.let { card.addQuestion(CardQuestion(question = it, displayOrder = i.toShort())) }
        }
        return card
    }

    /** LLM 응답에서 첫 '{' ~ 마지막 '}' 사이를 JSON으로 추출 (앞뒤 잡텍스트 방어) */
    private fun extractJson(text: String): String {
        val start = text.indexOf('{')
        val end = text.lastIndexOf('}')
        require(start >= 0 && end > start) { "응답에서 JSON을 찾지 못함" }
        return text.substring(start, end + 1)
    }

    private fun slugify(title: String): String {
        val base = Normalizer.normalize(title, Normalizer.Form.NFKD)
            .lowercase(Locale.getDefault())
            .replace(Regex("[^a-z0-9가-힣]+"), "-")
            .trim('-')
            .take(80)
        // 슬러그 충돌 방지: 짧은 시각 suffix
        val suffix = OffsetDateTime.now().toInstant().toEpochMilli().toString().takeLast(5)
        return if (base.isBlank()) "card-$suffix" else "$base-$suffix"
    }

    private fun startOfTodayUtc(): OffsetDateTime =
        OffsetDateTime.now(ZoneOffset.UTC).toLocalDate().atStartOfDay().atOffset(ZoneOffset.UTC)
}
