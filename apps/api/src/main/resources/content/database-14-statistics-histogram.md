---
area: DATABASE
mode: CONCEPT
coach: database-coach
title: "인덱스 통계·히스토그램 — 옵티마이저 오판 진단"
slug: database-14-statistics-histogram
topicKey: database-125
difficulty: 4
summary: "카디널리티와 값 분포 통계가 실행 계획 비용 추정에 미치는 영향을 이해하고 추정 오차를 진단한다."
tags:
  - "Query Optimizer"
  - "Statistics"
  - "Histogram"
  - "Cardinality"
questions:
  - "행 수 추정이 실제와 크게 다를 때 조인 순서와 알고리즘에 어떤 영향이 생기나요?"
  - "Distinct 값 수만으로 편향된 상태 컬럼의 선택도를 정확히 추정하기 어려운 이유는 무엇인가요?"
  - "통계를 갱신했는데도 상관된 두 컬럼 조건의 추정이 틀릴 수 있는 이유를 설명해보세요."
---
## 1. 실행 계획은 추정 위에 세워진다

Optimizer는 테이블·인덱스 통계로 각 연산의 행 수와 비용을 추정한다. 오래되거나 편향을 표현하지 못한 통계는 좋은 인덱스가 있어도 잘못된 Scan, Join 순서와 메모리 크기를 고르게 한다.

```mermaid
flowchart LR
    D[데이터 분포] --> S[통계·Histogram]
    S --> C[Cardinality 추정]
    C --> P[Join 순서·Access Path]
    P --> E[실제 실행]
    E -->|추정/실제 차이| S
```

| 통계 | 표현하는 것 | 한계 |
|---|---|---|
| Row Count | 테이블 규모 | 조건 분포 없음 |
| NDV | Distinct 수 | 편향 숨김 |
| Histogram | 값 구간·빈도 | Bucket 해상도·변화 |
| 다중 컬럼 통계 | 상관관계 | 조합 관리 비용 |

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders
WHERE status = 'FAILED' AND region = 'SEOUL';
```

> **운영 주의** — `ANALYZE`가 붙은 실행 계획은 Query를 실제 수행한다. 쓰기 Query와 운영 부하에서는 안전한 환경과 방법을 사용한다.

## 2. 추정과 실제를 비교한다

노드별 Estimated Rows와 Actual Rows 비율이 처음 크게 벌어지는 지점을 찾는다. 통계 갱신, 더 높은 Histogram 해상도, 다중 컬럼 통계 또는 Query·Index 재설계를 검토한다.

> **면접 포인트** — 강제로 특정 Index를 쓰기 전에 Optimizer가 왜 오판했는지 데이터 분포와 통계로 설명한다.
