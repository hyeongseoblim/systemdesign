---
area: DATABASE
mode: REVIEW
coach: database-coach
title: "인덱스 안티패턴 리뷰 — 중복·저선택도·과잉 인덱싱"
slug: database-13-index-antipattern-review
topicKey: database-209
difficulty: 4
summary: "DDL과 실행 계획을 함께 검토해 중복 Prefix, 사용되지 않는 인덱스, 쓰기 증폭과 잘못된 복합 키 순서를 찾는다."
tags:
  - "Index Review"
  - "Query Plan"
  - "Write Amplification"
  - "Selectivity"
questions:
  - "`(user_id)`와 `(user_id, created_at)` 인덱스가 항상 중복인지 판단하려면 무엇을 확인하나요?"
  - "Boolean 저선택도 컬럼 인덱스가 유용해지는 조건과 무용한 조건을 설명해보세요."
  - "사용 횟수가 0인 인덱스를 즉시 삭제하면 안 되는 이유와 안전한 절차는 무엇인가요?"
---
## 1. 인덱스 목록만 보지 않는다

실제 Query 형태, 조건 분포, 정렬, 반환 행 수와 실행 계획을 연결한다. 복합 인덱스의 Prefix가 단일 인덱스를 대체할 수 있어도 크기, Covering, 엔진 동작과 다른 Query를 확인해야 한다.

```mermaid
flowchart TD
    D[DDL·Index 목록] --> Q[Query·빈도]
    Q --> P[실행 계획·실측]
    P --> W[쓰기·저장 비용]
    W --> C{유지·통합·삭제}
    C --> M[변경 후 회귀 관측]
```

| 리뷰 냄새 | 확인할 반례 | 개선 후보 |
|---|---|---|
| 모든 컬럼 인덱스 | 쓰기 많은 테이블 | 핵심 Query만 유지 |
| 낮은 선택도 단독 | Partial Index 가능성 | 조건부·복합 인덱스 |
| 중복 Prefix | Covering·크기 차이 | 통합 후 검증 |
| 미사용 통계 | 관측 기간·Failover 역할 | 숨김/비활성 후 삭제 |

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, created_at
FROM orders
WHERE user_id = :user
ORDER BY created_at DESC
LIMIT 20;
```

> **리뷰 주의** — 운영에서 `ANALYZE`는 Query를 실제 실행한다. 변경 Query의 부작용과 부하를 확인하고 안전한 환경·값으로 측정한다.

## 2. 삭제도 단계적으로 한다

충분한 관측 기간과 배치·월말 Query를 포함해 사용 여부를 확인한다. 지원하면 먼저 Invisible/비활성 상태로 회귀를 관찰하고, 삭제 뒤 Lock과 복제 지연도 감시한다.

> **면접 포인트** — 인덱스는 읽기 최적화 구조이자 모든 쓰기가 유지해야 할 복제 데이터라는 양면을 설명한다.
