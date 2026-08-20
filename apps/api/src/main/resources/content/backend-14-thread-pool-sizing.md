---
area: BACKEND_DEV
mode: CONCEPT
coach: backend-dev-coach
title: "Thread Pool 사이징 — 처리율·대기·거부 정책"
slug: backend-14-thread-pool-sizing
topicKey: backend-dev-127
difficulty: 4
summary: "CPU와 I/O 대기 비율, 하위 시스템 용량을 기준으로 Thread 수와 Queue 상한, 포화 시 거부 정책을 설계한다."
tags:
  - "Thread Pool"
  - "Little's Law"
  - "Backpressure"
  - "Concurrency"
questions:
  - "I/O Bound 작업의 Thread 수를 CPU Core 수보다 크게 둘 수 있는 이유와 한계는 무엇인가요?"
  - "무제한 Queue가 최대 Thread 설정을 무력화하고 장애를 지연시킬 수 있는 이유는 무엇인가요?"
  - "CallerRuns 거부 정책이 Backpressure가 되는 조건과 위험을 설명해보세요."
---
## 1. Thread 수가 처리율을 무한히 늘리지 않는다

CPU 작업은 Core보다 많은 Runnable Thread가 Context Switch를 늘린다. I/O 작업은 대기 중 다른 Thread가 진행할 수 있지만 DB 연결, 외부 API 동시성 등 더 작은 하위 한도를 넘으면 Queue만 이동한다.

```mermaid
flowchart LR
    R[요청 도착] --> Q[Bounded Queue]
    Q --> T[Worker Threads]
    T --> D[(DB Pool)]
    T --> H[External API]
    Q -->|가득 참| X[Reject·Degrade]
```

| 변수 | 너무 작을 때 | 너무 클 때 |
|---|---|---|
| Thread | CPU·I/O 유휴 | 전환·메모리·하위 포화 |
| Queue | 짧은 Burst 거절 | 오래된 요청·OOM |
| Task Timeout | 조기 실패 | 자원 장기 점유 |
| Pool 분리 | 자원 비효율 | 장애 격리 실패 시 전파 |

```text
concurrency ≈ throughput × average_service_time
starting_threads ≈ cores × (1 + wait_time / compute_time)
```

> **설계 함정** — 공식은 시작점일 뿐이다. 꼬리 지연, Lock 경쟁, 하위 Pool과 컨테이너 CPU Quota를 실제 부하로 측정한다.

## 2. 포화를 명시적으로 드러낸다

활성 Thread, Queue 길이와 Age, 거절률, 작업 시간, 하위 호출 대기를 관측한다. 우선순위가 다른 작업은 Pool을 격리하고 이미 Deadline을 넘긴 작업은 실행 전에 폐기한다.

> **면접 포인트** — Thread 수 하나보다 Admission Control, Bounded Queue, Deadline과 실패 응답까지 포화 정책으로 설명한다.
