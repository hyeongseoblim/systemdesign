---
area: INFRA
mode: CONCEPT
coach: infra-coach
title: "Kubernetes 자원 관리 — Requests·Limits·QoS"
slug: infra-12-kubernetes-resource-management
topicKey: infra-135
difficulty: 4
summary: "Scheduler의 Requests와 Runtime의 Limits, QoS·OOMKilled·CPU Throttling의 관계를 이해해 자원을 설정한다."
tags:
  - "Kubernetes"
  - "Resources"
  - "QoS"
  - "OOMKilled"
questions:
  - "CPU Request와 Limit이 Scheduling 및 실행 중 Throttling에 각각 어떻게 작용하나요?"
  - "메모리 Limit 초과가 CPU처럼 느려지는 대신 종료로 이어질 수 있는 이유는 무엇인가요?"
  - "Request를 평균 사용량에만 맞출 때 Node 과밀과 Eviction에 어떤 문제가 생기나요?"
---
## 1. 예약과 상한을 구분한다

Scheduler는 Requests를 기준으로 Pod를 배치한다. CPU Limit은 Cgroup 실행 시간을 제한해 Throttling을 만들 수 있고, 메모리 Limit 초과는 OOM 종료로 이어질 수 있다. 애플리케이션 Runtime 설정도 컨테이너 상한 안에 둔다.

```mermaid
flowchart LR
    P[Pod Spec] --> R[Requests]
    R --> S[Scheduler Placement]
    P --> L[Limits]
    L --> C[Cgroup Enforcement]
    C --> T[CPU Throttle]
    C --> O[Memory OOM]
```

| 설정 | 주요 사용처 | 잘못 설정한 증상 |
|---|---|---|
| CPU Request | 배치·공유 가중치 | 과소: 경합, 과대: 미배치 |
| CPU Limit | 실행 상한 | 꼬리 지연·Throttling |
| Memory Request | 배치·Eviction 판단 | Node 압박 |
| Memory Limit | 강제 상한 | OOMKilled·재시작 |

```yaml
resources:
  requests: { cpu: "500m", memory: "512Mi" }
  limits: { memory: "768Mi" }
```

> **운영 함정** — JVM Heap을 메모리 Limit과 같게 잡으면 Native Memory와 Thread Stack 공간이 없다. 프로세스 전체 RSS 여유를 둔다.

## 2. 분위수와 실패 비용으로 조정한다

평균보다 시간대별 분위수, Startup Peak, GC, OOM·Throttle 지표를 본다. Vertical 권고를 참고하되 Replica 수와 장애 시 재배치 여유까지 함께 검증한다.

> **면접 포인트** — 모든 Pod에 같은 비율을 적용하지 말고 Burst 허용, 지연 SLO, 종료 비용에 따라 Limit 정책을 설명한다.

## 참고

- [Kubernetes Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
