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
> **검수 기준 — 2026-09-27**
>
> 통계·히스토그램·다중 컬럼 통계의 이름과 자동 갱신 방식은 DBMS마다 다르다. 통계 갱신이 정확한 실행계획을 보장하는 것도 아니므로 추정치·실측치·데이터 분포를 함께 확인한다.
> 참고: [PostgreSQL Planner Statistics](https://www.postgresql.org/docs/17/planner-stats.html), [PostgreSQL Extended Statistics](https://www.postgresql.org/docs/17/planner-stats.html#PLANNER-STATS-EXTENDED), [MySQL Histograms](https://dev.mysql.com/doc/refman/8.4/en/optimizer-statistics.html)

## 1. 실행 계획은 추정 위에 세워진다

Optimizer는 테이블·인덱스 통계로 각 연산의 행 수와 비용을 추정한다. 오래되거나 편향을 표현하지 못한 통계는 좋은 인덱스가 있어도 잘못된 Scan, Join 순서, Join 알고리즘과 메모리 크기를 고르게 할 수 있다. 그러나 실제 조건이 넓거나 테이블이 작으면 Seq Scan이 올바른 선택일 수 있다.

```mermaid
flowchart LR
    D[데이터 분포] --> S[통계·Histogram·Extended Stats]
    S --> C[Cardinality 추정]
    C --> P[Join 순서·Access Path]
    P --> E[실제 실행]
    E -->|추정/실제 차이| S
```

| 통계 | 표현하는 것 | 한계 |
|---|---|---|
| Row Count | 테이블 규모 | 조건 분포 없음 |
| NDV | Distinct 수 | 값의 편향·꼬리 분포 숨김 |
| Histogram | 값 구간·빈도 | Bucket 해상도·변경 시점 |
| 다중 컬럼 통계 | 일부 컬럼 상관관계 | DBMS별 기능·조합 관리 비용 |

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders
WHERE status = 'FAILED' AND region = 'SEOUL';
```

`EXPLAIN ANALYZE`는 Query를 실제 수행할 수 있지만, 통계 수집 명령인 `ANALYZE`와 같은 뜻이 아니다. 쓰기 Query에서는 부작용과 운영 부하를 확인하고, 가능하면 읽기 전용 복제 환경·샘플 데이터·안전한 실행 방법을 사용한다.

## 2. 추정과 실제를 비교한다

노드별 Estimated Rows와 Actual Rows의 비율이 처음 크게 벌어지는 지점을 찾는다. 통계 갱신만 반복하지 말고 값 편향, NULL, Parameter 값, 컬럼 상관관계, predicate 형태, 데이터 변화 시점을 확인한다. PostgreSQL extended statistics나 MySQL histogram 같은 기능을 사용하더라도 버전·통계 대상·적용 계획을 확인한다.

### 실패 입력 → 판단 → 복구

`status='FAILED' AND region='SEOUL'`의 estimated rows가 100인데 actual rows가 900,000이면 Nested Loop나 작은 메모리 Hash 계획이 실제로는 비쌀 수 있다. 먼저 노드별 첫 괴리와 조인 입력·loops·Buffers를 확인하고, 통계가 오래됐는지와 두 컬럼이 상관되는지 조사한다. 통계를 갱신한 뒤에도 차이가 남으면 다중 컬럼 통계·히스토그램·쿼리 분리·인덱스 설계를 비교하고 동일 Parameter와 데이터에서 다시 측정한다.

강제 Index Hint는 데이터 분포가 바뀌면 반대의 회귀를 만들 수 있다. 계획이 틀렸다는 이유로 바로 힌트를 영구화하지 말고, 원인·재현 조건·변경 감시 지표와 Rollback을 함께 기록한다.

> **면접 포인트** — 강제로 특정 Index를 쓰기 전에 Optimizer가 왜 오판했는지 통계·분포·상관관계·실제 Buffer와 함께 설명하고, 수정 후 첫 괴리 노드와 p95를 재확인한다.
