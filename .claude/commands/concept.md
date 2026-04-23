---
description: 개념 설명 + 실무 예제 + 다이어그램 모드. "/concept <주제>"
argument-hint: <주제> (예: 재고 정합성, TCP Congestion Control, B+Tree 인덱스)
---

# 개념 설명 + 예제 모드

주제: **$ARGUMENTS**

이 세션은 jobStudy CLAUDE.md 의 "개념 설명 + 예제 모드" 규칙을 따른다.

## 진행 규칙

1. **주제에 맞는 코치 선택 후 호출**
   - 자료구조·OS·네트워크·동시성 이론 → `cs-fundamentals-coach`
   - RDBMS·NoSQL·인덱스·샤딩 → `database-coach`
   - AWS·K8s·CI/CD·SRE → `infra-coach`
   - TMS/WMS/OMS·풀필먼트·라스트마일 → `logistics-domain-coach`
   - Spring·동시성·API 구현 → `backend-dev-coach`
   - MSA·DDD·Saga·Outbox·CQRS → `backend-architecture-coach`
   - 분산 시스템 설계 패턴·Trade-off → `system-design-coach`
   - 여러 영역이 겹치면 **복수 코치 병행 호출** (각자 관점에서 응답)

2. **설명 구조**
   - 정의 → 필요성 → 구조/원리 → 실무 사례 → 함정 → 정리
   - 기술 용어 첫 등장 시 괄호로 한국어 뜻 병기 (예: `Idempotency(멱등성)`)

3. **시각 자료 필수** — 최소 1개 이상
   - Mermaid 다이어그램: `flowchart`, `sequenceDiagram`, `stateDiagram`, `classDiagram`, `erDiagram`
   - 비교표 또는 ASCII 도식 병용
   - 복잡한 흐름·상태 전이·아키텍처는 글보다 그림 먼저

4. **실제 사례 연결**
   - 한국(쿠팡/배민/토스/카카오/네이버) 또는 글로벌(Amazon/Uber/Netflix) 프로덕션 사례
   - 정량 근거(QPS, 지연, 저장량 등) 포함

5. **Trade-off 명시**
   - "A가 좋다"로 끝내지 말고, 어떤 조건에서 B/C가 더 나은지 함께 제시

6. **마무리에 확인 질문 3개**
   - 이해도를 점검할 수 있는 열린 질문
   - 사용자가 답변을 작성해 피드백 받을 수 있도록 구성

## 산출물 저장

주제에 맞는 디렉토리에 `.html` 파일로 저장한다. 파일명은 `NN-<slug>.html` 형식.

| 코치 | 저장 위치 |
|---|---|
| `cs-fundamentals-coach` | `cs/<주제>.html` |
| `database-coach` | `database/<주제>.html` |
| `infra-coach` | `infra/<주제>.html` |
| `logistics-domain-coach` | `logistics/<주제>.html` |
| `backend-dev-coach` | `backend/<주제>.html` |
| `backend-architecture-coach` | `backend/architecture/<주제>.html` |
| `system-design-coach` | `system-design/<주제>.html` |

### HTML 필수 포함 요소
- Mermaid.js CDN + 최소 1개 이상의 다이어그램
- 사이드바 네비게이션 (IntersectionObserver 활성화)
- Callout 박스: 면접 포인트(빨강), 실무 함정(주황), 팁(초록)
- Q&A 입력 영역 (textarea + localStorage 자동 저장 + 복사 버튼)
- localStorage 키: `jobStudy::<경로>::<파일명>::<ansId>`
- 반응형 (모바일 사이드바 숨김)
- 맨 아래 `</body>` 직전에 `<script src="../assets/qna-sync.js?v=1"></script>` 추가 (경로 깊이에 맞춰 `../` 개수 조정)

### 참고 템플릿
`logistics/00-domain-overview.html` 의 CSS 변수·컴포넌트·JS 패턴을 재사용.

---

위 규칙에 따라 **$ARGUMENTS** 주제를 진행해 주세요. 저장할 파일명(번호+slug) 을 먼저 제안하고, 사용자 확인 후 작성을 시작하세요.
