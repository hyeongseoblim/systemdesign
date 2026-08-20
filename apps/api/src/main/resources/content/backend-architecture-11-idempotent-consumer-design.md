---
area: BACKEND_ARCHITECTURE
mode: DESIGN
coach: backend-architecture-coach
title: "멱등 이벤트 소비 파이프라인 설계"
slug: backend-architecture-11-idempotent-consumer-design
topicKey: backend-architecture-257
difficulty: 4
summary: "At-least-once 전달에서 Inbox, 비즈니스 트랜잭션, 재시도와 DLQ를 결합해 중복 부작용을 막는다."
tags:
  - "Idempotency"
  - "Inbox"
  - "Retry"
  - "DLQ"
questions:
  - "메시지 ACK 직전에 프로세스가 죽을 때 중복 처리를 막는 트랜잭션 경계를 설명해보세요."
  - "Event ID 중복 제거만으로 충분하지 않은 장기 재전송·업무 키 사례는 무엇인가요?"
  - "DLQ 메시지를 수정 후 재처리할 때 순서와 멱등성을 어떻게 보장하나요?"
---
## 1. 전달과 효과를 분리한다

Broker의 At-least-once 전달은 정상이다. 소비자는 Event ID를 Inbox에 기록하고 비즈니스 변경을 같은 DB 트랜잭션에 넣어 한 효과만 커밋한다. ACK는 커밋 뒤 수행한다.

```mermaid
sequenceDiagram
    participant B as Broker
    participant C as Consumer
    participant D as DB
    B->>C: event E
    C->>D: begin; insert inbox(E)
    C->>D: business update; commit
    C-->>B: ACK
    B->>C: E redelivery
    C->>D: inbox conflict → skip
```

| 실패 | 결과 | 처리 |
|---|---|---|
| 커밋 전 종료 | 효과 없음 | 재전달 처리 |
| 커밋 후 ACK 전 종료 | 중복 전달 | Inbox로 Skip |
| 영구 검증 오류 | 반복 실패 | 격리·수동 판단 |
| 일시 외부 장애 | 재시도 | Backoff·Jitter·한도 |

```sql
INSERT INTO consumer_inbox(consumer, event_id, received_at)
VALUES (:consumer, :eventId, now())
ON CONFLICT DO NOTHING;
```

> **실무 함정** — Inbox 삽입과 비즈니스 변경이 다른 트랜잭션이면 “처리했다고 기록했지만 효과는 없는” 데이터 손실이 생긴다.

## 2. 외부 부작용

외부 결제나 메일은 같은 DB 트랜잭션에 넣을 수 없다. 내부 Outbox에 명령을 기록하고 외부 시스템이 지원하는 멱등 키로 별도 전달한다.

> **면접 포인트** — Exactly-once라는 표현 대신 어느 경계에서 중복 전달을 허용하고 어디서 효과를 한 번으로 만드는지 명확히 한다.
