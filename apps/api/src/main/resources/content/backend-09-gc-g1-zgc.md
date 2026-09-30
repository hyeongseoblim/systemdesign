---
area: BACKEND_DEV
mode: CONCEPT
coach: backend-dev-coach
title: "Garbage Collector — G1 vs ZGC·STW·Region·Concurrent"
slug: backend-09-gc-g1-zgc
topicKey: backend-dev-113
difficulty: 4
summary: "Collector 이름을 외우지 않고 Allocation Rate, Live Set, Pause 목표와 CPU·메모리 여유로 선택한다."
tags:
  - "GC"
  - "G1"
  - "ZGC"
  - "STW"
  - "Latency"
questions:
  - "G1의 Pause 목표가 보장이 아닌 이유와 목표를 낮출수록 처리량·메모리 여유에 어떤 압력이 생기는지 설명해보세요."
  - "ZGC가 대부분의 작업을 애플리케이션과 동시에 수행할 때 추가로 지불하는 CPU·메모리·Barrier 비용을 설명해보세요."
  - "GC Pause가 길어졌을 때 Heap 크기부터 늘리기 전에 Allocation Rate, Live Set, Promotion, CPU 포화를 어떤 순서로 확인할지 설명해보세요."
---
> **검수 경계** — G1·ZGC의 단계·옵션·지원 JDK와 pause 특성은 JDK 버전에 따라 달라진다. pause 숫자와 처리량은 보장값이 아니며 같은 JDK·heap·workload·컨테이너 제한에서 부하 테스트로 비교한다.

## 1. GC 문제는 세 숫자에서 시작한다

- `Allocation Rate`: 초당 새로 만드는 객체 바이트
- `Live Set`: GC 뒤에도 살아남는 객체 크기
- `Pause/Throughput Goal`: 허용 중단 시간과 애플리케이션 처리량

Heap이 커지면 GC 빈도는 줄 수 있지만 Live Set 스캔과 장애 시 Dump·재시작 비용은 커질 수 있다. Collector 선택은 지연 목표뿐 아니라 CPU와 메모리 여유를 함께 본다.

```mermaid
flowchart TD
    ALLOC[Object Allocation] --> YOUNG[Young Regions]
    YOUNG -->|Survive| OLD[Old Regions]
    subgraph G1["G1"]
        EVAC[선택 Region Evacuation]
        MIXED[Young + Old Mixed Collection]
    end
    subgraph ZGC["ZGC"]
        CONCURRENT[대부분 Concurrent Mark/Relocate]
        BARRIER[Load Barrier]
    end
    OLD --> EVAC
    OLD --> CONCURRENT
```

| 관점 | G1 | ZGC |
|---|---|---|
| 목표 | 예측 가능한 Pause와 처리량 균형 | 매우 낮은 Pause 우선 |
| 구조 | Region별 회수, Young/Mixed Cycle | 동시 Mark·Relocate 중심 |
| 비용 | Evacuation Pause, Remembered Set | 동시 작업 CPU, Barrier, 메모리 여유 |
| 선택 질문 | 수십~수백 ms 목표로 충분한가? | 더 낮은 Tail Latency가 사업상 필요한가? |

## 2. 로그로 원인을 분류한다

```bash
java \
  -Xlog:gc*,safepoint:file=gc.log:time,uptime,level,tags \
  -XX:+HeapDumpOnOutOfMemoryError \
  -jar app.jar
```

Pause 한 건보다 시간축을 본다. Allocation Rate가 갑자기 늘었는지, Old 점유율이 Cycle마다 회복되는지, Evacuation 실패나 Promotion 압력이 있는지, GC Thread가 쓸 CPU가 남아 있는지 확인한다. Safepoint 시간에는 GC 외의 원인도 있으므로 분리한다.

> **실무 함정** — `MaxGCPauseMillis`는 SLA 보장이 아니라 Collector의 목표다. 무리하게 낮추면 Young 영역과 회수 작업 선택이 달라져 GC 빈도와 CPU 비용이 증가할 수 있다.

## 3. 선택과 검증

기본 Collector로 실제 트래픽을 재현해 기준선을 만든 뒤, 같은 Heap·부하·워밍업 조건에서 p99 응답, 처리량, CPU, RSS를 비교한다. ZGC가 Pause를 낮춰도 CPU 포화로 요청 지연이 늘면 전체 SLA는 나빠질 수 있다.

> **면접 포인트** — “ZGC가 더 최신이므로 선택”이 아니라 Pause 예산, Allocation Rate, Live Set, 컨테이너 여유, 장애 복구 시간을 수치로 제시한다.

## 검수 경계와 실패 흐름

- `MaxGCPauseMillis`는 목표이며 모든 workload에서 달성되는 SLA가 아니다. 목표를 낮출수록 collector가 회수량·young 크기·CPU를 조정할 수 있으므로 allocation rate와 처리량을 함께 본다.
- GC pause가 늘면 heap을 먼저 키우지 말고 allocation burst, live set, promotion/evacuation 실패, CPU quota와 safepoint를 시간축으로 분리한다.
- ZGC·G1 선택은 JDK 버전, heap 크기, barrier·concurrent 작업 CPU, 메모리 여유, tail latency 목표의 결합이다. collector 변경 후 p99·error rate·RSS·복구 시간을 같은 조건에서 비교한다.
- Full GC·OOM·컨테이너 종료가 발생하면 요청 timeout·retry storm과 cascading failure를 막는 admission control과 graceful degradation도 함께 확인한다.

## 공식·1차 출처

- [Java 25 Garbage Collection Tuning Guide](https://docs.oracle.com/en/java/javase/25/gctuning/index.html)
- [Java 21 Garbage Collection Tuning Guide](https://docs.oracle.com/en/java/javase/21/gctuning/index.html)
- [OpenJDK ZGC](https://wiki.openjdk.org/display/zgc)
