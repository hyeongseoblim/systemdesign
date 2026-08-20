---
area: SYSTEM_DESIGN
mode: CONCEPT
coach: system-design-coach
title: "트랜잭션 격리 심화 — Write Skew·Phantom·SSI"
slug: system-design-25-transaction-isolation
topicKey: system-design-115
difficulty: 5
summary: "격리 수준을 현상 이름이 아니라 애플리케이션 불변식으로 평가하고 Write Skew와 직렬화 실패를 안전하게 처리한다."
tags:
  - "Transaction Isolation"
  - "Write Skew"
  - "Serializable"
  - "SSI"
questions:
  - "Snapshot Isolation에서 두 트랜잭션이 서로 다른 행을 수정해 불변식을 깨는 Write Skew를 설명해보세요."
  - "Predicate Lock과 Serializable Snapshot Isolation은 Phantom을 어떤 방식으로 다루나요?"
  - "직렬화 실패 재시도에서 전체 트랜잭션을 다시 실행해야 하는 이유는 무엇인가요?"
---
## 1. 읽은 집합까지 충돌의 일부다

두 의사가 모두 상대가 당직임을 읽고 각자 당직을 해제하면 같은 행을 쓰지 않아도 “최소 한 명 당직” 불변식이 깨진다. 행 쓰기 충돌만 탐지하는 Snapshot Isolation의 대표적인 Write Skew다.

```mermaid
sequenceDiagram
    participant A as Tx A
    participant B as Tx B
    participant D as Database
    A->>D: read B=on
    B->>D: read A=on
    A->>D: set A=off; commit
    B->>D: set B=off; commit
    Note over D: 불변식 위반
```

| 격리 접근 | 막는 방식 | 애플리케이션 책임 |
|---|---|---|
| Read Committed | 문장 단위 가시성 | 복합 불변식 보호 |
| Snapshot Isolation | 일관된 Snapshot·쓰기 충돌 | Write Skew 인지 |
| 명시적 Lock | 관련 행·범위 직렬화 | Lock 순서·범위 |
| Serializable/SSI | 위험한 의존성 탐지·중단 | Abort 전체 재시도 |

```sql
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT count(*) FROM doctors WHERE on_call;
UPDATE doctors SET on_call = false WHERE id = :me;
COMMIT;
```

> **설계 함정** — 격리 수준 이름은 DBMS마다 세부 보장이 다를 수 있다. 실제 엔진 문서와 재현 테스트로 필요한 이상 현상이 차단되는지 검증한다.

## 2. 재시도도 업무 계약이다

직렬화 실패는 정상적인 동시성 제어 결과다. DB 트랜잭션 전체를 새 Snapshot에서 재실행하고, 트랜잭션 안의 외부 호출은 Outbox 등으로 분리해 중복 부작용을 막는다.

> **면접 포인트** — “Serializable이 안전하다”에서 끝내지 말고 경합, Abort율, 재시도 예산과 불변식을 더 작은 범위로 만드는 대안을 설명한다.
