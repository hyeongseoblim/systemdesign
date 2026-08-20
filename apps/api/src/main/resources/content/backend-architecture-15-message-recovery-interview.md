---
area: BACKEND_ARCHITECTURE
mode: INTERVIEW
coach: backend-architecture-coach
title: "메시지 유실·중복 장애 면접 — 탐지와 정합성 복구"
slug: backend-architecture-15-message-recovery-interview
topicKey: backend-architecture-278
difficulty: 5
summary: "발행·전달·소비 경계의 장애를 분리하고 Outbox, Inbox, 대사와 보정 이벤트로 정합성을 복구하는 면접 연습을 한다."
tags:
  - "Messaging"
  - "Outbox"
  - "Recovery"
  - "Reconciliation"
questions:
  - "DB 변경은 커밋됐지만 이벤트가 발행되지 않은 장애를 어떻게 탐지하고 복구하나요?"
  - "소비자 DB 커밋 후 ACK 전에 죽은 경우 어떤 중복이 발생하며 어떻게 차단하나요?"
  - "이미 고객에게 잘못 노출된 상태를 수정할 때 재생과 보정 이벤트 중 무엇을 선택하나요?"
---
## 1. 손실처럼 보이는 위치를 분해한다

생산자 DB와 Broker 사이, Broker 보존, 소비자 처리, 조회 투영 사이에 각각 다른 실패가 있다. Correlation ID와 단계별 상태를 연결해 “발행 안 됨”과 “소비 지연”을 먼저 구분한다.

```mermaid
flowchart LR
    D[(Producer DB)] --> O[(Outbox)]
    O --> B[(Broker)]
    B --> I[(Consumer Inbox)]
    I --> V[(Business DB)]
    V --> Q[Read Model]
    A[Reconciliation] -.대사.-> D
    A -.대사.-> Q
```

| 장애 경계 | 안전장치 | 복구 증거 |
|---|---|---|
| DB→Broker | Transactional Outbox | 미발행 Outbox |
| Broker→Consumer | ACK·보존 | Offset·Lag |
| Consumer 효과 | Inbox·멱등 키 | Event ID·업무 키 |
| 투영 | 재생·Version | 원본과 Checksum |

```text
recover in order: stop amplification → define source of truth → scope affected keys → replay or compensate → reconcile
```

> **면접 전략** — 재처리를 바로 실행하지 않는다. 비멱등 부작용과 잘못된 이벤트 자체를 다시 적용할 위험을 먼저 분류한다.

## 2. 복구도 정상 기능으로 만든다

기간·업무 키로 제한된 Replay, Dry Run, 처리율 제한, 결과 대사를 제공한다. 사실 기록이 잘못됐다면 삭제보다 원본을 상쇄하는 보정 이벤트가 감사에 유리하다.

> **면접 포인트** — 예방 패턴뿐 아니라 장애 탐지 시간, 영향 범위 산정, 고객 상태 복구와 재발 방지까지 닫는다.
