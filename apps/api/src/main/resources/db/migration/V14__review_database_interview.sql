-- DB 면접 카드 심층 검수. 기존 ID와 질문 유지.
UPDATE cards
SET content_md = $db_interview$## 1. 가설을 실행계획과 대기 증거로 좁힌다

기준은 MySQL 8.4 InnoDB와 PostgreSQL 17이다. 질문의 200ms·8만 행·초당 3만 요청은 가상 면접 조건이며 측정된 제품 성능이 아니다. 먼저 실제 SQL·바인딩 값·테이블 정의·인덱스·격리수준과 재현 시점을 받는다. 실행 시간에는 락 대기·CPU·I/O·정렬·네트워크가 섞일 수 있다.

```mermaid
flowchart TD
    A[SQL과 바인딩·버전 확인] --> B[실행계획과 대기 증거]
    B --> C[추정과 실제 행·반복 횟수]
    B --> D[정렬·필터·테이블 접근]
    B --> E[락 소유자·트랜잭션 시간]
    C --> F[한 가설씩 변경 후 동일 조건 비교]
    D --> F
    E --> F
```

> **면접 포인트**
>
> EXPLAIN ANALYZE는 실제 쿼리를 실행한다. 운영의 무거운 조회나 변경문을 무심코 실행하지 말고 안전한 재현 환경과 영향 범위를 확인한다. 추정치와 관측치를 같은 실행 노드·단위·반복 횟수로 대조한다.

## 2. R1 — 인덱스를 탔는데 왜 느린가

**답변 예시:** “range는 접근 방식일 뿐 빠르다는 판정은 아닙니다. rows=500과 실측 8만이 같은 노드·한 번 실행 기준인지 확인하겠습니다. 실제 행·loops·필터·정렬 입력량을 보고, 커버링 여부와 ICP, 통계 오차를 따로 검사하겠습니다.”

```sql
SELECT order_id, buyer_id, total_amount, created_at
FROM orders
WHERE shop_id = 4210 AND status = 'PAID'
ORDER BY created_at DESC
LIMIT 20;

CREATE INDEX idx_shop_status_created
ON orders (shop_id, status, created_at);
```

이 단순 쿼리는 앞 두 등치 조건으로 구간을 정하고 created_at 순서를 이용할 수 있다. 같은 구간에서 created_at 범위 조건을 추가하는 것만으로 정렬이 반드시 깨지는 것은 아니다. `(shop_id, created_at, status)`도 정렬을 유지할 수 있지만 status에 맞는 20건을 찾기 위해 더 많이 훑을 수 있다. “인덱스 뒤 컬럼은 전혀 못 쓴다”와 “정렬은 못 한다”를 혼동하지 않는다.

created_at이 같은 행 사이 순서까지 안정적이어야 한다면 order_id 같은 동점 구분 키와 그에 맞는 인덱스를 검토한다. 실제 선택된 계획은 데이터 분포와 비용에 달려 있으며 LIMIT 20이 모든 내부 읽기 20회를 보장하지 않는다.

| 관측 | 의미 | 다음 확인 |
|---|---|---|
| Using filesort | 별도 정렬 단계 | 실제 ORDER BY·방향·표현식·조인·입력 행 수 |
| Using index | 필요한 값을 인덱스에서 얻는 커버링 접근 | 인덱스 크기·쓰기 비용·실제 I/O |
| Using index condition | ICP로 인덱스에서 일부 조건을 검사 | 탈락 행과 테이블 접근 감소, 커버링과 구분 |
| 추정과 actual 괴리 | 계획의 예상과 관측이 다름 | 반복 횟수·통계·치우친 값·컬럼 상관 |

filesort는 반드시 디스크 정렬을 뜻하지 않는다. 커버링이 아니면 테이블 접근이 늘 수 있지만 그것만으로 추정 500과 실제 8만의 괴리를 설명했다고 할 수 없다. 캐시에서 읽었는지 저장 장치까지 갔는지도 별도다. Handler 카운터는 세션 전후 차이를 보조 지표로 사용하며 고유 행 수나 물리 디스크 읽기 수와 동일시하지 않는다.

통계가 오래됐는지 확인하고 ANALYZE를 검토하되, 값의 편향과 조건 간 상관은 갱신만으로 해결되지 않을 수 있다. PostgreSQL의 actual rows는 반복당 평균을 표시할 수 있어 loops와 함께 해석한다. 상위·하위 노드 시간을 단순 합산하면 중복 계산될 수 있다.

**후속 압박:** “필요한 컬럼을 전부 인덱스에 넣으면 해결되죠?”

인덱스 폭·쓰기 증폭·캐시 점유를 비교한다. InnoDB 보조 인덱스에는 PK가 포함되지만 PostgreSQL의 다른 인덱스에 PK가 자동 포함되지는 않는다. PostgreSQL INCLUDE로 모든 조회 값을 담아도 Visibility Map에 따라 Heap Fetch가 필요하다. Index Only Scan 이름만으로 테이블 접근이나 디스크 I/O가 0이라고 단정하지 않는다.

## 3. R2 — RR인데 갱신 유실, 잠그니 데드락

가상 잔액이 1000이고 두 요청이 각각 500을 적립한다. 두 트랜잭션이 먼저 1000을 읽고 애플리케이션에서 계산한 상수 1500으로 덮어쓴다고 하자.

```sql
BEGIN;
SELECT balance FROM account WHERE id = 100;
-- 다른 요청도 같은 값을 읽을 수 있다.
UPDATE account SET balance = 1500 WHERE id = 100;
COMMIT;
```

MySQL InnoDB RR의 일반 Snapshot SELECT와 상수 UPDATE 조합에서는 이런 갱신 유실이 가능하다. PostgreSQL RR에서는 Snapshot 이후 다른 트랜잭션이 같은 행을 변경해 커밋하면 갱신 시 직렬화 실패가 발생할 수 있다. **PostgreSQL도 먼저 락 대기를 할 수 있으며, “락 대기 대신 오류”라는 양자택일이 아니다.**

| 방법 | 장점 | 지켜야 할 조건 |
|---|---|---|
| balance = balance + 500 | DB의 현재 행에 연산 | 요청 재전송 중복은 업무 키로 별도 차단 |
| SELECT FOR UPDATE | 읽고 판단하는 동안 충돌 제어 | 같은 트랜잭션·좁은 잠금 범위·일관된 획득 순서 |
| version 조건 UPDATE | 오래된 값을 덮어쓰는 충돌 감지 | 영향 행 0이면 재조회·재판단·제한 재시도 |
| 직렬화 격리 | 직렬 실행과 같은 결과 목표 | 실패한 전체 트랜잭션의 재시도와 외부 효과 분리 |

PostgreSQL RR에서 FOR UPDATE로 바꿨다고 오래된 Snapshot이 자동으로 최신 Snapshot으로 바뀌지는 않는다. 동시 변경이 확정되면 오류를 처리하고 새 트랜잭션에서 업무 판단부터 다시 한다.

**데드락 답변 예시:** “T1이 A를 잡고 B를 기다리며 T2가 B를 잡고 A를 기다리면 순환 대기입니다. 오류 1213과 잠금 대기 시간 초과를 구분하고 InnoDB 데드락 기록에서 실제 인덱스·레코드·SQL을 확인하겠습니다. 모든 경로의 자원 획득 순서를 맞추고 트랜잭션을 짧게 하겠습니다.”

여러 계좌의 ID를 정렬한 뒤 개별 PK 잠금을 같은 순서로 요청하는 설계가 가능하다. 하지만 SELECT의 ORDER BY 하나만으로 트리거·FK·다른 인덱스·범위 잠금까지 포함한 모든 데드락이 사라진다고 보장하지 않는다. 인덱스 없는 잠금 쿼리는 InnoDB에서 잠금 범위를 크게 넓힐 수 있으나 PostgreSQL까지 “스캔한 모든 행을 테이블 락으로 잠근다”고 일반화하지 않는다.

MySQL 데드락은 트랜잭션 전체가 롤백된다. 반면 InnoDB 잠금 대기 시간 초과는 기본적으로 해당 문장만 롤백하므로 부분 작업이 남은 트랜잭션을 무심코 커밋하면 안 된다. 애플리케이션에서 명시적으로 전체를 롤백하고 재시도 범위를 정한다. 재시도는 횟수·기한·지터·멱등성을 갖춰야 한다.

## 4. R3 — 단일 행 핫스팟을 SQL 변경 없이 완화한다

```sql
UPDATE stock
SET qty = qty - 1
WHERE sku = 'HOT-SKU' AND qty >= 1;
```

sku의 고유성, 양수 요청량, 영향 행 검사, 다른 쓰기 경로의 동일 불변 조건이 전제다. 이 문장의 원자성이 같은 요청의 두 번 차감까지 막지는 않는다. 질문은 정확성 구현을 유지하면서 대기 폭증을 완화하는 방법을 요구한다.

| 완화책 3가지 | 실행 | 비용과 한계 |
|---|---|---|
| 락 보유 시간 단축 | 트랜잭션 안의 원격 호출·불필요한 작업을 밖으로 이동, 커밋 지연 조사 | 업무 원자성 경계를 깨지 않아야 하며 WAL·I/O 병목은 별도 |
| 동시성·유입 제한 | SKU별 허용 대기 수와 요청 기한 설정, 과부하 거절, 중복 요청 병합 | 일부 요청이 기다리거나 실패하며 여러 서버의 총 동시성을 관리해야 함 |
| SKU별 처리 순서화 | 같은 키의 작업을 제한된 소비자로 처리, DB 성공 후 완료 기록 | 큐 지연·재전달·소비자 교체와 다른 Writer의 경합이 남음 |

가상의 락 점유가 평균 5ms면 해당 직렬 구간은 단순 계산상 초당 약 200회가 상한 후보다. 실제 처리율 측정은 아니며 디스크·다른 락·분포에 따라 달라진다. 유입이 지속적으로 이를 넘으면 커넥션을 늘리는 대신 대기가 쌓인다. 큐도 처리 용량 자체를 무한히 늘려주지 않는다.

lock_wait_timeout을 낮추는 것은 대기 예산을 제한하는 방법이지 락 처리율을 높이는 방법이 아니다. 고정된 2~3초를 정답으로 삼지 말고 요청 기한·DB 밖 대기·재시도 총량에 맞춘다. 빠른 실패 후 무제한 재시도는 다시 폭주를 만든다.

**후속 압박:** “재고 버킷이나 Redis로 옮기면 더 빠르지 않나요?”

이는 스키마·소유권·복구를 바꾸는 별도 설계다. 버킷은 빈 버킷 선택에 따른 불필요한 실패와 재분배를 다뤄야 하며 무조건 N배 빨라지지 않는다. Redis 선차감은 확인된 예약의 내구성·DB 반영·중복·결과 불명 복구가 필요하다. AOF를 켰다는 사실만으로 모든 장애의 예약 유실이 사라지지 않는다. 기존 SQL을 거의 유지하는 세 가지 완화와 구분해 후속 대안으로 제시한다.

## 5. 면접 답변의 검증 기준

- 쿼리와 계획이 다르면 원문·바인딩부터 맞춘다. 추정 오차와 테이블 접근 비용을 혼동하지 않는다.
- 잠금 대기·데드락·직렬화 실패의 원인과 롤백 범위를 DBMS별로 설명한다.
- 정합성을 지키는 것과 요청 기한 안에 처리하는 것을 각각 측정한다.
- 변경 뒤에는 실제 처리율·p99·대기 건수·실패·재시도·중복 차감을 함께 본다.

이 문답의 성능 수치는 가상 조건이다. 실제 MySQL 8.4 장애·부하 시험을 수행한 결과가 아니다.

## 참고 자료

- [MySQL 8.4 ORDER BY 최적화](https://dev.mysql.com/doc/refman/8.4/en/order-by-optimization.html)
- [MySQL 8.4 ICP](https://dev.mysql.com/doc/refman/8.4/en/index-condition-pushdown-optimization.html)
- [MySQL 8.4 InnoDB 오류와 롤백 범위](https://dev.mysql.com/doc/refman/8.4/en/innodb-error-handling.html)
- [MySQL 8.4 데드락 대응](https://dev.mysql.com/doc/refman/8.4/en/innodb-deadlocks-handling.html)
- [PostgreSQL 17 트랜잭션 격리](https://www.postgresql.org/docs/17/transaction-iso.html)
- [PostgreSQL 17 Index Only Scan](https://www.postgresql.org/docs/17/indexes-index-only-scans.html)$db_interview$
WHERE slug = 'database-08-interview-index-lock' AND source = 'MANUAL';
