---
area: DATABASE
mode: DESIGN
coach: database-coach
title: "무중단 스키마 마이그레이션 설계 — Expand·Backfill·Contract"
slug: database-12-zero-downtime-migration
topicKey: database-272
difficulty: 5
summary: "구버전과 신버전 애플리케이션이 공존하도록 스키마를 확장하고 Backfill·검증 후 안전하게 축소한다."
tags:
  - "Schema Migration"
  - "Backfill"
  - "Expand Contract"
  - "Zero Downtime"
questions:
  - "큰 테이블에 NOT NULL 컬럼을 추가할 때 잠금과 기존 행을 어떻게 처리하나요?"
  - "Dual Write 없이 컬럼 형식을 전환하는 단계와 읽기 전환 기준을 설명해보세요."
  - "Backfill 중 최신 쓰기를 덮어쓰지 않도록 어떤 조건과 검증을 사용하나요?"
---
## 1. 배포 한 번에 의미를 바꾸지 않는다

먼저 호환 가능한 새 컬럼·테이블을 추가한다. 애플리케이션이 새 형식도 쓰게 한 뒤 과거 데이터를 작은 Batch로 채우고, 대사 후 읽기를 전환한다. 마지막에 구 경로를 제거한다.

```mermaid
flowchart LR
    E[Expand Schema] --> W[호환 Writer 배포]
    W --> B[Throttle Backfill]
    B --> V[대사·Shadow Read]
    V --> R[Read 전환]
    R --> C[Contract 제거]
```

| 단계 | 보호 장치 | 롤백 |
|---|---|---|
| Expand | 짧은 Lock 확인 | 미사용 구조 유지 |
| Write 전환 | 멱등 변환·관측 | 구 쓰기 유지 |
| Backfill | 작은 Batch·부하 제한 | 중단 후 재개 |
| Contract | 구 버전 0 확인 | 유예 기간 뒤 제거 |

```sql
UPDATE orders
SET normalized_code = normalize(legacy_code)
WHERE id > :cursor AND id <= :end
  AND normalized_code IS NULL;
```

> **실무 함정** — 애플리케이션 Dual Write 두 번이 원자적이지 않으면 불일치가 생긴다. 가능하면 DB 트랜잭션, 생성 컬럼, 변경 로그 등 한 기록에서 파생한다.

## 2. 완료를 데이터로 증명한다

Null 수, 구·신 값 불일치, Backfill 속도, 복제 지연, Lock 대기를 관측한다. Contract는 모든 실행 버전과 배치 작업이 구 필드를 쓰지 않음을 확인한 뒤 수행한다.

> **면접 포인트** — DDL 문법보다 혼합 버전 기간, 데이터 대사, 재시작 가능한 Cursor와 삭제의 비가역성을 설명한다.
