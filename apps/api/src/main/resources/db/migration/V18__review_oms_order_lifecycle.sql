-- logistics-01-oms-order-management deep review. Existing card and question IDs are preserved.
UPDATE cards
SET content_md = $oms_review$## 1. OMS가 책임지는 것과 다른 시스템이 책임지는 것

OMS(Order Management System, 주문관리 시스템)는 채널의 주문을 접수하고, 업무 정책에 따라 검증·이행 경로를 조정하며, 주문 진행 상황을 고객과 운영자에게 보여주는 역할을 맡을 수 있다. 하지만 회사마다 시스템 경계와 데이터 소유권은 다르다. OMS가 결제 원장, 창고의 실물 수량, 운송사의 배송 기록까지 모두 대체하는 단일 진실 원천이라고 가정하지 않는다.

| 관심사 | 보통 두는 책임 경계 | 확인할 계약 |
| --- | --- | --- |
| 주문 접수와 이행 의도 | OMS 또는 상거래 서비스 | 주문·라인 식별자, 변경/취소 가능 시점 |
| 위치별 재고와 창고 작업 | WMS 또는 재고 서비스 | 가용성, 예약, 피킹·출고 확정 시점 |
| 운송장과 배송 진행 | 운송사 연동 또는 TMS | 상태 이벤트의 중복·순서·정정 규칙 |
| 승인·매입·환불 | PG와 내부 결제 원장 | 금액, 외부 참조 ID, 결과 불명 조회 |

연동 경계에서는 각 시스템이 무엇을 확정하고 어떤 이벤트를 보내는지 정의한다. OMS의 주문 화면은 이런 사실을 합쳐 보여주는 투영일 수 있으며, 원천 시스템의 기록과 불일치하면 대사 절차가 필요하다.

## 2. 상태는 객체의 범위에 맞춰 나눈다

`isPaid`, `isShipped`, `isCanceled` 같은 Boolean을 늘리면 조합은 많아지지만 허용되는 조합은 분명하지 않다. 예를 들어 취소된 주문이 배송 중인지, 일부만 매입됐는지 플래그만으로 판단하기 어렵다. 상태 머신은 객체별 허용 전이와 검증 지점을 명확히 한다. Enum만 도입한다고 잘못된 전이·중복 이벤트·감사 기록이 자동으로 해결되지는 않는다.

```mermaid
stateDiagram-v2
    state "OrderLine / fulfillment intent" as L {
        [*] --> ACCEPTED
        ACCEPTED --> ALLOCATED
        ACCEPTED --> CANCELLED
        ALLOCATED --> FULFILLING
        ALLOCATED --> CANCELLED
        FULFILLING --> PARTIALLY_FULFILLED
        FULFILLING --> FULFILLED
        PARTIALLY_FULFILLED --> FULFILLED
        PARTIALLY_FULFILLED --> CANCELLED_REMAINDER
    }
    state "Shipment" as S {
        [*] --> CREATED
        CREATED --> DISPATCHED
        DISPATCHED --> IN_TRANSIT
        IN_TRANSIT --> DELIVERED
        IN_TRANSIT --> EXCEPTION
        EXCEPTION --> IN_TRANSIT
        EXCEPTION --> RETURN_TO_SENDER
    }
```

이 그림은 개념 예시다. 결제 상태는 별도 객체에 두고, 실제 주문 헤더 상태는 제품 정책에 맞는 집계 규칙으로 계산하거나 저장한다. 한 enum에 결제·출고·반품을 전부 넣지 않는다.

한 주문 라인의 일부 수량이 배송 단위로 나뉘면 이벤트도 대상 Shipment와 이행 라인을 식별해야 한다. 아래는 형태를 설명하기 위한 예시이며, 실제 필드와 상태 사전은 연동 계약에서 정의한다.

```json
{
  "eventId": "evt-42",
  "type": "ShipmentDispatched",
  "orderLineId": "line-7",
  "shipmentId": "ship-2",
  "occurredAt": "2026-09-22T10:30:00Z"
}
```

전이 저장에는 보통 현재 상태 조건이나 버전 비교를 사용해 동시 갱신을 판정하고, 상태 변경과 도메인 이벤트 기록을 원자적으로 묶는다. 재시도는 명령별 멱등 키와 유일성 제약 등으로 중복 효과를 막는다. 이런 영속성 규칙이 있어야 감사와 멱등성이 구현된다.

## 3. Allocation은 제약과 정책을 함께 푼다

Allocation(할당)은 각 주문 라인의 수량을 공급 위치·창고·이행 경로에 연결하는 결정이다. 거리나 배송비 하나를 최소화하면 된다고 단정할 수 없다. 고객 약속일, 판매 가능 수량, 창고 처리 능력, 온도·위험물 제약, 분할 허용 여부와 비용을 정책으로 표현한다.

| 결정 | 검토할 조건 |
| --- | --- |
| 한 창고에서 전량 이행 | 요청 수량의 예약 성공, 약속일, 위치 적합성 |
| 여러 창고로 분할 | 부분 이행 허용, 추가 배송비·포장, 고객 안내 |
| 대기 또는 대체 경로 | 다음 공급 가능 시점, 고객 동의, 취소 정책 |

할당 후보를 조회한 뒤 예약하기까지 재고가 바뀔 수 있다. 그래서 가용 수량 조회만 믿지 말고 예약 응답을 최종 판정으로 다루며, 실패 시 재조회·다른 후보 선택·주문 보류 중 어느 정책을 적용할지 정한다. 다른 창고로 재할당도 무조건 가능한 보상은 아니다. 이미 확정된 작업과 고객 약속을 확인해야 한다.

## 4. 주문 라인과 배송은 1:1이 아닐 수 있다

한 라인의 수량이 여러 위치에서 나뉘거나, 일부만 먼저 준비되거나, 상품 특성상 포장이 달라지면 이행 라인과 배송 단위가 나뉠 수 있다. 실제 데이터 모델은 부분 수량과 출고 관계를 추적해야 한다. 예컨대 주문 라인 3개 중 두 개가 배송 완료되고 나머지 라인이 배송 예외라면, 헤더를 `DELIVERED`로 덮어쓰지 말고 미완료 라인과 예외 Shipment를 유지한다.

헤더 상태는 예를 들어 `PARTIALLY_FULFILLED`처럼 진행을 요약하거나 하위 상태에서 계산할 수 있다. 무엇이 고객에게 보이는 상태인지와 운영용 상태는 분리할 수 있다. 실패한 Shipment는 운송사 재시도, 재출고, 반송 확인, 잔여 라인 취소 등 원인과 정책에 맞춰 처리한다. 전액 주문 취소나 환불을 자동으로 실행하면 이미 배송된 라인과 충돌할 수 있다.

## 5. 결제와 재고 사이의 분산 실패

결제 승인(authorization)과 매입(capture)을 분리할 수 있지만, 가능한 시점과 유효 기간은 PG·결제 수단·업무 정책에 따라 다르다. 예를 들어 일부 결제 API는 수동 매입을 지원한다. 그러므로 “모든 주문은 배송 때 매입한다”를 보편 규칙으로 쓰지 말고, 승인 만료와 부분 매입 지원을 확인한다.

```mermaid
sequenceDiagram
    participant O as 주문 서비스
    participant P as 결제 제공자
    participant I as 재고/WMS
    O->>P: 결제 요청 (업무별 멱등 키)
    P-->>O: 승인 또는 매입 결과
    O->>I: 재고 예약
    I-->>O: 예약 성공 또는 실패
    Note over O,P: 이미 승인됨 + 예약 실패: 승인 취소/해제 가능 여부 확인
    Note over O,P: 이미 매입됨 + 취소 확정: 환불 절차와 대사
```

이 단계는 여러 시스템에 걸친 Saga로 모델링할 수 있다. 보상은 원래 동작의 역연산이 아니라 현재까지 확정된 사실에 맞춘 새 업무 명령이다. 예약이 실패했을 때 승인만 된 결제라면 PG의 취소/승인 해제 동작을 확인하고, 이미 매입된 결제라면 환불을 검토한다. PG 응답이 시간 초과되어 결과가 불명확하면 같은 작업을 새 키로 반복하지 말고 외부 참조 ID나 대사 API로 먼저 확인한다.

멱등 키는 재시도된 동일 명령이 중복 실행되는 위험을 줄인다. 키의 범위·보존 기간·같은 키의 파라미터 규칙은 제공자별로 확인하고, 애플리케이션도 결제 명령 ID와 처리 상태를 영속화한다. Saga 진행 기록, 재시도, 보상 실패 큐, 주기적 대사를 함께 설계한다.

## 6. 큐와 이벤트는 필요한 보장을 기준으로 선택한다

주문 저장과 외부 이벤트 발행을 연결한다면 Transactional Outbox가 커밋과 발행 사이의 유실 구간을 줄이는 한 방법이다. 소비자는 중복 전달을 전제로 멱등하게 처리하고, 순서 보장 범위와 재처리 절차를 정한다. 큐를 도입하는 이유는 피크 흡수, 하류 장애 격리, 비동기 처리 등 구체적인 요구여야 한다. 특정 브로커가 모든 OMS의 표준이라고 말할 수 없다.

회사 사례를 설명할 때는 공개 문서가 확인해 주는 범위만 사실로 말한다. 내부 할당 로직, 마감 시각, 분할 배송 비율은 근거 없는 추측으로 제시하지 않는다. 비교가 필요하면 “가상 설계 A는 빠른 부분 출고를, B는 합배송을 우선한다”처럼 가정임을 밝힌다.

## 면접에서 답할 때

먼저 Order, OrderLine, Shipment, Payment 중 어떤 객체의 상태인지 밝힌다. 이어 부분 이행과 취소를 어떤 수량·전이로 기록할지, 외부 호출의 결과 불명과 재시도를 어떻게 대사할지 설명한다. 상태 이름이나 메시지 브로커를 나열하는 것보다 시스템 간 확정 시점과 실패 복구를 구체적으로 말한다.

> **면접 포인트**
>
> 헤더 상태는 요약 정보다. 부분 이행을 보존하는 하위 객체와 외부 시스템의 확정 사실을 먼저 모델링하고, 그 위에 고객용 요약 규칙을 둔다.

## 참고 자료

- [Oracle Fusion Cloud Order Management — Split Order Lines](https://docs.oracle.com/en/cloud/saas/supply-chain-and-manufacturing/25d/fauom/split-fulfillment-lines.html)
- [Oracle Fusion Cloud Order Management — Source Orders and Fulfillment Lines](https://docs.oracle.com/en/cloud/saas/supply-chain-and-manufacturing/25c/fauom/how-order-management-transforms-source-orders-into-sales-orders.html)
- [Stripe API — Confirm a PaymentIntent and capture method](https://docs.stripe.com/api/payment_intents/confirm)
- [Stripe API — Idempotent requests](https://docs.stripe.com/api/idempotent_requests)$oms_review$
WHERE slug = 'logistics-01-oms-order-management' AND source = 'MANUAL';
