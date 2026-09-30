---
area: BACKEND_ARCHITECTURE
mode: CONCEPT
coach: backend-architecture-coach
title: "Aggregate 설계 규칙 — 불변식·크기·트랜잭션 경계"
slug: backend-architecture-08-aggregate-boundary
topicKey: backend-architecture-103
difficulty: 4
summary: "객체 그래프가 아니라 한 트랜잭션에서 반드시 지켜야 하는 불변식을 기준으로 Aggregate 경계를 정한다."
tags:
  - "DDD"
  - "Aggregate"
  - "Invariant"
  - "Transaction Boundary"
  - "Optimistic Lock"
questions:
  - "주문과 재고를 하나의 Aggregate로 묶으면 강한 일관성은 쉬워지지만 어떤 확장성·경합 문제가 생기는지 설명해보세요."
  - "Aggregate 밖의 객체를 ID로 참조해야 하는 이유와, 참조 대상의 최신 정보가 필요할 때 사용할 조회 전략을 제시해보세요."
  - "한 유스케이스가 두 Aggregate를 변경해야 할 때 단일 DB 트랜잭션, 도메인 이벤트, Saga 중 무엇을 선택할지 기준을 설명해보세요."
---
## 1. Aggregate는 동시 변경의 최소 단위다

`Aggregate(애그리게이트)`는 연관된 Entity와 Value Object의 묶음이며, 외부 변경은 Aggregate Root를 통해서만 들어온다. 핵심은 객체를 예쁘게 묶는 것이 아니라 “커밋 순간에 반드시 참이어야 하는 Invariant(불변식)”의 경계를 정하는 것이다.

```mermaid
flowchart LR
    API[Application Service] --> ORDER[Order Aggregate Root]
    ORDER --> LINE[OrderLine]
    ORDER --> ADDRESS[ShippingAddress VO]
    ORDER -. ID 참조 .-> CUSTOMER[Customer Aggregate]
    ORDER -->|OrderConfirmed 이벤트| BUS[Outbox/Event Bus]
    BUS --> INVENTORY[Inventory Aggregate]
```

| 경계 선택 | 장점 | 비용·위험 |
|---|---|---|
| 큰 Aggregate | 한 트랜잭션으로 많은 규칙 보장 | 긴 락, 충돌 증가, 전체 로딩 비용 |
| 작은 Aggregate | 독립 확장, 경합 감소 | Aggregate 간 최종 일관성·보상 필요 |
| 외부 객체 직접 참조 | 탐색과 구현이 직관적 | 저장소 경계 누수, 의도치 않은 연쇄 로딩 |
| ID 참조 | 경계와 생명주기 명확 | 별도 조회·조합 필요 |

## 2. 경계 찾는 순서

1. 명령과 동시에 깨지면 안 되는 비즈니스 규칙을 문장으로 쓴다.
2. 그 규칙에 필요한 상태만 같은 Aggregate에 둔다.
3. 다른 객체는 ID로 참조하고, 즉시 일관성이 정말 필요한지 되묻는다.
4. 동시 명령이 몰릴 Root를 찾아 버전 충돌과 처리량을 계산한다.

```kotlin
class Order(
    val id: OrderId,
    private val lines: MutableList<OrderLine>,
    private var status: OrderStatus,
    private var version: Long,
) {
    fun confirm(): OrderConfirmed {
        check(status == OrderStatus.DRAFT) { "확정 가능한 주문 상태가 아니다" }
        check(lines.isNotEmpty()) { "빈 주문은 확정할 수 없다" }
        status = OrderStatus.CONFIRMED
        return OrderConfirmed(id, lines.map { it.skuId to it.quantity })
    }
}
```

주문 확정과 재고 예약을 같은 Aggregate로 묶으면 모든 SKU 주문이 재고 Root에 경합할 수 있다. 주문은 자기 불변식을 지킨 뒤 `OrderConfirmed`를 Outbox에 기록하고, 재고 Aggregate가 예약을 시도하게 만들 수 있다. 예약 실패는 주문 취소나 대체 제안이라는 명시적 상태 전이로 처리한다.

> **실무 함정** — “한 요청이므로 한 트랜잭션”이라는 이유로 여러 Aggregate를 항상 같이 저장하면 서비스 계층이 사실상의 거대한 Aggregate가 된다. 불변식과 실패 보상 규칙을 먼저 써야 한다.

## 3. 충돌은 경계 품질의 신호다

낙관적 락 충돌률이 높다면 재시도만 늘리지 말고 Root가 너무 큰지, 핫한 카운터를 별도 모델로 분리할지 검토한다. 반대로 Aggregate를 지나치게 작게 쪼개 보상 흐름이 비즈니스보다 복잡해졌다면 강한 일관성이 필요한 규칙을 다시 합친다.

> **면접 포인트** — Aggregate 크기에 정답은 없다. “같이 바뀌는 데이터”가 아니라 “동시에 참이어야 하는 규칙”을 기준으로 경계를 제시하고, 경합률과 실패 복잡도로 설계를 검증한다.

## 4. 실패 입력 → 판단 → 복구

| 실패 입력 | 판단 | 복구·완화 |
|---|---|---|
| 주문 확정과 재고 차감을 한 번에 처리하려는데 특정 SKU의 동시 요청이 몰림 | 같은 Root에 모든 주문을 넣었는지, 재고 행의 경합과 낙관적 락 충돌을 분리해 측정한다. “재고는 항상 주문 Aggregate의 자식”이라고 가정하지 않는다. | 주문의 불변식과 재고 예약을 분리하고 `OrderConfirmed` 같은 명령/이벤트로 연결한다. 예약 실패·만료·취소를 명시적 상태로 저장하고 재시도는 멱등하게 한다. |
| ID 참조로 바꾼 뒤 명령 처리마다 Customer·Warehouse를 동기 조회함 | Aggregate를 작게 만든 효과가 분산 객체 그래프로 상쇄됐는지, 참조 값이 현재값인지 사건값인지 확인한다. | 명령에 필요한 검증만 API/Read Model로 수행하고, 주문 당시 값은 Snapshot으로 저장한다. 조회 화면 조합은 별도 Query 경로로 둔다. |
| 두 Aggregate를 같은 DB 트랜잭션에 넣을지 이벤트로 나눌지 논쟁이 생김 | 반드시 같은 커밋 순간 참이어야 하는 규칙인지, 지연과 보상을 사용자에게 노출할 수 있는지, DB 경계를 넘는지 판단한다. | 단일 저장소의 작은 원자 작업이면 트랜잭션을 선택할 수 있다. 분산 경계나 긴 업무 흐름이면 Outbox·Saga·멱등 소비자로 연결하고 상태를 `PENDING`처럼 공개한다. |

Aggregate 경계·트랜잭션 수·재시도 횟수는 이 카드의 고정 숫자가 아니다. 실제 충돌률, Root 로딩 폭, p95, 보상 미해결 건수를 관측해 경계를 다시 평가한다.

## 5. 공식 참고 자료

- [Microsoft Learn — Use domain analysis to model microservices](https://learn.microsoft.com/en-us/azure/architecture/microservices/model/domain-analysis)
- [Microsoft Learn — Designing a microservice domain model](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/microservice-domain-model)
- [Microsoft Learn — Saga pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/saga)
