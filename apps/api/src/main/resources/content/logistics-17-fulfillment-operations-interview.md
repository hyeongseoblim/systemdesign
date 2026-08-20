---
area: LOGISTICS
mode: INTERVIEW
coach: logistics-coach
title: "풀필먼트 운영 면접 — 병목·WIP·예외 흐름"
slug: logistics-17-fulfillment-operations-interview
topicKey: logistics-158
difficulty: 4
summary: "입고부터 출고까지 공정별 처리량과 재공품을 계산하고 병목 및 예외를 운영 지표로 해결하는 면접 프레임을 익힌다."
tags:
  - "Fulfillment Center"
  - "Bottleneck"
  - "WIP"
  - "Operations"
questions:
  - "시간당 주문이 처리 능력을 넘을 때 어느 공정이 병목인지 어떤 지표로 찾나요?"
  - "Pick 효율을 높이는 Wave가 주문 리드타임을 악화시킬 수 있는 이유는 무엇인가요?"
  - "재고 불일치 주문을 정상 흐름과 분리하고 다시 합류시키는 절차를 설계해보세요."
---
## 1. 흐름과 대기열을 그린다

처리량은 가장 느린 공정에 제한되고, 병목 앞 WIP가 증가한다. 평균 생산성만 보지 말고 주문 유형과 시간대별 도착률, 처리율, 대기 시간, 재작업률을 함께 본다.

```mermaid
flowchart LR
    I[입고] --> S[Putaway]
    S --> P[Picking]
    P --> K[Packing]
    K --> O[Sort·출고]
    P --> E[Short 예외]
    E --> K
```

| 관찰 | 가능한 원인 | 첫 대응 |
|---|---|---|
| Pick 앞 WIP 증가 | Replenishment·동선 병목 | 재고 보충·Zone 균형 |
| Pack 재작업 증가 | 상품·라벨 오류 | 원인 코드 분리 |
| 출차 Miss | Wave 종료와 Cutoff 불일치 | 우선순위·Buffer 조정 |
| Short 증가 | 장부·실물 불일치 | 예외 격리·Cycle Count |

```text
WIP ≈ throughput × flow_time
capacity_by_hour = workers × units_per_worker_hour × availability
```

> **면접 전략** — 인력을 늘리기 전에 도착률과 처리율을 같은 시간축으로 비교한다. 병목이 아닌 공정 증원은 WIP만 옮길 수 있다.

## 2. 예외를 제품으로 본다

Short, 파손, 라벨 실패는 수작업으로 숨기지 말고 사유·소유자·SLA가 있는 큐로 만든다. 정상 주문의 흐름을 보호하면서 복구 후 어느 단계로 합류할지 정의한다.

> **면접 포인트** — 알고리즘뿐 아니라 현장 Scan, 작업자 화면, Cutoff, 장애 때의 수동 운영까지 답변에 포함한다.
