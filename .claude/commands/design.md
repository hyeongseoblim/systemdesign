---
description: 시스템 설계 실습 모드. "/design <주제>" — 요구사항 → 추정 → 아키텍처 → Deep-dive → Trade-off
argument-hint: <주제> (예: URL Shortener, Twitter 피드, 쿠팡 라스트마일 추적)
---

# 시스템 설계 실습 모드

주제: **$ARGUMENTS**

이 세션은 jobStudy CLAUDE.md 의 "시스템 설계 실습 모드" 규칙을 따른다. 코치는 **함께 설계**하는 파트너 역할이며, 사용자의 판단을 끌어내면서 설계를 발전시킨다.

## 6단계 프레임워크

각 단계마다 사용자와 합의하며 진행한다. 한 번에 6단계를 몰아서 작성하지 않는다.

### ① 요구사항 명확화 (5분)
- **Functional**: 핵심 사용 사례 3-5개, 무엇을 할 수 있어야 하는가
- **Non-functional**: 가용성(SLA), 일관성(Strong/Eventual), 지연(p99), 확장성, 데이터 보존 기간, 지역(단일/멀티 리전)
- 애매한 요구사항은 **사용자에게 질문**으로 확인 — 임의 가정 금지
- Out-of-scope 도 명시 (경계 설정)

### ② 용량 추정 (5분) — Back-of-the-envelope
- DAU → QPS (평균 / 피크, 피크계수 4-10배)
- 저장량 = 레코드 수 × 평균 크기 × 보존 기간
- 대역폭 = QPS × 평균 페이로드
- 단위 실수 주의 (MB vs GB, b vs B)
- 기본 수치: 1일 ≈ 86,400초 / SSD ≈ 0.1ms / DC 내부 RTT ≈ 0.5ms / 대륙 간 ≈ 150ms
- 처리량 기준: MySQL 1K–10K QPS / Redis 100K QPS / Kafka 수백만 msg/s

### ③ API & 데이터 모델 (5분)
- 핵심 엔드포인트 3-5개 (REST or gRPC). 메서드·경로·요청/응답 구조
- 데이터 모델: 주요 테이블과 **인덱스 전략**
- 샤딩 키 후보 식별 (④에서 결정)
- 완벽한 스키마에 시간 낭비 금지

### ④ High-level 아키텍처 (10분)
- Client → CDN → LB → App Server → Cache / DB / Queue / Search / Storage
- 데이터 흐름, 읽기/쓰기 경로 분리
- 확장 포인트와 SPOF(단일 장애점) 표시
- Mermaid `flowchart` 로 다이어그램 필수

### ⑤ Deep-dive (15분)
- 가장 어려운 1-2개 컴포넌트 집중 (면접관/사용자와 합의 후 선택)
- 병목 분석, 일관성 모델, 장애 전파, 데이터 정합성, 캐시 무효화, Hot partition, Fan-out 등
- **정량 근거**로 선택을 뒷받침
- 실패 시나리오 → 대응 전략 (Retry, Circuit Breaker, Fallback, DLQ)

### ⑥ Trade-off 정리 (5분)
- 선택한 방식 vs 대안 비교 (최소 2개 축)
- 다음에 개선할 수 있는 항목 제시
- "지금 상황에선 A, 조건이 X로 바뀌면 B로 전환" 식 조건부 추천

## 진행 규칙

1. **코치 호출**: `system-design-coach` 를 메인으로, 주제에 따라 `database-coach` / `logistics-domain-coach` / `backend-architecture-coach` 등을 **병행 호출**
2. **정량 근거**: 모든 주장을 숫자로 뒷받침
3. **실제 사례**: 한국(쿠팡/배민/토스/카카오/네이버) 또는 글로벌(Amazon/Uber/Netflix) 연결
4. **물류 맥락 재해석**: 가능하면 범용 문제를 풀필먼트/라스트마일 관점으로도 해석
5. **면접 난이도**: FAANG/국내 빅테크 시니어 기준. 안일한 답변 지적

## 산출물 저장

`system-design/<NN>-<slug>.html` 로 저장. 타 도메인이 주가 되면 해당 디렉토리로.

### HTML 필수 포함 요소
- Mermaid.js CDN + `flowchart` 최소 1개, 상태 전이 있으면 `stateDiagram`, 흐름 있으면 `sequenceDiagram`
- 사이드바 네비게이션 (6단계를 섹션으로)
- Callout 박스: 면접 포인트(빨강), 실무 함정(주황), 팁(초록)
- 용량 추정을 표 또는 계산식 블록으로 시각화
- Q&A 입력 영역 (textarea + localStorage)
- 맨 아래 `</body>` 직전에 `<script src="../assets/qna-sync.js?v=1"></script>` 추가 (경로 깊이에 맞춰 조정)
- 반응형

### 참고 템플릿
`logistics/00-domain-overview.html` 재사용.

---

위 규칙에 따라 **$ARGUMENTS** 설계를 진행해 주세요.

먼저 **① 요구사항 명확화** 단계부터 시작하고, 저장할 파일명(번호+slug)을 제안해 주세요. 한 단계가 끝날 때마다 사용자 확인을 받고 다음 단계로 넘어갑니다.
