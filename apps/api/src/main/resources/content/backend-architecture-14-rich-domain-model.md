---
area: BACKEND_ARCHITECTURE
mode: CONCEPT
coach: backend-architecture-coach
title: "Rich Domain Model — 행위 응집과 불변식"
slug: backend-architecture-14-rich-domain-model
topicKey: backend-architecture-124
difficulty: 3
summary: "도메인 객체가 상태 전이와 불변식을 책임지게 하고 애플리케이션 서비스는 유스케이스 조정에 집중시킨다."
tags:
  - "DDD"
  - "Rich Domain Model"
  - "Encapsulation"
  - "Invariant"
questions:
  - "Setter만 있는 Entity와 모든 로직을 Service에 둔 모델이 변경에 취약한 이유는 무엇인가요?"
  - "도메인 객체가 Repository나 외부 API에 직접 의존하면 어떤 문제가 생기나요?"
  - "단순 CRUD 영역에서 Rich Model이 과도한 비용이 되는 기준을 설명해보세요."
---
## 1. 상태와 변경 규칙을 같은 곳에 둔다

주문 취소 가능 여부를 여러 Service가 복사하면 규칙 변경 때 누락된다. Entity가 의도를 드러내는 메서드로 전이를 제한하면 유효하지 않은 상태를 생성하기 어렵다.

```mermaid
flowchart LR
    A[Application Service] --> O[Order.cancel]
    O --> I{불변식 검사}
    I -->|통과| S[상태 전이·Domain Event]
    I -->|실패| E[Domain Error]
    A --> R[Repository·외부 Port]
```

| 책임 | Domain Model | Application Service |
|---|---|---|
| 불변식 | 핵심 책임 | 호출 순서 보조 |
| 상태 전이 | 의도 메서드 | 유스케이스 시작 |
| 트랜잭션 | 알지 않음 | 경계 설정 |
| 외부 연동 | Port 의미 정의 | 구현 호출·조정 |

```kotlin
fun cancel(now: Instant): OrderCancelled {
    check(status.canCancel && now < shippingCutoff)
    status = CANCELLED
    return OrderCancelled(id, now)
}
```

> **모델링 함정** — Rich Model은 Entity 안에 모든 코드를 넣는 것이 아니다. 여러 Aggregate 조정과 I/O는 도메인 또는 애플리케이션 서비스로 분리한다.

## 2. 복잡도에 비례해 적용한다

규칙이 적고 CRUD가 중심이면 단순 모델이 낫다. 상태 전이, 계산, 예외가 늘어나는 핵심 도메인에 집중하고 읽기 전용 모델에는 같은 복잡성을 강요하지 않는다.

> **면접 포인트** — Anemic을 무조건 나쁘다고 하지 말고 변경 빈도와 불변식 밀도를 적용 기준으로 제시한다.
