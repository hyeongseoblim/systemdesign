---
area: SYSTEM_DESIGN
mode: DESIGN
coach: system-design-coach
title: "분산 락 설계 — Lease·Fencing Token·장애 복구"
slug: system-design-21-distributed-lock-design
topicKey: system-design-136
difficulty: 5
summary: "Lease 만료만으로 막지 못하는 지연된 소유자의 쓰기를 Fencing Token으로 차단하는 분산 락을 설계한다."
tags:
  - "Distributed Lock"
  - "Lease"
  - "Fencing Token"
  - "Consensus"
questions:
  - "프로세스 정지로 Lease가 만료된 뒤 기존 소유자가 다시 실행되면 어떤 안전성 문제가 생기나요?"
  - "단조 증가 Fencing Token을 저장 시스템이 검증해야 하는 이유를 설명해보세요."
  - "락보다 낙관적 동시성이나 단일 Writer가 더 적합한 사례는 무엇인가요?"
---
## 1. 락 획득과 쓰기 권한은 다르다

Lease는 죽은 소유자의 자원을 회수하지만, 네트워크 지연이나 긴 GC 뒤에 돌아온 이전 소유자가 쓰는 것을 혼자 막지 못한다. 락 서비스가 증가하는 Token을 발급하고 실제 자원이 더 작은 Token을 거부해야 한다.

```mermaid
sequenceDiagram
    participant A as Worker A
    participant L as Lock Service
    participant R as Resource
    participant B as Worker B
    A->>L: acquire
    L-->>A: token=41
    Note over A: 긴 정지, lease 만료
    B->>L: acquire
    L-->>B: token=42
    B->>R: write(token=42)
    A->>R: late write(token=41)
    R-->>A: reject
```

| 방식 | 적합한 상황 | 한계 |
|---|---|---|
| DB 조건부 갱신 | 한 레코드 경쟁 | 범용 자원 조정 어려움 |
| 단일 Writer | 키별 순차 처리 | 라우팅·복구 설계 필요 |
| Lease | 제한 시간 소유 | 지연된 쓰기 차단 불충분 |
| Lease+Fencing | 외부 자원 보호 | 자원의 Token 검증 필요 |

```text
accept write only when incoming_fence >= last_accepted_fence
persist last_accepted_fence with the protected mutation
```

> **실무 함정** — 락 획득 성공을 작업 성공으로 간주하면 안 된다. Lease 갱신 실패, 세션 단절, 작업의 멱등성을 별도로 처리한다.

## 2. 운영 기준

합의 기반 세션의 가용성, 획득 지연, 만료 횟수, Token 거절량을 관측한다. 결제처럼 정합성이 핵심이면 락보다 데이터베이스 제약과 상태 전이를 우선 검토한다.

> **면접 포인트** — “Redis로 락”보다 실패 모델과 보호 대상이 Token을 검증하는 끝단 안전성을 설명한다.
