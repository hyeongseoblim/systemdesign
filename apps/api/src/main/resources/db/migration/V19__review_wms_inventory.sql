-- logistics-02-wms-warehouse deep review. Existing card and question IDs are preserved.
UPDATE cards
SET content_md = $wms_review$## 1. WMS의 범위와 주변 시스템

WMS(Warehouse Management System, 창고관리 시스템)는 창고 안의 위치별 재고와 작업 흐름을 다루는 시스템으로 설계할 수 있다. 제품에 따라 재고 원장, 주문 할당, 운송 연동의 책임이 ERP·OMS·재고 서비스·WMS 사이에 다르게 배분된다. 그러므로 WMS를 SKU 재고 전체의 보편적인 단일 진실 원천으로 보지 말고, 수량·위치·상태별 데이터 소유자와 확정 이벤트를 먼저 정한다.

| 질문 | 계약으로 정할 내용 |
| --- | --- |
| OMS가 주문 수락에 사용할 수량은? | 창고별·상태별 범위, 예약·안전재고·입고예정 반영 여부 |
| WMS가 작업 완료를 알리는 시점은? | 피킹, 패킹, 선적 확인 중 어떤 이벤트가 출고 확정인지 |
| 재고 상태는 어떻게 바뀌나? | 입고·이동·격리·조정·출고 이벤트와 대사 절차 |
| TMS/운송사와 무엇을 나누나? | 운송장 발급, 인계, 배송 이벤트, 예외·정정 처리 |

## 2. 입고 → 검수 → 적치

ASN(Advance Shipping Notice, 사전입고통지)은 예정 입고 정보를 미리 전달하는 한 방법이다. 도착한 상품은 발주 정보와 대조하고, 수량·파손·로트·유통기한 등을 확인한 뒤 적치 위치와 재고 상태를 기록한다. 실제 업무는 공급사, 상품 유형, 창고 설정에 따라 다를 수 있다.

```mermaid
flowchart LR
    A[입고 예정 정보] --> B[도착·접수]
    B --> C{수량·품질 확인}
    C -->|정상| D[적치 위치와 재고 상태 등록]
    C -->|차이·파손| E[격리·보류·조사]
    D --> F[예약 가능성 정책에 반영]
```

바코드/RFID 스캔이나 작업자 확인은 잘못된 상품·수량·위치 입력을 줄이는 수단이다. 특정 정확도 목표를 보편 기준으로 두기보다 입고 오차와 후속 조정의 실제 원인을 측정한다.

## 3. 재고는 수량뿐 아니라 차원과 상태를 가진다

재고 수량을 계산할 때는 SKU만이 아니라 창고, 위치, 로트/일련번호, 재고 상태처럼 판매·피킹 가능성에 영향을 주는 차원을 정해야 한다. On-hand(실물 수량), Reserved(예약 수량), Available(할당 가능 수량)은 시스템마다 정의와 집계 범위가 다르다.

| 개념 | 예시 정의 | 주의점 |
| --- | --- | --- |
| Physical on-hand | 선택한 차원·상태에 기록된 물리 수량 | 격리/불량을 포함하는지 정의 |
| Physical reserved | 물리 재고 중 주문이나 작업에 묶인 수량 | 예약 차원 수준과 취소 규칙을 정의 |
| Available physical | 예: 같은 판매 가능 차원에서 `on-hand − reserved` | 안전재고, 할당 제한 등은 별도 반영 가능 |
| Expected/ordered | 아직 도착하지 않은 입고 예정 수량 | 백오더/예약 정책이 허용할 때만 약속에 반영 |

예를 들어 상태가 `SELLABLE`인 차원만 조회하고 예약 수량도 같은 차원에서 집계한다면 `availablePhysical = physicalOnHand − physicalReserved`로 표현할 수 있다. `DAMAGED`·`QUARANTINE` 재고를 같은 on-hand 합계에 넣었다면 가용량에서 차감하거나 별도 상태로 제외해야 하며, 둘 다 하면 중복 차감이다. 주문 약속에 사용할 수량은 이 값에 안전재고, 예정 입고, 채널별 정책을 적용해 결정한다.

따라서 주문 수락 기준은 화면의 “Available” 이름만 보고 고르지 않는다. 그 값이 어떤 창고·상태·로트와 예약 정책을 반영하는지 확인하고, 허용한다면 입고 예정이나 백오더도 명시적으로 모델링한다. Microsoft Dynamics 365 문서는 물리 가용량과 예약 가용량을 구분하고, 설정에 따라 예약 가능량에 예상 입고를 포함할 수 있음을 설명한다.

## 4. Reserve → Commit → Ship은 한 가지 가능한 흐름

재고 예약을 두는 이유는 같은 수량을 여러 주문에 동시에 약속하지 않고, 예약을 취소하거나 만료할 조건을 관리하기 위해서다. 아래 흐름은 개념 예시다. 실제 시스템에서는 `Pick`/`Packed`/`Deducted` 같은 상태와 재고 원장 반영 시점이 다르고, 예약을 주문 접수·결제·작업 시작 중 언제 하는지도 정책에 달려 있다.

```mermaid
sequenceDiagram
    participant O as 주문 서비스
    participant W as WMS/재고 서비스
    participant P as 작업자
    O->>W: Reserve(orderLine, qty, reservationId)
    W-->>O: 예약 결과와 유효 조건
    O->>W: 작업 확정 또는 예약 변경
    W->>P: 피킹 작업 지시
    P-->>W: 피킹·검수 결과
    W->>W: 정책상 출고 확정 이벤트와 재고 원장 갱신
    W-->>O: 출고/예외 이벤트
```

예약에 TTL(Time To Live, 만료 시간)을 쓰면 결제나 주문 확정이 끝나지 않은 임시 점유를 해제할 수 있다. 모든 WMS 예약에 TTL을 붙이는 것은 아니다. TTL을 쓴다면 해제와 결제가 경합할 때 한쪽 결과만 확정되도록 예약 ID·상태를 조건부로 갱신한다. 만료 뒤 늦은 결제가 도착하면 재예약을 시도하거나, 불가능하면 결제 제공자 정책에 맞춰 승인 취소/환불 후 대사한다. TTL 길이와 실물 수량 원장 반영 지점은 업무·제품 정책으로 정한다.

## 5. 피킹 전략은 주문과 창고 형태에 맞춰 고른다

피킹(Picking)은 주문 수량을 보관 위치에서 모으는 작업이다. Batch, Zone, Wave, Cluster는 사용할 수 있는 전략의 예이며 서로 조합될 수도 있다.

| 전략 | 개념 | 고려할 점 |
| --- | --- | --- |
| Batch | 여러 주문에서 같은 품목을 함께 집음 | 이후 주문별 분류가 필요할 수 있음 |
| Zone | 작업자가 담당 구역의 품목을 피킹 | 구역 사이 인계·주문 완결 흐름 |
| Wave | 정해진 기준으로 작업 묶음을 한꺼번에 해제 | 마감, 출고 도크, 주문 변화 대응 |
| Cluster | 한 번의 순회에서 여러 주문 칸에 나눠 담음 | 카트 용량과 분류 정확성 |

선택은 SKU 수, 주문당 품목 수, 통로·설비, 작업자 이동, 분류 비용과 출고 마감으로 평가한다. UPH(시간당 처리 단위)나 정확도 수치를 비교하려면 상품 구성, 시설, 분모 정의, 측정 기간을 함께 제시한다. 근거와 범위가 없는 업계 평균이나 회사별 생산성 배수는 일반 사실로 제시하지 않는다.

## 6. Oversell 방지와 동시성

두 요청이 마지막 재고를 동시에 읽고 각자 판매 가능하다고 판단하면 초과 약속이 생긴다. 가장 단순한 관계형 데이터베이스 예는 차원별 재고 행을 조건부로 갱신하고, 영향받은 행 수를 확인하는 것이다.

```sql
UPDATE inventory_balance
SET reserved_qty = reserved_qty + :qty,
    version = version + 1
WHERE sku_id = :sku
  AND warehouse_id = :warehouse
  AND inventory_status = 'SELLABLE'
  AND on_hand_qty - reserved_qty >= :qty;
```

이 예제는 `sku + warehouse + inventory_status` 한 행에 대한 단순 모델이다. 실제 키에는 로트·위치 등 재고 차원이 들어갈 수 있다. 영향 행이 0이면 이 요청의 예약은 성립하지 않은 것으로 처리한다. 같은 데이터베이스 안에서 예약 레코드도 만든다면 갱신과 삽입을 한 트랜잭션으로 묶고, 중복 요청을 위한 유일 키와 복구 방법을 둔다.

| 방법 | 적합한 조건 | 비용과 주의점 |
| --- | --- | --- |
| 조건부 UPDATE | 한 저장소에서 재고와 예약을 확정 | 핫 행 경합, 조건에 필요한 차원 키를 정확히 선택 |
| 낙관적 버전 확인 | 충돌이 비교적 드물고 재시도 가능 | 충돌 시 재시도·사용자 결과 정책이 필요 |
| 비관적 잠금 | 짧은 임계 구역에서 직렬화 필요 | 잠금 대기와 데드락 가능성을 관리 |
| Redis 스크립트/함수 | Redis 안의 확인·차감을 원자화해야 함 | 다른 DB 쓰기까지 원자화하지 않음, 재시도·복구·대사 필요 |

Redis에서 단순 `DECR` 후 음수면 되돌리는 것과, 조건 확인 후 차감하는 원자 연산은 다르다. 스크립트나 함수로 Redis 내부 연산을 묶더라도 관계형 DB와 Redis 사이의 분산 원자성이 생기는 것은 아니다. 두 저장소에 재고를 나눠 기록한다면 내구성, 중복 요청, 장애 복구, 정합성 대사를 포함한 설계가 필요하다.

## 7. Cycle count로 장부와 실물을 대조한다

정상적인 코드 경로도 분실·파손·잘못된 스캔·단위 변환·작업 중 예외로 실물과 기록이 달라질 수 있다. Cycle count(순환 실사)는 일부 위치나 품목을 계획·임계값·현장 판단에 따라 세고, 차이가 난 항목을 검토한 뒤 조정하는 한 방법이다. ABC 분류로 우선순위를 정할 수도 있지만 모든 창고가 같은 주기를 쓰는 것은 아니다.

```mermaid
flowchart LR
    A[실사 대상 선택] --> B[현장 수량 기록]
    B --> C{기록과 일치?}
    C -->|예| D[실사 완료]
    C -->|아니오| E[원인·권한 확인]
    E --> F[승인된 재고 조정]
    F --> G[재고 이벤트와 대사 기록]
```

실사 차이가 나면 무조건 입력 값을 덮어쓰기보다 재검수, 조정 권한, 사유 코드와 감사 기록을 둔다. Dynamics 365의 cycle counting 문서도 작업 생성, 현장 계수, 차이 검토 단계를 구분한다. 재고 오차율 목표는 상품과 창고의 측정 기준을 정한 뒤 정한다.

## 면접에서 답할 때

먼저 가용 수량의 차원과 정의를 말한다. 다음으로 예약 갱신이 어떤 저장소에서 어떻게 원자적으로 확정되는지 설명하고, 예약 만료·늦은 결제·피킹 이후 취소를 다룬다. 마지막으로 실사 차이는 권한 있는 조정 이벤트와 대사로 관리한다고 덧붙인다. WMS의 상태 이름이나 KPI 숫자를 보편 규칙처럼 외우지 않는다.

> **면접 포인트**
>
> “Available”은 이름만으로 정의되지 않는다. 어떤 재고 차원과 약속 정책을 기준으로 한 숫자인지 먼저 밝힌다.

## 참고 자료

- [Microsoft Dynamics 365 — Inventory on-hand list](https://learn.microsoft.com/en-us/dynamics365/supply-chain/inventory/inventory-on-hand-list)
- [Microsoft Dynamics 365 — Reserve inventory quantities](https://learn.microsoft.com/en-us/dynamics365/supply-chain/inventory/reserve-inventory-quantities)
- [Microsoft Dynamics 365 — Inventory posting profiles](https://learn.microsoft.com/en-us/dynamics365/finance/general-ledger/inventory-posting-profiles)
- [Microsoft Dynamics 365 — Cycle counting](https://learn.microsoft.com/en-us/dynamics365/supply-chain/warehousing/cycle-counting)
- [Redis — Scripting with Lua](https://redis.io/docs/latest/develop/programmability/eval-intro/)
- [AWS DynamoDB — Atomic counters and idempotency](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/WorkingWithItems.html)$wms_review$
WHERE slug = 'logistics-02-wms-warehouse' AND source = 'MANUAL';
