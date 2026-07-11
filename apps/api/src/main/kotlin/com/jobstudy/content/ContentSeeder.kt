package com.jobstudy.content

import com.jobstudy.card.CardService
import com.jobstudy.card.CreateCardRequest
import com.jobstudy.card.SlugConflictException
import com.jobstudy.common.LearningMode
import com.jobstudy.common.TopicArea
import org.slf4j.LoggerFactory
import org.springframework.boot.ApplicationArguments
import org.springframework.boot.ApplicationRunner
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.core.annotation.Order
import org.springframework.core.io.support.PathMatchingResourcePatternResolver
import org.springframework.stereotype.Component
import org.yaml.snakeyaml.Yaml

/**
 * 수동 큐레이션 학습 콘텐츠를 카드로 시드한다.
 *
 * `classpath:content` 아래 `.md` 파일의 프론트매터 + 마크다운 본문을 읽어 [CardService.create] 로
 * 발행(source = MANUAL) 한다. slug 기준 멱등(idempotent) — 이미 존재하는 slug 는 건너뛴다.
 * 따라서 매 부팅마다 안전하게 재실행되며, AI 생성 파이프라인(Phase 2)과 공존한다.
 *
 * Flyway 마이그레이션은 컨텍스트 초기화 시점에 먼저 끝나므로 실행 시 테이블이 보장된다.
 * `jobstudy.seed.content.enabled=false` 로 끌 수 있다(테스트 등).
 */
@Component
@Order(100)
@ConditionalOnProperty(
    prefix = "jobstudy.seed.content",
    name = ["enabled"],
    havingValue = "true",
    matchIfMissing = true,
)
class ContentSeeder(
    private val cardService: CardService,
) : ApplicationRunner {

    private val log = LoggerFactory.getLogger(javaClass)
    private val yaml = Yaml()

    override fun run(args: ApplicationArguments) {
        val resources = runCatching {
            PathMatchingResourcePatternResolver().getResources("classpath*:$CONTENT_GLOB")
        }.getOrElse {
            log.warn("[seed] content 리소스 스캔 실패 — 스킵: {}", it.message)
            return
        }

        if (resources.isEmpty()) {
            log.info("[seed] {} 없음 — 스킵", CONTENT_GLOB)
            return
        }

        var created = 0
        var skipped = 0
        var failed = 0

        for (res in resources.sortedBy { it.filename }) {
            val name = res.filename ?: "(unknown)"
            try {
                val text = res.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                val req = parse(text)
                if (req == null) {
                    log.warn("[seed] 프론트매터 파싱 실패 — 스킵: {}", name)
                    failed++
                    continue
                }
                cardService.create(req)
                created++
            } catch (e: SlugConflictException) {
                skipped++
            } catch (e: Exception) {
                log.warn("[seed] 카드 생성 실패: {} — {}", name, e.message)
                failed++
            }
        }

        log.info("[seed] 콘텐츠 시드 완료 — 신규 {} / 스킵(이미 존재) {} / 실패 {}", created, skipped, failed)
    }

    /** `---` 프론트매터 + 마크다운 본문을 [CreateCardRequest] 로 변환. 형식 불량이면 null. */
    private fun parse(raw: String): CreateCardRequest? {
        val text = raw.replace("\r\n", "\n").trimStart('\uFEFF', '\n', ' ')
        val match = FRONT_MATTER.find(text) ?: return null

        @Suppress("UNCHECKED_CAST")
        val fm = runCatching { yaml.load<Map<String, Any?>>(match.groupValues[1]) }.getOrNull() ?: return null
        val body = match.groupValues[2].trim()
        if (body.isBlank()) return null

        val area = enumOrNull<TopicArea>(fm["area"]) ?: return null
        val mode = enumOrNull<LearningMode>(fm["mode"]) ?: return null
        val title = fm["title"]?.toString()?.trim().orEmptyNull() ?: return null
        val slug = fm["slug"]?.toString()?.trim().orEmptyNull() ?: return null

        return CreateCardRequest(
            area = area,
            mode = mode,
            title = title,
            slug = slug,
            contentMd = body,
            summary = fm["summary"]?.toString()?.trim(),
            coach = fm["coach"]?.toString()?.trim(),
            difficulty = (fm["difficulty"] as? Number)?.toShort() ?: 1,
            tags = asStringList(fm["tags"]),
            questions = asStringList(fm["questions"]),
            publishNow = true,
        )
    }

    private inline fun <reified E : Enum<E>> enumOrNull(v: Any?): E? =
        v?.toString()?.trim()?.let { s -> runCatching { enumValueOf<E>(s) }.getOrNull() }

    private fun asStringList(v: Any?): List<String> =
        (v as? List<*>)?.mapNotNull { it?.toString()?.trim()?.orEmptyNull() } ?: emptyList()

    private fun String?.orEmptyNull(): String? = this?.ifBlank { null }

    companion object {
        private const val CONTENT_GLOB = "content/*.md"
        // (?s) DOTALL — 본문의 개행 포함. 첫 --- 블록을 프론트매터로 캡처.
        private val FRONT_MATTER = Regex("(?s)^---\\s*\\n(.*?)\\n---\\s*\\n(.*)$")
    }
}
