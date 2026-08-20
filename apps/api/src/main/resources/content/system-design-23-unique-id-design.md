---
area: SYSTEM_DESIGN
mode: DESIGN
coach: system-design-coach
title: "분산 고유 ID 설계 — 순서·충돌·정보 노출"
slug: system-design-23-unique-id-design
topicKey: system-design-147
difficulty: 4
summary: "UUID, 구간 할당, 시간 기반 ID를 비교하고 시계 역행과 노드 ID 충돌을 견디는 생성기를 설계한다."
tags:
  - "Unique ID"
  - "UUID"
  - "Snowflake"
  - "Clock Skew"
questions:
  - "랜덤 UUID와 시간 정렬 ID가 B-Tree 쓰기 패턴과 정보 노출에 어떤 차이를 만드나요?"
  - "시간 기반 생성기에서 시계가 뒤로 갈 때 안전하게 대응하는 전략을 설명해보세요."
  - "노드 ID 할당이 중복되면 어떤 장애가 생기며 이를 어떻게 탐지하고 차단하나요?"
---
## 1. 필요한 속성을 먼저 고른다

전역 고유성, 대략적 시간 순서, 생성 가용성, 예측 불가능성은 서로 다른 요구다. 외부 공개 ID는 순차 번호 노출을 피하고, 내부 저장 키는 인덱스 지역성을 고려해 분리할 수도 있다.

```mermaid
flowchart LR
    T[Timestamp] --> P[Bit Packing]
    N[Node ID] --> P
    S[Sequence] --> P
    P --> I[64-bit ID]
    I --> DB[(Ordered Index)]
```

| 방식 | 장점 | 주요 위험 |
|---|---|---|
| DB Sequence | 강한 고유성·단순함 | 중앙 의존·번호 노출 |
| 구간 할당 | DB 호출 감소 | 사용하지 않은 구간·할당 장애 |
| 랜덤 UUID | 조정 없는 생성 | 큰 키·인덱스 분산 쓰기 |
| 시간 기반 ID | 정렬·작은 키 | 시계 역행·노드 ID 충돌 |

```text
id = timestamp_bits | node_bits | per_tick_sequence
if clock < last_clock: stop, wait, or switch to a persisted logical epoch
```

> **실무 함정** — “충돌 확률이 낮다”와 “구조적으로 충돌하지 않는다”를 혼동하지 않는다. 생성 방식에 맞는 중복 제약은 최종 저장소에도 둔다.

## 2. 운영 안전장치

노드 ID는 임의 환경 변수보다 임대 레지스트리로 유일성을 보장한다. 시계 역행, 시퀀스 소진, 중복 제약 위반을 지표화하고 재시작 뒤 마지막 Epoch를 복구한다.

> **면접 포인트** — 초당 생성량으로 Timestamp·Sequence Bit를 계산하고 수명, 정렬성, 장애 시 가용성의 Trade-off를 설명한다.
