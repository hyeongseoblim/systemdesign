-- Reviewed MANUAL card bodies. Existing card and question IDs are preserved.

UPDATE cards
SET content_md = $review_21_logistics_04_fulfillment_inventory$## 1. 풀필먼트는 어떤 책임을 묶는가

풀필먼트는 온라인 주문을 실제 출고로 연결하는 운영 범위다. 일반적으로 입고·검수·보관·피킹·패킹·출고와 반품 처리를 포함하지만, 회사마다 OMS·WMS·운송사 사이의 경계와 계약 범위가 다르다. 따라서 “풀필먼트는 항상 이 시스템이 담당한다”라고 단정하기보다 **재고를 누가 보유하고, 작업을 누가 수행하며, 어느 사건을 어느 시스템이 확정하는지**를 먼저 적어야 한다.

[Amazon FBA의 공식 설명](https://sell.amazon.com/fulfill.html)은 판매자가 상품을 풀필먼트 센터로 보내면 Amazon이 보관·피킹·패킹·배송·고객 서비스·반품을 수행하는 한 가지 운영 예를 보여준다. 이 사례는 풀필먼트의 가능한 범위를 설명하지만, 모든 사업자의 조직 경계를 정의하지는 않는다.

```mermaid
flowchart LR
    Supplier(["판매자·공급사"]) --> Inbound["입고·검수"]
    Inbound --> Storage["보관·재고 원장"]
    Storage --> Pick["피킹"]
    Pick --> Pack["패킹·출고 검증"]
    Pack --> Handover["운송사 인계"]
    Handover --> Customer(["고객·반품"])

    style Inbound fill:#fef3c7,stroke:#f59e0b
    style Storage fill:#fef3c7,stroke:#f59e0b
    style Pick fill:#fef3c7,stroke:#f59e0b
    style Pack fill:#fef3c7,stroke:#f59e0b
    style Handover fill:#dbeafe,stroke:#3b82f6
    style Customer fill:#dcfce7,stroke:#22c55e
```

| 질문 | 먼저 정할 계약 |
| --- | --- |
| 재고 소유권 | 판매자 재고인지, 사업자가 매입한 재고인지 |
| 수량의 권위 | WMS 원장인지, 3PL의 재고 보고서인지, 별도 동기화 원장인지 |
| 작업 완료의 증거 | 스캔·패킹 확정·운송사 인수 중 어느 사건인지 |
| 예외 책임 | 파손·분실·오피킹·지연을 누가 조사하고 보상하는지 |

## 2. 자체 FC·3PL·드랍쉬핑 비교

세 모델은 우열 순서가 아니라 책임과 고정비의 배치가 다르다.

| 관점 | 자체 FC | 3PL | 드랍쉬핑 |
| --- | --- | --- | --- |
| 재고·작업 | 사업자가 재고와 시설·인력을 직접 운영 | 사업자가 재고를 보유하거나 계약 조건에 따라 위탁하고, 3PL이 작업 | 공급사가 재고를 보유하고 고객에게 직접 발송 |
| 고정비 | 시설·설비·인력의 고정비가 커질 수 있음 | 사용량·보관·작업·운송 계약으로 나뉨 | 재고·시설 고정비는 낮지만 공급사 의존 비용이 생김 |
| 통제 | 프로세스·데이터를 직접 정할 여지가 큼 | 계약 SLA·연동 품질·예외 처리에 의존 | 재고 가시성·포장·출고 품질을 통제하기 어려울 수 있음 |
| 확장 | 수요에 앞서 공간·인력을 준비해야 함 | 계약 가능한 공간·처리량만큼 확장 | 공급사의 품목·처리량·정책에 제약 |
| 리드타임 | 위치와 공정 설계에 따라 달라짐 | 3PL의 위치·컷오프·처리능력에 따라 달라짐 | 공급사의 재고·출고·운송 정책에 따라 달라짐 |

[Shopify의 드랍쉬핑 정의](https://help.shopify.com/en/manual/products/dropshipping/what-is-dropshipping)처럼 드랍쉬핑은 판매자가 재고를 보관하거나 직접 배송하지 않고 공급사가 고객에게 보내는 방식이다. 이것만으로 마진, 배송 속도, 품질이 정해지는 것은 아니다.

전환 시점은 “일 출고량이 몇 건이면 자체 FC” 같은 보편 임계값으로 정할 수 없다. 다음의 월별 데이터를 같은 단위로 비교한다.

```text
자체 운영 예상비용 = 시설·인력 고정비 + 작업·운송 변동비 + 품질·재고 리스크 비용
외부 위탁 예상비용 = 보관료 + 입출고 작업료 + 운송료 + 연동·예외 처리 비용
전환 판단 = 비용 차이 + SLA 위반 비용 + 필요한 통제 수준
```

물동량이 증가해도 SKU 수, 계절성, 반품률, 권역, 냉장·위험물 제약에 따라 결과가 달라진다. 그러므로 먼저 작은 권역·SKU 집합으로 실제 피킹 시간, 재고 오차, 지연, 반품 처리 비용을 측정하고 계약 또는 내재화의 가정을 갱신한다.

## 3. 전산재고·실물재고·가용재고

재고를 하나의 숫자로만 저장하면 예약, 품질 보류, 입고 예정, 창고 차원을 구분할 수 없다. [Microsoft Dynamics 365의 on-hand 문서](https://learn.microsoft.com/en-us/dynamics365/supply-chain/inventory/inventory-on-hand-list)는 Physical inventory, Physical reserved, Available physical을 별도 값으로 보고하며, Available physical을 물리 재고에서 물리 예약을 뺀 값으로 설명한다. 실제 제품의 명칭·예약 계층·차원은 구현마다 다를 수 있다.

```text
PhysicalOnHand(w, sku, lot, status)
Reserved(w, sku, reservationId)
AvailablePhysical = PhysicalOnHand - Reserved
```

판매 화면의 ATP(Available To Promise)는 위 값과 같다고 단정하지 않는다. 채널별 안전 버퍼, 품질 보류, 유통기한, 확정 입고, 다른 주문의 우선순위가 추가될 수 있다.

```text
SellableATP
  = policy(AvailablePhysical,
           confirmedInbound,
           safetyBuffer,
           quality·expiry constraints,
           channel allocation)
```

따라서 “물리적으로 100개가 있으니 100개 판매”가 아니라, 예를 들어 물리 재고 100개 중 30개가 예약되고 5개가 품질 보류라면 판매 정책이 허용하는 최대치는 65개보다 작거나 같을 수 있다. Safety Stock은 계획·보충 정책의 완충 목표이지 모든 WMS에서 물리 재고 원장에 별도 차감되는 상태는 아니다.

### 불일치 원인과 보정

- **현장 사건 누락**: 입고·이동·피킹·반품 스캔이 늦거나 누락됨.
- **식별 오류**: 비슷한 SKU, 로트, 시리얼, 단위 환산을 잘못 처리함.
- **실물 손실**: 파손·분실·폐기·오피킹으로 장부와 실물이 갈라짐.
- **동시성·재처리 오류**: 같은 예약이나 이벤트를 두 번 적용하거나, 외부 연동의 결과를 확인하지 못한 채 재시도함.

Cycle count는 전수 실사를 완전히 대체하는 규칙이 아니라, 위치·품목·임계값·계획에 따라 작은 범위를 반복 점검하는 통제다. [Microsoft의 cycle-counting 절차](https://learn.microsoft.com/en-us/dynamics365/supply-chain/warehousing/cycle-counting)는 작업 생성→현장 계수→차이 검토의 단계를 구분하고, 차이가 난 작업을 Pending review로 남긴다. 이처럼 조정에는 원인·승인·원장 이력이 필요하다.

```text
countedQty != systemQty
  -> 차이 기록
  -> 원인·승인 확인
  -> adjustment transaction
  -> 재고 투영과 감사 로그 갱신
```

정확도 목표, 오피킹률, 손실률의 숫자는 상품·단위·기간·분모를 밝히지 않으면 비교할 수 없다. 99.5%, 99.9%, 1~2% 같은 업계 일반값을 이 카드의 기준으로 사용하지 않는다.

## 4. 멀티 창고 할당과 Race condition

멀티 창고 할당은 거리만 최소화하는 문제가 아니다. 후보 창고마다 가용 수량·품질·온도·출고 마감·운송 약속·분할 출고 비용을 평가하고, 여러 라인을 한 창고에 묶을지까지 결정한다. 목적 함수는 사업 정책에 따라 달라진다.

```mermaid
flowchart LR
    Order["주문·라인"] --> Candidates["후보 창고 조회"]
    Candidates --> Policy["재고·SLA·분할·운송 정책 필터"]
    Policy --> ReserveA["창고 A 예약 시도"]
    Policy --> ReserveB["창고 B 예약 시도"]
    ReserveA --> Result{"모든 라인 예약 성공?"}
    ReserveB --> Result
    Result -->|예| Commit["할당 확정·작업 지시"]
    Result -->|아니오| Release["성공한 예약 해제·재할당 또는 보류"]
```

같은 창고의 남은 수량이 1개일 때 애플리케이션이 SELECT와 UPDATE를 나누면 두 요청이 모두 1개를 읽고 성공할 수 있다. 한 행의 조건부 갱신은 판단과 차감을 한 데이터베이스 쓰기로 묶는 기본 예다.

```sql
UPDATE inventory
SET available = available - :qty,
    reserved = reserved + :qty,
    version = version + 1
WHERE warehouse_id = :warehouse
  AND sku_id = :sku
  AND available >= :qty;
```

영향 행이 1이면 예약 성공, 0이면 재시도·다른 창고·품절 중 정책을 선택한다. 낙관적 락은 version이 예상값과 같은지 검사하고 충돌이면 다시 판단한다. 둘 다 예약의 고유 키, 트랜잭션 범위, 만료·해제 처리를 별도로 설계해야 한다.

창고 A와 B의 예약을 하나의 로컬 트랜잭션으로 묶을 수 없다면, 다음과 같은 분산 흐름을 사용할 수 있다.

1. 각 창고에 reservationId와 주문 라인 키를 포함한 예약 명령을 보낸다.
2. 모든 필요한 예약이 확정되면 할당을 COMMITTED로 바꾼다.
3. 하나가 실패하거나 제한 시간이 지나면 성공한 예약에 RELEASE를 보낸다.
4. 응답이 불명확하면 재시도만 하지 말고 조회·대사로 실제 예약 상태를 확인한다.

이것은 Saga 형태의 **업무 보상 흐름**이지 여러 창고의 원자 커밋을 만들어 주는 기능이 아니다. 보상 실패, 중복 명령, 창고 장애, 늦은 성공을 PENDING_RECONCILIATION 같은 상태로 관찰할 수 있어야 한다.

## 5. 안전재고와 재주문점

안전재고는 수요 또는 보충 리드타임의 변동 때문에 품절 위험을 낮추기 위해 보유하려는 계획상의 완충량이다. [Microsoft의 safety-stock 문서](https://learn.microsoft.com/en-us/dynamics365/supply-chain/master-planning/safety-stock-replenishment)는 최소 재고 수준 아래로 내려갈 때 계획 주문을 만들어 보충하는 한 가지 정책을 설명한다.

단순한 통계 예에서는 다음을 사용한다.

```text
ROP = 평균 리드타임 수요 + Safety Stock
SS  = Z × σ(리드타임 동안의 수요)
```

Z는 목표 서비스 수준에 따른 선택값이지 모든 상품에 적용되는 표준 상수가 아니다. 수요와 리드타임이 독립이고 변동성이 안정적이라는 가정이 깨지면, 리드타임 변동·계절성·프로모션·공급 제약을 포함한 모델이나 시뮬레이션을 검토해야 한다.

예를 들어 평균 일수요 100개, 4일의 고정 리드타임, 일수요 표준편차 30개라는 **가정**에서만 σ_LT = 30 × √4 = 60이다. 목표 계수 1.65를 선택하면 SS ≈ 99, ROP ≈ 499가 된다. 이 계산은 정책을 설명하는 예시이며 실제 서비스 수준을 보장하는 측정 결과가 아니다.

| 안전재고를 낮게 잡을 때 | 안전재고를 높게 잡을 때 |
| --- | --- |
| 보관·폐기 부담은 줄지만 수요 급증과 공급 지연에 취약 | 결품 위험은 낮출 수 있지만 자본·공간·진부화 부담 증가 |
| 대체 가능하고 수요가 안정적인 SKU에 적합할 수 있음 | 결품 손실이 크거나 보충이 느린 SKU에 적합할 수 있음 |

결품 비용은 놓친 주문, 재배송, 고객 이탈처럼 여러 기간에 분산되어 관측된다. 그래서 목표 서비스 수준은 “99%가 항상 정답”이 아니라 품목별 마진·대체 가능성·폐기 비용·고객 약속을 함께 비교해 정한다.

## 6. 백엔드 설계 연결

| 문제 | 설계 선택 | 반드시 기록할 것 |
| --- | --- | --- |
| 단일 창고의 동시 예약 | 조건부 UPDATE 또는 버전 검사 | 영향 행, reservationId, 만료·해제 |
| 여러 창고의 부분 성공 | 단계별 예약 + 명시적 보상 | 창고별 결과, 보상 실패, 대사 상태 |
| 재고 변경 이벤트 | 트랜잭션 안의 원장·outbox | 원장 커밋과 eventId, 재처리 결과 |
| 조회 폭주 | 캐시·읽기 모델 | 기준 시각, 허용 지연, 원장 재조회 경로 |
| 실물과 장부 차이 | cycle count와 승인된 조정 | 계수자, 차이 원인, adjustment 전표 |
| 보충 판단 | ROP·안전재고 계산 | 수요 기간, 리드타임, 서비스 목표, 가정 버전 |

```json
{
  "reservationId": "res-2026-04-0007",
  "orderLineId": "line-42",
  "warehouseId": "fc-seoul-1",
  "sku": "SKU-X",
  "quantity": 1,
  "status": "RESERVED",
  "expiresAt": "2026-09-27T12:15:00Z"
}
```

### 면접에서 답할 때

먼저 세 모델의 재고 소유권·작업 책임·SLA 계약을 분리한다. 다음으로 PhysicalOnHand, Reserved, AvailablePhysical, 판매 정책상 ATP를 같은 숫자로 취급하지 않는다. 멀티 창고에서는 각 창고의 원자 예약과 전체 할당의 보상·대사를 구분하고, 안전재고 공식에는 수요·리드타임 분포와 서비스 목표라는 가정을 붙인다.

> **검수 경계** — 재고 계산과 할당 예제의 수치는 가상 입력이다. 실제 가용 재고와 출고 가능 시점은 원장 기준 시각, 예약·격리 상태, 창고별 계약을 확인해 판단한다.

## 참고 자료

- [Amazon FBA — Fulfillment by Amazon](https://sell.amazon.com/fulfill.html)
- [Shopify Help — What is dropshipping?](https://help.shopify.com/en/manual/products/dropshipping/what-is-dropshipping)
- [Microsoft Learn — Inventory on-hand list](https://learn.microsoft.com/en-us/dynamics365/supply-chain/inventory/inventory-on-hand-list)
- [Microsoft Learn — Reserve inventory quantities](https://learn.microsoft.com/en-us/dynamics365/supply-chain/inventory/reserve-inventory-quantities)
- [Microsoft Learn — Cycle counting](https://learn.microsoft.com/en-us/dynamics365/supply-chain/warehousing/cycle-counting)
- [Microsoft Learn — Safety stock fulfillment](https://learn.microsoft.com/en-us/dynamics365/supply-chain/master-planning/safety-stock-replenishment)$review_21_logistics_04_fulfillment_inventory$
WHERE slug = 'logistics-04-fulfillment-inventory' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_21_logistics_05_last_mile_routing$## 1. 라스트마일의 비용 구조를 어떻게 설명할까

라스트마일은 허브·배송 캠프·지역 터미널에서 최종 수령지까지 화물을 전달하는 구간이다. 거리만으로 비용을 설명하면 부족하다. 배송지의 밀도, 정차마다 걸리는 서비스 시간, 차량·기사의 근무 제약, 시간창, 실패 재방문, 반품 회수와 같은 요소가 함께 비용을 만든다.

“전체 물류비의 40~60%” 같은 비율은 국가·상품·운송 범위·비용 분모에 따라 달라지는 업계 주장이다. 출처와 분모가 없는 상태에서 이 카드를 일반 상수로 사용하지 않는다. 대신 다음 지표의 정의와 측정 기간을 먼저 고정한다.

| 지표 | 의미 | 주의할 점 |
| --- | --- | --- |
| 배송 밀도 | 일정 권역의 배송 정차 수를 면적·주행 거리·근무 시간 중 하나로 나눈 값 | 분모가 stops/km²인지 stops/route-hour인지 구분 |
| 정차 서비스 시간 | 주차·출입·인수·사진·실패 처리에 쓰는 시간 | 이동 시간과 섞으면 병목을 숨김 |
| 1차 배송 성공률 | 첫 방문에서 성공한 배송 건수 / 첫 방문 시도 건수 | 취소·주소 오류·수령 거부를 분모에서 임의로 빼지 않음 |
| 경로당 원가 | 기사·차량·운송·재방문·CS 비용 / 완료된 배송 단위 | 주문·화물·배송 라인의 단위를 고정 |

밀도가 높아지면 같은 이동으로 더 많은 정차를 처리할 가능성이 커지지만, 주차·엘리베이터·수령 확인 때문에 정차 수가 늘어도 시간이 선형으로 줄지는 않는다. 최적화 목표는 총거리 하나가 아니라 약속 준수, 안전, 기사 근무, 재방문 비용을 포함한 정책 함수다.

## 2. 배차 — 화물과 기사·차량을 연결하기

배차는 화물 또는 배송 라인을 기사·차량·출발지에 연결하는 결정이다. 라우팅은 연결된 정차의 순서를 정하는 단계이므로 먼저 다음 제약을 확정한다.

| 제약 | 확인할 값 |
| --- | --- |
| 차량 | 중량·부피·온도대·위험물·적재 순서 |
| 기사 | 근무 시작·종료, 휴게, 출발·복귀 위치, 자격 |
| 고객 | 배송 시간창, 부재 정책, 인수 방식 |
| 네트워크 | 통행 제한, 캠프 마감, 운송사 계약, 재방문 |
| 업무 | 픽업 선행, 배송 우선순위, 교환·회수 동시 처리 |

고정 권역은 주소와 건물 접근 지식을 쌓기 쉽지만 물량 변동을 흡수하기 어렵다. 동적 배차는 잔여 용량을 유연하게 사용할 수 있지만, 재배정 비용과 기사 앱의 변경 수용 절차가 필요하다. 어느 방식이 “표준”이라고 단정하지 말고, 재배정 빈도·성공률·근무시간 위반·현장 확인 시간을 비교한다.

```mermaid
flowchart LR
    Orders["출고 완료 화물"] --> Filter["권역·차량·시간창 후보 필터"]
    Filter --> Assign["기사·차량 임시 배정"]
    Assign --> Feasible{"제약을 만족하는가?"}
    Feasible -->|예| Route["경로 생성"]
    Feasible -->|아니오| Fallback["다른 기사·보류·재약속"]
    Route --> Ack["기사 앱 확인"]
    Ack --> Version["routeVersion 확정"]
```

임시 배정과 확정을 분리하면 최적화 결과를 계산하는 동안 차량이 다른 주문에 배정되는 경합을 다룰 수 있다. 기사 앱이 이전 routeVersion을 확인한 뒤 늦게 도착한 결과는 덮어쓰지 않고 재계산 또는 운영자 확인으로 보낸다.

## 3. TSP·VRP·CVRP·VRPTW

TSP는 한 차량이 출발지로 돌아오거나 정해진 종점에 도착하면서 여러 정차를 방문하는 순서를 찾는 모델이다. VRP는 여러 차량과 출발지를 다루는 일반화이며, CVRP는 차량 용량을, VRPTW는 정차별 방문 시간창을 추가한다. 실제 배송은 픽업·배송 선행, 여러 상품 단위, 휴게·운전자격, 다중 온도대까지 더할 수 있다.

[Google OR-Tools의 공식 Vehicle Routing 문서](https://developers.google.com/optimization/routing)는 TSP, 용량 제약 VRP, 시간창 VRP와 자원 제약을 각각 설명한다. 정차 수와 제약이 커지면 가능한 경로를 모두 비교하는 방식은 현실적인 시간 안에 최적해를 찾기 어렵다. OR-Tools 문서도 큰 VRP에서 최적해가 아니라 시간 제한 안의 좋은 해를 반환할 수 있다고 명시한다.

| 접근 | 쓰임 | 검증할 것 |
| --- | --- | --- |
| 정확해·정수계획 | 작은 문제, 기준선, 비용 민감한 배치 | 계산 시간과 최적성 증명 범위 |
| 휴리스틱 | 삽입·절약·최근접 등 빠른 초기해 | 제약 위반 여부와 해 품질 |
| 국소·메타휴리스틱 | 2-opt, 교환, 재배치로 초기해 개선 | 시간 예산, 재현성, 안정성 |
| 제한 시간 최적화 | 운행 중 재계산 | 현재 경로 유지와 변경 범위 |

거리 행렬은 위도·경도 직선거리로 대체하면 안 된다. 도로 방향, 통행 제한, 교통, 차량 종류에 따라 시간이 달라지기 때문이다. [Google Routes API의 Compute Route Matrix](https://developers.google.com/maps/documentation/routes/compute_route_matrix)는 여러 출발지·도착지 조합의 거리와 시간을 계산하는 공식 API 예다. 이 API의 요소 수 제한과 과금·쿼터는 시스템 규모와 비용 계획에 포함해야 하며, 무료·자체 운영을 목표로 한다면 사전 계산된 도로망이나 다른 공급자를 비교한다.

## 4. 운행 중 재최적화

운행 중에는 신규 주문, 교통 변화, 기사 이탈, 배송 실패, 회수 추가가 발생한다. 전체 경로를 다시 풀면 전역 품질을 회복할 여지가 있지만 이미 기사에게 전달한 순서가 크게 바뀐다. 증분 삽입은 현재 경로를 보존하면서 일부 정차를 추가하지만 누적된 비효율을 놓칠 수 있다.

```mermaid
sequenceDiagram
    participant App as 기사 앱
    participant Ingest as 이벤트 수집
    participant Planner as 배차·최적화
    participant Read as 고객 ETA

    App->>Ingest: 위치·상태·완료 이벤트
    Ingest->>Planner: 현재 routeVersion과 새 제약
    Planner->>Planner: 삽입·교환 또는 전체 재계산
    Planner-->>App: 새 경로와 적용 버전
    Planner-->>Read: 지연·약속 변경 투영
```

| 상황 | 먼저 시도할 방법 | 실패 시 처리 |
| --- | --- | --- |
| 한 건의 신규 주문 | 가능한 위치에 삽입하고 시간창 재검증 | 불가능하면 다른 기사·다음 슬롯·거절 |
| 교통 지연 | 남은 정차의 ETA만 갱신 | 약속 위반 예상 시 재배차·고객 알림 |
| 기사 이탈 | 미완료 정차를 후보 기사에 재할당 | 용량 부족이면 보류·운영자 결정 |
| 경로 열화 누적 | 전체 재계산을 별도 워커에서 시도 | 제한 시간 초과 시 기존 경로 유지 |

응답 시간의 “수십 ms”나 “수백 ms”를 일반값으로 쓰지 않는다. 정차 수, 거리 행렬 캐시, 최적화 시간 제한, 네트워크 왕복, 결과 승인 절차를 실제 데이터로 측정한다. 동선 변경 최소화도 목적 함수의 한 항으로 넣고, 재계산 결과에는 적용 전 routeVersion과 새 routeVersion을 기록한다.

## 5. POD와 배송 실패 상태

POD(Proof of Delivery)는 배송 완료를 주장할 때 조회할 수 있는 증거 묶음이다. 상품·계약·배송 방식에 따라 서명, 수령자 또는 대리 수령자, 배송 시각·위치, 사진, OTP, 운송장과 같은 필드가 달라진다. 모든 배송에 사진·GPS·서명이 존재한다고 가정하지 않는다.

[USPS의 공식 POD 설명](https://faq.usps.com/articles/Knowledge/What-is-Proof-of-Delivery)은 적용 가능한 서비스에서 배송 정보, 수령자 이름, 운송장, 서명 이미지와 배송 위치 정보를 제공할 수 있다고 설명한다. [DHL의 공식 Tracking API 문서](https://developer.dhl.com/tracking?language_content_entity=de)는 디지털 서명이 캡처된 경우 전자 POD에서 배송 상세와 서명 이미지를 조회할 수 있다고 설명한다. 이 자료들은 POD의 가능한 필드를 보여주며, 사업자별 보존 기간·수집 의무를 정하지 않는다.

```mermaid
stateDiagram-v2
    [*] --> OUT_FOR_DELIVERY
    OUT_FOR_DELIVERY --> DELIVERED : 증거 검증
    OUT_FOR_DELIVERY --> DELIVERY_FAILED : 부재·주소·거부
    OUT_FOR_DELIVERY --> MISDELIVERED : 오배송 의심
    DELIVERY_FAILED --> REATTEMPT : 재방문 가능
    DELIVERY_FAILED --> RETURN_TO_HUB : 재방문 불가·정책 종료
    MISDELIVERED --> RECOVERY : 회수·조사
    RECOVERY --> REATTEMPT : 재배송
    DELIVERED --> [*]
    RETURN_TO_HUB --> [*]
```

POD는 단일 boolean보다 다음처럼 원본과 판정 결과를 나누는 편이 안전하다.

| 데이터 | 역할 |
| --- | --- |
| 원본 이벤트 | 기사 앱·스캐너가 보낸 사건과 발생 시각 |
| 증거 객체 | 서명·사진·OTP·위치 등 실제 첨부와 접근 권한 |
| 판정 | 배송 완료·실패·오배송 조사 상태 |
| 감사 정보 | 누가 언제 어떤 근거로 상태를 바꿨는지 |

사진을 WORM 저장소에 보관하거나 앱 카메라만 허용하는 것은 가능한 통제안이다. 법적 증거 효력을 자동으로 보장하는 규칙은 아니므로 보존기간, 개인정보 접근, 위변조 탐지, 삭제 요청 정책을 별도로 정한다.

## 6. 위치 이벤트와 백엔드

위치 이벤트 처리량은 운영 숫자를 먼저 정하지 말고 기사 수와 수집 주기로 계산한다.

```text
초당 입력량 = 활성 기사 수 × 기사당 위치 이벤트 빈도(초당)
일일 입력량 = 초당 입력량 × 운영 초
```

예를 들어 100명의 기사가 10초마다 한 번씩 위치를 보낸다는 **가정**은 초당 10건이다. 1만 QPS가 필요하다는 질문의 수치는 기사 수·주기·상태 이벤트·재전송을 구체화한 뒤 검증할 부하 목표이지 라스트마일의 보편 사실이 아니다.

[Apache Kafka의 메시지 전달 의미 문서](https://kafka.apache.org/40/design/design/)는 at-most-once, at-least-once, exactly-once를 producer와 consumer의 서로 다른 문제로 나눈다. Kafka producer idempotence는 producer 재시도로 인한 로그 중복을 줄이지만, 외부 데이터베이스에 쓰는 부작용의 멱등성을 대신하지 않는다.

| 이슈 | 설계 예 | 경계 |
| --- | --- | --- |
| 최신 위치 조회 | 짧은 TTL 캐시·지리 인덱스·최신 상태 투영 | 원본 이벤트 보존과 분리 |
| 배송 상태 이력 | 불변 eventId 원장 + 멱등 consumer | 늦은 이벤트와 정정 규칙 필요 |
| 고객 ETA | 지연을 허용하는 읽기 모델 | 약속 변경 알림과 원본 계산 분리 |
| 재계산 요청 | 비동기 worker + routeVersion | 취소·중복·오래된 결과 폐기 |
| 외부 운송사 연동 | outbox·재시도·대사 | 전송 성공과 실제 인수는 다름 |

```json
{
  "eventId": "pos-2026-09-27-0001",
  "driverId": "D-17",
  "routeVersion": 31,
  "latitude": 37.5665,
  "longitude": 126.9780,
  "occurredAt": "2026-09-27T04:10:11Z",
  "receivedAt": "2026-09-27T04:10:12Z"
}
```

### 면접에서 답할 때

먼저 배차가 기사·차량·화물을 연결하고, 라우팅이 방문 순서를 정한다는 경계를 말한다. 다음으로 TSP·VRP·용량·시간창 제약을 구분하고, 최적화 결과의 시간 제한과 fallback을 설명한다. 운행 중에는 routeVersion과 기사 확인을 두어 오래된 계산 결과가 현재 경로를 덮지 않게 한다. 마지막으로 위치 이벤트의 입력량을 파라미터로 계산하고, Kafka·캐시·외부 DB의 전달 보장을 각각 설명한다.

> **검수 경계** — 경로 최적화의 목적 함수와 위치 이벤트 입력량은 운영 데이터·계약에 따라 달라진다. 제시한 수치가 측정 결과인지 가상 요구인지 밝히고, 시간창 위반과 배송 실패를 비용 절감보다 먼저 검증한다.

## 참고 자료

- [Google OR-Tools — Vehicle Routing](https://developers.google.com/optimization/routing)
- [Google OR-Tools — VRP with Time Windows](https://developers.google.com/optimization/routing/vrptw)
- [Google Maps Routes API — Compute Route Matrix](https://developers.google.com/maps/documentation/routes/compute_route_matrix)
- [Apache Kafka — Message Delivery Semantics](https://kafka.apache.org/40/design/design/)
- [USPS — What is Proof of Delivery?](https://faq.usps.com/articles/Knowledge/What-is-Proof-of-Delivery)
- [DHL — Shipment Tracking and Electronic Proof of Delivery](https://developer.dhl.com/tracking?language_content_entity=de)$review_21_logistics_05_last_mile_routing$
WHERE slug = 'logistics-05-last-mile-routing' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_21_logistics_06_returns_reverse_logistics$## 1. 역물류(Reverse Logistics) 개념과 측정 기준

> **핵심 책임** — 고객이 받은 상품을 *회수·검수·재처리*하는 흐름. 정방향 출고와 같은 주문에 매달린 부속 작업으로 취급하면 반품 상태, 품질, 재고, 결제의 경계가 흐려진다.

Reverse Logistics(역물류)는 고객 또는 판매 지점에서 물류 거점으로 상품을 되돌리고, 검수 결과에 따라 재판매·수리·공급사 반송·폐기·환불을 처리하는 흐름이다. 단순 반품 외에도 교환, 리콜, 오배송 회수처럼 회수 사유와 후속 처리가 다른 사례를 포함한다.

| 관점 | 정방향(Forward) | 역방향(Reverse) |
| --- | --- | --- |
| 흐름 방향 | 주문 이행을 위해 창고에서 고객으로 이동 | 반품 사유와 회수 경로에 따라 거점으로 이동 |
| 상품 상태 | 출고 전 품질 기준을 통과한 재고 | 사용·개봉·파손 여부를 입고 후 판정 |
| 핵심 작업 | 피킹·패킹·출고 | **접수·회수·검수·등급 분류·재처리 판정** |
| 재고 처리 | 판매 가능 재고에서 차감 | QC 결과에 따라 격리, 가용, 리퍼브, 폐기 등으로 이동 |
| 결제 처리 | 결제 승인과 매출 기록 | 승인된 반품 라인과 결제 수단에 연결한 환불·조정 |

반품률 하나만으로 운영 품질을 판단하지 않는다. 사유별 접수 건수, 회수 성공률, 입고 후 검수 대기시간, QC 판정별 수량, 가용 재고 전환률, 환불 요청·성공·조정 건수처럼 **정의와 집계 시점을 고정한 지표**를 함께 둔다. 각 지표의 분모와 취소·중복 이벤트 처리 규칙을 먼저 정하지 않으면 기간별 비교가 왜곡된다.

## 2. 반품 전체 흐름 — 신청부터 재처리까지

반품 접수에서 수거·입고·검수·결제 조정·재고 처리가 이어진다. QC는 중요한 관문이지만 환불 정책이 반드시 QC 완료를 기다려야 한다는 뜻은 아니다. 선환불 정책에서는 환불 승인과 물류 검수의 상태를 분리하고, 사후 조정 경로를 명시해야 한다.

```mermaid
flowchart TB
    Start(["반품 신청(Return Request)"]) --> Schedule["수거 예약(Pickup Scheduled)"]
    Schedule --> Pickup["택배기사 회수(Picked Up)"]
    Pickup --> Inbound["반품 입고 · 검수 대기"]
    Inbound --> QC{"검수(QC) 판정"}
    QC -->|"정상(재판매 가능)"| Restock["재고 환원(Restock)\n→ 정방향 가용재고 복귀"]
    QC -->|"하자(공급사 책임)"| Vendor["공급사 반송 / 클레임"]
    QC -->|"오사용·파손(고객 책임)"| Reject["반품 거부\n→ 재반송 또는 정책별 조정"]
    QC -->|"재판매 불가"| Dispose["폐기 / 리퍼브 처리"]
    Restock --> Refund["환불(Refund) 또는 교환 출고"]
    Vendor --> Refund
    Dispose --> Refund
    Reject --> End2(["고객 협의"])
    Refund --> End(["반품 완료(Closed)"])

    style Restock fill:#dcfce7,stroke:#22c55e
    style QC fill:#fce7f3,stroke:#ec4899
    style Reject fill:#fff7ed,stroke:#ea580c
    style Dispose fill:#fee2e2,stroke:#ef4444
```

*반품 흐름 분기 — 검수(QC) 판정이 재고 환원·환불·폐기를 가르는 단일 관문*

> **💡 핵심 — 검수와 결제의 경계를 분리**
>
> 검수 전에 상품을 가용 재고로 올리면 불량품이 재출고될 수 있다. 반대로 결제 정책상 선환불을 허용할 수 있으므로 `RefundApproved`와 `QCApproved`를 같은 상태로 합치지 않는다. 환불 정책, QC 판정, 재고 전환은 서로의 결과를 참조하되 각각 재시도·보상·감사 이력을 갖는다.

## 3. 반품 상태 머신 — 정·역방향 상태 합류 지점

반품도 주문과 마찬가지로 **Enum + 명시적 전이**로 상태를 강제한다. 중요한 것은 정방향 주문의 `RETURNED` 상태와 역방향 반품 상태 머신이 **어디서 합류(Join)하는가**이다.

```mermaid
stateDiagram-v2
    state "정방향 주문" as FWD {
        DELIVERED --> RETURN_REQUESTED : ReturnRequested
        RETURN_REQUESTED --> RETURNED : 역물류 완료 신호 수신
        RETURNED --> [*]
    }
    state "역방향 반품" as REV {
        [*] --> ReturnRequested : 반품 접수
        ReturnRequested --> PickupScheduled : 수거 예약
        PickupScheduled --> PickedUp : 회수 완료
        PickedUp --> Inspected : 검수(QC) 수행
        Inspected --> Approved : QC 통과
        Inspected --> Rejected : QC 불합격
        Approved --> Refunded : 환불 처리
        Approved --> Exchanged : 교환 출고
        Rejected --> ReturnToCustomer : 재반송
    }
    note right of REV : Approved → Refunded/Exchanged 도달 시\n정방향에 "역물류 완료" 이벤트 발행\n→ 주문이 RETURNED로 전이 (합류점)
```

*정방향 주문 상태와 역방향 반품 상태 머신 — 역방향이 Approved→Refunded에 도달하면 정방향 RETURNED로 합류*

> **🎯 면접 포인트 — 상태 합류(Join)**
>
> 주문 상태와 반품 상태를 한 Enum에 넣으면 부분 반품, 여러 반품 요청, 재검수, 환불 결과 불명확 상태를 표현하기 어렵다. 정방향 주문과 역방향 반품을 **별도 Aggregate(집합체)** 로 두고, 반품이 정책상 종결될 때 `ReturnCompleted` 같은 도메인 이벤트를 발행한다. 주문 서비스는 이벤트의 `returnId`, 대상 라인, 버전 또는 멱등키를 검증한 뒤 주문 라인 상태를 갱신한다. 이벤트를 받았다고 주문 전체를 무조건 `RETURNED`로 바꾸면 부분 반품에서 오류가 난다.

### 왜 별도 상태 머신으로 분리하나

- **생명주기 차이**: 한 주문에 반품이 여러 번(라인별·부분) 걸릴 수 있어 1:N. 주문 헤더 상태로는 표현 불가.
- **합류 시점 명시**: `Approved → Refunded` 도달이라는 단일 지점에서만 정방향을 건드림 → 상태 꼬임 방지.
- **멱등성**: `ReturnCompleted` 이벤트가 재전송돼도 주문은 한 번만 `RETURNED`로 전이.

### 상태 합류 실패 흐름

이벤트 소비자가 이미 처리한 `ReturnCompleted`를 다시 받으면 `returnId`와 이벤트 ID를 중복 기록으로 판정하고 같은 결과를 반환한다. 대상 주문 버전이 현재 버전과 다르면 즉시 덮어쓰지 않고 `JOIN_REVIEW_REQUIRED` 또는 재처리 큐로 보낸다. 반품이 주문에 속하지 않거나 이미 취소된 라인을 가리키면 주문 상태를 변경하지 않고 불일치 사건을 기록한다. 이벤트 발행은 로컬 트랜잭션의 outbox에 먼저 저장하고, 소비 성공 시 inbox 또는 처리 이력을 남기면 DB 커밋과 메시지 발행 사이의 유실을 재처리할 수 있다.

## 4. 검수(QC, Quality Check) — 상태 분류와 재고 환원

QC(Quality Check, 품질 검수)는 회수된 상품을 등급으로 분류하고, **재판매(Restock) 가능 여부와 재고 환원 시점**을 결정하는 핵심 단계다.

| QC 분류 | 판정 기준 | 재판매 가능? | 재고 환원(Restock) 처리 | 환불 방향 |
| --- | --- | --- | --- | --- |
| **정상(Good)** | 미개봉·신품 동등 | 가능 | 가용재고로 즉시 환원 | 전액 환불 |
| **경미 하자(Minor)** | 개봉·전시급 | 리퍼브 채널 한정 | 별도 리퍼브 재고로 환원 | 전액 환불 |
| **공급사 하자(Defective)** | 제조 결함 또는 리콜 기준 해당 | 불가(공급사 정책에 따름) | 가용재고로 환원하지 않음 | 계약·정책에 따른 환불 또는 조정 |
| **고객 오사용(Damaged)** | 사용 흔적·파손 등 정책상 재판매 불가 | 불가 | 가용재고로 환원하지 않음 | 근거와 정책에 따른 부분 환불 또는 거부 |

> **⚠️ 실무 함정 — 재고 환원 시점**
>
> 재고를 **"반품 입고 시점"이 아니라 "QC 통과 시점"** 에 가용재고로 올린다. 입고 즉시 환원하면 검수에서 하자로 판정될 상품이 판매 가능 재고에 섞일 수 있다. QC 전에는 `RETURN_INSPECTING` 같은 별도 보류 상태로 격리하고, 상품·수량·등급·창고·판정 근거를 함께 기록한다.

### QC 격리·환원 실패 흐름

입고 스캔은 `RETURN_RECEIVED`와 격리 재고 이동을 만든다. 이 이동이 재시도될 수 있으므로 `returnId + lineId + inspectionVersion` 같은 업무 키를 사용해 같은 입고를 두 번 가산하지 않는다. QC가 승인되면 가용재고 전환 명령을 한 번 발행하고, 재고 서비스가 이미 적용한 업무 키를 다시 받으면 현재 결과를 반환한다. 전환 결과를 알 수 없는 타임아웃에서는 재고를 다시 더하지 말고 조회 또는 조정 큐로 확인한다.

QC가 재검수되면 이전 판정과 새 판정을 연결하고, 이전 판정의 재고 이동을 상쇄한 뒤 새 판정을 적용한다. 한 번 가용재고로 전환된 상품이 별도 주문에 할당된 뒤 판정이 바뀌는 경우에는 재고를 음수로 덮어쓰지 말고 보류·회수·운영자 검토 정책을 적용한다. `RETURN_INSPECTING`, `AVAILABLE`, `REFURBISH`, `DISPOSED`는 상호 배타적인 수량 상태로 모델링해 동일 수량이 두 상태에 동시에 보이지 않게 한다.

## 5. 환불 흐름 — 타이밍 Trade-off와 회계 처리

환불(Refund)은 결제 PG(Payment Gateway)와 회계 시스템에 동시에 영향을 준다. 핵심 설계 결정은 **"언제 환불할 것인가"** — 회수 즉시(선환불) vs 검수 통과 후(검수후환불)이다.

```mermaid
sequenceDiagram
    participant C as 고객
    participant RMS as 반품관리(RMS)
    participant WMS as WMS(검수)
    participant PG as 결제 PG
    participant ACC as 회계

    C->>RMS: 반품 신청
    RMS->>RMS: PickupScheduled → PickedUp
    RMS->>WMS: 반품 입고 · 검수 요청
    WMS-->>RMS: QC 결과(Approved)
    Note over RMS,WMS: 검수 통과 시점에만 환불 트리거
    RMS->>PG: Refund(orderId, amount, Idempotency-Key)
    PG-->>RMS: Refunded(refundId)
    RMS->>ACC: 매출 차감 · 환불 전표 기표
    RMS-->>C: 환불 완료 알림
    Note over RMS: 부분 환불 시 amount = 라인 단위 합산
```

*검수후환불 시퀀스 — QC Approved 이후에만 PG Refund 호출, 멱등키로 중복 환불 차단*

### 선환불 vs 검수후환불 Trade-off

| 관점 | 선환불 (회수 즉시) | 검수후환불 (QC 통과 후) |
| --- | --- | --- |
| 고객 경험(CX) | 검수 완료를 기다리지 않아 정책상 빠른 처리가 가능 | 검수 완료 뒤 승인하므로 고객이 기다릴 수 있음 |
| 손실 리스크 | 하자·오사용도 선환불 → 환수 어려움 | QC로 걸러내 손실 최소화 |
| 회계 처리 | 환불 후 검수 → 충당금·역분개 복잡 | 확정 후 1회 기표 → 단순 |
| 적합 상황 | 회수·고객·상품 조건을 사전에 평가하고 사후 조정이 가능한 정책 | 검수 결과가 환불 금액·자격을 결정하는 정책 |

> **🎯 면접 포인트 — 부분 환불 & 회계 시점**
>
> "라인 3개 중 1개만 반품 승인"이면 환불액은 승인된 라인과 할인·배송비 배분 규칙으로 계산한다. 계산 결과와 원주문·반품·결제 환불 ID를 연결해야 재시도와 대사에서 같은 금액을 중복 반영하지 않는다. 회계 전표의 세부 세법·증빙 규칙은 관할과 사업 정책을 확인해 별도로 구현한다.

### 환불 결과가 불명확한 경우

PG 호출이 타임아웃되면 애플리케이션은 `FAILED`로 단정하지 않는다. 네트워크 응답을 잃었어도 PG에 요청이 접수됐을 수 있기 때문이다. 반품 라인에는 `REFUND_REQUESTED`와 요청 멱등키를 저장하고, PG의 환불 조회 API 또는 웹훅으로 `SUCCEEDED`, `FAILED`, `PENDING`을 확인한다. 조회 전 재호출이 필요하면 같은 멱등키와 같은 금액을 사용하고, 키를 바꾸어 중복 환불을 만들지 않는다.

환불 성공 웹훅은 중복 수신을 전제로 처리한다. 이미 성공한 환불 ID가 같은 반품에 연결되어 있으면 상태를 그대로 반환하고, 다른 반품·다른 금액을 가리키면 자동 병합하지 않고 대사 큐로 보낸다. 일정 시간 동안 결과가 확정되지 않는 `PENDING` 건은 고객에게 확정 완료라고 알리지 않고 운영 대시보드와 재조회 작업에 남긴다. 환불 실패 뒤 재시도할 수 있는 오류와 결제 수단·잔액·정책 확인이 필요한 오류를 구분한다.

## 6. 엣지 케이스 — 역물류 특유의 함정

> **⚠️ 회수 중 분실 · 파손**
>
> 회수 후 입고 전 상품이 분실·파손되면 `PickedUp` 상태에서 바로 환불이나 폐기로 확정하지 않는다. 운송장 스캔, 운송사 사건 번호, 마지막 확인 시각을 근거로 `IN_TRANSIT_EXCEPTION` 사건을 만들고, 고객 보상·운송사 클레임·재고 조정의 책임 주체를 정책에 따라 결정한다. SLA는 상품과 계약별 설정값으로 취급하고 본문에 고정된 기간을 두지 않는다.

> **⚠️ 교환 시 신규 출고와의 합류**
>
> 교환은 **역방향 회수 + 정방향 신규 출고**가 묶이지만 한 DB 상태로 합치지 않는다. 두 Shipment를 별도로 추적하고 하나의 `ExchangeCase`에 연결한다. 선출고·후출고 정책, 회수 미완료 시 보류·취소·추가 청구 규칙을 명시하고, 어느 한쪽만 성공했을 때 보상 또는 운영자 검토 경로를 둔다.

> **⚠️ 재고 환원 타이밍 오류**
>
> QC 통과 전 재고를 환원하면 불량 재출고가 발생할 수 있다. **"보류 재고(RETURN_INSPECTING) → QC 통과 시 가용 전환"**의 2단계 상태를 두고, 환원 이벤트를 멱등하게 처리한다. 이미 전환된 수량을 다시 더하는 대신 업무 키별 처리 결과를 조회하고, 결과 불명확 시 대사 큐에서 확인한다.

## 7. 정책 비교 — 운영 조건별 역물류

| 조건 | 설계 선택 | 확인할 근거 |
| --- | --- | --- |
| 회수 경로가 기존 배송망과 겹침 | 회수 지점·운송장·입고 스캔을 하나의 사건 흐름으로 연결 | 운송사 계약, 스캔 이벤트, 분실·파손 책임 |
| 신선·개봉·위험 상품 | 반품 자격과 폐기·격리 기준을 접수 전에 명시 | 상품 규정, 안전·위생 기준, 사진·검수 증거 |
| 고가 또는 재판매 영향이 큰 상품 | QC 완료 후 환불하거나 선환불 후 사후 조정 | 고객·상품 위험 평가, 결제 정책, 대사 절차 |
| 교환 | 반품 Shipment와 신규 출고 Shipment를 `ExchangeCase`로 연결 | 선출고 조건, 회수 미완료 처리, 두 흐름의 보상 규칙 |

운영 사례를 인용할 때는 공개된 정책 문서와 실제 계약·상품 규칙을 확인한다. 특정 업체의 내부 반품률, 기사 동선, 환불 SLA를 일반 설계의 사실처럼 사용하지 않는다.

## 8. 백엔드 시스템 디자인 연결

| 역물류 이슈 | 설계 패턴 | 이유 |
| --- | --- | --- |
| 정·역 상태 머신 합류 | **별도 Aggregate + 도메인 이벤트** | 역방향 종결 시 `ReturnCompleted` 발행 → 정방향 `RETURNED` 전이, 느슨한 결합 |
| 상태 전이 이력 추적 | **이벤트 소싱(부분 적용)** | "왜 거부됐나" 감사 추적, 분쟁 시 회수~검수~환불 전 과정 재현 |
| 회수-검수-환불 분산 일관성 | **Saga + 보상 트랜잭션** | 각 단계의 확정 상태와 보상·수동 대사 경로를 분리 |
| 중복 환불 · 중복 환원 | **Idempotency-Key(멱등키)** | PG Refund·재고 환원 이벤트 재전송 시 한 번만 반영 |
| 재고 환원 타이밍 | **보류 재고 상태 분리** | `RETURN_INSPECTING` → QC 통과 시 가용 전환, 2단계 격리 |

> **🎯 면접 정리 — 한 문장**
>
> "역물류는 정방향과 **별도 상태 머신** 으로 모델링하되 `ReturnCompleted` 이벤트로 정방향에 합류시키고, **검수(QC)를 모든 분기의 게이트** 로 두며, 환불·재고 환원은 **Saga + 멱등키 + 보류 재고 격리** 로 일관성을 맞춘다."

```text
REQUESTED -> COLLECTED -> RECEIVED -> INSPECTED
                                      ├─ RESTOCKABLE -> RESTOCKED
                                      ├─ REPAIRABLE  -> REPAIR
                                      └─ DISPOSAL    -> DISPOSED
```

## 9. 설계 체크리스트

- 반품 요청이 주문 전체인지 특정 라인·수량인지 식별하는가?
- 주문 상태와 반품 상태를 별도 Aggregate로 저장하고, 합류 이벤트에 `returnId`, 대상 라인, 이벤트 ID를 포함하는가?
- `RETURN_INSPECTING` 수량이 가용·리퍼브·폐기 수량에 중복 집계되지 않는가?
- QC 재시도와 재검수에서 이전 재고 이동을 추적하고 상쇄할 수 있는가?
- 환불 요청의 멱등키, PG 환불 ID, 금액, 통화, 원주문을 저장하는가?
- PG 응답 타임아웃을 실패로 단정하지 않고 조회·웹훅·대사 큐로 결과를 확정하는가?
- 선환불 정책이라면 QC 불합격 후 추가 청구·환수·분쟁 처리의 책임과 상태가 있는가?
- 이벤트·스캔·검수 판정·환불 결과를 감사 추적할 수 있고, 개인정보와 결제정보를 최소화하는가?

## 10. 참고 자료

- [GS1 EPCIS 2.0 Standard](https://ref.gs1.org/standards/epcis/2.0.0/) — 물류 객체의 상태·변화·이벤트를 추적할 때 사용할 수 있는 이벤트 모델.
- [Stripe Refunds](https://docs.stripe.com/refunds) — 환불 객체와 결제 환불의 상태·실패 가능성을 확인하는 참고 자료.
- [Stripe Idempotent requests](https://docs.stripe.com/api/idempotent_requests) — 네트워크 재시도에서 같은 요청을 한 번만 처리하기 위한 멱등키 설계 참고 자료.
- [AWS Prescriptive Guidance: Saga pattern](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/saga.html) — 여러 서비스에 걸친 작업의 단계·보상·실패 처리를 설계할 때의 참고 자료.$review_21_logistics_06_returns_reverse_logistics$
WHERE slug = 'logistics-06-returns-reverse-logistics' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_21_logistics_07_case_studies$## 1. 공개 서비스와 설계 가설의 경계

이 카드는 네 회사의 서비스 설명을 출발점으로 OMS·WMS·TMS·라스트마일의 책임을 비교한다. 회사가 공개한 서비스 범위와 실제 내부 DB, 이벤트 버스, 재고 소유권, 배차 목적 함수는 서로 다른 정보다. 다음 표의 **공개 범위**만 회사 사례로 다루고, 아래 시스템 흐름은 면접용 가상 설계로 사용한다.

| 사례 | 공개 자료에서 확인할 수 있는 범위 | 여기서 검토할 설계 질문 |
| --- | --- | --- |
| 쿠팡 Rocket Delivery | 회사는 커머스·물류·라스트마일을 통합한 인프라와 빠른 배송을 설명한다. | 여러 서비스가 주문 약속·재고·운송 상태를 어떻게 조정할까? |
| CJ대한통운 | 회사는 택배·풀필먼트·운송 서비스를 설명한다. | 화주와 운송사 사이의 상태 계약과 중복 이벤트를 어떻게 다룰까? |
| 컬리 샛별배송 | 컬리는 밤 11시 주문 마감과 다음 날 아침 7시 배송을 기술 블로그에서 설명한다. | 마감 역산·온도 이탈·품질 판정을 어떻게 분리할까? |
| Amazon FBA | 판매자가 보낸 재고를 Amazon이 보관하고 주문 이행을 맡는 서비스다. | 판매자·SKU·창고별 원장과 분할 출고·정산을 어떻게 나눌까? |

[쿠팡 회사 소개](https://www.aboutcoupang.com/aboutus/)는 통합 물류 인프라와 배송 서비스를 설명한다. [CJ대한통운의 사업 소개](https://www.cjlogistics.com/ko/business/parcel)는 택배와 풀필먼트 사업을 구분한다. [컬리 기술 블로그](https://helloworld.kurly.com/blog/2023-delivery-system/)는 샛별배송의 마감·배송 약속을 설명한다. [Amazon FBA 소개](https://sellingpartners.aboutamazon.com/fulfillment-by-amazon)는 판매자 재고를 Amazon 네트워크로 보내는 절차를 설명한다. 이 자료만으로 회사별 내부 시스템의 일관성 수준은 알 수 없다.

## 2. 소유 경계와 데이터 일관성

수직 통합은 한 사업자가 여러 운영 단계를 조정할 여지를 넓히지만 **단일 트랜잭션이나 강한 일관성을 자동으로 만들지 않는다**. 3PL 연동도 모든 데이터가 반드시 최종 일관성이어야 한다는 뜻은 아니다. 동기 API로 확정하는 명령, 비동기 Webhook으로 받는 운송 사실, 주기적으로 대사하는 고객용 투영을 필드별로 구분해야 한다.

| 사실 | 가능한 원본 | 수신 측의 확인 |
| --- | --- | --- |
| 주문 약속과 취소 | OMS | 약속 버전·취소 가능 시점 |
| 창고의 실물·예약 수량 | WMS 또는 계약된 3PL 원장 | SKU·창고·상태·기준 시각 |
| 운송사 인수·배송 완료 | 운송사·기사 앱·스캐너 | 원본 이벤트 ID·발생 시각·증거 |
| 고객용 배송 상태 | OMS/TMS 읽기 모델 | 지연·정정·알림 정책 |
| 판매자 정산 | 계약별 원장 | 판매자·주문 라인·Shipment 연결 |

예를 들어 창고가 `SHIPPED`를 확정한 뒤 운송장 발급 응답을 잃었다고 하자. 새 운송장을 무조건 만들면 같은 화물에 운송장이 둘 생길 수 있다. `shipmentId`와 외부 요청 키를 기록하고 운송사에 기존 결과를 조회한 뒤, 결과가 없을 때만 재시도한다. 운송사 Webhook은 `providerEventId`로 멱등 수신하고 원본 이벤트와 고객용 현재 상태를 분리한다. 늦게 도착한 `IN_TRANSIT`가 이미 확인된 `DELIVERED`를 되돌리지 않도록 정정 절차를 둔다.

## 3. 배송 약속과 마감 역산: 컬리 사례를 가상 요구로 풀기

질문에 주어진 `23시 Cut-off → 다음 날 07시 도착`은 이 설계 문제의 입력이다. 실제 적용 상품·권역·날짜의 최신 조건은 별도로 확인해야 한다. 고정 마감이 있다면 주문 마감부터 배송 완료까지 8시간을 그대로 작업 시간으로 사용할 수 없다. 결제 확정, 주문 검증, Wave 구성, 피킹, 패킹, 상차, 간선, 최종 배송, 예외 여유를 역산한다.

```text
고객 약속 시각
  - 최종 배송 여유
  - 간선·터미널 여유
  - 상차·패킹·피킹 예상 시간
  = 해당 Wave의 최종 시작 시각
```

Wave picking은 같은 권역·온도대·출발 차수를 묶을 때 도움이 될 수 있지만 마감 직전 주문이 모두 같은 Wave에 들어가야 한다는 뜻은 아니다. 실시간 단건 처리와 배치 작업의 경계를 정하고, Wave가 늦어지면 약속을 조용히 유지하지 말고 대체 차수·지연 안내·취소 또는 환불 정책으로 분기한다.

콜드체인에서 온도 이탈이 관측되면 즉시 재판매 불가라고 단정하지 않는다. 기록의 신뢰도, 노출 온도·시간, 상품별 품질 기준을 확인하고 격리·검수·재배송·환불·폐기를 결정한다. 이 판정과 고객 보상을 별도 상태로 남겨야 나중에 원인을 설명할 수 있다.

## 4. 판매자 재고와 멀티 FC: FBA 사례를 가상 설계로 풀기

FBA처럼 판매자 재고를 사업자가 보관·이행하는 모델에서는 판매자, SKU, FC, 로트, 품질 상태를 한 숫자로 합치지 않는다. 실제 창고 선택 알고리즘은 공개 서비스 설명만으로 알 수 없으므로 아래 흐름은 설계 예다.

```mermaid
flowchart LR
    Order[주문 라인] --> Candidate[배송 약속·재고 후보 FC]
    Candidate --> Reserve[FC별 조건부 예약]
    Reserve --> Decision{필요 수량 확보?}
    Decision -->|예| Shipment[Shipment별 출고 지시]
    Decision -->|아니오| Recovery[부분 예약 해제·재할당·약속 변경]
    Shipment --> Ledger[판매자·상품·FC 원장과 정산]
```

같은 주문 라인이 여러 FC에서 나뉘면 `OrderLine → Shipment`가 1:N이 될 수 있다. FC별 예약 성공과 주문 전체 약속 확정은 별도 사건이다. 일부 FC만 성공했거나 응답이 유실되면 예약 ID로 결과를 조회하고, 재할당·분할 출고·보상 중 정책을 선택한다. 판매자 재고와 사업자가 매입한 재고가 한 플랫폼에 함께 있을 수 있으므로 회사 이름만으로 모든 상품의 소유권을 단정하지 않는다.

## 5. 네 사례에서 공통으로 확인할 실패 흐름

| 실패 입력 | 판단할 사실 | 복구 경로 |
| --- | --- | --- |
| 운송사 이벤트 중복·역순 도착 | 원본 이벤트 ID와 현재 투영 버전 | 멱등 저장 후 허용 전이·정정 큐 |
| 외부 발번 성공 뒤 응답 유실 | 외부 요청 키·기존 운송장 조회 결과 | 중복 발번 없이 재조회·대사 |
| 냉장 상품의 온도 이탈 | 센서 기록·상품별 품질 규정 | 격리·검수 후 재배송·보상 판정 |
| 여러 FC 중 일부 예약만 성공 | FC별 예약 ID와 만료 시각 | 분할·재할당·보상 및 고객 약속 갱신 |
| 장부와 실물 수량 불일치 | 실사 기준 시각·재고 상태 | 승인된 조정 이벤트와 원장 대사 |

면접에서는 먼저 공개 자료로 확인된 서비스 범위를 말한다. 다음으로 각 사실의 소유자와 상태 전파 계약을 정하고, 위 실패 흐름에서 응답 유실·중복·부분 성공이 일어났을 때 고객 약속과 원장이 어떻게 수렴하는지 설명한다. 특정 회사의 실제 DB, 이벤트 버스, cut-off 구현, FC 할당 목적 함수는 확인되지 않은 가설로 표시한다.

> **사례 해석 경계** — 표의 설계 질문과 복구 경로는 공개 서비스 설명을 바탕으로 만든 학습용 가설이다. 특정 회사의 내부 구현이나 실제 장애 대응 절차로 단정하지 않는다.

## 참고 자료

- [Coupang About Us](https://www.aboutcoupang.com/aboutus/)
- [CJ대한통운 택배·풀필먼트 사업](https://www.cjlogistics.com/ko/business/parcel)
- [컬리 기술 블로그 — 배송 시스템](https://helloworld.kurly.com/blog/2023-delivery-system/)
- [Amazon Fulfillment by Amazon](https://sellingpartners.aboutamazon.com/fulfillment-by-amazon)$review_21_logistics_07_case_studies$
WHERE slug = 'logistics-07-case-studies' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_21_logistics_08_dispatch_optimization$> **검수 경계 — 공개 알고리즘과 예시 설계를 구분한다**
>
> H3·OR-Tools·Redis의 문서가 보장하는 기능과, 특정 배달 회사의 실제 운영 알고리즘은 서로 다른 주장이다. 이 카드의 수치·윈도우·처리량은 제품 요구사항으로 주어진 값이 아니라 예시 변수로 다룬다. Uber·배민·쿠팡의 내부 매칭 정책이나 품질 개선 폭은 공개 자료가 확인하는 범위에서만 언급하고, 나머지는 가상 설계로 표시한다.

## 1. 요구사항 명확화 (Functional / Non-functional)

배차 최적화 시스템(Dispatch Optimization System)은 "발생한 주문·화물"과 "가용한 기사·차량"을 잇고, 각 기사의 방문 순서(경로)를 최소 비용으로 배열하는 엔진이다. 즉시배송(퀵커머스)과 계획배송(당일·익일)이 한 플랫폼에 공존한다고 가정한다.

### Functional Requirements

| 구분 | 요구사항 |
| --- | --- |
| 매칭(Matching) | 신규 주문을 후보 기사 집합에서 최적 기사에게 배정 |
| 라우팅(Routing) | 배정된 기사의 다중 정거장 방문 순서 최적화 (VRP/VRPTW) |
| 재배차(Re-dispatch) | 기사 이탈·노쇼·주문 취소 시 남은 화물 재배정 |
| 실시간 삽입(Dynamic insertion) | 운행 중 기사 동선에 신규 주문 끼워넣기 |
| 상태 관리 | 기사 상태(대기/배정/픽업/운행/오프라인) 원자적 전이 |

### Non-functional Requirements

- **매칭 지연 SLA(Service Level Agreement)**: 즉시배송은 주문 접수 → 배정까지 **P99 3초** 이내. 계획배송은 배치 수 분 허용.
- **정합성(Consistency)**: 이중 배차 절대 금지 — 한 기사, 한 시점, 한 활성 배정.
- **가용성(Availability)**: 최적화 엔진 장애 시에도 greedy fallback으로 배차는 계속.
- **확장성(Scalability, 예시 입력)**: 피크 시간당 100만 주문(평균 약 280건/초), 활성 기사 10만. 실제 목표는 제품 SLA와 관측 데이터로 정한다.

> **🎯 면접 포인트 — "무엇을 최소화하나"를 먼저 못 박아라**
>
> 요구사항 단계에서 목적함수(objective)를 확정하지 않으면 설계가 산으로 간다. 즉시배송은 **고객 대기시간(pickup ETA)** 최소화가 1순위, 계획배송은 **총 주행거리·차량 수** 최소화가 1순위다. 여기에 기사 수입 형평성(fairness)·취소율까지 얹히면 **다목적 가중합(weighted multi-objective)** 이 된다. "그냥 가까운 기사요"라고 답하면 시니어 탈락. 🔥

## 2. 용량 추정 (Back-of-the-envelope)

정량 감각은 제품 요구사항으로 주어진 예시 입력을 사용한다. 아래 값은 특정 회사의 공개 처리량이 아니다.

- **주문 유입 예시**: 피크 시간당 **100만 건** → 평균 **약 280 QPS(Queries Per Second, 초당 쿼리 수)**. 실제 피크와 허용 지연은 제품 요구사항으로 다시 산정한다.
- **활성 기사 예시**: **10만 명**이 5초마다 위치를 갱신한다고 가정하면 위치 업데이트량은 20,000건/초다. 이 값은 설계 입력이며 특정 회사의 공개 처리량이 아니다.
- **거리/시간 행렬**: n개 정거장이면 `n²` 셀. 기사당 20 스톱이면 400 셀, 캐싱 필수.
- **매칭 상태 저장**: 활성 배정 10만 × (주문ID·기사ID·상태·TTL) ≈ 수십 MB → 인메모리(Redis) 충분.

> **💡 팁 — 후보 축소가 90%의 승부처**
>
> 배차의 계산량은 "후보 기사 수 × 주문 수"에 지배된다. 후보를 10만 → 50으로 줄이면 계산량이 **2,000배** 감소한다. 지오 인덱스(H3/S2) 기반 반경 후보 조회가 사실상 전체 시스템의 처리량 상한을 결정한다.

## 3. API / 데이터 모델

### API

```kotlin
// 신규 주문 배차 요청 (즉시배송)
POST /v1/dispatch
{
  "orderId": "ORD-9F2A",
  "pickup":   { "lat": 37.4979, "lng": 127.0276 },  // 판교
  "dropoff":  { "lat": 37.5013, "lng": 127.0396 },
  "slaSeconds": 1800,          // 시간창(VRPTW) — 30분 내 완료
  "capacity":  1               // 적재 단위
}
// 202 Accepted → 비동기 배정. 결과는 이벤트/웹훅으로 통지

// 기사 위치 스트리밍 (5초 주기, 대량)
POST /v1/drivers/{driverId}/location
{ "lat": 37.499, "lng": 127.031, "ts": 1751846400, "state": "IDLE" }

// 재배차 트리거 (기사 이탈·취소)
POST /v1/dispatch/{orderId}/reassign
{ "reason": "DRIVER_OFFLINE" }
```

### 데이터 모델 (Aggregate 경계)

```mermaid
erDiagram
    ORDER ||--o| ASSIGNMENT : "배정된다"
    DRIVER ||--o{ ASSIGNMENT : "수행한다"
    DRIVER ||--|| DRIVER_STATE : "현재상태"
    ASSIGNMENT ||--|{ ROUTE_STOP : "동선"
    ORDER {
        string order_id PK
        string status
        int sla_seconds
        geo pickup
        geo dropoff
    }
    DRIVER_STATE {
        string driver_id PK
        geo location
        string state
        int active_capacity
        long version
    }
    ASSIGNMENT {
        string assignment_id PK
        string order_id FK
        string driver_id FK
        string status
        long assigned_at
    }
    ROUTE_STOP {
        string assignment_id FK
        int seq
        string stop_type
        geo location
        long eta
    }
```

> **⚠️ 실무 함정 — 기사 상태는 강한 일관성, 위치는 최종 일관성**
>
> `DRIVER_STATE.state`(IDLE→ASSIGNED)의 조건부 전이는 이중 배차를 막는 **정합성의 핵심**이다. 위치는 관측 시각과 허용 지연을 가진 별도 투영으로 다룰 수 있다. 위치 갱신과 배정 원장을 한 핫 레코드에 묶으면 경합이 커질 수 있으므로 저장·갱신 경계를 측정해 정한다. Redis 안의 원자 전이가 다른 DB의 배정 원장까지 원자화하지는 않는다.

## 4. High-level 아키텍처

```mermaid
flowchart TB
    subgraph Ingest["유입 계층"]
        ORD["주문 API"]
        LOC["위치 스트림 API\n(처리량은 요구사항으로 산정)"]
    end
    ORD --> MQ["주문 큐\n(Kafka 파티션: geo-shard)"]
    LOC --> GEO["지오 인덱스 스토어\n(Redis GEO / H3 셀)"]

    MQ --> MATCH["매칭 서버\n(shard by region)"]
    GEO -->|"후보 기사 조회\n반경 축소"| MATCH
    MATCH -->|"조건부 배정\n(CAS on version)"| STATE[("기사 상태\n원장·투영 경계 명시")]
    MATCH --> OPT["최적화 워커\nVRP/VRPTW\n(OR-Tools)"]
    OPT -->|"동선 갱신"| MATCH
    MATCH --> EVT["배정 이벤트\n(Outbox → Kafka)"]
    EVT --> PUSH["기사 앱 푸시"]
    EVT --> ETA["ETA / 고객 트래킹"]
    EVT --> SETTLE["정산"]

    style MATCH fill:#dcfce7,stroke:#22c55e
    style OPT fill:#fef3c7,stroke:#f59e0b
    style STATE fill:#dbeafe,stroke:#3b82f6
```

*배차 엔진 아키텍처 — 지역 샤딩된 매칭 서버 + 지오 인덱스 후보 축소 + 원자적 상태 전이 + 비동기 VRP 워커*

핵심은 **매칭 서버를 지역(region)으로 샤딩**해 한 지역의 주문·기사·상태를 한 파티션에서 처리하는 것이다. 그래야 이중 배차를 로컬에서 직렬화할 수 있고, 크로스 리전 분산 락을 피한다.

## 5. Deep-dive

### 5-1. VRP의 NP-hard와 실무 근사

VRP(Vehicle Routing Problem, 차량 경로 문제)와 그 파생인 VRPTW(VRP with Time Windows, 시간창 제약)·CVRP(Capacitated VRP, 용량 제약)는 모두 **NP-hard**다. 정거장 n개의 경로 조합은 계승(factorial)으로 폭증해 20개만 돼도 완전 탐색이 불가능하다. 따라서 최적해 대신 **"충분히 좋은 해를 수십 ms~수 초에"** 찾는다.

| 접근 | 방법 | 특징 · 도구 |
| --- | --- | --- |
| 정확해(Exact) | 정수계획법(MILP), 분기한정(B&B) | 최적 보장, 수십 노드 한계. `Gurobi`, `CPLEX` |
| 휴리스틱(Heuristic) | 최근접 이웃, Savings, cheapest insertion | 빠르고 단순, 초기해·실시간 삽입용 |
| 메타휴리스틱(Metaheuristic) | 2-opt/Or-opt, 타부서치, ALNS, 담금질 | 품질↑ 시간↑. `OR-Tools`(구글), `LKH` |

실시간 매칭에서는 **cheapest insertion(최소 비용 삽입)** 으로 즉시 배정하고, 백그라운드 워커가 **국소 2-opt/ALNS**로 동선을 다듬는 2단계 구조를 선택할 수 있다. SLA와 목적 함수에 맞춰 검증한다.

### 5-2. 배치 매칭 vs 실시간 greedy 매칭

```mermaid
sequenceDiagram
    participant O as 주문
    participant M as 매칭 서버
    participant W as 배치 윈도우 버퍼
    participant D as 기사 풀

    Note over M,W: 가상 배치 모드
    O->>W: 주문 도착 (버퍼링)
    Note over W: 짧은 윈도우로 모음
    W->>M: 윈도우 종료 → 일괄 최적화
    M->>D: 윈도우 내 후보 매칭(시간 제한)
    Note over M: 대기 지연 증가, 품질은 평가 필요

    Note over M,D: greedy 모드 (초저지연)
    O->>M: 주문 도착 즉시
    M->>D: 최근접 가용 기사 배정
    Note over M: 대기 지연 감소, 후속 주문은 미반영
```

| 관점 | 배치 매칭 (Batch) | 실시간 greedy |
| --- | --- | --- |
| 매칭 지연 | 큼 (윈도우 정책에 따름) | 작음 (서비스 SLA에 따름) |
| 해 품질 | 윈도우 안의 후보를 함께 비교할 수 있음 | 현재 후보에서 빠르게 선택하나 후속 주문을 보지 못함 |
| 기사 활용 | 묶음 배정 기회가 생기지만 대기 비용 발생 | 즉시 배정하되 후속 주문과 묶을 기회 감소 |
| 취소·이탈 민감도 | 윈도우 안에서는 재계산 가능, 확정 후에는 재배차 필요 | 확정 직후부터 재배차 정책 필요 |
| 적용 예 | 공개 자료와 제품 요구사항으로 검증 | 단순 콜 배차 설계 예 |

> **🎯 면접 포인트 — 우버는 왜 "잠깐 기다렸다" 매칭하나**
>
> 직관과 달리 **즉시 배정이 항상 최선은 아니다**. [Uber의 승차 매칭 설명](https://www.uber.com/ca/en/marketplace/matching/)은 가까운 기사·승객 요청을 몇 초 모아 한 배치에서 평가한다고 밝힌다. 이는 Uber 승차 서비스의 공개 사례이며 배민·쿠팡의 내부 알고리즘이나 모든 배달 서비스의 표준을 뜻하지 않는다. 이 카드의 가상 설계에서는 배치와 greedy를 지연·밀도·재배차 비용으로 비교하고, 개선 폭을 동일한 데이터셋과 목적 함수로 측정한다.

### 5-3. 지오 인덱스로 후보 축소 (H3 / S2 / geohash)


| 인덱스 | 셀 모양 | 특징 |
| --- | --- | --- |
| **H3** | 육각형(hexagon) | 이웃 셀 조회와 링 확장을 제공하며 후보 검색에 사용할 수 있음 |
| **S2** (Google) | 사각형(구면 힐베르트) | 계층·범위 스캔 강함, 지리 검색 범용 |
| **geohash** | 사각형(문자열) | 단순·prefix 검색, 경계 왜곡·경계 문제 큼 |

> **⚠️ 실무 함정 — 셀 경계(boundary) 문제**
>
> 픽업 지점이 셀 가장자리에 있으면 더 가까운 기사가 옆 셀에 있어 후보에서 누락될 수 있다. 픽업 셀과 인접 셀을 함께 조회하고, H3에서는 gridDisk 같은 이웃 셀 조회를 사용한 뒤 실제 거리·ETA로 재필터링한다. hotspot에서는 한 셀의 후보 수가 급증할 수 있으므로 해상도·조회 반경·상위 후보 수를 운영 변수로 둔다. 후보 축소로 해 품질이 얼마나 떨어지는지는 동일한 로그와 목적 함수로 측정한다.

### 5-4. 이중 배차 방지 — 원자적 할당

가장 위험한 정합성 문제. 두 주문 스레드가 같은 IDLE 기사를 동시에 집으면 **한 기사에 두 배정**이 생긴다.

```kotlin
// Redis Lua — CAS(Compare-And-Swap) 원자적 배정
// KEYS[1] = driver:{id}:state, ARGV[1] = orderId
val script = """
  if redis.call('HGET', KEYS[1], 'state') == 'IDLE' then
    redis.call('HSET', KEYS[1], 'state', 'ASSIGNED', 'order', ARGV[1])
    return 1            -- 배정 성공
  else
    return 0            -- 이미 다른 주문이 선점 → 다음 후보로
  end
"""
```

| 기법 | 지연 | 처리량 | 정합성 | 적합성 |
| --- | --- | --- | --- | --- |
| 낙관적 락 (version CAS) | 충돌·재시도에 좌우 | 핫 행 경합에 좌우 | DB의 조건부 갱신 범위 | 충돌 드문 상태 전이 |
| 분산 락 (Redis/etcd) | lease 획득·갱신 비용 | 락 키 경합에 좌우 | 보호 대상 쓰기와 fencing을 별도로 설계 | 여러 작업자 조정 |
| 원자적 CAS (Lua/CAS) | 저장소 내부 왕복·경합에 좌우 | 핫 키 분포에 좌우 | 해당 저장소의 한 상태 전이를 원자화 | **단일 기사 상태 전이** |
| 단일 파티션 직렬화 | 큐 적체에 좌우 | 파티션 수·핫 지역에 좌우 | 파티션 소유 경계의 순서 보장 | 지역 샤드 내 순차 처리 |

지역 샤딩, DB 낙관적 락, Redis CAS, 단일 파티션 직렬화 중 하나 또는 조합을 선택하되, 각 선택의 소유 경계와 복구 경로를 명시한다. 매칭 서버가 지역별로 샤딩돼 있으면 한 지역 배정이 한 스레드에서 순차 처리돼 경합 자체가 줄고, 남은 경합은 CAS로 막는다.

### 5-5. 실시간 재배차

```mermaid
stateDiagram-v2
    [*] --> PENDING : 주문 접수
    PENDING --> ASSIGNED : 매칭 성공 (CAS)
    ASSIGNED --> PICKED_UP : 기사 픽업
    PICKED_UP --> DELIVERED : 배송 완료
    ASSIGNED --> PENDING : 기사 이탈/노쇼 (재배차)
    ASSIGNED --> CANCELLED : 고객 취소 → 기사 해제
    PICKED_UP --> REASSIGN_MID : 기사 사고 (인계 재배차)
    REASSIGN_MID --> PICKED_UP : 인접 기사 인수
    DELIVERED --> [*]
    CANCELLED --> [*]
```

*배차 상태 머신 — 이탈·취소·중도 사고를 재배차/해제로 흡수. 각 전이는 도메인 이벤트로 발행*

- **기사 이탈·노쇼**: `ASSIGNED → PENDING` 으로 되돌려 재매칭 큐에 재투입. 이때 기사 상태는 CAS로 IDLE 복귀.
- **고객 취소**: 배정 해제 + 기사 즉시 IDLE → 다음 후보로. 취소가 픽업 후면 반품 흐름.
- **멱등성(Idempotency)**: 재배차 트리거·기사 스캔은 중복 수신되므로 `assignment_id` 기준 멱등 처리. 안 그러면 한 주문이 두 번 재배차된다.

### 5-6. 시뮬레이션과 A/B

배차 알고리즘은 프로덕션에서 바로 실험하면 위험하다(잘못된 매칭 = 실제 지각·손실). 그래서 **과거 주문·기사 로그를 리플레이하는 시뮬레이터**로 오프라인 평가 후, **셰도우 트래픽(shadow) → 소규모 지역 A/B → 전면 롤아웃** 순으로 검증한다. 지표는 픽업 ETA·완료율·기사 유휴율·취소율.

> **💡 팁 — 배차는 마켓플레이스다, "매칭"만 보지 마라**
>
> 배차 최적화의 궁극 목표는 개별 매칭이 아니라 **공급(기사)-수요(주문) 균형**이다. 특정 지역에 주문이 몰리면 인접 지역 기사를 미리 유도(surge/reposition)하는 것까지가 배차의 영역이다. 가격·인센티브·재배치가 배차 공급에 영향을 줄 수 있다는 가설은 별도의 비즈니스 정책으로 검증해야 한다.

## 6. Trade-off 정리

| 결정 | 선택지 A | 선택지 B | 언제 A / 언제 B |
| --- | --- | --- | --- |
| 매칭 방식 | 짧은 윈도우의 배치 | greedy(즉시) | 밀도·지연 예산·이탈률을 측정해 선택 |
| 최적화 위치 | 동기(요청 경로) | 비동기 워커 | SLA 여유 → A / 초저지연 → B(삽입만 동기) |
| 이중배차 방지 | 분산 락 | 지역 샤딩+CAS | 크로스 리소스 → A / 단일 상태 → B |
| 후보 축소 | 큰 반경(품질↑) | 작은 반경(속도↑) | 저밀도 → A / hotspot → B |
| 재배차 | 즉시 전체 재계산 | 증분 삽입 | 대량 이탈 → A / 단건 → B |

> **🎯 면접 정리 — 한 문장**
>
> "배차 최적화는 **지오 인덱스로 후보를 줄이고**, **밀도와 SLA에 따라 배치/greedy를 선택**하며, **VRP의 제약과 시간 제한을 둔 근사 해법**을 사용한다. 배정 상태는 조건부 갱신으로 이중 배차를 막고, 위치 지연·기사 이탈·최적화 시간 초과는 멱등 이벤트와 fallback으로 흡수한다."

## 7. 실패 흐름과 검증 경계

배차는 점수 계산만으로 끝나지 않는다. 다음 상태를 함께 설계해야 한다.

- **후보 셀 경계 누락**: 픽업 셀 하나만 조회하지 말고 H3의 인접 셀 조회 범위를 정책으로 정한다. 조회 범위를 넓힌 뒤 거리·ETA로 재필터링한다.
- **동시 배정**: 후보를 읽은 뒤 상태를 다시 조건부 갱신한다. Redis 스크립트가 원자적이어도 Redis와 관계형 DB의 원자성이 자동으로 합쳐지는 것은 아니므로 최종 원장, outbox, 재대사 작업을 둔다.
- **기사 이탈·노쇼**: assignment_id 기준으로 한 번만 재배차 큐에 넣고, 이전 배정의 해제와 새 배정의 소유자를 기록한다.
- **위치 데이터 지연**: 마지막 위치의 시각과 정확도를 함께 보관하고, 오래된 위치를 현재 위치처럼 사용하지 않는다.
- **최적화 시간 초과**: 무응답으로 두지 말고 제한 시간 내 최선의 해, greedy fallback, 수동 운영 큐 중 하나를 명시한다.
- **실험 중 품질 저하**: 과거 로그 리플레이와 shadow 평가로 지표를 비교한 뒤 작은 권역부터 rollout한다. 개선 폭은 반드시 동일 데이터셋과 동일 목적 함수로 보고한다.

## 8. 공식 출처

- [Google OR-Tools — Vehicle Routing](https://developers.google.com/optimization/routing)
- [Google OR-Tools — Routing Options](https://developers.google.com/optimization/routing/routing_options)
- [H3 — gridDisk traversal](https://h3geo.org/docs/api/traversal/)
- [Uber — Marketplace Matching](https://www.uber.com/ca/en/marketplace/matching/)
- [Redis — Lua scripting atomic execution](https://redis.io/docs/latest/develop/programmability/eval-intro/)
- [Redis — Functions](https://redis.io/docs/latest/develop/programmability/functions-intro/)

OR-Tools 문서는 VRP의 제약·탐색 제한·최적해 보장의 한계를 설명하고, H3 문서는 인접 셀 조회 API를 설명한다. Uber 자료는 자사 승차 매칭의 공개 설명이며 배달 회사의 내부 구현을 증명하지 않는다. Redis 원자성은 Redis 실행 단위에 한정되며 다른 DB와의 분산 트랜잭션을 보장하지 않는다.$review_21_logistics_08_dispatch_optimization$
WHERE slug = 'logistics-08-dispatch-optimization' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_21_logistics_09_interview_domain$> **검수 경계 — 면접 시나리오는 가상 장애다**
>
> 이 카드의 “택배사 API가 6시간 죽었다”는 문장은 실제 특정 회사의 장애 기록이 아니라 면접용 가상 입력이다. 회사별 SLA, 재고 원장, 결제·운송 계약은 공개 자료와 계약에 따라 다르므로 숫자나 복구 시간을 보편 규칙처럼 답하지 않는다. 답변은 상태 소유자, 재시도·멱등성, 보상, 고객 안내, 대사와 운영 개입의 경계를 설명해야 한다.

## 1. 면접 시나리오 개요

이 카드는 **물류 도메인 지식 면접**을 시뮬레이션한다. 면접관은 대규모 커머스의 재고·주문 정합성을 가상 시나리오로, 표면적 답변이 나오면 **실무 엣지 케이스로 파고든다**. 각 라운드는 `메인 질문 → 모범 답변 포인트 → 압박 후속 질문` 구조다. 답을 먼저 스스로 말해보고 포인트와 대조하라.

전제 시스템: **OMS**(Order Management System, 주문관리) — 주문 수집·검증·상태, **WMS**(Warehouse Management System, 창고관리) — 입고·보관·피킹·출고, **TMS**(Transportation Management System, 운송관리) — 배차·운송. 이 카드는 세 시스템이 별도 서비스·별도 DB인 가상 전제를 사용한다. 실제 제품의 경계는 요구사항과 운영 계약으로 확인해야 한다.

```mermaid
flowchart LR
    C["고객"] -->|"주문"| OMS["OMS\n주문·판매가능재고"]
    OMS -->|"출고 지시"| WMS["WMS\n실물재고·피킹"]
    WMS -->|"운송장 생성"| TMS["TMS\n배차·배송"]
    OMS -.->|"재고 이벤트\n(비동기)"| WMS
    WMS -.->|"입고·실사 반영\n(비동기)"| OMS
    style OMS fill:#dbeafe,stroke:#3b82f6
    style WMS fill:#dcfce7,stroke:#22c55e
    style TMS fill:#fef3c7,stroke:#f59e0b
```

*세 시스템 경계 — OMS는 판매가능재고, WMS는 실물재고를 본다. 이 둘의 간극이 모든 면접 질문의 씨앗*

> **💡 팁 — "재고는 하나의 숫자가 아니다"부터 깔고 들어가라**
>
> 초보는 재고를 `stock: 100` 단일 값으로 본다. 실무는 **On-hand(실물)·Available(가용)·Reserved(예약)·In-transit(이동중)·Damaged(손망실)** 를 구분한다. 이 구분을 첫 문장에 깔면 이후 모든 압박 질문에 방어선이 생긴다.

## 2. 라운드별 압박 시나리오

### 라운드 1 — 주문↔재고 정합성을 어떻게 보장하나

**메인 질문**: "고객이 주문하면 재고를 차감해야 한다. OMS와 WMS가 별도 DB인데, 어떻게 정합성을 맞추나?"

**모범 답변 포인트**
- 주문 시점에 가용 수량을 예약하고 실물 원장의 감소 시점을 별도 정책으로 둔다. 예시로 Available과 Reserved를 예약 시 갱신하고, On-hand는 피킹·출고 확정·재고 원장 정책 중 하나에서 갱신할 수 있다. 동일 수량을 두 번 차감하지 않도록 원장 이벤트로 추적한다.
- 이 카드의 3단계 라이프사이클인 Reserve(예약) → Commit(확정) → Ship(출고)는 하나의 설계 예시다, 미결제·이탈은 **예약 만료(TTL)** 로 자동 환원.
- 서비스 간 원자성이 불가하므로 **Saga(보상 트랜잭션)** + **Outbox(아웃박스로 이벤트 발행 보장)** 로 최종 일관성.

**압박 후속 질문**
1. "예약만 하고 결제가 20분간 안 오면? 그 재고는 죽어 있나?" → 예약 TTL(만료)로 자동 해제, 만료 이벤트로 Available 환원. TTL을 너무 길게 잡으면 재고가 잠겨 **판매 기회 손실**, 너무 짧으면 결제 중 만료로 **결제 후 품절** 사고.
2. "Outbox 없이 그냥 커밋 후 이벤트 발행하면?" → 커밋 성공·발행 실패 시 **재고 이벤트 유실** → WMS가 모르는 유령 예약. Outbox는 커밋과 이벤트를 한 트랜잭션에 묶어 유실을 막는다.

> **⚠️ 실무 함정 — "재고를 그냥 빼면 되지"는 즉시 탈락**
>
> 주문 즉시 실물 원장을 차감하면 결제 실패·이탈·취소 시 환원 타이밍이 꼬일 수 있다. 예약·확정·출고 시점을 분리하고, 동시성 조건부 갱신과 보상 이벤트를 둔다.

### 라운드 2 — 오버셀이 났다, 어떻게 복구하나

**메인 질문**: "프로모션 트래픽에 동시성 제어가 뚫려 재고 10개인데 13건이 결제됐다. 어떻게 복구하나?"

**모범 답변 포인트**
- 먼저 **재발 방지**와 **기발생 복구**를 분리. 재발은 원자적 차감(DB `UPDATE ... WHERE available > 0`, 조건부 감소)·분산 락으로.
- 복구는 **자동 vs 수동 경계**를 정한다: 소액·재입고 임박은 자동 지연 배송 안내, 고가·긴급은 수동 CS 개입.
- 보상 우선순위: ① 고객(가장 먼저 알림·대안 제시·보상쿠폰) ② 재고(초과분 취소 처리, 재입고 예약) ③ 정산(취소분 결제 취소·PG 환불, 정산 마감 전 반영).

**압박 후속 질문**
1. "13명 중 누구를 취소시키나? 순서는?" → 정책 문제. 결제 완료 시각 순(선착순), 또는 등급·귀책. 아무 기준 없이 랜덤 취소하면 **CS 폭발**. 면접에선 "비즈니스 정책으로 명시적 규칙을 둔다"가 정답.
2. "이미 출고 지시가 WMS로 넘어간 3건은?" → 출고 취소 가능 상태면 회수, 이미 피킹·상차됐으면 **되돌릴 수 없어** 다른 창고 재고로 대체하거나 사과·보상. 상태에 따라 복구 경로가 갈린다.

```kotlin
// 재발 방지 — 조건부 원자적 차감 (오버셀 방지의 1차 방어선)
// 영향 행수 0이면 재고 부족 → 예약 실패로 처리
val affected = jdbc.update(
    """
    UPDATE inventory
       SET available = available - :qty,
           reserved  = reserved  + :qty
     WHERE sku = :sku
       AND available >= :qty
    """.trimIndent(),
    mapOf("qty" to qty, "sku" to sku),
)
if (affected == 0) throw OutOfStockException(sku)  // 오버셀 차단
```

> **🎯 면접 포인트 — "복구"를 기술로만 답하면 반쪽**
>
> 오버셀 복구는 순수 기술 문제가 아니라 **고객 경험·정산·법무가 얽힌 운영 문제**다. 시니어는 "누구를 취소할지, 어떻게 통지할지, 정산 마감과 어떻게 정렬할지"라는 **정책·프로세스**까지 답한다. 기술적 롤백만 말하면 미들 수준. 🔥

### 라운드 3 — WMS와 OMS의 재고가 다르다, 어디가 진실인가

**메인 질문**: "WMS는 실물 98개, OMS는 판매가능 90개라고 한다. 어느 쪽이 맞나?"

**모범 답변 포인트**
- **둘 다 일부 필드에서는 맞을 수 있다** — 서로 다른 시점·상태·책임 범위를 세기 때문이다. 단순히 "한쪽이 진실"이라 답하면 안 된다.
- 차이의 정상적 원인: ① **예약(Reserved)** — OMS가 판 것을 뺐지만 아직 실물은 있음 ② **이동중(In-transit)** — 창고 간 이동 재고 ③ **미반영 입고** — 입고됐으나 OMS 미동기화 ④ **실사 차이(손망실·오피킹)** — 전산≠실물.
- **진실의 원천**은 필드와 시점별로 계약한다. 물리 입고·피킹·실사 원장은 WMS가 담당할 수 있고, 고객에게 노출하는 판매 가능 수량은 예약·안전재고를 반영한 OMS 투영이 담당할 수 있다. 이 구성이 모든 제품에 자동으로 적용되는 것은 아니다. 정기 **재고 실사(Cycle count)** 로 격차를 좁히고 원인을 분류한다.

**압박 후속 질문**
1. "그럼 고객에게 보여줄 '재고 있음/없음'은 누구 기준인가?" → **OMS의 Available** 기준(팔 수 있는가). 단, 안전재고(safety stock) 버퍼로 실사 오차·동시성 리스크를 흡수.
2. "실사에서 실물이 전산보다 계속 적게 나오면?" → 손망실·오피킹·도난 신호. 원인 분류 후 **재고 조정(adjustment)** 을 감사 로그와 함께 기록. 조용히 숫자만 맞추면 근본 원인을 못 잡는다.

| 항목 | 나쁜 답변 | 좋은 답변 |
| --- | --- | --- |
| 재고 모델 | "stock 하나로 관리" | On-hand/Available/Reserved/In-transit 구분 |
| 정합성 | "트랜잭션으로 묶으면 됨" | 서비스 분리 → 예약+Saga+Outbox+TTL |
| 진실 원천 | "무조건 한 시스템이 진실" | 필드별 원천을 계약하고 실사·대사로 수렴 |
| 불일치 | "버그니까 맞추면 됨" | 정상 원인 분류 + 손망실은 감사·조정 |

### 라운드 4 — 택배사 API가 6시간 죽었다

**메인 질문**: "가상 상황: 운송장 발번·배송 조회를 위탁하는 택배사 API가 일정 시간 장애다. 어떻게 버티나?"

**모범 답변 포인트**
- 주문과 출고를 무조건 멈추거나 무조건 계속하지 말고, 운송장 없이 물리 출고가 가능한지와 고객 약속을 확인한 뒤 비동기 큐·보류·대체 경로로 나눈다.
- **멱등성(Idempotency)** 필수 — 재시도로 같은 주문에 운송장 두 번 발번되면 안 됨. `orderId` 기준 멱등키.
- Circuit Breaker로 죽은 API를 계속 호출하지 않게 하고, 계약상 허용된 임시 shipment_id·대체 택배사·보류 큐 중 하나로 우회한다.
- 고객 배송 조회는 **캐시된 마지막 상태 + "조회 지연 안내"** 로 노출.

**압박 후속 질문**
1. "복구 후 6시간치 밀린 요청이 한꺼번에 몰리면?" → **큐 + Rate limit(속도 제한)** 으로 점진 소진(백프레셔). 한 번에 쏟으면 복구된 API를 또 죽인다.
2. "그 6시간에 발번 없이 상차·간선 출발한 화물은?" → 계약상 허용된 내부 shipment_id로 흐름을 잇고, 발번 후 외부 운송장과 매핑한다. 물리 흐름(상차)과 시스템 흐름(발번)을 분리해 설계한 게 핵심.

```mermaid
sequenceDiagram
    participant I as 면접관
    participant U as 지원자
    Note over I,U: 라운드 4 — 택배사 API 6시간 장애
    I->>U: 택배사 API가 죽었다, 주문을 멈추나?
    U->>I: 운송장 발번을 비동기 큐로 분리, 출고는 계속
    I->>U: 재시도하면 운송장 중복 발번은?
    U->>I: orderId 멱등키로 중복 차단
    I->>U: 복구 후 6시간치가 몰리면?
    U->>I: Rate limit + 백프레셔로 점진 소진
    I->>U: 발번 없이 상차된 화물은?
    U->>I: 사내 임시번호로 잇고 발번 후 매핑
    Note over I,U: 물리 흐름과 시스템 흐름 분리 → 시니어 시그널
```

*라운드 4 문답 흐름 — 압박이 3단계 이어질 때 방어선(비동기→멱등→백프레셔→흐름분리)이 무너지지 않아야 한다*

> **⚠️ 실무 함정 — 외부 API를 동기 강결합하면 전체가 같이 죽는다**
>
> 택배사·PG·지도 API 같은 외부 의존을 주문 처리 경로에 **동기 호출**로 박으면, 그 API 장애가 곧 주문 불능이 된다. 실무는 **비동기 분리 + Circuit Breaker + Fallback + 멱등 재시도**로 외부 장애를 흡수한다. "재시도하면 되죠"만 답하면 중복·폭주 함정에 빠진다.

## 3. 좋은 답변 vs 나쁜 답변 (종합)

| 주제 | 나쁜 답변 (탈락) | 좋은 답변 (합격) |
| --- | --- | --- |
| 재고 차감 | 주문 즉시 실물 원장 차감 | 예약·확정·출고의 시점과 TTL을 정책으로 명시 |
| 서비스 정합성 | 분산 트랜잭션(2PC)으로 묶기 | Saga + Outbox + 최종 일관성 |
| 오버셀 | "동시성 버그니까 락 걸면 끝" | 재발 방지 + 정책 기반 복구 + 보상 |
| 진실 원천 | "WMS가 무조건 맞다" | 관점별 진실 + 실사로 수렴 |
| 외부 API 장애 | "재시도하면 됨" | 비동기+CB+Fallback+멱등+백프레셔 |
| 불일치 처리 | 숫자만 맞춤 | 원인 분류 + 감사 로그 + 조정 |

> **💡 팁 — 압박에 답이 막히면 "정책으로 정한다"로 빠져나오라**
>
> "누구를 취소하나", "TTL 몇 분이 맞나" 같은 질문은 **정답이 없는 비즈니스 정책**이다. 임의 숫자를 우기지 말고 "이건 손실률·CS 비용·전환율을 저울질하는 비즈니스 정책 결정이고, 저라면 A/B로 튜닝하겠다"고 답하면 오히려 성숙도로 읽힌다.

## 4. 평가 루브릭 (자기 진단)

| 레벨 | 재고 모델 | 정합성 | 장애·엣지 | 종합 시그널 |
| --- | --- | --- | --- | --- |
| **주니어** | stock 단일 값 인식 | 트랜잭션으로 묶으려 함 | 재시도만 언급 | 정상 흐름만 답, 엣지 취약 |
| **미들** | On-hand/Available 구분 | 예약+최종 일관성 이해 | CB·멱등 언급 | 기술 해법은 알되 정책·운영 약함 |
| **시니어** | 5종 재고 상태 + 실사 | Saga+Outbox+TTL, 진실원천 관점화 | 백프레셔·흐름분리·정책 결정 | 기술+운영+비즈니스 균형, 압박 3단계 방어 |

> **🎯 면접 정리 — 한 문장**
>
> "물류 도메인 면접의 핵심은 **재고를 다차원 상태로 보고**(On-hand·Available·Reserved·In-transit), **분산 정합성을 예약+Saga+Outbox+TTL로 풀며**, **오버셀·불일치·외부장애를 정책과 보상 트랜잭션으로 복구**하고, **어느 쪽이 진실이냐에 '관점별 진실 + 실사 수렴'으로 답하는** 것 — 정상 흐름이 아니라 엣지 케이스에서 레벨이 갈린다."

## 5. 결과 불명과 보상 흐름을 반드시 말하기

분산 시스템에서 가장 위험한 상태는 실패가 확정된 상태만이 아니라, 요청이 처리됐는지 응답만 잃은 상태다.

- 재고 예약 요청의 응답이 유실되면 같은 명령을 재전송하되 command_id를 멱등 키로 사용하고, 원장 조회로 이미 처리됐는지 확인한다.
- 결제·운송·재고 중 하나가 결과 불명이면 즉시 취소로 덮지 말고 PENDING_RECONCILIATION 상태와 재조회 작업을 남긴다.
- 보상은 “롤백”이 아니라 이미 외부 세계에 반영된 작업을 되돌리는 별도 업무다. 예약 해제, 승인 취소, 환불, 배송 취소는 각각 성공·실패·결과 불명으로 기록한다.
- Outbox는 서비스 DB 변경과 이벤트 기록의 이중 쓰기 누락을 줄이지만, 소비자 중복과 외부 시스템의 멱등성까지 자동으로 해결하지 않는다.
- Saga는 여러 로컬 트랜잭션과 보상 흐름을 조정하는 패턴이며, 참가자는 반복 실행에 안전해야 한다. 참여자가 늘수록 상태 추적·관측성·운영 개입이 필요하다.

## 6. 공식 출처

- [AWS Prescriptive Guidance — Saga patterns](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/saga-patterns.html)
- [AWS Prescriptive Guidance — Saga orchestration](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/saga-orchestration.html)
- [Microservices.io — Transactional outbox pattern](https://microservices.io/patterns/data/transactional-outbox)
- [Redis — Lua scripting and atomic execution](https://redis.io/docs/latest/develop/programmability/eval-intro/)
- [Microsoft Learn — Inventory on-hand and reserved physical](https://learn.microsoft.com/en-us/dynamics365/supply-chain/inventory/inventory-on-hand-list)
- [Microsoft Learn — Cycle counting](https://learn.microsoft.com/en-us/dynamics365/supply-chain/warehousing/cycle-counting)

AWS 자료는 Saga가 로컬 트랜잭션과 보상 트랜잭션으로 구성되고, 반복 실행·결과 불명·최종 일관성을 고려해야 함을 설명한다. Outbox 문서는 DB 기록과 이벤트 발행의 이중 쓰기 문제를 다룬다. 이 출처들이 특정 OMS/WMS 제품의 필드 소유권을 결정해 주는 것은 아니므로, 면접에서는 제품 요구사항과 계약을 먼저 제시한다.$review_21_logistics_09_interview_domain$
WHERE slug = 'logistics-09-interview-domain' AND source = 'MANUAL';
