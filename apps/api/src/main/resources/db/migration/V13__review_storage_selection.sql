-- 저장소 선택 카드 심층 검수. 기존 ID와 질문 유지.
UPDATE cards
SET content_md = $storage_selection$## 1. CAP은 제품 분류표가 아니다

CAP의 C는 선형화 가능성, A는 실패하지 않은 노드가 받은 연산의 완료, P는 노드 사이 메시지가 전달되지 않는 실행을 고려한다는 뜻이다. 모든 요청에 오류를 돌려주는 것으로 A를 만족시키지는 않는다. CAP의 가용성과 요청 성공률·지연 SLO는 같은 정의가 아니다.

분할을 고려하는 읽기·쓰기 시스템은 분할 중 C와 A를 모두 보장할 수 없다. 이를 “평소에도 셋 중 둘만 가능”이라고 확대하지 않는다. 분할의 빈도나 시스템 전체의 성능도 이 정리가 계산해주지 않는다.

PACELC는 분할 시 가용성/일관성 선택에 더해, 평상시 복제와 읽기 경로의 지연/일관성 선택을 살펴보는 틀이다. ACID의 업무 불변 조건과 CAP의 C도 구분한다. 한 항목을 최신으로 읽었다고 여러 항목의 원자적 Snapshot을 읽은 것은 아니다.

> **첫 질문의 전제**
>
> DynamoDB와 PostgreSQL을 이름만으로 PA/EL 또는 PC/EC에 고정하지 않는다. 배포 구성·읽기 대상·확인 정책·연산을 먼저 정한 뒤 어느 응답을 기다리고 어느 실패에서 진행을 멈추는지 설명한다. 단일 PostgreSQL 서버 자체는 분산 복제 구성이 아니다.

## 2. 구성과 연산별로 보장을 적는다

| 구성·연산 | 확인할 보장과 비용 |
|---|---|
| PostgreSQL 17 비동기 Standby 읽기 | 복제 지연과 오래된 읽기, 장애 전환 때 미복제 커밋 손실 가능성 |
| PostgreSQL 동기 복제 | 확인을 기다리는 Standby와 synchronous_commit 정책, 대기·가용성 비용 |
| DynamoDB 테이블·LSI 읽기 | eventual 또는 strong 옵션, 요청 목적과 읽기 비용 |
| DynamoDB GSI·Stream 읽기 | 강한 읽기 옵션을 지원하지 않음 |
| DynamoDB Global Tables | MREC와 MRSC를 구분하고 리전·연산 지원 조건 확인 |
| Cassandra 읽기·쓰기 | Consistency Level과 응답 복제본 수, 충돌·복구 정책 |

PostgreSQL의 동기 복제도 디스크 기록 확인과 Standby 적용 확인은 다르다. Standby에서 즉시 보이는지가 요구라면 remote_apply 같은 적용 대기 조건과 실제 읽기 대상을 살핀다. 승격·옛 Writer 차단·클라이언트 재연결도 별도의 고가용성 설계다.

DynamoDB Global Tables는 현재 MREC뿐 아니라 MRSC도 제공하므로 “모든 글로벌 복제는 eventual”로 외우지 않는다. Amazon Dynamo 연구 논문과 관리형 DynamoDB 제품도 동일한 구현으로 취급하지 않는다. 제품 문서는 2026-09-16 확인 기준이며 실제 도입 시 해당 리전과 테이블 모드의 지원 범위를 다시 확인한다.

## 3. 모델 계열은 기능의 유무를 결정하지 않는다

| 계열 | 주로 표현하는 모델 | 설계할 접근 패턴 |
|---|---|---|
| 관계형 | 테이블·관계·제약 | 조인·집계·갱신 불변 조건과 인덱스 |
| Key-Value | 키 기반 항목 접근 | 키 조회·만료·조건부 갱신 |
| Document | 중첩된 문서 | 함께 읽고 변경할 범위·문서 성장 |
| Wide-column | Partition과 정렬 키 중심 행 집합 | 범위 조회·Partition 크기·분산 |
| Graph | 정점과 관계 | 탐색 깊이·방향·선택도·인덱스 |

이 분류는 서로 배타적인 제품 명세가 아니다. DynamoDB는 항목 속성과 정렬 키 질의를 지원하고 Redis는 여러 자료구조를 제공한다. “KV는 값 내부를 전혀 다룰 수 없다”거나 “모든 NoSQL은 조인·트랜잭션이 없다”고 단정하지 않는다.

DynamoDB의 TransactWriteItems는 같은 계정·리전에서 최대 100개 서로 다른 항목, 합계 4MB 제한 안의 원자적 작업을 지원한다. BatchWriteItem의 부분 성공과 다르다. 트랜잭션 변경이 GSI·Stream에 보이는 과정까지 같은 원자적 관측으로 가정하지 않는다. MongoDB도 다중 문서 트랜잭션을 지원한다. 지원 여부뿐 아니라 배포 조건·범위·격리·재시도·비용을 비교한다.

Document 모델도 데이터 계약은 필요하다. 함께 읽는지만 보지 말고 문서 크기·자식 증가·독립 갱신·중복 데이터 정정 비용을 검토한다. 임베딩과 참조 어느 쪽도 항상 더 빠른 것은 아니다.

## 4. Query-first는 읽기 비용을 쓰기와 운영 비용으로 바꾼다

관계형 설계도 접근 패턴을 무시한 채 스키마만 먼저 만들면 안 된다. 정규화·제약·인덱스와 실제 쿼리를 함께 설계한다. Cassandra에서는 지원해야 할 조회마다 Partition/Clustering Key와 테이블을 설계하는 접근이 특히 중요하다. DynamoDB도 키·보조 인덱스·Single-table 또는 여러 테이블을 접근 패턴에 맞춰 선택한다.

가상 배송 서비스가 “운송장별 시간순 이력”과 “센터별 미처리 목록”을 모두 필요로 하면 별도 조회 모델이 유리할 수 있다. 중복 저장은 조회 시 넓은 탐색을 줄이지만, 쓰기 증폭·저장 공간·변경 전파·백필·대사 비용을 만든다. 두 모델의 권위 있는 원본과 허용 지연, 누락 복구 절차를 정한다.

```mermaid
flowchart LR
    E[검증된 배송 이벤트] --> O[권위 있는 기록]
    O --> R[재시도 가능한 변경 전파]
    R --> W[운송장별 이력 모델]
    R --> C[센터별 작업 모델]
    W --> V[누락과 지연 대조]
    C --> V
```

## 5. DynamoDB Query는 페이지를 끝까지 처리해야 한다

가상 테이블의 PK가 USER#1234이고 SK가 PROFILE, ORDER#9001 등이라고 하자. PK와 정렬 키 조건으로 관련 항목을 조회할 수 있지만 “관련 모든 주문을 한 API 요청으로 읽는다”는 보장은 없다. Query는 최대 1MB 또는 설정한 Limit 경계에서 멈출 수 있다.

아래는 SDK와 분리한 **페이지 처리 예제**다. query_page는 실제 SDK 호출을 감싸는 함수이며 네트워크 오류의 재시도는 호출 계층에서 별도로 처리한다.

```python
def collect_pages(query_page):
    items = []
    cursor = None
    while True:
        page = query_page(cursor)
        items.extend(page.get("Items", []))
        cursor = page.get("LastEvaluatedKey")
        if not cursor:
            return items
```

다음 요청에는 같은 조회 조건과 함께 이전 LastEvaluatedKey를 ExclusiveStartKey로 전달한다. FilterExpression은 읽은 뒤 적용되므로 Items가 빈 페이지에도 다음 키가 있을 수 있다. **빈 Items를 종료 조건으로 삼으면 뒤의 결과를 누락한다.** 대량 결과는 전부 메모리에 모으는 대신 페이지별 처리·체크포인트·재시도 멱등성을 설계한다. 여러 페이지가 하나의 시점 Snapshot이라고 가정하지 않는다.

## 6. 핫 키를 나누면 읽기도 달라진다

PK를 오늘 날짜 하나로 잡으면 같은 키에 쓰기가 집중될 수 있다. 가상 date#shard 형태로 쓰기를 분산하면 읽기는 여러 Shard 결과를 가져와 병합해야 한다. 무작위 Shard는 조회 Fan-out이 필요하고, 업무 키에서 계산한 Shard는 단일 항목의 위치를 재계산할 수 있다. 두 방식 모두 분포와 Shard 수 변경 정책을 확인한다.

날짜 Bucket은 이력 크기를 제한하는 데 도움이 되지만 활성 Bucket의 폭주까지 자동 해결하지 않는다. 운송장별 Partition도 무한 이력이 쌓이는 장수 객체라면 보존·Bucket 정책을 검토한다. 단순히 Composite Key를 썼다는 사실만으로 균등 분산이나 선형 확장을 보장하지 않는다.

## 7. 물류 저장소 선택을 가상 요구로 설명한다

| 업무와 가정 | 후보 | 함께 설계할 것 |
|---|---|---|
| 주문·결제 상태와 복잡한 제약·조회 | PostgreSQL 같은 RDBMS | 로컬 트랜잭션·업무 키·외부 결제 결과 불명 |
| 운송장별 대량 시간순 이력 | Cassandra 같은 Wide-column 또는 기존 RDBMS | 측정한 쓰기·조회량, Bucket·보존·정정·중복 |
| 재생성 가능한 세션 조회 캐시 | Redis 같은 KV | TTL·퇴출·권위 원본·캐시 장애 대응 |

외부 결제 API는 관계형 DB 트랜잭션에 자동 포함되지 않는다. 세션을 잃으면 안 되는 요구라면 Redis를 재생성 가능한 캐시라고 가정해서도 안 된다. 운송장 상태 정정은 단순 Append 순서만으로 해결하지 않고 사건 ID·업무 버전과 재처리 정책을 둔다.

Polyglot persistence는 저장소 수를 늘리는 목표가 아니다. 기존 DB의 인덱스·파티셔닝·읽기 모델로 요구를 충족하는지 측정하고, 추가 저장소의 배포·백업·접근 권한·온콜·데이터 대사 비용을 포함해 선택한다. 특정 기업의 실제 구성을 출처 없이 이 가상 설계의 근거로 쓰지 않는다.

## 참고 자료

- [Abadi: PACELC 논문](https://www.cs.umd.edu/~abadi/papers/abadi-pacelc.pdf)
- [PostgreSQL 17 Standby와 동기 복제](https://www.postgresql.org/docs/17/warm-standby.html)
- [DynamoDB 읽기 일관성](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.ReadConsistency.html)
- [DynamoDB 트랜잭션](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/transaction-apis.html)
- [DynamoDB Query 페이지네이션](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Query.Pagination.html)
- [DynamoDB Write Sharding](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-partition-key-sharding.html)
- [Cassandra 데이터 모델링](https://cassandra.apache.org/doc/latest/cassandra/developing/data-modeling/intro.html)
- [MongoDB 트랜잭션](https://www.mongodb.com/docs/manual/core/transactions/)

실제 관리형 DB·복제 장애·부하 시험과 페이지 처리 함수의 로컬 검증은 구분한다.$storage_selection$
WHERE slug = 'database-05-rdbms-vs-nosql' AND source = 'MANUAL';
