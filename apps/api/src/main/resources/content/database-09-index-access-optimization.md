---
area: DATABASE
mode: CONCEPT
coach: database-coach
title: "인덱스 접근 최적화 — Index Merge·Skip Scan·ICP·MRR"
slug: database-09-index-access-optimization
topicKey: database-104
difficulty: 4
summary: "복합 인덱스 하나만 외우지 않고 옵티마이저가 후보 행과 테이블 접근 순서를 줄이는 네 가지 실행 전략을 EXPLAIN으로 구분한다."
tags:
  - "MySQL"
  - "Index Merge"
  - "Skip Scan"
  - "ICP"
  - "MRR"
questions:
  - "Index Merge가 두 단일 인덱스를 합칠 수 있어도 복합 인덱스보다 느릴 수 있는 이유를 후보 행 수와 정렬·병합 비용으로 설명해보세요."
  - "선두 컬럼 조건이 없는 복합 인덱스에서 Skip Scan이 유리해질 수 있는 데이터 분포와 불리한 분포를 비교해보세요."
  - "ICP와 MRR이 각각 줄이려는 비용을 인덱스 레코드 검사와 테이블 페이지 접근 관점에서 설명해보세요."
---
> **검수 기준 — 2026-09-27**
>
> Index Merge·Skip Scan·ICP·MRR은 MySQL의 특정 버전·스토리지 엔진·옵티마이저 조건에 따라 선택되는 실행 전략이다. 존재한다고 항상 사용되거나 더 빠른 것은 아니며 `EXPLAIN ANALYZE`와 실제 데이터로 확인한다.

## 1. 네 전략은 서로 다른 낭비를 줄인다

MySQL 옵티마이저는 통계와 비용 모델을 바탕으로 접근 경로를 고른다. 각 최적화가 존재한다고 해서 항상 선택되는 것은 아니며, 최종 판단은 실제 데이터 분포에서 `EXPLAIN ANALYZE`로 확인한다.

| 전략 | 줄이는 비용 | 잘 맞는 상황 | 경계 |
|---|---|---|---|
| Index Merge | 한 테이블의 여러 인덱스 결과 결합 | 서로 다른 컬럼의 OR/AND 조건 | 후보 집합 병합과 테이블 조회 비용 |
| Skip Scan | 복합 인덱스 선두값별 반복 탐색 | 선두 컬럼 Cardinality가 낮음 | 선두값 종류가 많으면 반복 비용 증가 |
| ICP | 스토리지 엔진 단계에서 인덱스 조건 평가 | 인덱스만으로 일부 조건 필터 가능 | 인덱스에 없는 조건은 테이블에서 평가 |
| MRR | 랜덤한 테이블 페이지 접근을 묶음·정렬 | Secondary Index가 많은 행을 가리킴 | 버퍼링·정렬 자체의 비용 |

```mermaid
flowchart TD
    Q[WHERE 조건] --> OPT[Cost-based Optimizer]
    OPT --> IM[Index Merge\n여러 range 결과 병합]
    OPT --> SS[Skip Scan\n선두값별 range 반복]
    OPT --> RANGE[Range Scan]
    RANGE --> ICP[ICP\n인덱스 레코드에서 조기 필터]
    ICP --> MRR[MRR\nRow ID를 모아 페이지 순서 접근]
    IM --> ROW[Base Table Rows]
    SS --> ROW
    MRR --> ROW
```

## 2. 실행계획을 읽는 최소 실험

```sql
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_region_created ON orders(region, created_at);

EXPLAIN ANALYZE
SELECT *
FROM orders
WHERE status = 'READY' OR customer_id = 42;

EXPLAIN ANALYZE
SELECT *
FROM orders
WHERE created_at >= CURRENT_DATE - INTERVAL 1 DAY;
```

첫 쿼리는 두 단일 인덱스의 Index Merge 후보가 될 수 있다. 하지만 `(status, customer_id)` 복합 인덱스가 OR 조건을 자동 해결하는 것은 아니며, 조건 형태와 선택도에 따라 쿼리 분리 후 `UNION ALL`이 더 명확할 수도 있다. 두 번째 쿼리는 `region` 종류가 매우 적고 통계·비용 모델이 유리하다고 판단하면 `(region, created_at)`을 선두값별로 탐색하는 Skip Scan 후보가 될 수 있다. MySQL이 해당 Access Path를 선택하지 않거나 다른 DBMS에서는 기능·이름이 다를 수 있으므로 계획을 직접 확인한다.

ICP(Index Condition Pushdown, 인덱스 조건 푸시다운)는 인덱스 레코드를 읽은 시점에 조건을 먼저 평가해 Base Table 접근 횟수를 줄인다. MRR(Multi-Range Read, 다중 범위 읽기)은 Secondary Index에서 얻은 Row ID를 모아 데이터 페이지 순서에 가깝게 접근함으로써 랜덤 I/O를 줄인다.

> **실무 함정** — `type=index_merge`가 보인다고 최적이라고 판단하면 안 된다. 예상 행과 실제 행의 차이, 반복 루프, Base Table 접근 수, 임시 정렬 비용을 함께 본다. 통계가 오래됐거나 컬럼 상관관계가 크면 비용 모델이 틀릴 수 있다.

## 3. 실패 입력 → 판단 → 복구

`status='READY' OR customer_id=42`에서 Index Merge가 선택됐지만 응답이 느리다고 하자. 두 인덱스에서 반환되는 후보 행의 합·중복 제거·Base Table 재방문·정렬 비용을 `EXPLAIN ANALYZE`로 비교한다. 선택도가 낮아 후보가 넓으면 조건을 업무 의미에 맞게 분리한 `UNION ALL`이나 실제 조회 패턴에 맞는 복합 인덱스를 검토하되, 중복 제거 조건을 보존한다.

선두 `region`의 값이 수만 개로 늘어난 뒤 Skip Scan이 선택되면 선두값별 반복 탐색 비용이 커질 수 있다. 통계와 실제 rows/loops가 맞는지 확인하고 `(created_at, ...)` 또는 별도 파티션·정렬 경로가 더 적합한지 비교한다. ICP가 기대한 만큼 Base Table 접근을 줄이지 않거나 MRR의 버퍼링 비용이 더 크면 기능을 강제하지 말고 같은 데이터에서 대안 계획·p95·I/O를 재측정한다.

참고: [MySQL 8.4 Index Merge Optimization](https://dev.mysql.com/doc/refman/8.4/en/index-merge-optimization.html), [MySQL 8.4 Skip Scan Range Access Method](https://dev.mysql.com/doc/refman/8.4/en/range-optimization.html), [MySQL 8.4 Index Condition Pushdown](https://dev.mysql.com/doc/refman/8.4/en/index-condition-pushdown-optimization.html), [MySQL 8.4 Multi-Range Read](https://dev.mysql.com/doc/refman/8.4/en/mrr-optimization.html)

## 4. 튜닝 순서

1. 필요한 행 수와 반환 컬럼을 줄인다.
2. 실제 조건·정렬에 맞는 복합 인덱스를 먼저 검토한다.
3. `EXPLAIN ANALYZE`로 추정치와 실측치를 비교한다.
4. Index Merge·Skip Scan·ICP·MRR은 결과로 관찰하고, 힌트로 강제할 때는 배포 데이터 분포 변화까지 감시한다.

> **면접 포인트** — 인덱스 개수를 늘리는 것이 답이 아니다. 옵티마이저가 읽은 인덱스 레코드 수와 Base Table 페이지 수를 분리해 설명하면 각 최적화의 목적이 선명해진다.

## 참고

- [MySQL 8.4 Index Merge Optimization](https://dev.mysql.com/doc/refman/8.4/en/index-merge-optimization.html)
- [MySQL 8.4 SELECT Optimization](https://dev.mysql.com/doc/refman/8.4/en/select-optimization.html)
