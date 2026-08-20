---
area: LOGISTICS
mode: CONCEPT
coach: logistics-domain-coach
title: "재고 원장 설계 — 이중기입·트랜잭션 로그·잔액 스냅샷"
slug: logistics-11-inventory-ledger
topicKey: logistics-109
difficulty: 4
summary: "현재고 숫자를 직접 고치는 대신 이동 원인을 불변 원장으로 남기고, 잔액은 검증 가능한 결과로 계산한다."
tags:
  - "Inventory Ledger"
  - "Double Entry"
  - "Reservation"
  - "Reconciliation"
  - "Audit"
questions:
  - "창고 A에서 B로 10개를 이동하는 재고 원장 Entry를 이중기입으로 표현하고, 한쪽만 반영되는 것을 어떻게 막을지 설명해보세요."
  - "원장 합산 조회가 느려 Snapshot을 도입할 때 Snapshot 시점 이후 이벤트의 누락·중복을 방지하는 키를 설계해보세요."
  - "실물 재고와 시스템 재고가 다를 때 기존 원장을 수정하지 않고 조정하는 절차와 감사 정보를 설명해보세요."
---
## 1. 잔액보다 변화를 먼저 저장한다

`inventory.quantity = 42`만 저장하면 왜 42가 됐는지 복원하기 어렵다. 재고 원장은 입고, 예약, 출고, 이동, 조정이라는 변화의 원인을 불변 Entry로 남기고 현재 잔액을 그 결과로 계산한다.

```mermaid
flowchart LR
    RECEIVE[입고 +100] --> LEDGER[(Inventory Ledger)]
    RESERVE[예약 Available -3\nReserved +3] --> LEDGER
    SHIP[출고 Reserved -3\nShipped +3] --> LEDGER
    ADJUST[실사 조정 -1] --> LEDGER
    LEDGER --> SNAP[Balance Snapshot]
    SNAP --> VIEW[Available / Reserved / On-hand]
```

| 모델 | 장점 | 위험·보완 |
|---|---|---|
| 잔액 직접 갱신 | 조회·구현 단순 | 원인 추적과 복구 어려움 |
| 단일 Entry 원장 | 변화 이력 보존 | 상대 계정 누락 가능 |
| 이중기입 원장 | 이동의 합계 불변식 검증 | Entry 수와 모델 복잡도 증가 |
| 원장+Snapshot | 빠른 조회와 감사성 결합 | Snapshot 기준점 관리 필요 |

## 2. 이동은 합계가 0이어야 한다

창고 간 이동이나 상태 간 전환은 같은 Transaction ID 아래 Debit/Credit Entry로 기록한다. 수량 단위의 부호 합계가 0이라는 불변식을 커밋 전에 검사하면 한쪽만 반영되는 오류를 차단할 수 있다.

```sql
CREATE TABLE inventory_ledger (
    entry_id UUID PRIMARY KEY,
    transaction_id UUID NOT NULL,
    sku_id UUID NOT NULL,
    location_id UUID NOT NULL,
    bucket VARCHAR(30) NOT NULL,
    quantity_delta NUMERIC(18, 3) NOT NULL,
    reason VARCHAR(40) NOT NULL,
    idempotency_key VARCHAR(120) NOT NULL UNIQUE,
    occurred_at TIMESTAMPTZ NOT NULL
);
```

예약은 `AVAILABLE -N`, `RESERVED +N`, 출고는 `RESERVED -N`, `SHIPPED +N`처럼 상태 버킷 사이의 이동으로 표현한다. 실제 총 On-hand가 줄어드는 폐기·손실도 명시적인 조정 상대 계정을 둔다.

> **실무 함정** — 과거 Entry를 UPDATE/DELETE하면 이미 생성한 정산·감사 결과와 불일치한다. 오류는 원 Entry를 참조하는 반대 Entry와 올바른 재기입으로 수정한다.

## 3. Snapshot과 대사

Snapshot에는 `(sku, location, bucket)` 잔액과 마지막 반영 순서 또는 Entry ID를 함께 저장한다. 조회는 Snapshot 이후 Entry만 합산한다. 주기적 대사는 원장 합계, Snapshot, 운영 Projection, 실물 실사를 비교하고 차이는 원인 코드가 있는 조정 Entry로 남긴다.

> **면접 포인트** — Event Sourcing 전체를 도입하지 않아도 재고처럼 감사성이 중요한 수량에는 불변 원장과 Projection을 분리할 수 있다. 핵심은 멱등 키와 합계 불변식이다.
