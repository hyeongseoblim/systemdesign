---
area: SYSTEM_DESIGN
mode: DESIGN
coach: system-design-coach
title: "메시지 큐 선택 설계 — 로그·작업 큐·라우팅"
slug: system-design-26-message-queue-selection
topicKey: system-design-164
difficulty: 4
summary: "Kafka, RabbitMQ, SQS 유형의 시스템을 제품명이 아니라 보존·재생·라우팅·순서와 운영 요구로 선택한다."
tags:
  - "Message Queue"
  - "Kafka"
  - "RabbitMQ"
  - "SQS"
questions:
  - "이벤트 재생이 필요한 감사 파이프라인과 한 번 처리 후 사라지는 작업 큐의 요구 차이는 무엇인가요?"
  - "전역 순서 대신 키별 순서를 선택해야 처리량이 확장되는 이유를 설명해보세요."
  - "메시지 Broker 교체 가능성을 높이려다 최소 공통 기능만 쓰면 어떤 비용이 생기나요?"
---
## 1. 메시지의 수명을 먼저 결정한다

이벤트 로그는 여러 소비자가 각자의 Offset으로 재생하고 장기간 보존한다. 작업 큐는 가용 Worker 하나에게 작업을 넘기고 ACK·Visibility Timeout으로 재전달한다. 복잡한 라우팅은 Exchange 유형과 Header 규칙이 중요하다.

```mermaid
flowchart TD
    R[요구사항] --> L{재생·다중 구독?}
    L -->|예| E[Partitioned Event Log]
    L -->|아니오| Q{복잡한 라우팅?}
    Q -->|예| B[Broker Queue·Exchange]
    Q -->|아니오| M[Managed Work Queue]
```

| 기준 | 이벤트 로그형 | Broker 큐형 | 관리형 작업 큐형 |
|---|---|---|---|
| 보존·재생 | 강점 | 제한적 | 제한적 |
| 라우팅 | Topic·Partition 중심 | Exchange·Binding | Queue·속성 중심 |
| 순서 | Partition별 | Queue 구성별 | 그룹/Queue별 |
| 운영 | Cluster·Partition 관리 | Broker 운영 | 공급자 제약 |

```text
required_throughput = peak_messages_per_second * retry_amplification
partition_count >= max(throughput_need, desired_parallel_consumers)
```

> **설계 원칙** — “Exactly-once 지원” 문구보다 생산자, Broker, 소비자 DB를 잇는 종단 효과가 멱등한지 확인한다.

## 2. 실패 모델을 계약에 넣는다

중복, 순서 역전, 독약 메시지, 긴 처리, Backlog 보존 한도를 정한다. 메시지 크기가 크면 객체 저장소에 본문을 두고 Broker에는 검증 가능한 참조를 전달한다.

> **면접 포인트** — 제품 비교표를 암기하기보다 메시지 수명과 소비 모델을 정한 뒤 후보를 좁힌다.
