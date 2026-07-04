package com.jobstudy.generation

import com.jobstudy.common.LearningMode
import com.jobstudy.common.TopicArea

/** CLAUDE.md 코치 페르소나와 품질 기준을 카드 생성/검증 프롬프트로 변환 */
object GenerationPrompts {

    fun coachFor(area: TopicArea): String = when (area) {
        TopicArea.SYSTEM_DESIGN -> "system-design-coach"
        TopicArea.LOGISTICS -> "logistics-domain-coach"
        TopicArea.BACKEND_DEV -> "backend-dev-coach"
        TopicArea.BACKEND_ARCHITECTURE -> "backend-architecture-coach"
        TopicArea.DATABASE -> "database-coach"
        TopicArea.INFRA -> "infra-coach"
        TopicArea.CS -> "cs-fundamentals-coach"
    }

    private fun modeGuide(mode: LearningMode): String = when (mode) {
        LearningMode.CONCEPT -> "개념을 구조적으로 설명하고 실제 빅테크 프로덕션 사례와 함께 제시. 끝에 확인 질문 3개."
        LearningMode.DESIGN -> "요구사항→용량추정→API/데이터모델→High-level→Deep-dive→Trade-off 순서로 설계."
        LearningMode.INTERVIEW -> "면접관 시점의 핵심 질문과 모범 답변 포인트, 흔한 함정 위주로."
        LearningMode.REVIEW -> "코드/구현 관점의 체크리스트와 안티패턴, 개선 방향 위주로."
    }

    /** 카드 생성 system prompt */
    fun generationSystem(area: TopicArea): String = """
        당신은 6년차 백엔드 개발자의 이직 준비를 돕는 '${coachFor(area)}' 코치다.
        한국어로 작성하되 기술 용어는 영어 원문 + 첫 등장 시 괄호로 한국어 뜻을 병기한다.
        품질 기준: (1) Trade-off 명시, (2) 정량 근거(QPS·지연·용량), (3) 한국/글로벌 빅테크 실제 사례,
        (4) 국내 빅테크·FAANG 시니어 눈높이, (5) 가능하면 물류 도메인 맥락 연결.
        반드시 아래 JSON 형식 '하나'로만 응답한다. JSON 외 다른 텍스트를 포함하지 않는다.
        {
          "title": "카드 제목(60자 이내)",
          "summary": "피드에 보일 한 줄 요약(120자 이내)",
          "contentMd": "마크다운 본문. 필요 시 ```mermaid 코드블록으로 다이어그램 포함",
          "difficulty": 1~5 정수,
          "tags": ["소문자-키워드", "..."],
          "questions": ["이해도 확인 질문1", "질문2", "질문3"]
        }
    """.trimIndent()

    fun generationUser(title: String, mode: LearningMode): String = """
        주제: "$title"
        모드: ${mode.name} — ${modeGuide(mode)}
        위 주제로 학습 카드 1장을 생성하라. JSON으로만 응답.
    """.trimIndent()

    /** 자가 검증 system prompt (품질 게이트 2) */
    fun verificationSystem(): String = """
        당신은 백엔드 학습 자료의 기술 감수자다. 주어진 학습 카드의 품질을 냉정하게 평가한다.
        평가 축: (1) 사실 정확성(틀린 기술 설명·수치 오류), (2) 구조·완결성, (3) 난이도 적정성(시니어 눈높이),
        (4) Trade-off/정량 근거 포함 여부.
        반드시 아래 JSON '하나'로만 응답한다.
        {
          "score": 0~100 정수,
          "issues": ["발견한 문제점(없으면 빈 배열)"]
        }
    """.trimIndent()

    fun verificationUser(title: String, contentMd: String): String = """
        [카드 제목] $title
        [본문]
        $contentMd

        위 카드를 평가하고 JSON으로만 응답하라.
    """.trimIndent()
}
