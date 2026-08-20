---
area: LOGISTICS
mode: DESIGN
coach: logistics-coach
title: "익일·당일 배송망 설계 — 주문 약속부터 라스트마일까지"
slug: logistics-15-rocket-delivery-design
topicKey: logistics-361
difficulty: 5
summary: "로켓배송 유형의 빠른 배송 서비스를 재고 배치, 주문 컷오프, 출고 파동, 간선·라스트마일 용량으로 설계한다."
tags:
  - "Fast Delivery"
  - "Order Promise"
  - "Fulfillment"
  - "Last Mile"
questions:
  - "결제 화면의 도착 약속을 재고와 각 운송 구간 용량으로 어떻게 계산하나요?"
  - "컷오프 직전 주문 폭증 때 어떤 주문을 어느 센터에서 처리할지 설계해보세요."
  - "빠른 배송률만 최적화할 때 비용과 현장 품질에 생기는 부작용은 무엇인가요?"
---
## 1. 하나의 종단 SLO로 연결한다

특정 회사 구현을 추정하지 않고, 빠른 배송 제품에 필요한 일반 설계를 다룬다. 약속 시각은 재고 보유 여부뿐 아니라 Pick·Pack 용량, 출차 Cutoff, Hub 처리량, 배송 권역별 잔여 Stop으로 계산한다.

```mermaid
flowchart LR
    O[주문·약속] --> F[FC Pick/Pack]
    F --> L[간선 출차]
    L --> H[지역 Hub]
    H --> R[Route·Last Mile]
    R --> D[고객 도착]
    C[구간별 용량] --> O
```

| 계층 | 핵심 결정 | 보호 장치 |
|---|---|---|
| 재고 배치 | 수요 예측·센터별 Safety Stock | 센터 간 전송 |
| 주문 약속 | Cutoff·잔여 용량 | 보수적 Buffer |
| 출고 | Wave·우선순위 | 병목 공정 WIP 제한 |
| 배송 | Stop·시간창·기사 용량 | 재경로·예외 인계 |

```text
promise_at = max(inventory_ready, pick_pack_done, linehaul_arrival, route_eta)
accept only if every constrained leg reserves capacity
```

> **설계 원칙** — 평균 처리량으로 약속하면 꼬리 지연이 고객 지연이 된다. 권역·시간대별 분위수와 날씨·프로모션 Buffer를 반영한다.

## 2. 품질과 비용

정시 도착률과 함께 약속 정확도, 단위 주문 비용, 재배송률, 작업자 과부하, 재고 이동량을 본다. 장애 시 전체 약속을 끄기보다 영향 권역과 구간만 용량을 낮춘다.

> **면접 포인트** — 브랜드 이름보다 수요→재고→시설→운송의 제약 전파와 약속을 지키지 못할 때의 감쇠 전략을 설명한다.
