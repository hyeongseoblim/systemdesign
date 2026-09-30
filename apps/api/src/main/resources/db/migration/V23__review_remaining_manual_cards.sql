-- Reviewed MANUAL card bodies. Existing card and question IDs are preserved.

UPDATE cards
SET content_md = $review_23_backend_01_api_design$> **검수 경계** — HTTP 메서드 의미·상태 코드·Problem Details는 표준 문서에 근거하지만, 리소스 경계·버전 방식·HATEOAS 채택은 제품 계약과 클라이언트 제약에 따른 설계 선택이다. 예시 ID·수치와 Spring API 동작은 해당 버전의 문서로 확인한다.

## 1. REST 제약과 Richardson 성숙도 모델

`REST(Representational State Transfer, 표현 상태 전이)`는 프로토콜이 아니라 **아키텍처 제약(Constraints)의 집합**이다. 핵심 6개 제약 중 면접에서 자주 묻는 것은 **Stateless(무상태)**와 **Uniform Interface(균일 인터페이스)**다.

```mermaid
flowchart LR
    L0["Level 0\nThe Swamp of POX\n단일 endpoint\nRPC over HTTP"]
    L1["Level 1\nResources\n리소스마다 URI 분리"]
    L2["Level 2\nHTTP Verbs\nGET/POST/PUT/DELETE\n상태 코드 활용"]
    L3["Level 3\nHATEOAS\n응답에 다음 액션\n링크 포함"]
    L0 --> L1 --> L2 --> L3
    style L0 fill:#fee2e2,stroke:#ef4444
    style L1 fill:#fef3c7,stroke:#f59e0b
    style L2 fill:#dcfce7,stroke:#22c55e
    style L3 fill:#dbeafe,stroke:#3b82f6
```

*Richardson Maturity Model — 실무 대부분은 Level 2에서 멈춘다. Level 3는 비용 대비 효용 논쟁이 있음*

> **💡 현실적 목표**
>
> 구현 비용 때문에 많은 API가 Level 2 제약의 일부를 선택하지만, 특정 회사의 내부 표준으로 일반화할 수는 없다. Level 3(HATEOAS)는 공개 API나 장기 진화·상태 전이가 중요한 경우 검토하고, 채택 범위는 클라이언트 계약으로 정한다.

## 2. 리소스 모델링 — 명사로 쪼개기

리소스는 **명사(Noun)**로, 행위는 **HTTP 메서드(Verb)**로 표현한다. `/getOrders`, `/createOrder` 같은 동사형 URI는 RPC 사고방식의 잔재다.

| 안티패턴 (동사형) | 권장 (리소스 + 메서드) | 의미 |
| --- | --- | --- |
| `POST /createOrder` | `POST /orders` | 주문 생성 |
| `GET /getOrder?id=42` | `GET /orders/42` | 단건 조회 |
| `POST /cancelOrder?id=42` | `POST /orders/42/cancellation` 또는 `PATCH /orders/42` (status 변경) | 취소 — 상태 전이 |
| `GET /orderLines?orderId=42` | `GET /orders/42/lines` | 하위 리소스 (Sub-resource) |

### 물류 도메인 예시 — 주문·배송 리소스 계층

```mermaid
flowchart TB
    O["/orders/{orderId}\n주문"]
    OL["/orders/{orderId}/lines\n주문 라인"]
    SH["/shipments/{shipmentId}\n배송 (독립 리소스)"]
    TR["/shipments/{shipmentId}/tracking\n추적 이벤트"]
    O -->|"1:N"| OL
    O -.->|"1:N (분할출고)"| SH
    SH -->|"1:N"| TR
    style O fill:#dbeafe,stroke:#3b82f6
    style OL fill:#dbeafe,stroke:#3b82f6
    style SH fill:#ede9fe,stroke:#8b5cf6
    style TR fill:#dcfce7,stroke:#22c55e
```

*Order ↔ Shipment는 분할출고로 1:N. Shipment를 Order 하위가 아닌 **독립 리소스**로 둬야 라이프사이클이 분리됨*

> **⚠️ 실무 함정 — 중첩 깊이**
>
> `/orders/42/lines/3/items/7/...` 처럼 3단계 이상 중첩하면 URI가 깨지기 쉽다. 식별자가 전역 유일하면 **최상위 리소스로 평탄화** ( `/shipments/{id}` )하고, 관계는 쿼리 파라미터나 링크로 표현하는 게 진화에 유리.

### 컬렉션 vs 단일 리소스 규칙

- **컬렉션**: 복수형 명사 — `/orders`, `/shipments`
- **필터·정렬·검색**은 쿼리 파라미터 — `/orders?status=PAID&sort=-createdAt`
- **표현형(Representation) 협상**은 `Accept` 헤더 — URI에 `.json` 박지 않기

## 3. HTTP 메서드 · 안전성 · 멱등성

면접 단골: **"PUT과 POST의 차이?"** → 단순히 "수정/생성"이 아니라 `Idempotency(멱등성)`로 답해야 한다. 멱등성은 *같은 요청을 N번 보내도 서버 상태가 1번 보낸 것과 동일*한 성질이다.

| 메서드 | Safe (안전·읽기전용) | Idempotent (멱등) | 용도 |
| --- | --- | --- | --- |
| `GET` | ✅ | ✅ | 조회 |
| `HEAD` | ✅ | ✅ | 메타데이터만 |
| `PUT` | ❌ | ✅ | 전체 교체 (Upsert) |
| `DELETE` | ❌ | ✅ | 삭제 (이미 없어도 결과 동일) |
| `PATCH` | ❌ | ⚠️ 보통 비멱등 | 부분 수정 |
| `POST` | ❌ | ❌ | 생성 — N번 보내면 N개 생성 위험 |

> **🎯 면접 포인트 — POST 중복 방지**
>
> "결제 API에 네트워크 타임아웃 후 클라이언트가 재시도하면 이중 결제가 나는데 어떻게 막나요?" → **비멱등 POST를 멱등하게 만드는 Idempotency-Key 헤더** 를 설명해야 한다. 자세한 구현은 [04. 복원력·멱등성](04-resilience-idempotency.html) 페이지에서 다룸. 🔥(Deep-dive)

### 왜 PATCH는 보통 비멱등인가

`{ "balance": "+100" }` 처럼 **상대적 변경**을 표현하면 N번 호출 시 N번 증가 → 비멱등. 반면 `{ "balance": 100 }` 같은 **절대값 교체**는 멱등하다. PATCH의 멱등성은 페이로드 설계에 달려 있다.

## 4. HTTP 상태 코드 — 정확하게 쓰기

| 상황 | 코드 | 흔한 실수 |
| --- | --- | --- |
| 리소스 생성 성공 | `201 Created` + `Location` 헤더 | 200으로 퉁치기 |
| 비동기 접수 (처리 진행 중) | `202 Accepted` | 처리 끝나지도 않았는데 200 |
| 본문 없는 성공 (DELETE) | `204 No Content` | 빈 body + 200 |
| 입력 검증 실패 | `400 Bad Request` / `422 Unprocessable` | 모든 에러를 500으로 |
| 인증 안 됨 / 권한 없음 | `401` / `403` | 401과 403 혼동 |
| 버전 충돌 (낙관적 락) | `409 Conflict` | 500으로 던지기 |
| 멱등 키 처리 중 | `409` 또는 원래 결과 반환 | 재처리 후 중복 생성 |
| Rate limit 초과 | `429 Too Many Requests` + `Retry-After` | 503으로 던져 재시도 폭주 유발 |

> **⚠️ 실무 함정 — 200 OK + body에 에러**
>
> "항상 200을 주고 body의 `{"success": false}` 로 판단" 패턴은 **관측성을 망친다** . APM·로드밸런서·재시도 미들웨어는 상태 코드로 에러율을 집계하는데, 전부 200이면 5xx 알람이 절대 안 울린다. 실제 장애가 대시보드에서 초록불로 보이는 참사가 발생.

## 5. API 버저닝 — 진화 전략

| 방식 | 예시 | 장점 | 단점 |
| --- | --- | --- | --- |
| **URI 경로** | `/v1/orders` | 명확·캐시 친화·디버깅 쉬움 | URI가 리소스 정체성 위반(같은 리소스 다른 URI) |
| **헤더** | `Accept: application/vnd.api.v2+json` | URI 깔끔·콘텐츠 협상 정석 | 브라우저 테스트 어려움·캐시 키 복잡 |
| **쿼리 파라미터** | `/orders?version=2` | 도입 쉬움 | 기본값 누락 시 혼란·캐시 오염 |

> **💡 실무 합의**
>
> 논쟁은 많지만 **실무 다수는 URI 경로 버저닝** 을 택한다(Stripe·GitHub은 변형 사용). 이유: 운영·디버깅·CDN 캐싱·문서화가 압도적으로 쉽다. 순수주의보다 운영성이 이긴 사례. 단, **버전을 남발하지 않는 것** 이 핵심 — 하위 호환(Backward compatible) 변경(필드 추가)은 버전을 올리지 않는다.

### 하위 호환 변경 vs 깨는 변경

- **호환(버전 유지)**: 선택 필드 추가, 새 엔드포인트 추가, 응답에 필드 추가
- **깨짐(버전 올림)**: 필드 삭제·이름 변경, 타입 변경, 필수 파라미터 추가, 의미 변경

클라이언트는 **Tolerant Reader(관대한 파서)** 원칙 — 모르는 필드는 무시 — 를 지켜야 서버 진화가 자유로워진다.

## 6. 페이지네이션 — Offset vs Cursor

면접에서 **"대용량 목록을 페이징하라"**는 질문은 흔하다. Offset 기반의 함정을 모르면 감점이다.

```mermaid
sequenceDiagram
    participant C as Client
    participant S as Server
    participant DB as Database
    Note over C,DB: Offset 방식 — LIMIT 20 OFFSET 1000000
    C->>S: GET /orders?offset=1000000&limit=20
    S->>DB: SELECT ... LIMIT 20 OFFSET 1000000
    DB-->>S: 100만 행 스캔 후 버리고 20행만 반환 😱
    S-->>C: 느림 + 중간 INSERT 시 중복/누락
    Note over C,DB: Cursor(Keyset) 방식 — WHERE id < last_id
    C->>S: GET /orders?cursor=eyJpZCI6...&limit=20
    S->>DB: SELECT ... WHERE (created_at, id) < (?, ?) LIMIT 20
    DB-->>S: 인덱스 타고 즉시 20행 🚀
    S-->>C: 일정한 성능 + 안정적 페이징
```

*Offset은 뒤로 갈수록 느려지고(O(offset)), 데이터 변경 시 중복·누락. Cursor는 인덱스 범위 스캔으로 일정*

| 관점 | Offset 기반 | Cursor (Keyset) 기반 |
| --- | --- | --- |
| 깊은 페이지 성능 | O(offset) — 뒤로 갈수록 급격히 느림 | O(limit) — 일정 |
| 임의 페이지 점프 | 가능 (5페이지로 바로) | 불가 (다음/이전만) |
| 실시간 데이터 안정성 | 중간 INSERT/DELETE 시 중복·누락 | 안정적 |
| 전체 개수 | 쉬움 | 비싸거나 근사치 |
| 적합 케이스 | 관리자 페이지·소규모·페이지 번호 필요 | 무한스크롤·피드·대용량 목록 |

#### Cursor 페이지네이션 응답 형태

```
// 커서는 정렬 키를 base64 인코딩 — 내부 구조 노출 방지
{
  "items": [ ... ],
  "pageInfo": {
    "nextCursor": "eyJjcmVhdGVkQXQiOiIyMDI2LTA3LTAxVDEyOjAwOjAwWiIsImlkIjo0Mn0=",
    "hasNext": true
  }
}
```

> **⚠️ 실무 함정 — 정렬 키 유일성**
>
> Cursor 정렬 키가 `created_at` 하나면 같은 시각 행에서 누락 발생. 반드시 **(created_at, id)** 같은 **유일성 보장 복합 키** 로 정렬하고 커서를 구성해야 한다.

## 7. 에러 모델 — RFC 7807 Problem Details

제각각인 에러 포맷(`{"msg":...}`, `{"error":...}`, `{"code":...}`)은 클라이언트를 괴롭힌다. `RFC 7807(Problem Details for HTTP APIs, HTTP API 문제 상세)`은 표준 에러 바디를 정의한다.

```
// Content-Type: application/problem+json
{
  "type":     "https://api.shop.com/problems/insufficient-stock",
  "title":    "재고 부족",
  "status":   409,
  "detail":   "SKU-1234의 가용 재고가 2개인데 5개를 요청했습니다.",
  "instance": "/orders/42",
  // 확장 필드 — 도메인 고유 정보
  "sku":        "SKU-1234",
  "available":  2,
  "requested":  5,
  "traceId":    "4bf92f3577b34da6a3ce929d0e0e4736"
}
```

*필드: type(문제 종류 URI)·title(요약)·status·detail(이번 발생 상세)·instance(발생 위치) + 확장*

#### Spring Boot 구현 — @RestControllerAdvice

```kotlin
@RestControllerAdvice
class GlobalExceptionHandler {

    @ExceptionHandler(InsufficientStockException::class)
    fun handleStock(e: InsufficientStockException): ResponseEntity<ProblemDetail> {
        val pd = ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, e.message)
        pd.type = URI.create("https://api.shop.com/problems/insufficient-stock")
        pd.title = "재고 부족"
        pd.setProperty("sku", e.sku)
        pd.setProperty("available", e.available)
        pd.setProperty("traceId", MDC.get("traceId"))   // 추적 연결
        return ResponseEntity.status(HttpStatus.CONFLICT).body(pd)
    }
}
```

*Spring 6 / Boot 3 계열에서는 `ProblemDetail` API를 사용할 수 있다. 실제 적용 여부와 필드 동작은 프로젝트가 사용하는 Spring 버전 문서로 확인하고 traceId를 로그·추적과 연결한다.*

> **💡 에러 분류 체계**
>
> 에러는 **(1) 클라이언트 잘못(4xx, 재시도 무의미)** 과 **(2) 서버/일시적(5xx·429, 재시도 가능)** 으로 명확히 나눠야 한다. 클라이언트가 `type` URI로 분기하고, `status` 로 재시도 여부를 판단하게 만들면 양쪽 코드가 단순해진다.

## 8. HATEOAS 개요 — 상태 기반 액션 노출

`HATEOAS(Hypermedia As The Engine Of Application State, 애플리케이션 상태 엔진으로서의 하이퍼미디어)`는 응답에 **"지금 이 리소스에서 가능한 다음 액션"**을 링크로 담는다. 클라이언트가 상태 전이 규칙을 하드코딩하지 않아도 된다.

```
// 결제 완료(PAID) 상태의 주문 — 가능한 액션만 링크로 제공
{
  "orderId": 42,
  "status": "PAID",
  "_links": {
    "self":   { "href": "/orders/42" },
    "cancel": { "href": "/orders/42/cancellation", "method": "POST" }
    // SHIPPED 상태였다면 cancel 링크는 사라지고 track 링크가 등장
  }
}
```

```mermaid
stateDiagram-v2
    [*] --> PAID
    PAID --> CANCELED : cancel 링크 노출
    PAID --> SHIPPED : (시스템)
    SHIPPED --> DELIVERED : track 링크 노출
    note right of PAID : _links.cancel 있음
    note right of SHIPPED : _links.cancel 없음\n_links.track 있음
```

*상태에 따라 노출 링크가 달라짐 — 클라이언트가 "취소 가능 여부"를 직접 판단하지 않게 함*

> **🎯 면접 포인트 — HATEOAS 채택 Trade-off**
>
> "왜 대부분 HATEOAS를 안 쓰나요?" → **(1) 페이로드 비대화, (2) 클라이언트가 실제로 링크를 따라가도록 구현하는 비용, (3) 모바일 앱은 어차피 화면 흐름을 하드코딩** . 반대로 채택 가치가 큰 곳은 **장기 진화하는 공개 API, 워크플로 엔진, 결제 같은 복잡 상태 전이** . "무조건 좋다/나쁘다"가 아니라 맥락으로 답하는 게 핵심.

## 검수 경계와 실패 흐름

- `POST`의 멱등 키는 요청 본문 해시·사용자·리소스 범위와 함께 저장하고, 응답 유실 후 재시도해도 같은 결과를 반환하도록 만료·동시 요청 정책을 정한다.
- 커서가 발급된 뒤 새 행이 삽입되거나 삭제되면 정렬 키와 cursor version이 일관된 페이지 경계를 유지하는지 확인한다. `(created_at, id)`가 유일하지 않으면 누락·중복이 생길 수 있다.
- 4xx·5xx·429를 재시도 정책과 연결하되, `Retry-After`가 없거나 결과가 unknown인 외부 호출은 중복 생성 방지·상태 조회·대사 경로를 별도로 둔다.
- 에러 응답의 `type`·`status`·확장 필드는 계약으로 버전 관리하고, 로그·메트릭의 개인정보와 내부 stack trace 노출을 차단한다.

## 공식·1차 출처

- [RFC 9110 — HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110)
- [RFC 9457 — Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc9457)
- [RFC 7807 — Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc7807)
- [RFC 8288 — Web Linking](https://www.rfc-editor.org/rfc/rfc8288)$review_23_backend_01_api_design$
WHERE slug = 'backend-01-api-design' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_backend_05_testing$> **검수 경계** — 테스트 계층·DB 방언·격리 수준·계약은 사용 중인 JDK, DB, 드라이버, 컨테이너 이미지, 테스트 프레임워크 버전으로 검증한다. 테스트 통과는 해당 시나리오의 증거이지 운영 전체의 보장이 아니다.

## 1. 테스트 피라미드

```mermaid
flowchart TB
    E2E["E2E (소수)\n느림 · 깨지기 쉬움 · 비쌈\n핵심 사용자 흐름만"]
    INT["Integration (중간)\nDB · Kafka · 외부 연동\nTestcontainers"]
    UNIT["Unit (다수)\n빠름 · 결정적 · 격리됨\n도메인 로직 집중"]
    E2E --> INT --> UNIT
    style E2E fill:#fee2e2,stroke:#ef4444
    style INT fill:#fef3c7,stroke:#f59e0b
    style UNIT fill:#dcfce7,stroke:#22c55e
```

*아래로 갈수록 많고 빠르게. E2E를 너무 많이 쌓으면 "아이스크림 콘 안티패턴" — 느리고 불안정*

> **⚠️ 안티패턴 — Ice Cream Cone**
>
> Unit이 적고 E2E·수동 테스트가 많은 역피라미드는 실행 시간이 길고 Flaky(불안정) 테스트로 신뢰를 잃기 쉽다. 도메인 로직은 **빠른 Unit으로 두텁게**, 연동 지점만 Integration으로 검증한다.

## 2. 테스트 더블 (Test Doubles)

| 종류 | 역할 | 예시 |
| --- | --- | --- |
| **Dummy** | 전달만 되고 안 쓰임 | 채우기용 인자 |
| **Stub** | 정해진 값 반환 | `when(repo.find()).thenReturn(x)` |
| **Mock** | 호출 여부·횟수 검증 | `verify(client).send(...)` |
| **Spy** | 실제 객체 일부만 가로채기 | 실 객체 + 특정 메서드 stub |
| **Fake** | 가벼운 실제 구현 | 인메모리 Repository |

> **💡 Mock 남용 경계**
>
> 모든 의존을 Mock하면 "구현을 테스트"하게 되어 리팩터링마다 깨진다. **경계(외부 시스템)는 Mock/Fake, 도메인 내부는 실제 객체** 로 두는 게 견고한 테스트의 핵심. "Mockist vs Classicist" 논쟁의 실용적 절충.

## 3. Unit 테스트 — 도메인 로직

```kotlin
// 테스트 이름: 메서드_상황_기대결과
class StockTest {
    @Test
    fun `decrease_재고보다많이차감_예외발생`() {
        val stock = Stock(quantity = 3)
        assertThrows<InsufficientStockException> {
            stock.decrease(5)
        }
    }

    @Test
    fun `decrease_정상차감_수량감소`() {
        val stock = Stock(quantity = 3)
        stock.decrease(2)
        assertThat(stock.quantity).isEqualTo(1)
    }
}
```

*도메인 불변식(재고는 음수 불가)을 객체 자체가 강제하는지 검증 — DB·스프링 없이 즉시 실행*

> **💡 좋은 Unit 테스트 — F.I.R.S.T**
>
> **F** ast(빠름)· **I** solated(독립)· **R** epeatable(반복 가능)· **S** elf-validating(자가 검증)· **T** imely(적시). 시간( `now()` )·랜덤·순서 의존을 주입 가능하게 만들면 Flaky가 사라진다.

## 4. ⭐ Integration 테스트 — Testcontainers

> **핵심 메시지** — 통합 테스트는 *진짜 DB·Kafka*로 — H2로는 잡을 수 없는 버그가 있다

```kotlin
@SpringBootTest
@Testcontainers
class OrderRepositoryTest {

    companion object {
        @Container
        val postgres = PostgreSQLContainer("postgres:16")   // 예시 버전; CI·운영과 호환되는 이미지로 고정

        @JvmStatic @DynamicPropertySource
        fun props(registry: DynamicPropertyRegistry) {
            registry.add("spring.datasource.url", postgres::getJdbcUrl)
            registry.add("spring.datasource.username", postgres::getUsername)
            registry.add("spring.datasource.password", postgres::getPassword)
        }
    }

    @Test
    fun `재고차감_조건부UPDATE_부족시0행`() {
        val updated = repository.decreaseStock(id = 1L, qty = 999)
        assertThat(updated).isEqualTo(0)   // 실제 PostgreSQL에서 검증
    }
}
```

*Docker로 지정한 PostgreSQL 이미지 버전을 띄워 테스트한다. 특정 기업의 내부 표준이라고 일반화하지 말고 CI와 운영이 사용하는 방언·확장·버전을 명시한다.*

> **🎯 면접 포인트 — 왜 H2로 통합 테스트하면 안 되나**
>
> **(1) SQL 방언 차이** ( `FOR UPDATE` , upsert, JSON 함수가 다르게 동작), **(2) 격리수준 기본값 차이** (03번 페이지), **(3) 시퀀스·인덱스·제약 동작 차이** . H2에서 통과한 테스트가 운영 MySQL/PostgreSQL에서 깨지는 일이 흔하다. Testcontainers로 **운영과 같은 엔진** 을 써야 진짜 검증이 된다. 🔥(Deep-dive)

#### 슬라이스 테스트 — 필요한 만큼만

- `@DataJpaTest` — JPA 레이어만 (단, 기본 H2 → Testcontainers로 교체 권장)
- `@WebMvcTest` — 컨트롤러·직렬화·검증만, 서비스는 Mock
- `@SpringBootTest` — 전체 컨텍스트 (느림, 핵심 흐름만)

## 5. Contract 테스트 — 서비스 간 계약

MSA에서 OMS와 WMS가 각자 배포된다. WMS가 응답 필드를 바꾸면 OMS가 깨진다. `Contract(계약) 테스트`는 **"이 API는 이런 형태로 응답한다"**는 계약을 양쪽이 공유·검증한다(Pact, Spring Cloud Contract).

```mermaid
sequenceDiagram
    participant C as Consumer (OMS)
    participant Pact as Pact Broker
    participant P as Provider (WMS)
    C->>C: 기대 계약 작성 (요청→응답 형태)
    C->>Pact: 계약 발행
    P->>Pact: 계약 가져오기
    P->>P: 실제 응답이 계약 만족하는지 검증
    Note over C,P: Provider 배포 전 계약 위반 감지→ 통합 환경 없이도 호환성 보장
```

*Consumer-Driven Contract — 소비자가 정의한 기대를 제공자가 CI에서 검증. E2E 없이 호환성 확보*

> **💡 Contract 테스트의 가치**
>
> 전체 환경을 띄우는 E2E보다 **훨씬 빠르고 안정적** 으로 "API 깨짐"을 잡는다. MSA가 많아질수록 E2E는 조합 폭발하므로, Contract가 그 빈틈을 메운다. 단, 비즈니스 로직 자체는 검증 안 함(형태/호환성만).

## 6. 동시성 테스트 — 재고 차감 검증

02번에서 만든 재고 차감이 정말 동시성 안전한지, **여러 스레드로 동시에 때려서** 검증한다. 단일 스레드 테스트로는 Race Condition을 절대 못 잡는다.

```kotlin
@Test
fun `재고100_100명동시주문_정확히0`() {
    val threads = 100
    val latch = CountDownLatch(threads)
    val pool = Executors.newFixedThreadPool(32)

    repeat(threads) {
        pool.submit {
            try { stockService.decrease(productId = 1L, qty = 1) }
            catch (e: Exception) { /* 부족 예외 카운트 */ }
            finally { latch.countDown() }
        }
    }
    latch.await(10, TimeUnit.SECONDS)   // 모든 스레드 완료 대기

    val remaining = repository.findById(1L).stock
    assertThat(remaining).isEqualTo(0)  // Oversell 없으면 정확히 0
    // 버그 있으면(naive read-modify-write) remaining > 0 으로 깨짐
}
```

*`CountDownLatch`로 모든 스레드를 동시 출발·완료 대기. 동시성 버그가 있으면 이 테스트가 실패*

> **⚠️ 실무 함정 — Flaky 동시성 테스트**
>
> 동시성 테스트는 타이밍 의존이라 가끔 통과/실패할 수 있다. (1) 충분한 스레드 수·반복, (2) 명확한 동기화(latch), (3) `@DirtiesContext` 로 상태 격리. 그래도 불안정하면 부하 테스트(Gatling/JMeter)로 보완. **Testcontainers + 실제 DB** 에서 돌려야 락 동작까지 검증된다.

## 검수 경계와 실패 흐름

- Testcontainers가 실제 DB를 띄워도 이미지 태그·확장·초기화 SQL·격리 수준이 운영과 다르면 검증 범위가 달라진다. 버전과 마이그레이션을 명시하고 CI에서 재현한다.
- 동시성 테스트는 스케줄러가 모든 interleaving을 탐색하지 않으므로 반복·장벽·불변식 단언과 실제 DB 로그를 함께 사용한다. 통과 횟수만으로 race 부재를 증명하지 않는다.
- Contract 테스트는 합의된 요청·응답 형태를 검증하지만 provider의 비즈니스 규칙, 데이터 품질, 네트워크·인증 장애까지 검증하지 않는다. 계약 변경은 consumer/provider 호환 창과 rollback을 함께 관리한다.
- 컨테이너 시작 실패, 포트 충돌, 테스트 간 공유 상태, 외부 의존성 timeout은 제품 결함과 분리해 진단하고 cleanup·재시도 정책을 둔다.

## 공식·1차 출처

- [Testcontainers for Java — PostgreSQL module](https://java.testcontainers.org/modules/databases/postgres/)
- [PostgreSQL — Transaction Isolation](https://www.postgresql.org/docs/current/transaction-iso.html)
- [Pact — Consumer Driven Contract Testing](https://docs.pact.io/)
- [JUnit 5 User Guide](https://junit.org/junit5/docs/current/user-guide/)$review_23_backend_05_testing$
WHERE slug = 'backend-05-testing' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_backend_06_observability$> **검수 경계** — 로그·메트릭·트레이스의 필드와 보존·샘플링 값은 비용·개인정보·SLO에 따른 설계 입력이다. Micrometer, OpenTelemetry, Prometheus와 Java/Spring 연동 동작은 사용하는 라이브러리 버전 문서로 확인한다.

## 1. 관측성의 세 기둥

```mermaid
flowchart LR
    subgraph O["Observability"]
      L["📜 Logs\n무슨 일이 일어났나\n(이벤트 상세)"]
      M["📊 Metrics\n얼마나/어떤 추세인가\n(집계 수치)"]
      T["🔗 Traces\n어디서 느렸나\n(요청의 전체 경로)"]
    end
    L -.->|traceId로 연결| T
    M -.->|이상 감지 → drill down| T
    style L fill:#fef3c7,stroke:#f59e0b
    style M fill:#dbeafe,stroke:#3b82f6
    style T fill:#ede9fe,stroke:#8b5cf6
```

*Logs·Metrics·Traces는 따로가 아니라 traceId로 묶여야 진짜 가치 — "메트릭에서 이상 → 트레이스로 추적 → 로그로 원인"*

> **💡 Monitoring vs Observability**
>
> **모니터링** 은 "미리 정한 질문에 답"(CPU 80% 넘으면 알람). **관측성** 은 "예상 못한 질문에 답"(왜 특정 사용자만 느린가). 세 기둥을 잘 엮으면 새 대시보드 없이도 새로운 질문에 답할 수 있다.

## 2. 구조적 로깅 (Structured Logging)

문자열 로그보다 **JSON 구조적 로그**가 기계 파싱·검색·집계에 유리하다. 사용 중인 로그 수집기에서 필드 검색을 지원하는지 확인하고, 모든 로그에 무조건 필수라고 일반화하지 않는다.

```
// ❌ 비구조적 — 파싱 불가, traceId 없음
log.info("order created for user kim, id=42")

// ✅ 구조적 — MDC로 traceId·userId를 모든 로그에 자동 부착
MDC.put("traceId", traceId)
MDC.put("orderId", "42")
log.info("order created")   // → {"msg":"order created","traceId":"...","orderId":"42","level":"INFO"}
```

> **⚠️ 실무 함정 — PII / 토큰 로깅 + 예외 삼키기**
>
> **(1) PII 마스킹** : 주민번호·카드번호·토큰을 로그에 찍으면 보안 사고·법규 위반. 직렬화 단계에서 마스킹. **(2) 예외 삼키기 금지** : `catch (e) {}` 로 삼키면 장애가 사일런트로 사라진다. 반드시 컨텍스트와 함께 로깅하거나 다시 던질 것.

#### 로그 레벨 규율

- `ERROR` — 즉시 조치 필요(알람 연결). 남발하면 알람 피로
- `WARN` — 잠재 문제(재시도 발생, 폴백 동작)
- `INFO` — 비즈니스 이벤트(주문 생성)
- `DEBUG` — 개발용 상세, 운영에선 끔

## 3. 메트릭 — RED / USE 방법론

| 방법론 | 대상 | 지표 |
| --- | --- | --- |
| **RED** (요청 중심) | 서비스·API (트래픽 받는 것) | **R**ate(처리율)·**E**rrors(에러율)·**D**uration(지연) |
| **USE** (자원 중심) | 리소스 (CPU·메모리·디스크·풀) | **U**tilization(사용률)·**S**aturation(포화)·**E**rrors |

```kotlin
// Micrometer — RED 지표를 Prometheus로 노출
@Timed(value = "order.place", percentiles = [0.5, 0.95, 0.99])  // Duration
fun placeOrder(cmd: PlaceOrder): Order { ... }

// Rate·Errors — 카운터
meterRegistry.counter("order.placed", "channel", cmd.channel).increment()
meterRegistry.counter("order.failed", "reason", e.code).increment()
```

> **🎯 면접 포인트 — 평균(avg)이 아니라 백분위(percentile)**
>
> "응답시간 어떻게 봐요?" → **평균은 거짓말** . avg 100ms여도 p99가 3초면 1%의 사용자가 끔찍한 경험을 한다. **p50·p95·p99** 로 봐야 한다(특히 꼬리 지연 Tail latency). 그리고 여러 서버 p99를 단순 평균하면 안 되고 히스토그램으로 집계해야 한다. 🔥(Deep-dive)

```mermaid
flowchart LR
    App["Spring App\nMicrometer"] -->|"/actuator/prometheus\nscrape"| Prom["Prometheus\n시계열 DB"]
    Prom --> Graf["Grafana\n대시보드·알람"]
    Prom -->|"임계 초과"| Alert["Alertmanager\n→ Slack/PagerDuty"]
    style App fill:#dcfce7,stroke:#22c55e
    style Prom fill:#fee2e2,stroke:#ef4444
    style Graf fill:#fef3c7,stroke:#f59e0b
```

*Micrometer → Prometheus → Grafana 표준 스택. Prometheus가 주기적으로 scrape(pull)*

## 4. ⭐ 분산 추적 · 상관관계 ID

> **MSA 디버깅 핵심** — 한 요청이 OMS→WMS→TMS 5개 서비스를 거칠 때, *어디서 느렸는지*를 하나의 trace로 추적

`TraceId(추적 ID)`는 요청 전체에 하나, `SpanId(스팬 ID)`는 각 서비스 구간마다 부여된다. 서비스 간 호출 시 HTTP 헤더(**W3C Trace Context** 표준 `traceparent`)로 전파된다.

```mermaid
sequenceDiagram
    participant GW as Gateway
    participant O as OMS
    participant W as WMS
    participant T as TMS
    Note over GW,T: traceId=abc 전체 공유, span은 구간마다
    GW->>O: traceparent: abc / span-1
    O->>W: traceparent: abc / span-2 (parent=1)
    W-->>O: 120ms
    O->>T: traceparent: abc / span-3 (parent=1)
    T-->>O: 2400ms 😱 (병목!)
    O-->>GW: 응답
    Note over T: trace 뷰에서 span-3가 길게 보임→ TMS가 병목임이 한눈에
```

*분산 추적 — 같은 traceId로 묶인 span들의 길이를 비교해 병목 서비스를 즉시 식별(Jaeger/Tempo 워터폴 뷰)*

```
// Spring Boot 3 + Micrometer Tracing — traceId/spanId가 MDC에 자동 주입
// logback 패턴에 %X{traceId} 추가하면 모든 로그에 traceId가 박힘
<pattern>%d %-5level [%X{traceId:-},%X{spanId:-}] %logger - %msg%n</pattern>

// 그러면 에러 로그의 traceId를 Jaeger에 넣어 전체 요청 흐름을 본다
// → 로그(원인) ↔ 트레이스(경로) ↔ 메트릭(추세) 삼각 연결 완성
```

> **⚠️ 실무 함정 — 컨텍스트 전파 끊김**
>
> 비동기(@Async)·스레드풀·Kafka 경계에서 **traceId가 안 넘어가** trace가 끊긴다. 메시지 헤더에 trace context를 실어 보내고, 컨슈머에서 복원해야 한다. 비동기에서 MDC가 사라지는 문제는 `TaskDecorator` 로 컨텍스트를 복사해 해결.

> **🎯 면접 단골 — Last-mile TrackingEvent 추적**
>
> "대량 TrackingEvent가 흐르는데 특정 운송장이 어디서 막혔는지 어떻게 찾나요?" → **운송장 번호를 도메인 상관관계 키로 로그·이벤트에 부착**하고 trace context와 연결한다. 전수 trace는 비용·개인정보·저장량을 따져 sampling하며, 오류·고지연 요청을 우선 보존하는 정책을 SLO와 함께 정한다.

## 5. OpenTelemetry (OTel)

`OpenTelemetry(OTel)`는 Logs·Metrics·Traces를 **벤더 중립 표준**으로 수집·내보내는 프레임워크다. 계측 코드를 한 번 작성하면 Jaeger·Tempo·Datadog 어디로든 보낼 수 있다(백엔드 종속 제거).

```mermaid
flowchart LR
    App["앱 (OTel SDK\n자동/수동 계측)"] --> Col["OTel Collector\n수집·가공·라우팅"]
    Col --> Tempo["Tempo (Trace)"]
    Col --> Prom["Prometheus (Metric)"]
    Col --> Loki["Loki (Log)"]
    Tempo & Prom & Loki --> Graf["Grafana\n통합 뷰"]
    style App fill:#dcfce7,stroke:#22c55e
    style Col fill:#ede9fe,stroke:#8b5cf6
```

*OTel Collector가 중앙 허브 — 앱은 표준 형식으로만 보내고, 백엔드 교체는 Collector 설정만 바꾸면 됨*

> **💡 왜 OTel이 표준이 됐나**
>
> 계측 형식과 백엔드를 분리하면 특정 APM에 대한 종속을 줄일 수 있다. OpenTelemetry와 Spring의 Micrometer 연동은 사용 버전과 exporter 설정을 확인하고, sampling·PII·전송 비용까지 포함해 선택한다.

## 6. SLI / SLO / SLA

| 용어 | 의미 | 예시 |
| --- | --- | --- |
| **SLI** (Indicator, 지표) | 측정하는 실제 수치 | 예: 최근 5분 성공 요청 비율 |
| **SLO** (Objective, 목표) | SLI가 만족해야 할 내부 목표 | 예: 가용성 목표를 계약으로 선언 |
| **SLA** (Agreement, 협약) | 고객과의 계약 + 위반 시 보상 | 계약에 정의한 보상 조건 |

> **💡 Error Budget(에러 예산)**
>
> SLO가 99.9%면 0.1%는 "실패해도 되는 예산"이다. 예산이 남으면 **배포·실험을 공격적으로** , 예산을 다 쓰면 **안정화에 집중** . 신뢰성과 개발 속도를 정량적으로 조율하는 SRE 핵심 도구. SLA는 SLO보다 느슨하게 잡아 버퍼를 둔다.

## 검수 경계와 실패 흐름

- trace context가 HTTP에서 Kafka·Queue·스레드풀로 넘어갈 때 parent/child 관계와 sampling 상태를 명시하고, context 누락을 별도 메트릭으로 관측한다.
- 로그·메트릭·trace 수집기가 지연되거나 장애 나도 업무 요청을 막지 않도록 비동기 buffer와 bounded queue를 두며, backpressure·드롭·재전송 정책을 정한다.
- 고카디널리티 값(사용자 ID·운송장 ID)을 메트릭 label로 넣으면 시계열이 폭발할 수 있다. 메트릭과 로그/trace의 식별자 역할을 분리한다.
- 오류율·지연 SLI는 측정 창·성공 정의·샘플링 편향을 문서화하고, PII·토큰·본문을 수집하지 않는 redaction과 보존기간을 적용한다.

## 공식·1차 출처

- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [W3C Trace Context](https://www.w3.org/TR/trace-context/)
- [Prometheus Histograms and Summaries](https://prometheus.io/docs/practices/histograms/)
- [Micrometer Observation](https://docs.micrometer.io/micrometer/reference/observation.html)$review_23_backend_06_observability$
WHERE slug = 'backend-06-observability' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_backend_08_jvm_memory$> **검수 경계** — JVM 메모리 영역·컨테이너 cgroup 동작·NMT 명령은 JDK와 런타임 버전에 따라 달라질 수 있다. `1GiB`, `640MiB`, `-Xmx` 값은 계산 예시이며 실제 RSS·Limit·Native 영역을 같은 시각에 측정한다.

## 1. 프로세스 메모리는 Heap보다 크다

JVM 프로세스의 RSS(Resident Set Size, 실제 상주 메모리)는 Java Heap뿐 아니라 Metaspace, Code Cache, Thread Stack, Direct Buffer, GC 자료구조, JNI 라이브러리를 포함한다. 컨테이너에서는 합계가 메모리 제한을 넘으면 Java `OutOfMemoryError` 전에 프로세스가 종료될 수도 있다.

```mermaid
flowchart TB
    RSS[JVM Process RSS] --> HEAP[Java Heap\n객체·배열]
    RSS --> META[Metaspace\n클래스 메타데이터]
    RSS --> STACK[Thread Stacks\n프레임·로컬 변수]
    RSS --> CODE[Code Cache\nJIT 컴파일 코드]
    RSS --> DIRECT[Direct/Native\nNIO·JNI·GC 구조]
    HEAP --> TLAB[TLAB\n스레드별 할당 영역]
```

| 영역 | 증가 원인 | 대표 증상 | 확인 방법 |
|---|---|---|---|
| Heap | 살아 있는 객체·캐시 | GC 후에도 Old 사용량 증가 | GC Log, Heap Dump |
| Metaspace | 클래스·ClassLoader | 재배포 후 클래스 미회수 | ClassLoader 통계, NMT |
| Thread Stack | 스레드 수·`-Xss` | 스레드 증가와 RSS 동반 | Thread Dump, 프로세스 스레드 수 |
| Direct Memory | NIO·Netty 버퍼 | Heap은 안정적인데 RSS 증가 | NMT, 버퍼 메트릭 |
| Code Cache | JIT 컴파일 | 컴파일 중단·성능 저하 | `jcmd Compiler.codecache` |

## 2. TLAB은 빠른 할당 경로다

TLAB(Thread-Local Allocation Buffer, 스레드 로컬 할당 버퍼)은 Heap 안에서 스레드가 포인터를 이동시키며 락 없이 작은 객체를 할당하게 한다. TLAB 밖에 할당된 객체와 마찬가지로 도달 가능성이 사라지면 GC 대상이다.

```bash
# Native Memory Tracking은 JVM 시작 시 활성화해야 상세 추적 가능
java -XX:NativeMemoryTracking=summary -jar app.jar
jcmd <pid> VM.native_memory summary
jcmd <pid> GC.heap_info
jcmd <pid> Thread.print
```

> **실무 함정** — `-Xmx`를 컨테이너 제한과 같게 두면 Native 영역이 쓸 공간이 없다. 스레드 수×Stack 크기, Direct Buffer 상한, Metaspace 변동과 안전 여유를 빼고 Heap 예산을 정한다.

## 3. 진단 순서

1. 컨테이너 제한, RSS, Heap committed/used를 같은 시각으로 맞춘다.
2. Full GC 뒤 Old 사용량이 회복되는지 확인한다.
3. Heap이 아니라면 스레드 수, Direct Buffer, Metaspace, Native Memory Tracking을 본다.
4. 메모리 증가율과 트래픽·배포·클래스 로딩 이벤트를 연결한다.

> **면접 포인트** — Heap OOM, Direct Buffer OOM, Native Thread 생성 실패, 컨테이너 OOMKilled는 원인과 증거가 다르다. “Heap Dump부터”가 아니라 계층을 먼저 분류한다.

## 검수 경계와 실패 흐름

- Heap 사용량이 안정적이어도 Metaspace·Code Cache·Thread Stack·Direct Buffer·JNI와 allocator fragmentation이 RSS를 올릴 수 있다. cgroup의 limit·current·events와 JVM 로그를 함께 본다.
- NMT는 시작 옵션과 수집 오버헤드가 있으므로 장애 중 처음 켜는 도구가 아니다. 재현 환경에서 활성화하고 운영에서는 비용·보안 노출을 검토한다.
- Heap Dump에 큰 객체가 없어도 native leak, classloader leak, thread 증가가 남을 수 있다. RSS delta를 영역별로 대사하고 재배포·트래픽·클래스 로딩과 상관분석한다.
- OOMKilled와 Java OOM은 증거와 완화가 다르다. 재시작 전에 영향 완화, 최소 메트릭, 반복 Thread Dump를 확보하고 원인별 limit·pool·buffer 정책을 조정한다.

## 공식·1차 출처

- [Oracle Java Launcher Options](https://docs.oracle.com/en/java/javase/25/docs/specs/man/java.html)
- [Oracle `jcmd` Reference](https://docs.oracle.com/en/java/javase/25/docs/specs/man/jcmd.html)
- [Oracle Native Memory Tracking](https://docs.oracle.com/en/java/javase/25/vm/native-memory-tracking.html)
- [Docker Runtime Resource Constraints](https://docs.docker.com/engine/containers/resource_constraints/)$review_23_backend_08_jvm_memory$
WHERE slug = 'backend-08-jvm-memory' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_backend_09_gc_g1_zgc$> **검수 경계** — G1·ZGC의 단계·옵션·지원 JDK와 pause 특성은 JDK 버전에 따라 달라진다. pause 숫자와 처리량은 보장값이 아니며 같은 JDK·heap·workload·컨테이너 제한에서 부하 테스트로 비교한다.

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
- [OpenJDK ZGC](https://wiki.openjdk.org/display/zgc)$review_23_backend_09_gc_g1_zgc$
WHERE slug = 'backend-09-gc-g1-zgc' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_backend_10_gc_diagnostics$> **검수 경계** — GC 로그·Heap Dump·JFR·NMT의 옵션과 비용은 JDK 버전·실행 옵션·Heap 크기에 따라 달라진다. Dump와 profile은 장애 증거이지 자동으로 누수를 확정하는 결과가 아니다.

## 1. 정지 시간과 생존량을 함께 본다

긴 Pause 하나만으로 누수를 결론 내리지 않는다. GC 원인, 전후 Heap, Old 생존량, 할당 속도, Full GC 빈도를 같은 시간축의 요청 지연과 비교한다.

```mermaid
flowchart LR
    S[지연·OOM 증상] --> L[GC 로그·메트릭]
    L --> H{GC 후 기준선 상승?}
    H -->|예| D[Dump·Dominator 분석]
    H -->|아니오| A[할당 폭증·용량 분석]
    D --> R[GC Root·보유 경로]
```

| 신호 | 가능한 원인 | 다음 증거 |
|---|---|---|
| 높은 Allocation | 임시 객체 폭증 | JFR Allocation Profile |
| Old 기준선 상승 | 장기 보유·누수 | Class Histogram·Dominator |
| Humongous 증가 | 큰 배열·응답 | 객체 크기·요청 유형 |
| Native RSS 상승 | Direct·Thread·JNI | Native Memory·스레드 수 |

```text
진단 순서: 증상 시각 고정 → 로그 상관분석 → 안전한 증거 수집 → 보유 경로 확인 → 재현
```

> **운영 주의** — 큰 Heap의 Dump는 긴 정지와 디스크 고갈을 만들 수 있다. 복제본 격리, 여유 공간, 자동 업로드·삭제 정책을 먼저 준비한다.

## 2. 원인을 객체 그래프로 확인한다

Shallow Size보다 Retained Size와 GC Root 경로를 본다. Cache라면 제한·만료가 실제로 작동하는지, ThreadLocal이면 Thread Pool 수명과 정리 경로를 확인한다.

> **면접 포인트** — Heap만 보지 말고 Metaspace, Direct Memory, Native Thread까지 프로세스 RSS와 구분한다.

## 검수 경계와 실패 흐름

- GC 후 Old 기준선 상승은 leak, 정상적인 promotion, cache warming, 요청량 변화가 모두 가능하다. 여러 GC cycle과 allocation profile·class histogram·GC root 경로를 함께 비교한다.
- 큰 Heap Dump는 stop-the-world 시간, 디스크 공간, 개인정보 노출을 만들 수 있다. replica/isolated node·충분한 여유 공간·암호화·자동 삭제 정책을 먼저 준비한다.
- 높은 allocation rate는 실제 leak이 아닐 수 있고, leak은 allocation이 정상이어도 retained reference로 나타날 수 있다. 짧은 구간의 로그만으로 결론 내리지 않는다.
- 조치 후에는 동일 workload에서 Old baseline·RSS·pause·p99와 재발 여부를 대조하고, 원인 미확인 상태의 무리한 heap 증설을 피한다.

## 공식·1차 출처

- [Java 25 Garbage Collection Tuning Guide](https://docs.oracle.com/en/java/javase/25/gctuning/index.html)
- [Oracle `jcmd` Reference](https://docs.oracle.com/en/java/javase/25/docs/specs/man/jcmd.html)
- [Java Flight Recorder Runtime Guide](https://docs.oracle.com/en/java/javase/25/develop/use-jfr-runtime.html)
- [Oracle Native Memory Tracking](https://docs.oracle.com/en/java/javase/25/vm/native-memory-tracking.html)$review_23_backend_10_gc_diagnostics$
WHERE slug = 'backend-10-gc-diagnostics' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_backend_11_http_client_design$## 1. Connect, Read, Deadline은 서로 다른 대기를 제한한다

상위 요청에 남은 시간이 800ms인데 외부 호출마다 1초 timeout과 3회 재시도를 주면 전체 응답 목표를 지킬 수 없다. 아래 수치는 설계 설명을 위한 가상 입력이다. 먼저 상위 deadline을 전파하고 풀 획득, DNS·연결·TLS, 요청 전송, 첫 응답, 본문 수신, 재시도 대기 각각에 남은 예산을 적용한다.

| 경계 | 제한하려는 대기 | 빠뜨렸을 때 |
|---|---|---|
| 풀 획득 | 사용 가능한 연결·실행 슬롯 대기 | 연결 timeout이 있어도 호출 전 큐에서 오래 기다림 |
| Connect | 새 연결 수립 | 원격이 도달하지 않을 때 자원 점유 |
| Read 또는 응답 대기 | 연결 뒤 응답·본문 수신 | 연결은 성공했지만 응답이 느릴 때 무기한 점유 |
| 전체 Deadline | 큐·연결·원격 처리·재시도 총합 | 시도별 timeout을 합쳐 상위 SLO 초과 |

`read timeout`의 의미는 클라이언트 라이브러리마다 다르다. 소켓의 연속 읽기 사이 유휴 시간인지, 응답 전체 시간인지 API 문서를 확인해야 한다. Java 21 `HttpClient`에는 클라이언트의 `connectTimeout`과 요청의 `timeout`이 있지만 모든 단계별 timeout이 별도 이름으로 제공되는 것은 아니다. 라이브러리 설정값을 추상적인 네 단계와 기계적으로 대응시키지 않는다.

```mermaid
flowchart LR
    A[상위 요청의 남은 시간] --> B[풀 획득 대기]
    B --> C[DNS·연결·TLS]
    C --> D[요청·응답 수신]
    D --> E{결과 확인}
    E -->|성공| F[응답 반환]
    E -->|결과 불명| G[업무 키로 상태 조회·대사]
    E -->|재시도 가능| H[남은 시간·재시도 예산 확인]
    H --> B
```

```text
remaining = parentDeadline - now
if remaining <= 0: return TIMEOUT
perAttemptBudget = min(remaining, perAttemptLimit)
```

## 2. POST 재시도에는 결과 불명을 다루는 계약이 필요하다

`POST /payments`가 서버에서 성공했지만 응답만 유실되면 클라이언트는 실패처럼 보이는 timeout을 받는다. 무조건 다시 보내면 중복 결제가 생길 수 있다. 클라이언트는 동일한 업무 명령에 안정적인 idempotency key를 재사용하고 요청 내용이 바뀌지 않았는지 확인한다. 서버는 키와 요청 해시·처리 결과를 영속화하고 중복 요청에 이전 결과 또는 현재 처리 상태를 돌려준다. 키 보존 기간과 충돌 처리 정책도 계약에 포함한다.

재시도 대상은 일시적인 연결 오류·일부 5xx·429 등으로 제한하고, `Retry-After`가 있으면 반영한다. 각 시도마다 남은 deadline을 재계산하고 backoff와 jitter, 최대 시도 횟수, 동시 재시도 총량을 둔다. timeout으로 결과가 불명확하면 상태 조회·대사 경로를 거친다. 클라이언트 취소는 이미 시작된 서버 작업의 취소 보장이 아니다.

## 3. 풀 고갈은 원인과 대기열을 함께 본다

Java `HttpClient` 문서는 클라이언트 인스턴스마다 연결 풀이 보통 공유되지 않으므로 요청마다 새 클라이언트를 만들면 재사용 이점이 줄 수 있다고 설명한다. 특정 라이브러리에서 풀 고갈이 발생했다면 **활성·유휴 연결, 획득 대기자, 획득 지연, 원격 응답 지연, 본문 소비·닫기 여부**를 함께 본다. 연결 수만 올리면 느린 외부 서비스에 더 많은 동시 요청을 보내 장애를 확대할 수도 있다.

대상별 동시성 한도와 짧은 풀 획득 대기, 실패 시 빠른 거절을 고려한다. 느린 응답의 원인이 원격 지연인지, 본문 스트림 미종료인지, DNS·TLS 재연결인지 구분한다. `sendAsync`의 future를 쓴다면 큐와 취소·완료 처리를 관측한다. 서킷 브레이커는 실패한 대상에 대한 불필요한 재호출을 줄일 수 있지만, fallback이 업무적으로 안전한지는 별도로 결정해야 한다.

> **답변 점검** — 세 질문 모두 한 요청의 남은 시간, POST의 UNKNOWN 상태, 풀 대기의 실제 위치를 연결한다. timeout 수치는 서비스의 SLO·외부사 지연 분포와 부하 시험을 근거로 정한다.

### 근거 자료

- [Java SE 21 — HttpClient](https://docs.oracle.com/en/java/javase/21/docs/api/java.net.http/java/net/http/HttpClient.html): 연결 timeout·클라이언트 재사용·동기/비동기 호출.
- [Java SE 21 — HttpRequest.Builder](https://docs.oracle.com/en/java/javase/21/docs/api/java.net.http/java/net/http/HttpRequest.Builder.html): 요청 timeout.
- [AWS Builders' Library — Making retries safe with idempotent APIs](https://aws.amazon.com/builders-library/making-retries-safe-with-idempotent-APIs/): 멱등성 계약과 안전한 재시도.
- [RFC 6585 — Additional HTTP Status Codes](https://www.rfc-editor.org/rfc/rfc6585.html): 429와 `Retry-After`.$review_23_backend_11_http_client_design$
WHERE slug = 'backend-11-http-client-design' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_backend_12_null_safety_review$## 1. `value ?: 0`을 허용할지 업무 의미로 판단한다

Kotlin의 Elvis 연산자는 왼쪽이 `null`일 때 오른쪽 값을 돌려줄 뿐, `0`이 올바른 업무 값인지 판단하지 않는다. 예를 들어 선택 입력인 `discountAmount`가 누락됐을 때 계약상 할인 없음이라면 `0`이 타당할 수 있다. 반면 재고 수량 조회가 실패해 `null`이 됐는데 `0`으로 바꾸면 품절로 오판하고 원래의 오류를 숨긴다. 리뷰에서는 필드별로 **누락 가능 여부, 0의 의미, 실패 시 정책, 데이터 원천**을 확인한다.

```text
선택 할인액 누락 → 계약상 할인 없음 → 0으로 변환 가능
필수 결제 금액 누락 → 요청 검증 오류 → 0으로 변환 금지
재고 서비스 응답 실패 → 결과 불명 → 품절(0)로 변환 금지
```

`!!`나 깊은 safe-call 체인도 같은 질문을 피하지 못한다. `!!`는 실행 시 예외로 바뀔 수 있고, `?.`가 연쇄되면 어느 필수 단계가 누락됐는지 사라질 수 있다. 경계에서 이유가 있는 오류로 변환하고 도메인 안에는 유효한 상태만 들인다.

| 입력 상태 | 예시 | 경계에서의 처리 |
| --- | --- | --- |
| 계약상 선택값 누락 | 할인액 미입력 | 계약이 허용할 때만 기본값 적용 |
| 필수값 누락 | 결제 금액 없음 | 필드 오류로 거절 |
| 의존성 결과 불명 | 재고 서비스 응답 실패 | 수량 0으로 변환하지 않고 실패·재조회 경로로 보냄 |

## 2. 외부 DTO와 도메인 사이의 변환 책임

HTTP 요청, 외부 API, DB 레코드처럼 신뢰 수준이 다른 입력은 각 경계의 변환기가 계약을 검사한다. HTTP DTO의 필수 누락은 보통 클라이언트 입력 오류로 응답하고, 외부 API의 계약 위반은 의존성 오류로 기록하며, 오래된 DB 행은 마이그레이션·데이터 정정 대상으로 다룬다. 같은 `null`이라도 오류 종류가 다르므로 모든 곳에서 `requireNotNull`만 던져 500 응답으로 만들지 않는다.

```kotlin
sealed interface CreateOrderInput {
    data class Valid(val customerId: String, val note: String?) : CreateOrderInput
    data class Invalid(val field: String) : CreateOrderInput
}

fun OrderRequest.validate(): CreateOrderInput {
    val id = customerId?.takeIf { it.isNotBlank() }
        ?: return CreateOrderInput.Invalid("customerId")
    return CreateOrderInput.Valid(id, note?.trim()?.takeIf { it.isNotEmpty() })
}
```

컨트롤러는 `Invalid`를 4xx로 매핑하고, `Valid`만 도메인 명령으로 바꾼다. 위 코드는 설명용이며 실제 오류 코드·필드명 노출 정책은 API 계약에 맞춘다. Kotlin의 non-null 타입은 이후 코드의 null 접근을 줄여도 외부 JSON 계약이나 Java 상호운용 경계의 검증을 자동으로 대신하지 않는다.

```mermaid
flowchart LR
    A[외부 DTO·DB 값] --> B{입력 출처와 계약 검증}
    B -->|필수값 누락| C[출처에 맞는 오류·정정]
    B -->|선택값 누락| D[계약상 기본값 또는 Missing]
    B -->|유효| E[도메인 값 생성]
    D --> E
    E --> F[불변식이 보장된 명령]
```

## 3. 미입력·알 수 없음·해당 없음을 구분한다

세 상태를 모두 `null`로 저장하면 업데이트 API에서 필드 미전송과 명시적 초기화를 구분할 수 없고, 통계에서는 '해당 없음'이 '측정 실패'와 섞인다. JSON에서는 필드 부재와 `null` 값 자체가 다르다. PATCH에서의 동작은 미디어 타입 계약에 달려 있다. JSON Merge Patch에서는 `null`이 멤버 제거를 뜻하지만, JSON Patch에서는 `remove` 연산과 `replace`로 `null` 값을 넣는 연산이 구분된다. 입력 계약에서 `Missing`, `Unknown`, `NotApplicable`, `Known(value)` 같은 명시적 상태를 두거나 별도 상태 코드와 값 필드를 조합한다. 모든 필드에 복잡한 타입이 필요한 것은 아니며, 실제로 구분해 행동이 달라지는 경우에 도입한다.

> **답변 점검** — 세 질문 모두 문법적 NPE 방지에서 끝내지 않고 입력 계약, 오류 처리, 도메인 불변식, 저장·조회 의미까지 연결한다.

### 근거 자료

- [Kotlin — Null safety](https://kotlinlang.org/docs/null-safety.html): nullable 타입·Elvis·`!!`의 언어 동작.
- [Kotlin — Sealed classes and interfaces](https://kotlinlang.org/docs/sealed-classes.html): 상태 모델과 `when`의 완전성 검사.
- [JSON Schema — null](https://json-schema.org/understanding-json-schema/reference/null): `null` 값과 필드 부재의 차이.
- [RFC 7396 — JSON Merge Patch](https://www.rfc-editor.org/rfc/rfc7396.html): `null`의 제거 의미.
- [RFC 6902 — JSON Patch](https://www.rfc-editor.org/rfc/rfc6902.html): `remove`와 `replace` 연산.$review_23_backend_12_null_safety_review$
WHERE slug = 'backend-12-null-safety-review' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_backend_13_jvm_incident_interview$> **검수 경계** — 장애 대응 순서와 명령의 안전성은 JDK·컨테이너·권한·운영 도구에 따라 달라진다. CPU 100%, RSS, Dump와 Thread Dump 수치는 예시이며 사용자 영향과 증거 수집 비용을 함께 판단한다.

## 1. 복구와 증거를 함께 설계한다

장애 시각, 영향 인스턴스, 배포·트래픽 변화를 먼저 고정한다. 자동 재시작 전에 비용이 낮은 메트릭과 여러 번의 Thread Dump를 수집하고, 위험한 Heap Dump는 격리된 복제본에서 판단한다.

```mermaid
flowchart TD
    A[알림·영향 확인] --> M[CPU·RSS·GC·Thread 메트릭]
    M --> B{주 병목}
    B -->|CPU| P[Profile·반복 Thread Dump]
    B -->|Memory| H[Heap/Native 구분]
    B -->|Wait| W[Lock·I/O·Pool 분석]
    P --> R[완화·재현]
    H --> R
    W --> R
```

| 증상 | 주요 가설 | 증거 |
|---|---|---|
| 높은 CPU | Loop·직렬화·GC | Profile·GC Time |
| 높은 RSS | Heap·Direct·Thread | Heap committed·Native |
| 낮은 CPU·지연 | Lock·I/O·Pool | Thread State·Queue |
| 간헐 정지 | Safepoint·GC | Pause 로그·JFR |

```text
timeline = deploy + traffic + host metrics + JVM events + request traces
compare at least several samples before declaring a stuck thread
```

> **면접 전략** — “재시작한다”와 “Dump를 뜬다”의 양자택일이 아니다. 사용자 영향 완화와 재발 방지에 필요한 최소 증거를 병렬로 확보한다.

## 2. 컨테이너 한계를 포함한다

프로세스 메모리는 Heap 외 Metaspace, Code Cache, Direct Buffer, Native Library와 Thread Stack을 포함한다. JVM 설정뿐 아니라 컨테이너 Limit과 종료 사유를 확인한다.

> **면접 포인트** — 관측→가설→안전한 증거→완화→재현과 회귀 방지의 순서로 답한다.

## 검수 경계와 실패 흐름

- CPU 포화 때 profile·Thread Dump 자체가 추가 비용을 만들 수 있으므로 영향 인스턴스를 격리하고 짧은 샘플을 여러 시점에 확보한다. 단일 snapshot으로 stuck thread를 확정하지 않는다.
- Heap이 안정적이어도 Direct/Native, Metaspace, Code Cache, Thread Stack과 cgroup limit 때문에 OOMKilled가 날 수 있다. JVM·host·container 신호의 시간대를 맞춘다.
- 재시작은 사용자 영향 완화일 수 있지만 증거를 잃을 수 있다. 자동 재시작 전후에 가능한 최소 메트릭·로그·JFR/Thread Dump를 보존하고, 재발 방지용 재현 workload를 만든다.
- Dump·JFR에는 요청 정보와 개인정보가 포함될 수 있으므로 접근 권한·보존·암호화·폐기 정책을 적용한다.

## 공식·1차 출처

- [Java Troubleshooting Guide](https://docs.oracle.com/en/java/javase/25/troubleshoot/)
- [Oracle `jcmd` Reference](https://docs.oracle.com/en/java/javase/25/docs/specs/man/jcmd.html)
- [Java Flight Recorder Runtime Guide](https://docs.oracle.com/en/java/javase/25/develop/use-jfr-runtime.html)
- [Docker Runtime Resource Constraints](https://docs.docker.com/engine/containers/resource_constraints/)$review_23_backend_13_jvm_incident_interview$
WHERE slug = 'backend-13-jvm-incident-interview' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_backend_14_thread_pool_sizing$> **검수 경계** — Thread 수·Queue 상한·거부 정책은 CPU quota, I/O 분포, DB/외부 API 동시성, timeout과 queueing에 따른 가상 설계 입력이다. Little’s Law와 시작 공식은 실제 부하·p99·하위 시스템 한계로 검증한다.

## 1. Thread 수가 처리율을 무한히 늘리지 않는다

CPU 작업은 Core보다 많은 Runnable Thread가 Context Switch를 늘린다. I/O 작업은 대기 중 다른 Thread가 진행할 수 있지만 DB 연결, 외부 API 동시성 등 더 작은 하위 한도를 넘으면 Queue만 이동한다.

```mermaid
flowchart LR
    R[요청 도착] --> Q[Bounded Queue]
    Q --> T[Worker Threads]
    T --> D[(DB Pool)]
    T --> H[External API]
    Q -->|가득 참| X[Reject·Degrade]
```

| 변수 | 너무 작을 때 | 너무 클 때 |
|---|---|---|
| Thread | CPU·I/O 유휴 | 전환·메모리·하위 포화 |
| Queue | 짧은 Burst 거절 | 오래된 요청·OOM |
| Task Timeout | 조기 실패 | 자원 장기 점유 |
| Pool 분리 | 자원 비효율 | 장애 격리 실패 시 전파 |

```text
concurrency ≈ throughput × average_service_time
starting_threads ≈ cores × (1 + wait_time / compute_time)
```

> **설계 함정** — 공식은 시작점일 뿐이다. 꼬리 지연, Lock 경쟁, 하위 Pool과 컨테이너 CPU Quota를 실제 부하로 측정한다.

## 2. 포화를 명시적으로 드러낸다

활성 Thread, Queue 길이와 Age, 거절률, 작업 시간, 하위 호출 대기를 관측한다. 우선순위가 다른 작업은 Pool을 격리하고 이미 Deadline을 넘긴 작업은 실행 전에 폐기한다.

> **면접 포인트** — Thread 수 하나보다 Admission Control, Bounded Queue, Deadline과 실패 응답까지 포화 정책으로 설명한다.

## 검수 경계와 실패 흐름

- I/O 대기 때문에 Thread를 늘려도 DB connection pool·외부 API rate limit·CPU quota가 먼저 포화되면 queue만 커진다. active threads·queue age·downstream in-flight를 함께 관측한다.
- 무제한 Queue는 거절을 늦추고 메모리·대기시간을 키운다. bounded queue, deadline 전 폐기, 우선순위·격리 pool과 명시적인 overload 응답을 정한다.
- `CallerRuns`는 호출자 스레드를 막아 producer에 backpressure를 줄 수 있지만, 요청 thread pool을 함께 고갈시키거나 재진입·응답 timeout을 만들 수 있다. 동기 경계와 비동기 경계를 분리한다.
- timeout 후에도 하위 작업이 계속 실행되면 유령 부하가 누적된다. 취소 전파·idempotency·retry budget·graceful shutdown과 queue drain을 설계한다.

## 공식·1차 출처

- [Java `ThreadPoolExecutor` API](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/concurrent/ThreadPoolExecutor.html)
- [Java `RejectedExecutionHandler` API](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/concurrent/RejectedExecutionHandler.html)
- [Google SRE: Handling Overload](https://sre.google/sre-book/handling-overload/)$review_23_backend_14_thread_pool_sizing$
WHERE slug = 'backend-14-thread-pool-sizing' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_backend_15_file_streaming_design$> **검수 경계** — 파일 크기·Part 크기·URL TTL·Range·checksum·보존기간은 객체 저장소와 클라이언트 계약에 따른 입력이다. Presigned URL·Multipart·Range의 실제 제약과 무결성 필드는 사용하는 저장소 버전 문서로 확인한다.

## 1. 제어 경로와 데이터 경로를 분리한다

API는 파일 메타데이터·크기·형식 정책·업로드 세션·권한을 관리한다. 큰 Byte Stream은 가능하면 Client와 객체 저장소가 직접 주고받아 애플리케이션 Heap과 연결을 보호하지만, URL 탈취·악성 콘텐츠·관측 공백을 별도로 보완한다.

```mermaid
sequenceDiagram
    participant C as Client
    participant A as API
    participant O as Object Storage
    C->>A: 업로드 세션 요청
    A-->>C: 제한된 URL·object key
    C->>O: multipart upload
    C->>A: 완료 요청(checksum, parts)
    A->>O: metadata 검증
    A-->>C: READY 또는 SCANNING
```

| 결정 | 장점 | 보호 장치 |
|---|---|---|
| 직접 업로드 | API 부하 감소 | 짧은 만료·Key 제한·완료 후 소유권 검증 |
| 서버 Proxy | 중앙 검증 단순 | Streaming·크기 상한 |
| Multipart | 재개·병렬화 | 미완료 Upload 청소 |
| Range 다운로드 | 재개·Seek | 권한·Cache Key |

```text
object_key = tenant_id + upload_session_id + random_suffix
accept completion only when size, part list, checksum, and owner match
```

> **보안 경계** — 파일명과 Content-Type을 신뢰하지 않는다. 저장 Key와 표시 이름을 분리하고 악성 코드 검사 전에는 비공개 상태로 둔다.

## 2. 흐름 제어와 수명주기

서버 경유 시 작은 Buffer와 Backpressure로 읽기·쓰기를 연결한다. 업로드 세션 만료, 고아 Part 정리, 검사 실패, 삭제 보존 정책과 감사 로그를 운영 기능으로 둔다.

> **면접 포인트** — 업로드 성공 응답보다 부분 실패, 중복 완료, 무결성, 권한 만료와 고아 데이터 비용까지 설명한다.

## 검수 경계와 실패 흐름

- Presigned URL은 권한을 위임하는 bearer credential이므로 짧은 TTL·method/content-length/content-type 제한·tenant별 object key·HTTPS·재사용 정책을 명시한다. URL을 가진 주체가 업로드할 수 있다는 경계를 숨기지 않는다.
- Multipart 중 일부 Part만 성공하거나 완료 응답이 유실될 수 있다. upload session·part 번호·checksum·owner를 원장에 기록하고, 완료 요청은 멱등하게 재검증하며 만료된 고아 upload를 청소한다.
- 객체 저장 성공 후 메타데이터 DB 기록이나 악성 코드 검사가 실패하면 READY로 노출하지 않는다. `UPLOADING → SCANNING → READY/REJECTED` 상태와 재처리·대사 작업을 둔다.
- Range 응답은 권한 검사 후 `Content-Range`·ETag/버전·부분 checksum을 검증하고, 삭제·버전 변경 중의 캐시와 재개 요청이 다른 객체를 섞지 않도록 object version을 고정한다.

## 공식·1차 출처

- [Amazon S3 Multipart Upload](https://docs.aws.amazon.com/AmazonS3/latest/userguide/mpuoverview.html)
- [Amazon S3 Presigned URLs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-presigned-url.html)
- [RFC 9110 — Range Requests](https://www.rfc-editor.org/rfc/rfc9110#name-range-requests)
- [OWASP File Upload Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html)$review_23_backend_15_file_streaming_design$
WHERE slug = 'backend-15-file-streaming-design' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_backend_architecture_02_ddd$## 1. 왜 DDD인가 — 문제 → 해결

**문제**: 큰 시스템에서 "상품", "주문" 같은 단어가 부서마다 다른 의미인데 하나의 거대 모델로 욱여넣으면, 모든 곳에 영향을 주는 *God Model(만능 모델)*이 생겨 변경이 마비된다.

**해결**: **DDD(Domain-Driven Design, 도메인 주도 설계)**는 도메인을 의미 경계로 나누고(`Bounded Context`), 그 안에서 도메인 전문가와 개발자가 같은 언어(`Ubiquitous Language`)를 쓰며, 일관성 경계(`Aggregate`)를 명확히 한다. Bounded Context는 모듈이나 서비스의 후보가 될 수 있지만 모든 경계를 별도 프로세스로 배포해야 한다는 뜻은 아니다.

```mermaid
flowchart LR
    P["같은 단어 '상품'"]
    P --> C1["Catalog 컨텍스트\n= 전시용 상품정보\n(이름·이미지·설명)"]
    P --> C2["Inventory 컨텍스트\n= 재고 가능한 SKU\n(수량·로케이션)"]
    P --> C3["Billing 컨텍스트\n= 과금 대상 항목\n(단가·세금)"]

    style P fill:#fee2e2,stroke:#ef4444
    style C1 fill:#dbeafe,stroke:#3b82f6
    style C2 fill:#fef3c7,stroke:#f59e0b
    style C3 fill:#fce7f3,stroke:#ec4899
```

*"상품"은 컨텍스트마다 다른 모델이다. 하나로 합치려는 시도가 곧 강결합의 시작.*

> **💡 적용 조건 — DDD를 항상 쓰진 않는다**
>
> DDD는 **도메인 복잡도가 높을 때** 가치가 크다. 단순 CRUD 게시판에 전술 패턴(Aggregate, Repository, Domain Event)을 다 끼우면 오버엔지니어링. 핵심 도메인(Core domain)에만 깊게 투자하고, 보조 도메인(Supporting/Generic)은 가볍게 간다.

## 2. Ubiquitous Language (유비쿼터스 언어)

도메인 전문가와 개발자가 **회의·코드·DB 컬럼·이벤트 이름까지 동일한 용어**를 쓰는 것. 번역 레이어(현업은 "출고지시", 코드는 `processItem()`)가 끼면 그 틈에서 버그가 자란다.

| 나쁜 예 (번역 발생) | 좋은 예 (유비쿼터스) |
| --- | --- |
| 현업 "재고를 잡아둬라" → 코드 `updateStock(-1)` | `inventory.reserve(orderId, qty)` — "예약(Reserve)"이라는 도메인 용어 그대로 |
| 현업 "배송 시작" → 코드 `status = 3` | `shipment.dispatch()` → `ShipmentDispatched` 이벤트 |

> **🎯 면접 포인트**
>
> "도메인 이벤트 이름은 어떻게 짓나요?" → **과거형 + 비즈니스 용어** ( `OrderPlaced` , `InventoryReserved` ). `doOrder` , `processData` 같은 명령형/기술용어는 유비쿼터스 언어 위반.

## 3. Bounded Context (경계 컨텍스트)

한 모델이 일관되게 적용되는 **명시적 경계**. 같은 단어가 경계 밖에선 다른 뜻이어도 된다. Bounded Context는 서비스·모듈 경계를 정할 때의 후보이며, 실제 분리는 트랜잭션·변경·소유권·운영 비용을 함께 보고 결정한다.

```mermaid
flowchart TB
    subgraph LOG["물류 도메인 — Bounded Context 분할"]
      direction LR
      CAT["📘 Catalog\n상품 전시"]
      ORD["🧠 Ordering\n주문 라이프사이클"]
      INV["🏭 Inventory\n재고·할당"]
      FUL["📦 Fulfillment\n피킹·패킹·출고"]
      SHIP["🚛 Shipping\n운송·배송추적"]
      BILL["💳 Billing\n결제·정산"]
      RET["♻️ Returns\n반품·환불"]
    end
    ORD --> INV
    ORD --> BILL
    INV --> FUL
    FUL --> SHIP
    SHIP --> RET
    RET --> BILL

    style CAT fill:#e0e7ff,stroke:#6366f1
    style ORD fill:#dbeafe,stroke:#3b82f6
    style INV fill:#fef3c7,stroke:#f59e0b
    style FUL fill:#fef3c7,stroke:#f59e0b
    style SHIP fill:#ede9fe,stroke:#8b5cf6
    style BILL fill:#fce7f3,stroke:#ec4899
    style RET fill:#dcfce7,stroke:#22c55e
```

*물류 도메인의 Bounded Context 예 — 각 컨텍스트가 "상품"·"주문"의 의미를 독자적으로 가진다.*

> **⚠️ 실무 함정**
>
> "서비스"는 만들었는데 **Bounded Context를 안 정의** 하면, 같은 `Product` 클래스를 모든 서비스가 공유 jar로 import → 한 곳 변경이 전 서비스에 전파. 경계마다 **자기만의 모델** 을 가져야 한다.

## 4. Context Map (컨텍스트 맵)

Bounded Context들 **사이의 관계와 통합 방식**을 그린 지도. "어느 쪽이 갑이고, 어떻게 변경 압력이 전파되는가"를 명시한다.

| 관계 패턴 | 의미 | 물류 예시 |
| --- | --- | --- |
| **Partnership** | 두 팀이 운명 공동체로 함께 변경 | 주문 ↔ 결제 (동시 출시 협의) |
| **Customer/Supplier** | 공급자가 소비자 요구를 반영 | Inventory(공급) → Ordering(소비) |
| **Conformist** | 상류 모델의 영향력을 감수하고 그대로 따름 | 번역 비용보다 상류 계약 준수가 이득인 작은 소비자 |
| **ACL (Anti-Corruption Layer, 부패 방지 계층)** | 외부 모델을 내 모델로 번역해 오염 차단 | 레거시 WMS / 외부 운송사 연동 어댑터 |
| **OHS (Open Host Service)** | 공개 표준 API로 다수 소비자에 제공 | 배송추적 조회 API (수많은 셀러가 소비) |
| **Published Language** | 공유 스키마/표준 메시지 포맷 | 운송장 이벤트 Avro/Protobuf 스키마 |
| **Shared Kernel** | 두 컨텍스트가 작은 공통 모델 공유 (위험) | 공통 Money/Address VO — 최소화 권장 |

```mermaid
flowchart LR
    EXT["외부 택배사 API\n(레거시 포맷)"]
    ACL["ACL\n부패 방지 계층\n번역 어댑터"]
    SHIP["Shipping 컨텍스트\n(내 모델)"]
    INV["Inventory\n(Supplier)"]
    ORD["Ordering\n(Customer)"]

    EXT -->|"오염된 모델"| ACL
    ACL -->|"정제된 내 모델"| SHIP
    INV -->|"Customer/Supplier\nOHS + Published Language"| ORD

    style EXT fill:#fee2e2,stroke:#ef4444
    style ACL fill:#fff7ed,stroke:#ea580c
    style SHIP fill:#ede9fe,stroke:#8b5cf6
    style INV fill:#fef3c7,stroke:#f59e0b
    style ORD fill:#dbeafe,stroke:#3b82f6
```

*ACL은 외부/레거시 모델이 내 도메인을 오염시키지 못하게 막는 핵심 방어선이다.*

> **🎯 면접 포인트**
>
> 레거시 WMS의 상태·코드·오류를 Shipping의 언어로 바꿔야 하면 ACL이 적합하다. 반대로 계약을 그대로 따르는 편이 비용과 위험이 낮다면 Conformist를 택할 수 있고, OHS는 내가 다수 소비자에게 안정된 공개 계약을 제공할 때의 선택이다. 패턴 이름만으로 결론을 내리지 말고 번역 비용·변경 주체·실패 격리를 비교한다. 🔥(Deep-dive)

## 5. 전술 빌딩블록 (Tactical Building Blocks)

| 블록 | 정의 | 예시 |
| --- | --- | --- |
| **Entity(엔티티)** | 식별자(ID)로 구분, 가변 | `Order`, `Shipment` |
| **Value Object(값 객체)** | 값으로 동등성 판단, 불변 | `Money`, `Address`, `Weight` |
| **Aggregate(애그리거트)** | 일관성 경계로 묶인 객체 그래프 | `Order` + `OrderLine`들 |
| **Aggregate Root(루트)** | 외부가 접근하는 유일한 진입점 | `Order` (OrderLine은 직접 못 건드림) |
| **Domain Event(도메인 이벤트)** | 도메인에서 일어난 사실(과거형) | `OrderPlaced` |
| **Repository(리포지토리)** | Aggregate 단위 영속화 추상화 | `OrderRepository` |
| **Domain Service(도메인 서비스)** | 한 Entity에 안 속하는 도메인 로직 | `AllocationService` (창고 할당) |

```mermaid
classDiagram
    class Order {
      <>
      +OrderId id
      +CustomerId customerId
      +OrderStatus status
      +Money totalAmount
      +place()
      +cancel()
      +addLine(sku, qty)
    }
    class OrderLine {
      <>
      +SkuId sku
      +int quantity
      +Money unitPrice
    }
    class Money {
      <>
      +long amount
      +Currency currency
    }
    class Address {
      <>
      +String zipcode
      +String detail
    }
    Order "1" *-- "1..*" OrderLine : 일관성 경계 내
    OrderLine *-- Money : unitPrice
    Order *-- Address : shippingAddress
```

*Order Aggregate — 외부 도메인 로직은 **Aggregate Root(Order)**를 통해 OrderLine의 변경을 요청한다. 영속화·조회 프레임워크의 내부 접근과 애그리거트 경계 밖의 조합 조회는 이 규칙과 구분한다.*

## 6. Aggregate 설계 — 한 트랜잭션 = 한 Aggregate

Aggregate의 핵심은 **Invariant(불변식)**를 지키는 일관성 경계다. 여러 Aggregate를 하나의 원자적 트랜잭션으로 수정할 수 없는 분산 경계라면 보통 이벤트·Saga와 최종 일관성으로 연결한다. 같은 저장소 안에서 즉시 검증해야 하는 규칙이 명확하면 여러 Aggregate를 한 트랜잭션에 포함할 수도 있지만, 락 범위·결합·재시도 비용을 설계에 명시해야 한다. “항상 한 트랜잭션 = 한 Aggregate”는 유용한 기본값이지 DB가 강제하는 보편 법칙은 아니다.

> **⚠️ 실무 함정 — Aggregate를 너무 크게**
>
> "주문 안에 결제·배송·재고까지 다 넣자" → Aggregate가 비대해져 한 주문 수정 때마다 거대한 객체 그래프에 락이 걸린다. Cut-off 직전 주문 폭주 시 **락 경합·트랜잭션 실패** 폭발. 작게 쪼개고 ID 참조로 느슨하게 연결하라. 🔥(Deep-dive)

### Aggregate 설계 4원칙 (Vaughn Vernon)

1. **진짜 불변식만 한 Aggregate에** — 즉시 일관성이 꼭 필요한 규칙만 같이 둔다.
2. **작게 설계** — 클수록 동시성·메모리·락 비용 증가.
3. **다른 Aggregate는 ID로만 참조** — 객체 직접 참조 금지 (`customerId`지 `Customer` 객체 아님).
4. **경계 밖 변경은 최종 일관성** — 도메인 이벤트로 비동기 처리.

```mermaid
flowchart LR
    subgraph T1["트랜잭션 1 (즉시 일관성)"]
      O["Order Aggregate\nOrderPlaced"]
    end
    subgraph T2["트랜잭션 2 (최종 일관성)"]
      I["Inventory Aggregate\nreserve()"]
    end
    O -->|"OrderPlaced 이벤트\n(비동기)"| I

    style T1 fill:#dbeafe,stroke:#3b82f6
    style T2 fill:#fef3c7,stroke:#f59e0b
```

*Order와 Inventory는 별개 Aggregate → 한 트랜잭션에 묶지 않고 이벤트로 연결. 이 구조가 Saga로 이어진다.*

## 7. 전략 설계 vs 전술 설계 — 순서가 중요

|  | 전략 설계 (Strategic) | 전술 설계 (Tactical) |
| --- | --- | --- |
| 관심사 | 큰 그림 — 경계와 관계 | 코드 — 객체 모델 |
| 도구 | Bounded Context, Context Map, Subdomain | Aggregate, Entity, VO, Repository |
| 순서 | **먼저** | 나중 |
| 실패 시 | 서비스 경계가 틀려 분산 모놀리스 | 코드가 지저분하지만 국소적 손해 |

> **🎯 면접 포인트 (가장 흔한 실수)**
>
> 많은 개발자가 곧장 **전술 설계(Aggregate/Repository 코드)** 로 뛰어든다. 하지만 경계(Bounded Context)가 틀리면 코드를 아무리 잘 짜도 시스템이 깨진다. **"먼저 Event Storming으로 경계를 그리고, 그 다음 Aggregate를 설계한다"** 가 정석 답변이다.

> **💡 실무 적용 — Event Storming**
>
> 도메인 전문가와 함께 **도메인 이벤트(주황 포스트잇) → 커맨드(파랑) → Aggregate(노랑) → Bounded Context** 순으로 워크샵하면 경계가 자연히 드러난다. 04(Saga)·03(Event-Driven)이 이 결과물 위에 세워진다.

```text
Event Storming 기록 예
Command: 주문 확정
Aggregate: Order
Event: OrderConfirmed
Policy: 주문 확정 시 재고 예약 요청
```

## 8. 실패 입력 → 판단 → 복구

| 실패 입력 | 판단 | 복구·완화 |
|---|---|---|
| Catalog·Inventory·Billing이 모두 `Product` 하나를 공유하다 가격 필드 변경으로 연쇄 배포가 발생함 | 같은 단어가 각 컨텍스트에서 같은 불변식·수명주기를 갖는지, 공유 코드와 데이터 소유자를 확인한다. | 컨텍스트별 모델과 명시적 계약을 분리하고, 필요한 값만 API·이벤트·Snapshot으로 전달한다. 공통 VO를 공유하더라도 변경 권한과 호환성 범위를 작게 둔다. |
| 주문 생성과 재고 예약을 한 로컬 트랜잭션으로 묶을 수 없음 | 주문 확정 순간 필요한 규칙과 재고 예약 실패를 사용자가 언제 알아야 하는지 구분한다. 외부 WMS·결제처럼 같은 DB에 없는 참여자는 원자 rollback 대상이 아니다. | 주문을 먼저 자기 Aggregate의 유효한 상태로 저장하고 Outbox로 예약 명령을 보낸다. `RESERVATION_PENDING`·실패·취소를 명시하고 소비자 멱등성·보상 정책으로 닫는다. |
| 레거시 WMS의 `3` 상태와 택배사의 `DELIVERED`를 Shipping 도메인에 그대로 노출함 | 상류 코드가 내 모델의 의미·오류·변경 주체를 오염시키는지, 내가 안정된 계약을 제공해야 하는지 판단한다. | 의미를 번역해야 하면 ACL을 두고, 상류 계약을 그대로 따를 때만 Conformist를 선택한다. 다수 소비자용 조회 계약은 OHS로 별도 버전 관리한다. |

경계·패턴·팀 배치는 고정된 정답이 아니다. 용어 충돌, 변경 전파, 계약 실패, 배포·운영 비용을 실제 사례와 지표로 확인한 뒤 경계를 다시 조정한다.

## 9. 공식 참고 자료

- [Microsoft Learn — Use domain analysis to model microservices](https://learn.microsoft.com/en-us/azure/architecture/microservices/model/domain-analysis)
- [Microsoft Learn — Designing a microservice domain model](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/microservice-domain-model)
- [Microsoft Learn — Domain events: Design and implementation](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/domain-events-design-implementation)$review_23_backend_architecture_02_ddd$
WHERE slug = 'backend-architecture-02-ddd' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_backend_architecture_05_cqrs_event_sourcing$## 1. 왜 읽기/쓰기를 분리하는가 — 문제 → 해결

**문제**: 하나의 모델로 쓰기(주문 생성·검증)와 읽기(주문 목록·대시보드·통계)를 다 처리하면, 복잡한 쓰기 불변식과 다양한 읽기 요구가 충돌한다. 읽기 트래픽이 폭주(운송추적 조회)하면 쓰기까지 같이 느려진다.

**해결**: **CQRS(Command Query Responsibility Segregation, 명령/조회 책임 분리)**는 쓰기 모델(Command)과 읽기 모델(Query)의 모델·인터페이스를 분리한다. 두 모델이 같은 DB를 사용해도 CQRS이며, 별도 저장소·프로젝션은 읽기/쓰기 부하와 모델 차이가 실제로 클 때 선택한다. 각각의 독립 최적화·확장에는 동기화와 운영 비용이 따른다.

> **⚠️ 가장 중요한 경고**
>
> CQRS는 **기본값이 아니다** . 단순 CRUD에 도입하면 코드 2배, 동기화 버그, 최종 일관성 디버깅 지옥. **읽기/쓰기의 모델·부하·확장 요구가 확연히 다를 때만** 도입하라. "멋있어서" 쓰면 면접에서 오히려 감점.

## 2. CQRS 구조

```mermaid
flowchart LR
    U(["사용자"])
    U -->|"Command\n(주문 생성)"| CM["Command 모델\n(쓰기 — 불변식·검증)"]
    CM --> WDB[("쓰기 DB\n정규화·트랜잭션")]
    WDB -->|"변경 이벤트\n동기화"| RM["Read 모델 갱신\n(Projection)"]
    RM --> RDB[("읽기 DB\n비정규화·조회 최적화")]
    U -->|"Query\n(주문 조회)"| RDB

    style CM fill:#dbeafe,stroke:#3b82f6
    style WDB fill:#dbeafe,stroke:#3b82f6
    style RM fill:#dcfce7,stroke:#22c55e
    style RDB fill:#dcfce7,stroke:#22c55e
```

*CQRS — 쓰기는 정규화·트랜잭션 최적화, 읽기는 비정규화·조회 최적화. 둘은 이벤트로 동기화(최종 일관성).*

|  | Command (쓰기) | Query (읽기) |
| --- | --- | --- |
| 목표 | 불변식 보장·정합성 | 빠른 조회·다양한 뷰 |
| 모델 | Aggregate (DDD) | DTO·비정규화 뷰 |
| 저장소 | 정합성과 명령 처리에 맞춘 저장소 | 조회 패턴에 맞춘 비정규화 테이블·검색·캐시 등(요구사항에 따라 선택) |
| 확장 | 쓰기 부하 기준 | 읽기 부하 기준(보통 훨씬 큼) |
| 일관성 | 강일관성 | 최종 일관성 (지연 허용) |

> **💡 물류 적용**
>
> 운송추적: **쓰기** 는 운송장 상태 전이(예: CREATED→PICKED_UP 허용 여부를 도메인 규칙으로 검증), **읽기** 는 고객 추적 화면이다. 실제 읽기량·지연 목표·검색 조건을 측정한 뒤 비정규화 테이블, 검색 저장소, 캐시 중 하나를 선택한다. 읽기 모델을 분리하면 독립 확장 여지가 생기지만 최종 일관성·재구축·중복 전달을 함께 운영해야 한다.

## 3. Projection (프로젝션) · 읽기 모델 구축

**Projection**은 쓰기 측 변경(또는 이벤트)을 받아 읽기 모델을 갱신하는 과정이다. 같은 데이터로 *여러 개의 다른 읽기 뷰*를 만들 수 있다.

```mermaid
flowchart LR
    E[("이벤트 스트림\nShipmentDispatched\nArrivedAtHub\nDelivered")]
    E --> P1["Projection 1\n고객 추적 뷰"]
    E --> P2["Projection 2\n기사 대시보드"]
    E --> P3["Projection 3\n운영 KPI 집계"]
    P1 --> V1[("Redis\n최신 상태")]
    P2 --> V2[("RDB\n기사별 할당")]
    P3 --> V3[("OLAP\n시간대별 OTD")]

    style E fill:#ede9fe,stroke:#8b5cf6
    style P1 fill:#dcfce7,stroke:#22c55e
    style P2 fill:#dcfce7,stroke:#22c55e
    style P3 fill:#dcfce7,stroke:#22c55e
```

*하나의 이벤트 스트림 → 여러 Projection → 용도별 읽기 저장소. 새 뷰가 필요하면 Projection을 추가하면 끝.*

> **⚠️ 실무 함정 — 동기화 지연과 Read-your-write**
>
> 읽기 모델은 보통 **비동기 갱신** 이라 "방금 쓴 걸 바로 못 읽는" 현상이 생긴다(Read-your-write 위반). 사용자가 주문 직후 목록에서 안 보임 → UX 문제. 해결: 쓰기 직후만 쓰기 모델에서 직접 읽기, 또는 클라이언트 낙관적 업데이트. 🔥(Deep-dive)

## 4. Event Sourcing (이벤트 소싱)

상태(현재 값)를 저장하는 대신 **상태를 바꾼 이벤트의 시퀀스**를 저장한다. 현재 상태는 이벤트를 처음부터 재생(replay)해 도출한다. 회계 장부(원장)처럼 "변경 내역이 곧 진실"이다.

```mermaid
flowchart LR
    subgraph STATE["상태 저장 (전통)"]
      direction TB
      ST["balance = 7,000원\n(이전 값 덮어씀)"]
    end
    subgraph ES["Event Sourcing"]
      direction TB
      E1["Deposited +10,000"]
      E2["Withdrawn -5,000"]
      E3["Deposited +2,000"]
      E1 --> E2 --> E3
      SUM["replay → 7,000원"]
      E3 --> SUM
    end

    style STATE fill:#fee2e2,stroke:#ef4444
    style ES fill:#dcfce7,stroke:#22c55e
```

*상태 저장은 "어떻게 7,000원이 됐는지" 역사를 잃는다. ES는 전체 이력을 보존하고 replay로 현재를 재구성.*

### 장점과 비용

| 장점 | 비용/위험 |
| --- | --- |
| 완전한 감사 로그(Audit) — 모든 변경 추적 | 이벤트 스키마 진화(버전 관리)가 매우 어려움 |
| 과거 임의 시점 상태 복원(시간여행) | 현재 상태 조회가 비쌈 → 스냅샷 필요 |
| 이벤트 재생으로 새 읽기 모델 생성 | 학습 곡선·운영 복잡도 높음 |
| 디버깅·재현 용이 (이벤트 재생) | "이벤트 삭제 불가" → GDPR 개인정보 삭제 충돌 |

> **⚠️ 실무 함정 — 흔한 오해**
>
> Event Sourcing을 "모든 변경을 로그 테이블에 남기는 것"으로 오해하면 안 된다. ES에서는 해당 이벤트 스트림이 Aggregate의 상태를 재구성하는 기록이며, 스냅샷과 읽기 모델은 파생물이다. 이벤트 스키마 버전, 순서·동시성 검사, 개인정보 보존·삭제 정책, 스냅샷·리플레이 전략 없이 시작하면 운영에서 무너진다.

## 5. 스냅샷(Snapshot) · 리플레이(Replay)

이벤트가 수만 개 쌓인 Aggregate를 매번 처음부터 재생하면 느리다. 주기적으로 **스냅샷**(특정 버전의 상태)을 저장하고, 이후 이벤트만 재생한다.

```mermaid
sequenceDiagram
    participant C as Client
    participant ES as Event Store
    participant A as Aggregate 재구성

    C->>A: 현재 상태 요청
    A->>ES: 최신 스냅샷 로드 (v1000)
    ES-->>A: state@v1000
    A->>ES: v1001~v1003 이벤트만 조회
    ES-->>A: 3개 이벤트
    A->>A: 스냅샷 + 3개 replay = 현재 상태
    A-->>C: 현재 상태 반환
```

*스냅샷 v1000 + 이후 3개 이벤트만 재생 → 1003개 전부 재생 대신 빠르게 현재 상태 도출.*

## 6. CQRS + Event Sourcing 결합

둘은 별개 패턴이지만 궁합이 좋다. ES가 이벤트를 진실로 저장하고, CQRS의 읽기 모델은 그 이벤트 스트림을 Projection해 만든다.

```mermaid
flowchart LR
    CMD["Command"] --> AGG["Aggregate\n(불변식 검증)"]
    AGG -->|"이벤트 append"| ESTORE[("Event Store\n진실의 원천")]
    ESTORE -->|"이벤트 발행"| PROJ["Projection"]
    PROJ --> READ[("Read 모델\n조회 최적화")]
    QRY["Query"] --> READ

    style AGG fill:#dbeafe,stroke:#3b82f6
    style ESTORE fill:#ede9fe,stroke:#8b5cf6
    style PROJ fill:#dcfce7,stroke:#22c55e
    style READ fill:#dcfce7,stroke:#22c55e
```

*ES(쓰기=이벤트 저장) + CQRS(읽기=Projection). Command는 이벤트를 만들고, Query는 Projection을 읽는다.*

> **🎯 면접 포인트**
>
> "CQRS와 Event Sourcing은 항상 같이 쓰나요?" → **아니다, 독립적이다.** CQRS만 써도 되고(읽기/쓰기 DB만 분리), ES만 써도 된다. 다만 함께 쓰면 시너지가 크다. 둘을 묶어서만 이해하면 오해. 🔥(Deep-dive)

## 7. Trade-off · 적용 조건

| 패턴 | 도입해야 할 때 | 도입하면 안 될 때 |
| --- | --- | --- |
| **CQRS** | 읽기/쓰기 부하·모델 차이 큼, 복잡한 조회 뷰 다수, 읽기 독립 확장 필요 | 단순 CRUD, 읽기/쓰기 비대칭 작음, 팀이 최종 일관성 감당 어려움 |
| **Event Sourcing** | 감사·재구성·시간여행이 요구되고 이벤트를 원장으로 운영할 역량이 있음 | 단순 도메인, 현재 상태 CRUD가 주 용도, 즉시 일관성 읽기 요구가 크거나 개인정보 삭제 정책을 충족할 설계가 없음 |

> **💡 시니어 판단 — 점진 도입**
>
> 처음부터 ES로 가지 마라. 먼저 감사·재구성 요구와 읽기/쓰기 비대칭을 확인하고, 필요한 경계에만 선택적으로 도입한다. CRUD에 CQRS를 적용할 때도 논리 모델 분리부터 시작할 수 있다. 조직 전체에 동일 패턴을 강제하기보다 이벤트 계약·운영 역량·삭제 정책을 검증한 뒤 범위를 넓힌다.

## 8. 실패 입력 → 판단 → 복구

| 실패 입력 | 판단 | 복구·완화 |
| --- | --- | --- |
| 쓰기 DB는 커밋됐지만 읽기 Projection 이벤트가 유실됨 | Outbox/이벤트 로그의 상태와 Projection의 마지막 버전을 대조한다. 브로커 lag만으로 유실을 단정하지 않는다. | 이벤트를 재발행하거나 원장부터 해당 범위를 재투영한다. 소비자는 `(aggregate_id, version)` 또는 event ID로 중복·역순을 막는다. |
| 사용자가 방금 변경한 값이 읽기 화면에 없음 | 허용 지연과 Read-your-write 요구를 구분한다. 읽기 저장소가 최신인지, 캐시가 오래됐는지 확인한다. | 커밋 버전/토큰을 전달해 그 버전 이상을 읽거나, 짧은 시간 쓰기 모델 조회·낙관적 UI를 사용한다. “CQRS면 즉시 읽기”라고 가정하지 않는다. |
| 과거 이벤트에 개인정보가 포함되어 삭제 요청이 들어옴 | 이벤트가 append-only라는 사실과 법적 보존·삭제·암호화 정책을 분리해 검토한다. | PII를 이벤트에서 분리하거나 토큰화하고 키 폐기·마스킹·보정 이벤트·리드 모델 삭제를 정책과 증거로 실행한다. 단순 행 삭제가 replay를 깨뜨릴 수 있다. |
| 이벤트 스키마가 바뀌어 재생이 실패함 | 저장된 이벤트 버전과 현재 handler의 호환 범위를 확인한다. | upcaster/버전별 handler로 읽고, 재투영 전 새 모델을 격리 검증한다. 과거 이벤트를 무리하게 덮어쓰지 않는다. |

이 표의 지연·처리량·보존기간은 시스템 요구사항에서 정할 값이며 고정된 숫자나 특정 저장소가 보편적인 답은 아니다.

> **🎯 면접 포인트**
>
> “운송추적 시스템을 설계하라”는 질문에는 CQRS라는 이름보다 쓰기 불변식, 읽기 지연을 사용자에게 표시하는 방식, Projection 재구축과 중복 이벤트 처리를 함께 설명한다. 읽기를 Redis나 검색 저장소로 분리할지는 실제 질의와 SLO로 결정한다. 🔥(Deep-dive)

```sql
SELECT event_id, aggregate_version, event_type, payload
FROM event_store
WHERE aggregate_id = :id
ORDER BY aggregate_version;
```

## 9. 공식 참고 자료

- [Microsoft Learn — CQRS pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/cqrs)
- [Microsoft Learn — Event Sourcing pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/event-sourcing)
- [Microsoft Learn — Materialized View pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/materialized-view)$review_23_backend_architecture_05_cqrs_event_sourcing$
WHERE slug = 'backend-architecture-05-cqrs-event-sourcing' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_backend_architecture_08_aggregate_boundary$## 1. Aggregate는 동시 변경의 최소 단위다

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
- [Microsoft Learn — Saga pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/saga)$review_23_backend_architecture_08_aggregate_boundary$
WHERE slug = 'backend-architecture-08-aggregate-boundary' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_backend_architecture_09_aggregate_reference$## 1. 참조는 일관성 요구를 드러낸다

Aggregate 밖의 객체를 ORM 연관관계로 직접 물리면 탐색은 편하지만 트랜잭션과 로딩 경계가 흐려진다. ID 참조는 “다른 Aggregate는 별도 일관성 경계”라는 사실을 코드에 드러낸다.

```mermaid
flowchart LR
    ORDER[Order Aggregate] -->|customerId| CUSTOMER[Customer Aggregate]
    ORDER -->|warehouseId| WAREHOUSE[Warehouse Aggregate]
    ORDER -->|OrderConfirmed| OUTBOX[(Outbox)]
    OUTBOX --> PROJECTION[Order Detail Read Model]
    CUSTOMER -->|CustomerChanged| PROJECTION
    WAREHOUSE -->|WarehouseChanged| PROJECTION
```

| 전략 | 값의 시점 | 장점 | 적합한 예 |
|---|---|---|---|
| ID 후 실시간 조회 | 현재 | 최신값, 중복 저장 감소 | 현재 고객 등급 |
| 명령 시 Snapshot | 과거 사건 시점 | 감사·재현 가능 | 주문 당시 주소·상품명·가격 |
| 이벤트 기반 Read Model | 약간 지연된 현재 | 조회 성능과 서비스 분리 | 주문 상세 통합 화면 |
| 객체 직접 참조 | 같은 Aggregate 내부 | 불변식 구현 단순 | Order와 OrderLine |

## 2. 현재값과 사건값을 구분한다

배송지는 고객 주소 ID만 저장하면 고객이 주소를 수정했을 때 과거 주문의 배송지가 바뀐다. 주문 확정 당시 주소는 Value Object Snapshot으로 복사하고, 현재 고객 정보가 필요하면 Customer Aggregate나 Read Model을 조회한다.

```kotlin
data class Order(
    val id: OrderId,
    val customerId: CustomerId,
    val shippingAddressAtOrder: ShippingAddress,
    val warehouseId: WarehouseId,
)
```

이벤트 기반 복제는 즉시 일관성을 포기하는 대신 조회 결합을 줄인다. 이벤트에는 소비자가 필요한 식별자와 변경 버전을 넣고, 소비자는 `(aggregateId, version)`으로 중복·역순을 방어한다.

> **실무 함정** — ID 참조를 도입한 뒤 Application Service가 매 요청마다 여러 서비스를 동기 호출하면 분산 객체 그래프가 된다. 화면 조합은 BFF(Read Model), 명령 불변식은 Aggregate 내부, 후속 반영은 이벤트로 역할을 나눈다.

## 3. 선택 질문

1. 이 값은 “현재값”인가 “사건 당시 값”인가?
2. 같은 트랜잭션에서 반드시 검증해야 하는가?
3. 지연 허용 시간과 잘못된 값의 비즈니스 비용은 얼마인가?
4. 참조 대상 장애가 핵심 명령을 막아도 되는가?

> **면접 포인트** — ID 참조는 성능 최적화가 아니라 일관성 경계 선언이다. Snapshot과 Read Model을 섞지 말고 값의 시간 의미부터 설명한다.

## 4. 실패 입력 → 판단 → 복구

| 실패 입력 | 판단 | 복구·완화 |
|---|---|---|
| 주문 상세에서 Customer를 매번 동기 호출하다 고객 서비스 장애가 주문 조회를 막음 | 해당 화면이 현재 고객 정보의 강한 최신성을 요구하는지, 주문 자체의 핵심 데이터인지 분리한다. 호출 수·타임아웃·캐시의 오래된 정도를 측정한다. | 주문 상세 Read Model에 필요한 표시값을 투영하고 버전을 기록한다. 최신값이 꼭 필요한 작업만 명시적 재조회·fallback을 사용한다. |
| 고객이 주소를 변경한 뒤 과거 주문의 배송지가 함께 바뀜 | 주소가 사건 당시 값인지 현재 프로필인지 의미를 확인한다. 동일한 `customerId`만 저장했는지와 Snapshot 시점을 확인한다. | 주문 확정 시 주소·상품명·가격 등 재현에 필요한 값을 Snapshot으로 저장하고, 정정은 새 주문 이벤트나 보정 기록으로 남긴다. |
| 동일 이벤트가 두 번 도착하거나 버전 8이 버전 7보다 먼저 도착함 | 전달 보장은 보통 at-least-once일 수 있으므로 event ID만으로 충분한지, Aggregate별 순서가 필요한지 확인한다. | `(consumer, event_id)` 고유 기록과 `(aggregate_id, version)` 조건부 적용을 트랜잭션으로 묶는다. 버전 gap은 보류·재조회하고 성공 응답을 다시 보내도 부작용은 한 번만 커밋한다. |

ID 참조가 네트워크 호출을 자동으로 없애는 것은 아니다. 핵심 명령에서 필요한 최신성, 화면 조합의 지연 허용, Snapshot의 보존·개인정보 정책을 각각 계약으로 적는다.

## 5. 공식 참고 자료

- [Microsoft Learn — Use domain analysis to model microservices](https://learn.microsoft.com/en-us/azure/architecture/microservices/model/domain-analysis)
- [Microsoft Learn — Designing a microservice domain model](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/microservice-domain-model)
- [Microsoft Learn — CQRS pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/cqrs)$review_23_backend_architecture_09_aggregate_reference$
WHERE slug = 'backend-architecture-09-aggregate-reference' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_backend_architecture_10_entity_value_object$## 1. 클래스 모양이 아니라 의미로 고른다

Entity는 속성이 바뀌어도 같은 대상을 추적하며 식별자와 수명주기를 가진다. Value Object는 구성 값이 같으면 같고, 유효한 상태로 한 번에 생성되어 교체된다.

```mermaid
classDiagram
    class Order {+OrderId id;+Money total;+changeAddress()}
    class Money {+amount;+currency}
    class Address {+postalCode;+lines}
    Order *-- Money
    Order *-- Address
```

| 기준 | Entity | Value Object |
|---|---|---|
| 동등성 | 식별자 | 모든 의미 있는 값 |
| 변경 | 수명주기 동안 상태 전이 | 새 값으로 교체 |
| 예 | 주문·회원 | 금액·기간·좌표 |
| 주의 | ID만 있는 빈 모델 | 과도한 객체 분해 |

```kotlin
data class Money private constructor(val amount: Long, val currency: Currency) {
    init { require(amount >= 0) }
}
```

> **모델링 함정** — ORM 테이블이 있다고 모두 Entity는 아니다. 반대로 외부 식별자가 없어도 도메인이 동일성을 추적하면 Entity다.

## 2. 경계 안에서 불변식을 지킨다

Value Object 생성자가 단위와 범위를 검증하면 잘못된 원시값이 도메인 깊숙이 흐르는 것을 막는다. Entity 변경은 의도를 드러내는 메서드로 제한하고 Aggregate가 일관성을 책임진다.

> **면접 포인트** — 동일한 개념도 Bounded Context의 질문에 따라 모델이 달라짐을 구체적인 수명주기와 비교 규칙으로 설명한다.

## 3. 실패 입력 → 판단 → 복구

| 실패 입력 | 판단 | 복구·완화 |
|---|---|---|
| 회원 주소를 수정했더니 과거 주문의 배송지가 변경됨 | 주문이 보존해야 하는 것은 현재 주소인지 주문 시점 주소인지 확인한다. 같은 mutable 객체를 여러 Aggregate가 공유했는지 검사한다. | 주문에는 주소 Value Object Snapshot을 복사하고, 회원 주소는 별도 Entity의 현재 상태로 관리한다. Snapshot 변경은 일반 수정이 아니라 명시적 정정 사건으로 처리한다. |
| `Money(100, KRW)`와 `Money(100, USD)`가 같다고 판정되거나 단위가 섞임 | 값 객체의 모든 의미 있는 필드와 단위·정밀도·반올림 규칙을 동등성에 포함했는지 확인한다. | 생성 시 통화·범위·스케일을 검증하고 통화 변환은 별도 정책/서비스를 거치게 한다. 원시 `Long`을 여러 통화의 금액으로 재사용하지 않는다. |
| DB surrogate key를 API에 그대로 노출해 식별자 변경·추측 문제가 발생함 | DB 행 식별자, Aggregate의 도메인 ID, 외부 공개 ID가 같은 수명주기와 노출 정책을 갖는지 분리해 본다. | 내부 FK와 공개 식별자를 별도 계약으로 두고, 도메인 ID의 생성·중복·마이그레이션 정책을 명시한다. 도메인 규칙이 자연키에 의존한다면 Unique 제약과 변경 정책도 함께 설계한다. |

Value Object의 불변성과 DB/ORM 매핑 방식은 언어·프레임워크에 따라 다르다. 생성 비용은 객체 수·직렬화·변경 빈도와 실제 프로파일링으로 판단하며, 불변 객체를 도입했다는 이유만으로 성능 수치를 가정하지 않는다.

## 4. 공식 참고 자료

- [Microsoft Learn — Designing a microservice domain model](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/microservice-domain-model)
- [Microsoft Learn — API design: Map REST to DDD patterns](https://learn.microsoft.com/en-us/azure/architecture/microservices/design/api-design)$review_23_backend_architecture_10_entity_value_object$
WHERE slug = 'backend-architecture-10-entity-value-object' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_backend_architecture_12_order_orchestration_design$## 1. 장기 흐름을 상태로 저장한다

오케스트레이터는 현재 단계, 시도 번호, Deadline, 명령 ID를 영속화한다. 각 참여 서비스는 같은 명령의 재시도를 멱등하게 처리하고 결과 이벤트는 Saga ID와 단계 ID를 포함한다.

```mermaid
stateDiagram-v2
    [*] --> ReservingInventory
    ReservingInventory --> AuthorizingPayment: reserved
    AuthorizingPayment --> CreatingShipment: authorized
    CreatingShipment --> Completed
    AuthorizingPayment --> ReleasingInventory: failed/expired
    ReleasingInventory --> Cancelled
```

| 상태 | Timeout 대응 | 보상 |
|---|---|---|
| 재고 예약 | 결과 조회 후 재시도 | 예약 해제 |
| 결제 승인 | 결과 미상 격리 | 승인 확인 후 취소 |
| 배송 생성 | 중복 조회 | 출고 전 취소 가능 여부 |
| 완료 | 이벤트 발행 재시도 | 업무 정책에 따름 |

```text
command_id = saga_id + step + attempt_semantic_version
transition only when current_state and version match
```

> **설계 원칙** — 보상은 DB Rollback이 아니다. 가격 변동, 이미 출고된 상품, 환불 지연처럼 되돌릴 수 없는 현실을 상태와 고객 정책으로 표현한다.

## 2. 운영과 수동 개입

상태별 체류 시간, 재시도, 보상 실패를 지표화한다. 자동 복구가 위험한 결과 미상은 운영 큐에서 근거를 확인하고 승인된 전이만 실행하며 모든 조치를 감사 기록으로 남긴다.

> **면접 포인트** — Happy Path보다 결과 미상, 중복 이벤트, 보상 실패, 오케스트레이터 재시작의 상태 전이를 깊게 설명한다.

## 3. 실패 입력 → 판단 → 복구

| 실패 입력 | 판단 | 복구·완화 |
|---|---|---|
| 재고 예약은 성공했지만 결제 API가 timeout을 반환함 | timeout은 실패가 아니라 결과 미상일 수 있다. 결제 제공자의 조회 API·멱등 키·승인 상태를 먼저 확인한다. | 주문을 `PAYMENT_PENDING`처럼 격리하고 동일 `command_id`로 상태 조회를 재시도한다. 승인 여부가 확인되기 전 재고를 성급히 해제하거나 고객에게 실패를 확정하지 않는다. |
| 결제 승인 뒤 배송 생성이 실패해 환불이 필요함 | 각 단계가 실제로 보상 가능한지, 배송이 이미 외부에 접수됐는지, 환불이 비동기인지 구분한다. | 보상 명령을 별도 멱등 작업으로 기록하고 `REFUND_PENDING`·운영 큐·고객 안내를 둔다. 가격·재고·배송이 원래 상태로 완전히 돌아간다고 가정하지 않는다. |
| 오케스트레이터가 명령을 보낸 직후 재시작됨 | 상태 전이와 발행된 명령의 원자성이 깨졌는지, lease 만료와 재처리 경합이 있는지 확인한다. | 상태·다음 단계·command ID를 한 저장소에 조건부로 기록하고 Outbox 또는 동등한 발행 보장을 사용한다. 재개 worker는 `current_state`와 version을 비교하고 참여 서비스는 명령을 멱등 처리한다. |
| 보상도 실패해 장시간 흐름이 정체됨 | 자동 재시도가 안전한 단계인지와 비가역적인 pivot 이후인지 판단한다. | 재시도 한도를 고정된 숫자로 가정하지 말고 오류 종류·deadline·비용으로 정한다. `COMPENSATION_REQUIRED`와 영향 범위를 대사하고 승인된 수동 전이와 감사 로그로 닫는다. |

오케스트레이션은 분산 트랜잭션을 하나의 DB rollback으로 바꾸지 않는다. 참여 서비스의 로컬 원자성, 메시지 중복·순서, 외부 API 결과 미상, 고객에게 보일 상태를 별도로 설계한다.

## 4. 공식 참고 자료

- [Microsoft Learn — Saga pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/saga)
- [Microsoft Learn — Choreography pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/choreography)
- [Microsoft Learn — CQRS pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/cqrs)$review_23_backend_architecture_12_order_orchestration_design$
WHERE slug = 'backend-architecture-12-order-orchestration-design' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_backend_architecture_13_boundary_interview$## 1. 명사보다 변경 이유를 찾는다

서비스 수가 목표가 아니다. 함께 지켜야 하는 불변식은 가까이 두고, 독립적으로 바뀌고 확장되는 업무 능력은 경계를 검토한다. 조직과 운영 성숙도가 낮으면 모듈러 모놀리스가 더 안전할 수 있다.

```mermaid
flowchart TD
    R[업무 규칙·변경 이유] --> M[모듈 후보]
    M --> I{동기 불변식인가?}
    I -->|예| T[같은 트랜잭션 경계]
    I -->|아니오| S[계약·이벤트 경계]
    S --> O[소유 데이터·SLO]
```

| 근거 | 함께 둘 신호 | 나눌 신호 |
|---|---|---|
| 불변식 | 원자적 변경 필수 | 지연 허용 |
| 변경 | 항상 함께 배포 | 빈도·팀이 다름 |
| 확장 | 같은 부하 특성 | 자원 특성이 다름 |
| 장애 | 함께 실패해도 됨 | 격리 가치가 큼 |

```text
boundary decision = business invariants + ownership + change pattern + failure isolation
not = one table or one noun per service
```

> **면접 전략** — “마이크로서비스가 좋다” 대신 현재 규모의 시작점과 분리 임계값을 제시한다. 경계 비용에는 네트워크와 운영도 포함된다.

## 2. 데이터 소유권으로 검증한다

한 데이터의 쓰기 소유자는 하나로 두고 다른 경계는 API, 이벤트 또는 읽기 모델로 소비한다. 공유 DB 분리는 먼저 쓰기 경로를 단일화한 뒤 변경 로그로 읽기를 옮기는 순서가 안전하다.

> **면접 포인트** — 결정의 반례와 되돌리는 경로까지 말하면 원칙 암기가 아니라 Trade-off 판단임을 보여준다.

## 3. 실패 입력 → 판단 → 복구

| 실패 입력 | 판단 | 복구·완화 |
|---|---|---|
| 주문과 결제를 별도 서비스로 나눴지만 모든 주문 요청이 결제 동기 호출을 기다림 | 결제 승인과 주문의 어떤 불변식이 같은 커밋을 요구하는지, timeout·결과 미상·재시도 비용을 분리한다. | 주문을 `PAYMENT_PENDING`으로 저장하고 결제 결과 이벤트·조회·보상으로 연결한다. 즉시 결제가 정말 필요한 핵심 경로만 동기화하고, 외부 호출에는 멱등 키와 상태 조회를 둔다. |
| 두 서비스가 같은 `orders` 테이블의 컬럼을 각각 수정함 | 스키마 변경·락·배포 순서·삭제 권한이 암묵적 계약이 됐는지 확인한다. 서비스 수보다 쓰기 소유자와 변경 이력을 먼저 찾는다. | 쓰기 소유자를 하나로 정하고 다른 쪽은 API/이벤트/Read Model로 전환한다. expand → dual-read 또는 backfill → cutover → contract 순서로 단계별 rollback을 남긴다. |
| 작은 변경에도 두 팀이 함께 배포하거나 장애가 연쇄 전파됨 | 공통 라이브러리·공유 테이블·동기 호출·이벤트 fan-out별 결합과 배포/장애 지표를 확인한다. 경계가 너무 잘게 쪼개져 호출이 폭증했는지도 본다. | 모듈러 모놀리스로 합치거나 계약 버전·비동기 경계·소유 데이터로 재조정한다. 분리 비용과 운영 인력까지 포함해 경계를 되돌릴 수 있게 한다. |

서비스 개수, 팀 개수, 한 서비스의 테이블 수에는 보편적인 임계값이 없다. 변경 빈도, 불변식, 데이터 소유권, 부하·SLO, 배포·장애 지표를 같은 기간에 관찰해 경계를 검증한다.

## 4. 공식 참고 자료

- [Microsoft Learn — Use domain analysis to model microservices](https://learn.microsoft.com/en-us/azure/architecture/microservices/model/domain-analysis)
- [Microsoft Learn — Microservices assessment: transaction handling](https://learn.microsoft.com/en-us/azure/architecture/guide/technology-choices/microservices-assessment)
- [Microsoft Learn — Saga pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/saga)$review_23_backend_architecture_13_boundary_interview$
WHERE slug = 'backend-architecture-13-boundary-interview' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_backend_architecture_14_rich_domain_model$## 1. 상태와 변경 규칙을 같은 곳에 둔다

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

## 3. 실패 입력 → 판단 → 복구

| 실패 입력 | 판단 | 복구·완화 |
|---|---|---|
| Controller와 여러 Service가 `status = CANCELLED`를 직접 대입함 | 상태 전이 조건이 호출자마다 복제됐는지, 동시에 처리된 취소·출고 요청의 불변식이 어디서 검사되는지 확인한다. | Aggregate의 의도 메서드와 조건부 저장으로 전이를 한 곳에 모은다. 단순 조회/매핑은 Service에 남기고 모든 코드를 Entity에 넣지는 않는다. |
| Domain Entity가 Repository나 결제 HTTP client를 직접 호출함 | 도메인 규칙과 I/O·재시도·timeout이 섞여 테스트와 재사용 경계가 무너졌는지 확인한다. | 도메인은 필요한 Port의 의미만 정의하고 구현·트랜잭션·외부 호출 조정은 application/infrastructure 계층에 둔다. 외부 결과 미상은 상태로 모델링한다. |
| 간단한 CRUD 화면에 VO·Domain Event·복잡한 Aggregate를 모두 도입함 | 업무 규칙의 변경 빈도·불변식 수·감사/재구성 요구가 패턴 운영 비용을 정당화하는지 확인한다. | 현재 상태 CRUD와 단순 검증은 persistence/application 모델로 유지하고, 복잡성이 생긴 경계에만 행위 모델을 점진 도입한다. |

Rich Model은 “객체 안에 모든 로직을 넣기”가 아니라 핵심 불변식의 소유자를 분명히 하는 선택이다. 조회 전용 모델과 외부 연동 조정은 별도 경로로 두며, 프레임워크의 Entity 생명주기·프록시 동작은 도메인 규칙과 구분한다.

## 4. 공식 참고 자료

- [Microsoft Learn — Designing a microservice domain model](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/microservice-domain-model)
- [Microsoft Learn — Designing a DDD-oriented microservice](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/ddd-oriented-microservice)
- [Microsoft Learn — Infrastructure persistence layer design](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/infrastructure-persistence-layer-design)$review_23_backend_architecture_14_rich_domain_model$
WHERE slug = 'backend-architecture-14-rich-domain-model' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_backend_architecture_15_message_recovery_interview$## 1. 손실처럼 보이는 위치를 분해한다

생산자 DB와 Broker 사이, Broker 보존, 소비자 처리, 조회 투영 사이에 각각 다른 실패가 있다. Correlation ID와 단계별 상태를 연결해 “발행 안 됨”과 “소비 지연”을 먼저 구분한다.

```mermaid
flowchart LR
    D[(Producer DB)] --> O[(Outbox)]
    O --> B[(Broker)]
    B --> I[(Consumer Inbox)]
    I --> V[(Business DB)]
    V --> Q[Read Model]
    A[Reconciliation] -.대사.-> D
    A -.대사.-> Q
```

| 장애 경계 | 안전장치 | 복구 증거 |
|---|---|---|
| DB→Broker | Transactional Outbox | 미발행 Outbox |
| Broker→Consumer | ACK·보존 | Offset·Lag |
| Consumer 효과 | Inbox·멱등 키 | Event ID·업무 키 |
| 투영 | 재생·Version | 원본과 Checksum |

```text
recover in order: stop amplification → define source of truth → scope affected keys → replay or compensate → reconcile
```

> **면접 전략** — 재처리를 바로 실행하지 않는다. 비멱등 부작용과 잘못된 이벤트 자체를 다시 적용할 위험을 먼저 분류한다.

## 2. 복구도 정상 기능으로 만든다

기간·업무 키로 제한된 Replay, Dry Run, 처리율 제한, 결과 대사를 제공한다. 사실 기록이 잘못됐다면 삭제보다 원본을 상쇄하는 보정 이벤트가 감사에 유리하다.

> **면접 포인트** — 예방 패턴뿐 아니라 장애 탐지 시간, 영향 범위 산정, 고객 상태 복구와 재발 방지까지 닫는다.

## 3. 실패 입력 → 판단 → 복구

| 실패 입력 | 판단 | 복구·완화 |
|---|---|---|
| DB 커밋 뒤 프로세스가 죽어 Broker에 이벤트가 없음 | 비즈니스 row와 Outbox row가 같은 로컬 트랜잭션에 기록됐는지, 단순 발행 로그와 실제 Broker 수신을 구분한다. | Outbox 미발행·재시도 age를 탐지하고 relay가 안전하게 재발행한다. Outbox row에 안정적인 event ID를 두어 재시도 중복을 소비자가 처리하게 한다. |
| 소비자 DB 커밋 후 ACK 전에 죽음 | Broker가 재전달한 동일 event ID가 이미 업무 효과를 만들었는지, inbox 기록과 business write가 같은 트랜잭션인지 확인한다. | `(consumer, event_id)` 고유 제약 또는 조건부 삽입으로 중복 효과를 막고, 이미 처리된 경우에도 ACK를 재전송한다. 외부 HTTP·메일 등 DB 밖 부작용은 별도 멱등 키/대사로 관리한다. |
| 잘못된 이벤트가 여러 Projection에 이미 반영됨 | 원본 사실이 잘못된 것인지 Projection handler만 결함인지, 영향 event/version/key 범위를 확정한다. | handler 결함이면 수정 후 제한 범위 재생, 원본 사실이면 상쇄·보정 이벤트를 발행한다. 재생 중 외부 부작용을 다시 실행하지 않도록 side effect를 분리하고 Dry Run·대사를 거친다. |
| 이벤트 보존기간이 지나 재생할 원본이 없음 | Broker의 보존 정책과 Outbox/원장/감사 저장소 중 어떤 것이 source of truth인지 확인한다. | 복구 가능한 원본을 별도로 보존하고, 누락 범위는 추정으로 채우지 말고 대사·수동 보정으로 표시한다. 보존기간과 복구 목표는 업무 요구로 정한다. |

Transactional Outbox는 DB와 Broker 사이의 모든 전달을 자동으로 exactly-once로 만들지 않는다. 원자적으로 기록한 뒤 relay가 적어도 한 번 전달하고, 소비자 멱등성·순서/버전 검사·대사로 최종 효과를 통제한다.

## 4. 공식 참고 자료

- [Microsoft Learn — Choreography pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/choreography)
- [Microsoft Learn — CQRS pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/cqrs)
- [Microsoft Learn — Competing Consumers pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/competing-consumers)$review_23_backend_architecture_15_message_recovery_interview$
WHERE slug = 'backend-architecture-15-message-recovery-interview' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_cs_01_ds_algo$## 1. 자료구조 선택 원칙

"어떤 자료구조를 쓸까?"의 답은 항상 **접근 패턴**에서 나온다. 면접에서 자료구조를 고를 때는 다음을 먼저 물어라: **읽기/쓰기 비율, 순서 보장 필요 여부, Range 조회 여부, 메모리 제약, 데이터 분포**.

```mermaid
flowchart TD
    A([데이터 접근 패턴은?]) --> B{Key로 빠른 조회?}
    B -- YES --> C{정렬 순서/Range필요?}
    C -- YES --> D["TreeMap (Red-Black Tree)O(log n), Range·정렬 보장"]
    C -- NO --> E["HashMap평균 O(1), 최악 O(n)"]
    B -- NO --> F{순서가 중요?}
    F -- YES --> G{양끝 삽입/삭제?}
    G -- YES --> H["Deque / LinkedList양끝 O(1)"]
    G -- NO --> I{LIFO or FIFO?}
    I -- LIFO --> J["Stack재귀·괄호검사·DFS"]
    I -- FIFO --> K["QueueBFS·작업 스케줄러"]
    F -- "Top-K / 우선순위" --> L["Heap (PriorityQueue)peek O(1), poll O(log n)"]

    style D fill:#fef3c7,stroke:#d97706
    style E fill:#dbeafe,stroke:#3b82f6
    style L fill:#ede9fe,stroke:#8b5cf6
    style H fill:#dcfce7,stroke:#059669
```

*자료구조 선택 의사결정 트리 — 접근 패턴 → 자료구조*

| 자료구조 | 조회 | 탐색 | 삽입 | 삭제 | 특징 / 실무 함정 |
| --- | --- | --- | --- | --- | --- |
| **Array** | O(1) | O(n) | O(n) | O(n) | 인덱스 접근 최적, 메모리 연속 → 캐시 지역성 우수 |
| **Dynamic Array** | O(1) | O(n) | O(1) 분할상환 | O(n) | append 시 2배 확장 → `amortized` O(1), 일시적 O(n) 복사 |
| **LinkedList** | O(n) | O(n) | O(1)* | O(1)* | *노드 위치 알 때. 캐시 지역성 낮아 실측은 느림 |
| **HashMap** | O(1) avg | O(1) avg | O(1) avg | O(1) avg | 충돌 집중 시 O(n), Resizing 시 O(n) 일시 정지 |
| **TreeMap** | O(log n) | O(log n) | O(log n) | O(log n) | Red-Black Tree, 정렬·Range 보장 |
| **Heap** | O(1) peek | O(n) | O(log n) | O(log n) | 최솟/최댓값 특화. 임의 탐색 비효율 |

> **🎯 면접 함정 — "HashMap이 항상 빠르다"**
>
> 평균 O(1)이라는 말은 키 분포와 구현의 가정을 포함한다. 충돌이 집중되면 최악 탐색 비용이 커지고 악의적 입력으로 서비스 지연이 생길 수 있다. Java 21 `HashMap`의 tree bin 전환 임계값과 용량 조건은 구현 세부사항이므로 다른 언어·JDK·자료구조에 일반화하지 않는다. 초기 용량은 예상 크기와 실제 load factor를 근거로 정하고, 충돌·resize·GC를 실측한다.

## 2. 해시 테이블 (Hash Table)

해시 테이블은 **해시 함수**로 Key를 버킷 인덱스로 매핑한다. 충돌(Collision) 해결 방식이 성능을 좌우한다.

### 충돌 해결: Chaining vs Open Addressing

| 방식 | 원리 | 장점 | 단점 | 대표 구현 |
| --- | --- | --- | --- | --- |
| **Chaining (체이닝)** | 버킷마다 LinkedList/Tree로 충돌 항목 연결 | Load factor > 1 허용, 삭제 단순 | 포인터 오버헤드, 캐시 지역성 낮음 | Java `HashMap` |
| **Open Addressing** | 충돌 시 다른 빈 슬롯 탐사(Linear/Quadratic/Double) | 캐시 친화적, 메모리 밀집 | Load factor 한계(~0.7), Clustering, 삭제 복잡(tombstone) | Python `dict`, Go `map` |

### Load Factor & Rehashing

**Load Factor(적재율)** = 저장된 항목 수 / 버킷 수. 구현이 정한 threshold를 넘으면 **Rehashing(재해싱)**으로 용량과 버킷 배치를 바꿀 수 있다. 이때 여러 항목을 재배치하는 비용이 한 호출에 몰릴 수 있으므로, 대규모 맵에서는 초기 용량·메모리·GC와 함께 지연을 측정한다.

> **⚠️ 실무 함정 — 대규모 트래픽**
>
> 대규모 추적 키를 단일 `ConcurrentHashMap`에 넣을 때는 resize·메모리·GC·동시 접근 경합을 함께 측정한다. 예상 크기를 알면 구현 문서의 capacity 계산을 참고해 초기 용량을 정할 수 있지만, 메모리 예산과 실제 키 분포를 확인하지 않고 큰 값을 예약하면 오히려 낭비가 된다.

### 확률적 자료구조

| 자료구조 | 용도 | 특성 | 실무 예 |
| --- | --- | --- | --- |
| **Bloom Filter** | "존재하지 않음"을 빠르게 판정 | False Positive 가능, False Negative 없음, 공간 효율 | 캐시 미스 방지, Cassandra SSTable 조회 |
| **HyperLogLog** | Cardinality(고유값 개수) 추정 | 구현이 정한 메모리·오차 trade-off | 일일 UV 집계 |
| **Count-Min Sketch** | 빈도(frequency) 추정 | 과대추정만 발생, 공간 고정 | Heavy Hitter 탐지, 트래픽 모니터링 |

## 3. 트리 & 힙 (Tree & Heap)

### 균형 트리가 필요한 이유

일반 BST(Binary Search Tree, 이진 탐색 트리)는 정렬된 입력이 들어오면 한쪽으로 치우쳐 **O(n)** 연결 리스트가 된다. AVL·Red-Black Tree는 회전(Rotation)으로 높이를 **O(log n)**으로 강제한다.

```mermaid
flowchart TB
    subgraph BAD["편향 BST — O(n)"]
      direction TB
      n1((1)) --> n2((2))
      n2 --> n3((3))
      n3 --> n4((4))
    end
    subgraph GOOD["균형 BST — O(log n)"]
      direction TB
      m2((2)) --> m1((1))
      m2 --> m3((3))
      m3 --> m4((4))
    end

    style BAD fill:#fef2f2,stroke:#dc2626
    style GOOD fill:#f0fdf4,stroke:#16a34a
```

*정렬 입력을 넣으면 일반 BST는 편향되어 O(n) — 균형 트리는 높이를 보장*

| 트리 | 균형 방식 | 특징 | 사용처 |
| --- | --- | --- | --- |
| **AVL Tree** | 엄격한 높이 균형(차 ≤ 1) | 조회 빠름, 삽입/삭제 시 회전 많음 | 읽기 집중 워크로드 |
| **Red-Black Tree** | 느슨한 균형(색 규칙) | 삽입/삭제 회전 적음, 균형 살짝 약함 | Java `TreeMap`; 과거 Linux CFS 구현 예시 |
| **B+Tree** | 다진 트리, 리프에 데이터 | 디스크 블록 친화, 낮은 높이, Range 스캔 빠름 | MySQL InnoDB 인덱스 |
| **Trie** | 문자 단위 분기 | 접두사 검색 O(L) | 자동완성, IP 라우팅 |
| **Segment / Fenwick** | 구간 합·최솟값 | 구간 질의 + 갱신 O(log n) | 구간 통계, 누적 집계 |

> **💡 백엔드 연결 — 왜 DB 인덱스는 B+Tree인가**
>
> B+Tree는 페이지 단위 저장과 높은 fan-out으로 트리 높이와 랜덤 I/O를 줄이는 데 유리하다. 실제 높이·페이지 접근 수·캐시 적중률은 엔진·페이지 크기·키 폭·데이터 분포에 따라 달라진다. 리프 연결과 정렬된 키를 활용하는 범위 스캔도 엔진의 실행 계획과 저장 구조를 확인해야 한다.

### 힙 (Heap) — Top-K의 표준 도구

힙은 완전 이진 트리로, 부모가 자식보다 항상 작거나(min-heap) 큰(max-heap) **힙 속성**을 유지한다. peek O(1), insert/poll O(log n). "스트림에서 상위 K개"는 크기 K짜리 힙으로 **O(n log K)**에 해결 — 전체 정렬 O(n log n)보다 빠르고 메모리도 K로 고정된다.

## 4. 그래프 (Graph)

### 인접 리스트 vs 인접 행렬

| 표현 | 공간 | 간선 존재 확인 | 인접 순회 | 적합 상황 |
| --- | --- | --- | --- | --- |
| **인접 리스트** | O(V+E) | O(degree) | O(degree) | 희소 그래프(Sparse). 대부분의 실무 그래프 |
| **인접 행렬** | O(V²) | O(1) | O(V) | 밀집 그래프(Dense), 간선 존재 빈번 조회 |

> **💡 물류 도메인 연결 — 그래프는 어디에나**
>
> 배송망의 허브·캠프·기사 노드와 운송 구간 간선이 곧 그래프다. **최단 경로(Dijkstra)** 는 라우팅, **위상 정렬** 은 작업 의존성(피킹→패킹→출고), **Union-Find** 는 동일 권역 클러스터링에 쓰인다. 실무 배송망은 대개 희소 → 인접 리스트가 정답.

### 핵심 그래프 알고리즘 복잡도

| 알고리즘 | 용도 | 복잡도 | 비고 |
| --- | --- | --- | --- |
| **BFS** | 최단 경로(무가중치) | O(V+E) | 큐 기반, 레벨 순회 |
| **DFS** | 연결성·사이클·위상정렬 | O(V+E) | 스택/재귀 |
| **Dijkstra** | 최단 경로(음수 없는 가중치) | O(E log V) | 우선순위 큐 |
| **Bellman-Ford** | 음수 간선 허용 최단 경로 | O(VE) | 음수 사이클 탐지 |
| **Topological Sort** | 의존성 정렬(DAG) | O(V+E) | Kahn / DFS |

## 5. 정렬 알고리즘 (Sorting)

```
복잡도 위계
O(1)  <  O(log n)  <  O(n)  <  O(n log n)  <  O(n²)  <  O(2ⁿ)
상수      로그          선형       선형로그        이차       지수

정렬의 이론적 하한: 비교 기반 정렬은 O(n log n)보다 빠를 수 없다
  (결정 트리 높이 = log(n!) = Θ(n log n))
Radix/Counting Sort가 O(n)인 이유: 비교를 안 하기 때문 (키 범위 제한 필요)

```

| 알고리즘 | 평균 | 최악 | 공간 | Stable | 언제 쓰나 |
| --- | --- | --- | --- | --- | --- |
| **Quick Sort** | O(n log n) | O(n²) | O(log n) | No | 일반 목적, in-place. Java `Arrays.sort`(primitive) |
| **Merge Sort** | O(n log n) | O(n log n) | O(n) | Yes | 안정 정렬·최악 보장 필요. 외부 정렬(디스크) |
| **Heap Sort** | O(n log n) | O(n log n) | O(1) | No | 메모리 제약 + 최악 보장 동시 필요 |
| **Tim Sort** | O(n log n) | O(n log n) | O(n) | Yes | 실데이터(부분 정렬 활용). Java `Collections.sort`, Python |
| **Radix Sort** | O(nk) | O(nk) | O(n+k) | Yes | 정수·고정길이 키. 비교 없음 |

> **🎯 면접 포인트 — "왜 각각인가"**
>
> 단순 Quick Sort는 피벗 선택과 입력에 따라 최악 O(n²)이 될 수 있다. 피벗 랜덤화만이 유일한 대응은 아니며 실제 라이브러리 구현의 최악 동작은 해당 버전 문서를 확인한다. Merge Sort는 안정성과 O(n log n) 최악 시간 보장이 있어 외부 정렬에서 정렬된 청크를 병합하는 데도 적합하다. Java SE 21 문서에서 객체 배열 정렬은 안정성을 보장하고 적응형 병합 정렬을 설명하며, primitive 배열의 `Arrays.sort(int[])`는 Dual-Pivot Quicksort 구현을 명시한다. 객체에서는 동등 비교 결과의 상대 순서를 보존해야 하지만 primitive 값에는 별도 객체 순서가 없다.

## 6. 면접 빈출 패턴 (Coding Patterns)

| 패턴 | 적용 신호 | 복잡도 | 대표 문제 |
| --- | --- | --- | --- |
| **Two Pointers(투포인터)** | 정렬 배열, 쌍 탐색 | O(n) | Two Sum(정렬), 회문 검사 |
| **Sliding Window(슬라이딩 윈도우)** | 연속 부분 배열/문자열 | O(n) | 최대 합 부분배열, 최장 무중복 부분문자열 |
| **Prefix Sum(누적 합)** | 구간 합 반복 질의 | 전처리 O(n), 질의 O(1) | 구간 합, 부분배열 합 = K |
| **Binary Search on Answer** | 단조성 있는 최적값 | O(n log range) | 최소 용량 배분, Koko 바나나 |
| **Union-Find** | 동적 연결성 | α(n) ≈ O(1) | 연결 요소, 사이클 탐지 |
| **Monotonic Stack** | 다음 큰/작은 원소 | O(n) | Next Greater Element, 빗물 가두기 |

### Sliding Window 직관

"연속 구간"이라는 신호가 보이면 슬라이딩 윈도우를 의심하라. 이중 루프 O(n²)을 윈도우 양끝 포인터로 **O(n)**으로 줄인다. 윈도우 확장(right++) → 조건 위반 시 축소(left++).

```
// 최장 무중복 부분문자열 — O(n)
int left = 0, best = 0;
Set<Character> window = new HashSet<>();
for (int right = 0; right < s.length(); right++) {
    while (window.contains(s.charAt(right))) {   // 조건 위반 → 축소
        window.remove(s.charAt(left++));
    }
    window.add(s.charAt(right));                 // 확장
    best = Math.max(best, right - left + 1);
}

```

> **💡 백엔드 연결**
>
> Sliding Window는 면접 문제만이 아니다. **Rate Limiter(처리율 제한)** 의 Sliding Window Log/Counter, 모니터링의 이동 평균(rolling average)이 모두 같은 원리다. Union-Find의 α(n)(역 아커만 함수)는 실질적으로 상수 — "사실상 O(1)"이라 말하되 이론적으론 거의 상수임을 정확히 표현하라.

## 7. BFS / DFS 순회

```mermaid
flowchart TB
    R((A)) --> B((B))
    R --> C((C))
    B --> D((D))
    B --> E((E))
    C --> F((F))

    style R fill:#dbeafe,stroke:#3b82f6
```

*동일 트리, 순회 순서 비교 — BFS: A B C D E F (큐) / DFS(전위): A B D E C F (스택)*

| 구분 | BFS | DFS |
| --- | --- | --- |
| **자료구조** | Queue(FIFO) | Stack / 재귀 |
| **메모리** | O(너비) — 최악 O(V) | O(깊이) — 최악 O(V) |
| **최단 경로** | 무가중치에서 보장 | 보장 안 됨 |
| **적합 상황** | 최단 거리, 레벨 단위 처리 | 경로 탐색, 사이클·위상정렬, 백트래킹 |
| **주의** | 너비 넓으면 큐 폭발 | 깊으면 Stack Overflow(재귀) → 명시 스택 |

> **⚠️ 실무 함정 — 재귀 DFS의 Stack Overflow**
>
> 깊은 그래프를 재귀 DFS로 돌리면 스레드 스택 한도와 프레임 크기에 따라 `StackOverflowError`가 날 수 있다. JVM 옵션·실행 환경의 스택 크기를 고정값으로 가정하지 말고, 깊이가 크거나 입력이 신뢰되지 않으면 명시적 `Deque` 스택으로 바꾼다. 방문 체크는 큐/스택에 **넣을 때** 표시해 중복 enqueue를 막는다.

## 8. 실패 흐름과 구현 경계

- HashMap 계열의 resize·treeification은 구현·JDK 버전에 따라 다르므로, 성능 문제가 생기면 평균 복잡도만 보지 말고 충돌 분포·capacity·GC pause·메모리 할당을 함께 확인한다.
- Top-K에서 K가 입력보다 크거나 중복 허용 규칙이 다르면 힙의 비교 조건과 결과 크기가 달라진다. 빈 입력·동률·NaN·정렬 안정성 규칙을 먼저 고정한다.
- Dijkstra는 음수 가중치에서 정답을 보장하지 않는다. 음수 간선·음수 사이클·overflow 가능성을 입력 계약에 포함하고 알고리즘을 선택한다.
- 외부 정렬은 메모리 청크를 정렬한 뒤 디스크 run을 병합하는 동안 디스크 공간·임시 파일·재시작·부분 실패를 관리한다. 정렬 결과를 원본 파일에 바로 덮어쓰지 말고 검증 후 교체한다.
- Java 객체 정렬의 안정성·primitive 정렬 구현은 Java SE 버전에 따라 확인한다. `Arrays.sort`의 overload와 `List.sort` 계약을 같은 구현으로 단정하지 않는다.

## 9. 참고 자료

- [Java SE 21 HashMap](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/HashMap.html)
- [Java SE 21 Arrays](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Arrays.html)
- [Java SE 21 List.sort](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/List.html#sort(java.util.Comparator))
- [Java SE 21 PriorityQueue](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/PriorityQueue.html)
- [Java SE 21 StackOverflowError](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/StackOverflowError.html)

## Q&A 연습

아래 질문에 직접 답변을 작성하세요. 자동 저장되며 피드백 요청 시 복사할 수 있습니다.

```text
문제 풀이 체크
1. 입력 크기와 목표 복잡도
2. 불변식과 자료구조 선택
3. 경계값·중복·빈 입력
4. 시간/공간 복잡도 검산
```$review_23_cs_01_ds_algo$
WHERE slug = 'cs-01-ds-algo' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_cs_02_os$## 1. 프로세스(Process) vs 스레드(Thread)

```mermaid
flowchart LR
    subgraph P["프로세스 (독립 주소 공간)"]
      direction TB
      Code["Text / Data(공유)"]
      Heap["Heap(스레드 간 공유)"]
      subgraph T1["Thread 1"]
        S1["Stack 1레지스터·PC"]
      end
      subgraph T2["Thread 2"]
        S2["Stack 2레지스터·PC"]
      end
    end

    style Heap fill:#fef3c7,stroke:#d97706
    style S1 fill:#dbeafe,stroke:#3b82f6
    style S2 fill:#dbeafe,stroke:#3b82f6
```

*스레드는 Heap·Code를 공유하고 Stack·레지스터만 독립 — 그래서 통신은 싸지만 동기화가 필요*

| 구분 | 프로세스 | 스레드 |
| --- | --- | --- |
| **주소 공간** | 독립 가상 주소 공간 | 프로세스 내 공유(Heap·전역·FD) |
| **통신** | IPC(파이프·공유메모리·소켓) | 공유 메모리 직접 접근 → 동기화 필요 |
| **Context Switch** | 주소 공간·실행 상태 전환이 추가될 수 있음 | 같은 주소 공간을 공유하지만 실행 상태·캐시 영향은 남음 |
| **장애 격리** | 높음(크래시 격리) | 낮음(한 스레드 크래시 → 전체) |
| **생성 비용** | 높음(주소공간 복제) | 낮음 |
| **Linux 구현** | `clone()` (CLONE_VM 없이) | `clone()` + `CLONE_VM`\|`CLONE_FILES`… |

> **💡 리눅스 관점 — 프로세스와 스레드의 경계가 흐리다**
>
> Linux에는 "프로세스 전용/스레드 전용" 시스템 콜이 따로 없다. 둘 다 `clone()` 한 줄로 만들어지며, **어떤 자원을 공유할지(CLONE_VM 등 플래그)** 만 다르다. 커널 입장에선 모두 스케줄링 단위인 **task_struct** 일 뿐이다. `cat /proc/<pid>/status` 에서 `Threads:` 수를 직접 확인할 수 있다.

> **🎯 면접 함정 — "스레드가 항상 빠르다"**
>
> runnable 스레드가 CPU와 코어 수를 크게 초과하면 스케줄링·캐시 경합이 커질 수 있다. Lock 경합이 심하면 직렬화되어 단일 스레드보다 느려질 수도 있다(Amdahl's Law). `fork`의 **Copy-on-Write(COW)** 는 공유 페이지를 유지하다 쓰기 시 복제하지만, 페이지 크기·메모리 접근·allocator에 따라 실제 비용이 달라진다.

## 2. 컨텍스트 스위칭 (Context Switch, 문맥 교환)

CPU가 실행 중인 task를 바꾸는 과정. PCB(Process Control Block, 프로세스 제어 블록)에 레지스터·PC(Program Counter)·스택 포인터를 저장하고 다음 task 상태를 복구한다.

```mermaid
sequenceDiagram
    participant T1 as Task A (Running)
    participant K as 커널 스케줄러
    participant T2 as Task B (Ready)
    T1->>K: 타임슬라이스 만료 / I/O 대기 / 인터럽트
    K->>K: A의 레지스터·PC를 PCB_A에 저장
    Note over K: CPU 캐시(L1/L2) 무효화주소공간 다르면 TLB flush
    K->>K: PCB_B에서 B의 상태 복구
    K->>T2: B 실행 재개
```

*컨텍스트 스위치 — 저장·복구와 캐시·주소 변환 계층의 영향이 워크로드·CPU·커널에 따라 달라진다*

- **직접 비용**: 레지스터·스케줄링 상태 저장/복구, 커널 진입/복귀. 고정된 마이크로초 값으로 일반화하지 않는다.
- **간접 비용**: 작업 집합이 바뀌며 캐시 적중률·분기 예측·메모리 대역폭이 달라질 수 있다.
- **주소 변환 영향**: 주소 공간 전환과 TLB 처리 방식은 CPU 기능·커널·페이지 테이블에 의존하며, 같은 프로세스의 스레드 전환도 비용이 0은 아니다.

> **⚠️ 관찰 도구**
>
> `vmstat 1` 의 `cs` 컬럼이 초당 컨텍스트 스위치 수다. 평소 대비 급증했다면 스레드 과다 생성·Lock 경합·인터럽트 폭주를 의심하라. `pidstat -w` 로 프로세스별 자발적(voluntary, I/O 대기)/비자발적(involuntary, 선점) 스위치를 구분할 수 있다 — 비자발적이 많으면 CPU 과부하 신호.

## 3. CPU 스케줄링 (CPU Scheduling)

```mermaid
stateDiagram-v2
    [*] --> New : fork() / clone()
    New --> Ready : 메모리 할당 완료
    Ready --> Running : 스케줄러 디스패치
    Running --> Ready : 타임슬라이스 만료(선점)
    Running --> Waiting : I/O 대기 / sleep()
    Waiting --> Ready : I/O 완료 인터럽트
    Running --> Terminated : exit()
    Terminated --> [*]
```

*프로세스 상태 머신 — Running↔Ready 전이가 곧 컨텍스트 스위치*

| 알고리즘 | 방식 | 장점 | 단점 |
| --- | --- | --- | --- |
| **FCFS** | 도착 순(비선점) | 단순·공정 | Convoy Effect(긴 작업이 뒤를 막음) |
| **SJF / SRTF** | 짧은 작업 우선 | 평균 대기시간 최소 | 긴 작업 기아(Starvation), 실행시간 예측 불가 |
| **Round Robin** | 타임퀀텀 순환(선점) | 응답성 좋음 | 퀀텀 작으면 스위칭 오버헤드 |
| **Priority** | 우선순위 높은 것 먼저 | 중요 작업 우선 | 기아 → Aging으로 완화 |
| **Linux 일반 공정 스케줄링** | 커널 버전에 따라 CFS 또는 EEVDF | 가중치에 따른 CPU 시간 배분 | 실시간 보장 아님(→ `SCHED_FIFO` 등 별도 정책) |

> **💡 백엔드 연결 — nice / cgroup**
>
> 과거 **CFS(Completely Fair Scheduler)** 는 가상 실행시간을 기준으로 실행 대상을 선택했다. Linux 6.6부터 일반 공정 스케줄링은 EEVDF로 전환되기 시작했으므로, 실행 중인 커널의 정책을 확인해야 한다. `nice`는 가중치에 영향을 주고, 컨테이너 CPU 제한은 cgroup 대역폭 제어를 통해 요청을 지연시킬 수 있다. 지연 스파이크를 볼 때 커널 버전·cgroup 버전별 throttling 지표와 CPU pressure를 확인한다.

## 4. 가상 메모리 & 페이징 (Virtual Memory & Paging)

각 프로세스는 전체 메모리를 독점한다고 "착각"하는 가상 주소 공간을 갖는다. MMU(Memory Management Unit)가 페이지 테이블을 통해 가상 → 물리 주소로 변환하며, TLB(Translation Lookaside Buffer, 변환 참조 버퍼)가 최근 변환을 캐싱한다.

```mermaid
flowchart LR
    VA["가상 주소"] --> TLB{TLB Hit?}
    TLB -- Hit --> PA["물리 주소"]
    TLB -- Miss --> PT["페이지 테이블 조회"]
    PT --> Present{페이지가메모리에?}
    Present -- Yes --> PA
    Present -- No --> PF["Page Fault디스크에서 로드(Swap-in)"]
    PF --> PA

    style TLB fill:#dbeafe,stroke:#3b82f6
    style PF fill:#fef2f2,stroke:#dc2626
```

*주소 변환 경로 — TLB Miss → 페이지 테이블 → 필요하면 Page Fault 처리. Major fault의 지연은 저장장치·캐시·메모리 압력에 의존한다.*

| 개념 | 의미 | 비용 / 영향 |
| --- | --- | --- |
| **Page Fault** | 접근 페이지가 현재 매핑·메모리 상태에 없음 | Minor와 Major를 구분하고 저장장치·메모리 압력에 따른 지연을 측정 |
| **Paging** | 고정 크기(4KB) 페이지 단위 관리 | 외부 단편화 없음, 내부 단편화 소량 |
| **Swapping** | 메모리 부족 시 페이지를 디스크로 내림 | 과도하면 Thrashing(스래싱)으로 시스템 마비 |
| **OOM Killer** | 메모리 고갈 시 커널이 프로세스 강제 종료 | JVM 컨테이너가 갑자기 죽는 단골 원인 |

> **⚠️ 실무 함정 — Swap과 GC는 상극**
>
> 스왑과 페이지 폴트는 메모리 접근 지연을 크게 늘릴 수 있다. GC 지연과 함께 page fault·memory pressure·스왑 입출력을 측정하되 모든 GC가 힙 전체를 스캔한다고 가정하지 않는다. 컨테이너에서 갑자기 종료됐다면 해당 cgroup의 OOM 이벤트와 오케스트레이터 종료 사유를 먼저 확인하고, 접근 가능한 호스트에서는 커널 로그도 대조한다.

## 5. 메모리 레이아웃 (Memory Layout)

```
프로세스 가상 주소 공간 (높은 주소 → 낮은 주소)
┌─────────────────────────────────────┐  높은 주소
│            Kernel Space             │
├─────────────────────────────────────┤
│            Stack (스택)             │  ← 지역변수·리턴주소, 자동 관리
│          ↓ (grows down)             │     실행 환경별 스택 한도 → Stack Overflow
├─────────────────────────────────────┤
│            (빈 공간)                │
├─────────────────────────────────────┤
│          ↑ (grows up)               │
│            Heap (힙)                │  ← malloc/new, 수동/GC 관리, 단편화
├─────────────────────────────────────┤
│       BSS (초기화 안 된 전역)        │
├─────────────────────────────────────┤
│       Data (초기화된 전역)          │
├─────────────────────────────────────┤
│       Text (코드, read-only 공유)   │  낮은 주소
└─────────────────────────────────────┘

```

### 힙 할당자 (malloc 내부)

유저 공간의 `malloc`은 OS에게 매번 요청하지 않고, `brk`/`mmap`으로 받은 큰 블록을 잘게 관리한다. 구현체에 따라 단편화·동시성 성능이 갈린다.

| 할당자 | 특징 | 강점 |
| --- | --- | --- |
| **glibc (ptmalloc)** | arena 기반, 범용 기본 | 호환성 |
| **tcmalloc (Google)** | 스레드 로컬 캐시 | 멀티스레드 할당 빠름 |
| **jemalloc** | 단편화 최소화 설계 | 긴 실행·고부하 서버(예전 Redis 권장) |

> **🎯 면접 — "Java Heap과 OS Heap은 같은가?"**
>
> JVM Heap은 JVM이 관리하는 객체 메모리이며 프로세스의 전체 메모리 사용량과 다르다. `-Xmx`는 힙의 최대치이지 시작 시 전부 물리 메모리로 확보한다는 뜻이 아니다. 메타스페이스, 스레드 스택, 직접 버퍼, 네이티브 라이브러리, 페이지 캐시 등도 컨테이너 한도에 영향을 준다. OOM Kill이면 힙 사용량뿐 아니라 cgroup 메모리·JVM 네이티브 메모리와 종료 사유를 함께 조사한다.

## 6. 동기화 프리미티브 (Synchronization Primitives)

공유 자원에 여러 스레드가 동시에 접근할 때 발생하는 **Race Condition(경쟁 상태)**을 막기 위해 **Critical Section(임계 구역)**을 보호한다.

| 메커니즘 | 특징 | 사용 상황 |
| --- | --- | --- |
| **Mutex(뮤텍스)** | 상호 배제. 잠근 스레드만 해제 가능(소유권) | 단일 자원 보호 |
| **Semaphore(세마포어)** | 계수형. N개 동시 접근 허용. 소유권 없음 | 연결 풀·동시 실행 수 제한 |
| **Spinlock(스핀락)** | 락 대기 중 CPU 점유(Busy-wait). 스위칭 없음 | 매우 짧은 임계구역, 멀티코어 커널 |
| **RWLock** | 읽기 동시 허용, 쓰기 배타 | 읽기 多 쓰기 少 |
| **Condition Variable** | 특정 조건까지 대기/통지(wait/notify) | Producer-Consumer |
| **CAS(Compare-And-Swap)** | 원자적 비교-교환. Lock-free 기반 | `AtomicInteger`, 락 없는 큐 |

> **💡 Mutex vs Spinlock — 언제 무엇을**
>
> 임계구역이 **매우 짧고** 멀티코어에서 소유자가 곧 실행될 때 Spin이 유리할 수 있다. 임계구역이 **길거나** 소유자가 선점·block될 수 있으면 Spin은 CPU를 낭비하므로 blocking mutex가 적합할 수 있다. 실제 primitive의 adaptive 동작은 OS·런타임·라이브러리 구현을 확인한다.

## 7. 데드락 (Deadlock, 교착 상태)

다음 4조건이 **동시에** 성립할 때 발생. 하나라도 깨면 예방된다.

```mermaid
flowchart LR
    A["1. 상호 배제한 번에 하나만 점유"] --> D
    B["2. 점유 대기쥔 채 추가 자원 대기"] --> D
    C["3. 비선점강제 회수 불가"] --> D
    E["4. 순환 대기A→B→A 순환"] --> D
    D(["⚠️ Deadlock"])

    style D fill:#fef2f2,stroke:#dc2626
    style A fill:#fef3c7,stroke:#d97706
    style B fill:#fef3c7,stroke:#d97706
    style C fill:#fef3c7,stroke:#d97706
    style E fill:#fef3c7,stroke:#d97706
```

*데드락 4조건 — 가장 실용적인 깨기는 "순환 대기 제거"(락 획득 순서 통일)*

| 대응 | 전략 | 비고 |
| --- | --- | --- |
| **예방(Prevention)** | 4조건 중 하나를 구조적으로 제거 | 락 순서 통일이 가장 실용적 |
| **회피(Avoidance)** | 안전 상태 유지(Banker's Algorithm) | 이론적, 실무 적용 드묾 |
| **탐지(Detection)** | 자원 할당 그래프 사이클 탐지 후 복구 | DB가 락 그래프로 탐지 → victim rollback |
| **타임아웃** | `tryLock(timeout)`으로 포기 후 재시도 | 가장 흔한 현실적 방어 |

> **🎯 면접 + 실무 — DB 데드락**
>
> 재고 차감에서 주문 A가 SKU1→SKU2, 주문 B가 SKU2→SKU1 순으로 락을 잡으면 DB 데드락이 날 수 있다. DB 엔진마다 탐지·victim 선택·timeout 동작이 다르므로 해당 엔진의 lock graph와 로그를 확인한다. 해결은 OS와 동일 — **모든 트랜잭션이 동일한 순서로 락을 잡게** 강제하고, 실패한 트랜잭션을 안전하게 재시도하며, 재고 불변식을 원자 조건부 갱신으로 보호한다.

## Q&A 연습

아래 질문에 직접 답변을 작성하세요. 자동 저장되며 피드백 요청 시 복사할 수 있습니다.

```bash
# 프로세스의 스레드·메모리·열린 파일 확인 예
ps -L -p <pid>
cat /proc/<pid>/status
ls /proc/<pid>/fd | wc -l
```

## 8. 실패 흐름과 진단 경계

- 컨테이너의 `-Xmx`는 JVM heap 상한일 뿐 프로세스 전체 메모리 상한이 아니다. metaspace·스레드 스택·direct buffer·native library·page cache·cgroup limit을 함께 보고 종료 주체가 JVM인지 커널인지 확인한다.
- OOM killer 로그가 있다고 바로 heap을 줄이거나 늘리지 않는다. cgroup memory events, RSS·committed heap, swap·page fault·GC, sidecar와 같은 시점의 로그를 대조한 뒤 조정한다.
- `volatile` 또는 mutex가 있어도 DB transaction·외부 호출·락 순서가 교착을 만들 수 있다. OS의 4조건과 DB의 lock graph·timeout·victim rollback을 분리해 진단한다.
- 컨텍스트 switch·CPU pressure가 증가했다고 스레드 수를 즉시 줄이지 않는다. runnable 수·I/O 대기·lock contention·cgroup throttling을 함께 확인하고, pool·queue·downstream concurrency를 같이 조정한다.
- Linux의 scheduler·cgroup·allocator 동작과 Java 21의 virtual/platform thread 자원은 버전에 따라 달라질 수 있다. 고정된 스택 크기·switch 비용·page fault 시간을 보편 상수로 제시하지 않는다.

### 근거 자료

- [Linux Kernel — EEVDF Scheduler](https://docs.kernel.org/scheduler/sched-eevdf.html): Linux 6.6 이후 일반 공정 스케줄링 전환.
- [Linux Kernel — Pressure Stall Information](https://docs.kernel.org/accounting/psi.html): CPU·메모리·I/O 대기 관측.
- [Java SE 21 — Thread](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/Thread.html): 플랫폼·가상 스레드와 스택 자원.
- [Java SE 21 — Java Language Specification, Threads and Locks](https://docs.oracle.com/javase/specs/jls/se21/html/jls-17.html): Java 메모리 모델과 happens-before.
- [Linux kernel — cgroup v2 memory](https://docs.kernel.org/admin-guide/cgroup-v2.html): 컨테이너 자원 제어와 메모리 pressure 경계.
- [Linux `proc_pid_status`](https://man7.org/linux/man-pages/man5/proc_pid_status.5.html): 프로세스·스레드·메모리 관측 필드.$review_23_cs_02_os$
WHERE slug = 'cs-02-os' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_cs_03_network$## 1. OSI 7계층 / TCP-IP 4계층

| OSI 7 | TCP/IP 4 | 역할 | 대표 프로토콜 / 단위(PDU) |
| --- | --- | --- | --- |
| 7 Application 6 Presentation 5 Session | Application | 애플리케이션 데이터·인코딩·세션 | HTTP·gRPC·DNS·TLS / Message |
| 4 Transport | Transport | 종단 간 신뢰성·포트 다중화 | TCP·UDP·QUIC / Segment |
| 3 Network | Internet | 호스트 간 라우팅·주소 지정 | IP·ICMP / Packet |
| 2 Data Link 1 Physical | Link | 인접 노드 전송·물리 매체 | Ethernet·ARP / Frame |

> **💡 백엔드 관점 — 계층은 디버깅 분기점**
>
> 장애가 어느 계층인지 빠르게 가르면 진단이 빨라진다. `ping` (L3) → 도달성, `telnet host port` / `ss` (L4) → 포트·연결, `curl -v` (L7) → TLS·HTTP 응답. "L7 LB는 경로 기반 라우팅, L4 LB는 IP:Port 기반"의 차이도 이 계층 모델에서 나온다.

## 2. TCP 핸드셰이크 (3-way / 4-way)

```mermaid
sequenceDiagram
    participant C as 클라이언트
    participant S as 서버
    Note over C,S: 연결 수립 — 3-way Handshake
    C->>S: SYN (seq=x)
    S->>C: SYN-ACK (seq=y, ack=x+1)
    C->>S: ACK (ack=y+1)
    Note over C,S: ESTABLISHED — 데이터 전송 가능
    Note over C,S: 연결 종료 — 4-way Handshake
    C->>S: FIN
    S->>C: ACK
    Note over S: 남은 데이터 전송 가능(Half-close)
    S->>C: FIN
    C->>S: ACK
    Note over C: TIME_WAIT (2×MSL)
```

*3-way로 양방향 시퀀스 번호 동기화, 4-way는 양쪽이 독립적으로 닫기 때문*

> **🎯 면접 단골 — "왜 연결은 3-way, 종료는 4-way? TIME_WAIT은 왜?"**
>
> **3 vs 4** : 수립 땐 서버의 ACK와 SYN을 SYN-ACK로 합칠 수 있지만, 종료 땐 서버가 보낼 데이터가 남아있을 수 있어 ACK와 FIN을 분리한다(Half-close). **TIME_WAIT(2×MSL)** 은 마지막 ACK 유실 시 재전송된 FIN에 응답하고 같은 연결 식별자의 오래된 세그먼트와 새 연결을 구분하는 데 필요하다. `ss -tan`으로 로컬·원격 주소별 상태를 본다. 높은 개수 자체를 장애로 단정하지 말고 실제 임시 포트 고갈·연결 실패를 확인한 뒤 연결 재사용과 종료 주체를 검토한다. `SO_REUSEADDR`나 커널 옵션을 보편적 해결책으로 제시하지 않는다.

> **⚠️ 함정 — 보통 능동 종료 측에 TIME_WAIT이 남지만 동시 종료도 가능하다**
>
> 서버가 먼저 끊었다면 해당 서버 쪽에 TIME_WAIT이 남을 수 있다. 양쪽 동시 종료라면 양쪽 모두 TIME_WAIT에 들어갈 수도 있다. 서버의 수신 소켓에서 TIME_WAIT이 많다는 이유만으로 임시 포트가 고갈된다고 단정하지 않는다. 실제 소켓의 로컬·원격 주소, 연결 실패, 종료 주체를 확인하고 서버↔서버 호출은 Keep-Alive 연결 풀로 불필요한 재연결을 줄인다.

## 3. 혼잡 제어 (Congestion Control)

TCP는 네트워크 혼잡을 감지해 전송 속도를 스스로 조절한다. **혼잡 윈도우(cwnd)**를 키우고 줄이는 알고리즘이 핵심이다.

```
Slow Start (느린 시작)        : ACK·cwnd 정책에 따라 지수적으로 증가하는 구간 — ssthresh까지
Congestion Avoidance (혼잡 회피): ssthresh 이후 RTT마다 +1 (선형 증가)
Fast Retransmit / Recovery    : 중복 ACK 3회 → 손실 추정, 즉시 재전송
손실 감지 시                   : cwnd를 줄이고 다시 회피 구간으로

```

| 알고리즘 | 혼잡 신호 | 특징 |
| --- | --- | --- |
| **Reno / NewReno** | 패킷 손실 | 고전적, 손실 기반(AIMD) |
| **CUBIC** | 패킷 손실 | Linux에서 널리 사용되지만 기본·세부 동작은 커널 설정과 버전에 의존 |
| **BBR** | 병목 대역폭·RTT 추정 | 모델 기반 제어; 버전·배포 설정·경로에 따라 동작과 공정성이 달라짐 |

> **🎯 면접 — Nagle vs TCP_NODELAY**
>
> Nagle은 작은 세그먼트를 모아 효율을 높일 수 있지만, 애플리케이션 write 패턴·Delayed ACK·RTT와 상호작용해 지연을 만들 수 있다. 지연에 민감한 RPC에서 `TCP_NODELAY`를 검토할 수 있지만 패킷 수·대역폭·CPU와 함께 측정해야 하며, 모든 지연의 원인으로 단정하지 않는다.

## 4. HTTP 버전 진화 (1.1 / 2 / 3)

```mermaid
flowchart TB
    H1["HTTP/1.1요청-응답 직렬HOL Blocking(앱 레벨)"] -->|멀티플렉싱| H2["HTTP/2한 TCP에 다중 스트림HPACK 헤더 압축"]
    H2 -->|"TCP HOL 영향 → QUIC 스트림 독립"| H3["HTTP/3QUIC(UDP 기반)스트림 독립·선택적 0-RTT"]
    H2 -.->|"패킷 손실 시전체 스트림 정지"| TCPHOL["TCP 레벨HOL Blocking 잔존"]

    style H1 fill:#fef3c7,stroke:#d97706
    style H2 fill:#dbeafe,stroke:#3b82f6
    style H3 fill:#dcfce7,stroke:#059669
    style TCPHOL fill:#fef2f2,stroke:#dc2626
```

*HTTP/2는 애플리케이션 스트림을 하나의 TCP 연결에 다중화하고, HTTP/3은 QUIC의 독립 스트림으로 전송 계층의 TCP HOL 영향을 줄인다.*

| 버전 | 전송 | 핵심 개선 | 남은 문제 |
| --- | --- | --- | --- |
| **HTTP/1.0** | TCP | 요청마다 연결 수립/종료 | 높은 지연·연결 비용 |
| **HTTP/1.1** | TCP | Keep-Alive, 파이프라이닝 | 응답 순서 보장 → HOL Blocking |
| **HTTP/2** | TCP | 멀티플렉싱, HPACK, 바이너리 프레이밍, 서버 푸시 | TCP 단일 손실이 전 스트림 정지 |
| **HTTP/3** | QUIC(UDP) | 스트림 독립, 연결 이주, 선택적 0-RTT | UDP 경로 차단·미들박스, 구현·CPU·재전송 정책 |

### 멱등성(Idempotency) & 안전(Safe) 메서드

| 메서드 | Safe | Idempotent | 비고 |
| --- | --- | --- | --- |
| GET / HEAD | ✅ | ✅ | 상태 변경 없음 → 캐시·재시도 안전 |
| PUT / DELETE | ❌ | ✅ | 여러 번 호출해도 결과 동일 |
| POST | ❌ | ❌ | 중복 시 부작용 → `Idempotency-Key` 필요 |

> **💡 백엔드 연결 — 결제·주문 재시도**
>
> 네트워크 타임아웃 후 재시도 시 POST가 중복 결제를 낼 수 있다. 클라이언트가 `Idempotency-Key` 헤더를 붙이고 서버가 키-결과를 저장하면, 재시도여도 동일 응답을 돌려준다. 멱등성은 HTTP 스펙 지식이자 분산 시스템 신뢰성의 핵심.

## 5. HTTPS / TLS 핸드셰이크

```mermaid
sequenceDiagram
    participant C as 클라이언트
    participant S as 서버
    Note over C,S: TLS 1.3 — 1-RTT
    C->>S: ClientHello (지원 암호 스위트 + key_share)
    S->>C: ServerHello (선택 스위트 + key_share)+ Certificate + CertVerify + Finished
    Note over C,S: 여기서 양측 대칭키 산출 완료(ECDHE)
    C->>S: Finished
    Note over C,S: 암호화된 애플리케이션 데이터 시작
    Note over C: 재방문 시 0-RTT(PSK)로 즉시 전송 가능
```

*TLS 1.3의 일반적인 full handshake는 1-RTT이지만, TLS 1.2·재개·HelloRetryRequest·네트워크 조건에 따라 왕복 수가 달라진다. 0-RTT early data는 replay 위험을 고려해야 한다.*

| 항목 | TLS 1.2 | TLS 1.3 |
| --- | --- | --- |
| 핸드셰이크 RTT | full handshake·재개 방식에 따라 다름 | 일반 full handshake 1-RTT, 재개 시 0-RTT early data 선택 가능 |
| 키 교환 | RSA / DHE / ECDHE | ECDHE만(전방향 비밀성 강제) |
| 암호 스위트 | 다수(취약한 것 포함) | AEAD만, 취약 알고리즘 제거 |

> **🎯 면접 — "HTTPS면 안전하다"는 함정**
>
> TLS는 ① **기밀성** (대칭키 암호화) ② **무결성** (MAC) ③ **인증** (인증서 체인 → CA)을 제공하지만, **인증서 검증을 클라이언트가 제대로 해야** 의미가 있다. 검증을 끄거나 만료/자가서명을 무시하면 MITM(중간자 공격)에 뚫린다. `SNI` (여러 도메인 한 IP), `ALPN` (HTTP/2 협상), **mTLS** (상호 인증, 서비스 메시) 개념도 함께.

> **⚠️ 대표 공격**
>
> MITM은 인증서 검증·신뢰 저장소 문제로, Replay는 프로토콜·애플리케이션의 freshness와 멱등성 문제로, Downgrade는 허용 버전·협상 정책 문제로 다룬다. TLS 1.3 강제나 HSTS만으로 CSRF·XSS·SQLi가 해결되는 것은 아니다. CSRF에는 origin·CSRF token·쿠키 정책, XSS에는 출력 인코딩·CSP, SQLi에는 parameter binding을 적용한다.

## 6. DNS (Domain Name System)

```mermaid
sequenceDiagram
    participant C as 클라이언트
    participant R as Resolver(재귀)
    participant Root as Root
    participant TLD as TLD(.com)
    participant Auth as 권한 서버
    C->>R: www.coupang.com A?
    R->>Root: .com 어디?
    Root-->>R: TLD 서버 주소
    R->>TLD: coupang.com 어디?
    TLD-->>R: 권한 서버 주소
    R->>Auth: www.coupang.com A?
    Auth-->>R: 1.2.3.4 (TTL=300)
    R-->>C: 1.2.3.4
    Note over R: TTL 동안 캐싱 → 다음 질의 즉답
```

*재귀 질의(Resolver) + 반복 질의(Root→TLD→Auth) — 캐싱 계층이 TTL로 동작*

| 레코드 | 의미 | 용도 |
| --- | --- | --- |
| **A / AAAA** | 도메인 → IPv4 / IPv6 | 기본 주소 매핑 |
| **CNAME** | 도메인 → 다른 도메인 | 별칭, CDN 연결 |
| **MX** | 메일 서버 | 이메일 라우팅 |
| **TXT** | 임의 텍스트 | SPF·도메인 소유 검증 |
| **SRV** | 서비스 위치(host:port) | 서비스 디스커버리 |

> **⚠️ 함정 — DNS 라운드로빈 LB의 한계**
>
> A 레코드 여러 개로 부하를 분산할 수 있지만, ① **TTL 캐싱** 때문에 장애 IP를 즉시 빼지 못하고, ② 클라이언트·Resolver가 캐시한 IP를 계속 써서 트래픽이 균등하지 않다. 그래서 프로덕션은 DNS는 진입점으로만 쓰고, 실제 분산은 L4/L7 LB·헬스체크로 한다. `dig +trace` 로 질의 경로를 직접 추적하라.

## 7. CDN (Content Delivery Network)

CDN은 사용자와 지리적으로 가까운 **Edge(엣지) 서버**에 콘텐츠를 캐싱해 지연을 줄이고 Origin 부하를 낮춘다. 정적 자원(이미지·JS·CSS)뿐 아니라 동적 가속·DDoS 완화에도 쓰인다.

```mermaid
flowchart LR
    U["👤 사용자(부산)"] --> E["🌐 CDN Edge(부산 PoP)"]
    E -->|Cache Hit| U
    E -->|Cache Miss| O["🏢 Origin(서울)"]
    O -->|"응답 + Cache-Control"| E
    E -->|캐시 후 응답| U

    style E fill:#dcfce7,stroke:#059669
    style O fill:#dbeafe,stroke:#3b82f6
```

*Edge 캐시 Hit이면 Origin까지 안 감 — 지연↓, Origin 부하↓*

| 캐시 제어 헤더 | 역할 |
| --- | --- |
| `Cache-Control: max-age` | 캐시 유효 기간(초) |
| `ETag` / `If-None-Match` | 변경 검증 → 304 Not Modified로 대역폭 절약 |
| `Vary` | 요청 헤더별로 캐시 분기(예: Accept-Encoding) |

> **💡 실무 연결 — 캐시 무효화가 어렵다**
>
> 정적 자원은 파일명에 콘텐츠 해시를 넣는 **Cache Busting**으로 새 버전과 이전 버전을 분리할 수 있다. 동적 콘텐츠는 `Cache-Control`, `ETag`, `Vary`, 개인정보 여부와 purge 실패를 함께 설계하고, `stale-while-revalidate`는 허용 가능한 오래된 데이터 범위가 있을 때만 사용한다.

## 8. 실패 흐름과 진단 경계

- TIME_WAIT이 많다는 사실만으로 서버 장애나 포트 고갈을 단정하지 않는다. 능동·수동 종료 주체, 임시 포트 범위, 연결 재사용, `connect()` 실패와 실제 latency를 함께 확인한다.
- HTTP/2의 TCP HOL과 HTTP/3의 QUIC stream independence는 서로 다른 계층의 문제다. HTTP/3로 바꿔도 UDP 경로 차단·MTU·loss·서버 처리·애플리케이션 HOL이 자동으로 사라지지 않는다.
- TLS 0-RTT는 replay 가능한 요청을 포함할 수 있으므로 주문·결제 같은 side effect 요청을 early data로 허용하지 않거나 서버에서 재생 방지·멱등성 정책을 적용한다.
- DNS TTL과 CDN cache가 오래된 origin·콘텐츠를 계속 제공할 수 있다. 인증서·DNS·origin health·cache key·purge 전파를 각각 확인하고 장애 시 stale 응답 허용 범위를 정한다.
- `TCP_NODELAY`, congestion control, keep-alive timeout은 커널·라이브러리·프로토콜·워크로드 조합의 설정이다. 한 옵션을 켜는 것만으로 지연을 해결한다고 말하지 않고 packet capture와 애플리케이션 latency를 함께 비교한다.

## Q&A 연습

아래 질문에 직접 답변을 작성하세요. 자동 저장되며 피드백 요청 시 복사할 수 있습니다.

```bash
dig +trace example.com
curl -v --http2 https://example.com
ss -tan state time-wait
```

### 근거 자료

- [RFC 9293 — TCP](https://www.rfc-editor.org/rfc/rfc9293.html): 종료 상태와 동시 종료·TIME-WAIT.
- [RFC 9114 — HTTP/3](https://www.rfc-editor.org/rfc/rfc9114.html): QUIC 스트림과 HTTP/3.
- [RFC 9110 — HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110.html): HTTPS URI 및 요청·응답 경계.
- [RFC 9000 — QUIC](https://www.rfc-editor.org/rfc/rfc9000.html): QUIC 전송과 스트림.
- [RFC 8446 — TLS 1.3](https://www.rfc-editor.org/rfc/rfc8446.html): TLS 1.3 handshake와 0-RTT 고려사항.
- [Linux kernel TCP documentation](https://docs.kernel.org/networking/ip-sysctl.html): Linux TCP 설정과 커널 버전별 확인 지점.$review_23_cs_03_network$
WHERE slug = 'cs-03-network' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_cs_04_concurrency_theory$## 1. 동시성(Concurrency) vs 병렬성(Parallelism)

```mermaid
flowchart TB
    subgraph CC["동시성 — 1코어, 번갈아 진행 (구조)"]
      direction LR
      c1["Task A"] -.시분할.-> c2["Task B"] -.-> c3["Task A"]
    end
    subgraph PP["병렬성 — 2코어, 동시에 실행 (실행)"]
      direction LR
      p1["Core1: Task A"]
      p2["Core2: Task B"]
    end

    style CC fill:#dbeafe,stroke:#3b82f6
    style PP fill:#dcfce7,stroke:#059669
```

*동시성은 "여러 일을 다루는 구조", 병렬성은 "여러 일을 같은 순간 실행" — Rob Pike의 구분*

- **동시성**: 작업을 잘게 나눠 번갈아 진행. 단일 코어로도 가능(I/O 대기 중 다른 작업). *구조*의 문제.
- **병렬성**: 실제로 동시에 여러 코어에서 실행. 멀티코어 필요. *실행*의 문제.

> **💡 백엔드 연결**
>
> I/O-bound 서버(DB·API 호출 대기 多)는 대기 중 다른 작업을 진행하는 **동시성**으로 처리량이 개선될 수 있다 — 이벤트 루프, 코루틴, Virtual Thread(JDK 21+)가 그 예다. CPU-bound 작업은 코어·스케줄러·병렬화 비용을 고려한 병렬성이 필요하다. 실제 풀 크기는 다운스트림 한도와 측정으로 정한다.

## 2. 임계 구역(Critical Section) & Race Condition

**Race Condition(경쟁 상태)**은 둘 이상 스레드가 공유 자원을 동시에 갱신할 때, 실행 순서에 따라 결과가 달라지는 버그다. 보호되지 않은 공유 자원 접근 구간이 **임계 구역**.

```sql
// 비원자적 read-modify-write — Race Condition
count++  실제로는 3단계:
  1) tmp = count      (read)
  2) tmp = tmp + 1    (modify)
  3) count = tmp      (write)
스레드 A,B가 1을 동시에 읽으면 → 둘 다 +1 → 결과가 +1 (Lost Update)

```

해결: ① 상호 배제(Mutex/synchronized)로 임계 구역 직렬화, ② 원자적 연산(CAS), ③ 애초에 공유 상태를 없애기(불변 객체·메시지 패싱).

> **⚠️ 실무 함정 — 재고 차감**
>
> `SELECT 재고; if(재고>0) UPDATE 재고-1;` 는 전형적 Check-then-Act 경쟁 상태로 **Oversell(초과판매)** 을 낳는다. 해결은 원자적 조건부 UPDATE( `UPDATE ... SET qty=qty-1 WHERE qty>0` )·낙관적 락(version)·비관적 락( `SELECT ... FOR UPDATE` )·Redis 원자 감소 중 부하 특성에 맞게 선택.

## 3. 락(Lock) vs CAS — 두 가지 동기화 철학

```mermaid
flowchart TB
    subgraph L["Lock 기반 (Pessimistic)"]
      direction TB
      l1["lock 획득"] --> l2["임계 구역"] --> l3["unlock"]
      l4["대기 스레드: 블로킹"]
    end
    subgraph C["CAS 기반 (Optimistic, Lock-free)"]
      direction TB
      c1["현재값 읽기(expected)"] --> c2["새 값 계산"]
      c2 --> c3{"CAS(addr, expected, new)성공?"}
      c3 -- 성공 --> c4["완료"]
      c3 -- 실패 --> c1
    end

    style L fill:#fef3c7,stroke:#d97706
    style C fill:#dcfce7,stroke:#059669
```

*Lock은 충돌을 막고(블로킹), CAS는 충돌을 감지하고 재시도(논블로킹)*

| 관점 | Lock (Blocking) | CAS / Lock-free |
| --- | --- | --- |
| 충돌 처리 | 대기(블로킹) | 재시도(스핀) |
| 경합 낮을 때 | 락 오버헤드 | 매우 빠름 |
| 경합 높을 때 | 안정적 | 재시도 폭증으로 비효율 가능 |
| 위험 | 데드락·우선순위 역전 | ABA 문제·라이브락 |
| 예 | `synchronized`, `ReentrantLock` | `AtomicInteger`, `ConcurrentLinkedQueue` |

`AtomicLong`은 단일 값의 원자 갱신에 적합하지만 경합이 높으면 같은 메모리 위치에서 CAS 재시도가 늘어난다. `LongAdder`는 여러 셀에 갱신을 분산하고 합산 시 값을 모으므로 통계 카운터처럼 정확한 순간값보다 높은 갱신 처리량이 중요한 경우에 유리할 수 있다. 계좌 잔액·재고처럼 매 연산의 강한 원자성이 필요한 값에 무조건 `LongAdder`를 사용하면 안 된다.

> **🎯 면접 — ABA 문제**
>
> CAS는 "값이 expected와 같으면 교체"인데, 값이 A→B→A로 돌아오면 CAS는 변화를 **감지하지 못한다** . 그 사이 자료구조가 바뀌었을 수 있어 위험하다. 해결: 값에 **버전/스탬프** 를 붙이는 `AtomicStampedReference` . Lock-free 자료구조 설계에서 반드시 짚는 포인트.

## 4. 메모리 모델 & 가시성 (Memory Model & Visibility)

현대 CPU·컴파일러는 성능을 위해 **명령 재정렬(Reordering)**을 하고, 각 코어는 자기 캐시에 값을 들고 있다. 그래서 한 스레드의 쓰기가 다른 스레드에 **즉시 보이지 않을 수** 있다 — 이것이 **가시성(Visibility)** 문제.

```mermaid
sequenceDiagram
    participant TA as Thread A (Core1)
    participant CA as L1 Cache A
    participant M as Main Memory
    participant CB as L1 Cache B
    participant TB as Thread B (Core2)
    TA->>CA: flag = true (캐시에만 기록)
    Note over CB: B의 캐시엔 아직 flag=false
    TB->>CB: while(!flag) ... 무한 루프 가능!
    Note over TA,TB: volatile/배리어 없으면 영원히 안 보일 수 있음
```

*가시성 문제 — 쓰기가 메인 메모리로 flush되고 읽기가 무효화되어야 보인다*

### happens-before 관계

A happens-before B이면, A의 결과가 B에 **반드시 보임**이 보장된다(JMM, Java Memory Model). 주요 규칙:

- 동일 스레드 내 프로그램 순서
- `volatile` 쓰기 → 같은 변수 읽기 (Memory Barrier 삽입)
- 모니터 unlock → 같은 모니터 lock
- `Thread.start()` → 시작된 스레드 내부 / 스레드 종료 → `join()` 반환

| 키워드 | 보장 | 주의 |
| --- | --- | --- |
| `volatile` | 가시성 + 재정렬 방지 | 원자성은 보장 안 함(`i++` 여전히 위험) |
| `synchronized` | 상호 배제 + 가시성 | 락 비용·경합 |
| `Atomic*` | 원자성 + 가시성(CAS) | 복합 연산은 별도 설계 필요 |

> **🎯 면접 — "double-checked locking" 함정**
>
> 싱글톤 지연 초기화에서 `volatile` 없이 double-checked locking을 쓰면, 객체 생성(할당→초기화→참조대입)이 재정렬되어 **초기화 덜 된 객체를 다른 스레드가 볼 수** 있다. 인스턴스 필드를 `volatile` 로 선언해 배리어를 강제해야 안전. 더 간단한 답은 **Holder Idiom** (클래스 로딩의 happens-before 활용)이나 **enum 싱글톤** .

## 5. 액터(Actor) / CSP 모델 — 공유 상태를 피하는 길

"공유 메모리 + 락"의 복잡성을 피하는 대안은 **상태를 공유하지 않고 메시지로 통신**하는 것이다. "Don't communicate by sharing memory; share memory by communicating."

| 모델 | 핵심 | 통신 | 대표 |
| --- | --- | --- | --- |
| **공유 메모리 + 락** | 공유 상태를 락으로 보호 | 직접 메모리 접근 | Java `synchronized`, pthread |
| **Actor 모델** | 각 액터가 자기 상태 소유, 메일박스로 메시지 수신 | 비동기 메시지 | Erlang/Elixir, Akka |
| **CSP** | 채널을 통한 동기 통신, 프로세스는 상태 비공유 | 채널(channel) | Go goroutine + channel |

> **💡 실무 연결**
>
> Go의 `goroutine + channel`은 CSP와 유사한 통신 모델을 제공하지만 채널만으로 데이터 경합·교착·back-pressure가 자동 해결되는 것은 아니다. Akka/Erlang의 액터도 mailbox 용량·순서·재시작 전략을 설계해야 한다. 동시성 버그를 줄이는 핵심은 **공유 가변 상태와 소유권을 명확히 하는 것**이다.

## 6. Amdahl's Law (암달의 법칙)

병렬화로 얻는 속도 향상에는 **상한**이 있다. 직렬(순차) 부분의 비율 `s`가 전체 속도 향상을 제한한다.

```
Speedup(N) = 1 / ( s + (1 - s) / N )

s   = 직렬 부분 비율 (병렬화 불가)
1-s = 병렬 가능 부분
N   = 코어(스레드) 수

예) 직렬 부분 s = 5% (0.05), N → ∞
    Speedup 최대 = 1 / 0.05 = 20배 (코어 무한대여도!)
    즉, 5%의 순차 코드가 20배에서 천장을 만든다.

```

```mermaid
flowchart LR
    A["코어 1개Speedup 1×"] --> B["코어 8개s=5% → 5.9×"]
    B --> C["코어 32개s=5% → 12.5×"]
    C --> D["코어 ∞s=5% → 20× (천장)"]

    style D fill:#fef2f2,stroke:#dc2626
    style A fill:#dcfce7,stroke:#059669
```

*직렬 5%만 있어도 코어를 무한히 늘려도 20배가 한계 — 수확 체감*

> **🎯 면접 — "스레드 늘리면 빨라지죠?"는 함정**
>
> Amdahl's Law로 반박하라: ① 직렬 부분(락 구간·순차 I/O)이 천장을 만들고, ② 스레드가 코어 수를 넘으면 컨텍스트 스위칭·Lock Contention(락 경합)으로 오히려 느려진다. 진짜 최적화는 스레드 추가가 아니라 **직렬 구간 축소** (락 범위 최소화·샤딩·lock-free·불변 객체)다. 참고로 입력 크기를 함께 키우면 더 낙관적인 **Gustafson's Law** 가 적용된다.

## 7. 실패 흐름과 구현 경계

- `volatile`은 가시성과 순서 제약을 제공하지만 `count++` 같은 read-modify-write를 원자화하지 않는다. 복합 불변식은 lock·atomic compound operation·메시지 소유권 중 하나로 보호한다.
- CAS loop는 경합이 높을 때 재시도가 폭증할 수 있고 ABA를 해결하지 않으면 오래된 관찰을 새 값으로 오인할 수 있다. 버전 태그·불변 노드·검증 가능한 소유권을 사용한다.
- Java 21 virtual thread는 blocking I/O에 적합할 수 있지만 CPU를 추가하거나 DB·파일 디스크립터·다운스트림 한도를 없애지 않는다. `synchronized` 또는 native 구간에서 pinning이 생길 수 있으므로 JDK 버전별 문서와 JFR/스레드 관측으로 확인한다.
- 락 순서를 일관되게 정해도 외부 호출·DB lock·콜백을 임계 구역에 넣으면 지연·교착이 생길 수 있다. timeout, 취소, 재시도, 보상 동작을 함께 설계한다.
- Amdahl 계산은 병렬 구간이 독립이고 오버헤드가 없다는 가정이다. 실제로는 스케줄링·동기화·메모리 대역폭·불균형 작업·I/O가 speedup을 낮출 수 있으므로 4→16 코어 결과는 측정으로 검증한다.

## 8. 참고 자료

- [Java SE 21 JLS 17: Threads and Locks](https://docs.oracle.com/javase/specs/jls/se21/html/jls-17.html)
- [Java SE 21 AtomicLong](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/concurrent/atomic/AtomicLong.html)
- [Java SE 21 LongAdder](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/concurrent/atomic/LongAdder.html)
- [Java SE 21 Thread](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/Thread.html)
- [JEP 444: Virtual Threads](https://openjdk.org/jeps/444)

## Q&A 연습

아래 질문에 직접 답변을 작성하세요. 자동 저장되며 피드백 요청 시 복사할 수 있습니다.$review_23_cs_04_concurrency_theory$
WHERE slug = 'cs-04-concurrency-theory' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_cs_05_complexity$## 1. 빅오(Big-O) · 오메가 · 세타

점근 표기법(Asymptotic Notation)은 입력 n이 커질 때 성장률을 **상수·저차항을 무시하고** 표현한다.

| 표기 | 의미 | 경계 | 쓰임 |
| --- | --- | --- | --- |
| **O(f) — Big-O** | 상한(upper bound) | "아무리 나빠도 이 이하" | 최악 보장 — 가장 흔히 사용 |
| **Ω(f) — Big-Omega** | 하한(lower bound) | "아무리 좋아도 이 이상" | 최선의 한계, 문제의 하한 증명 |
| **Θ(f) — Big-Theta** | 상·하한 일치(tight) | "정확히 이 차수" | 정확한 성장률 표현 |

> **🎯 면접 — "O를 정확히 쓰는가"**
>
> 흔히 "이 알고리즘은 O(n)"이라 말하지만, 정확히는 **최악이 O(n)** 이라는 뜻이다. 평균·최악을 구분하라: Quick Sort는 평균 Θ(n log n), 최악 O(n²). 또 Big-O는 상한이라 "O(n²) 알고리즘이 O(n³)이기도 하다"는 형식적으로 참이지만, 면접에선 **가장 빡빡한(tight) 경계** 를 말해야 한다 → 사실상 Θ를 답하는 셈.

## 2. 증가율 위계 (Growth Hierarchy)

```
O(1) < O(log n) < O(√n) < O(n) < O(n log n) < O(n²) < O(2ⁿ) < O(n!)
상수    로그        제곱근    선형     선형로그       이차      지수      팩토리얼

n = 1,000,000 일 때 대략의 연산 수
O(1)        : 1
O(log n)    : ~20
O(n)        : 1,000,000
O(n log n)  : ~20,000,000
O(n²)       : 1,000,000,000,000   ← 실제 제한·구현에 따라 대개 부담
O(2ⁿ)       : 사실상 영원

```

```mermaid
flowchart LR
    A["O(1)HashMap 조회"] --> B["O(log n)이진탐색·B+Tree"]
    B --> C["O(n)순차 스캔"]
    C --> D["O(n log n)비교 정렬 한계"]
    D --> E["O(n²)중첩 루프"]
    E --> F["O(2ⁿ)완전탐색"]

    style A fill:#dcfce7,stroke:#059669
    style D fill:#fef3c7,stroke:#d97706
    style E fill:#fff7ed,stroke:#ea580c
    style F fill:#fef2f2,stroke:#dc2626
```

*실무 판단: n이 크면 O(n log n) 이하 후보를 먼저 보고, O(n²)·O(2ⁿ)는 입력 제한·가지치기·실측을 함께 검토한다.*

> **💡 면접 입력 크기 감 잡기**
>
> 제약(constraint)은 후보 알고리즘의 범위를 좁히는 힌트다. n ≤ 20에서 O(2ⁿ) 후보를 검토할 수 있고, n이 커질수록 O(n²)보다 O(n log n)·O(n)을 우선 검토한다. "1초에 고정된 연산 수" 같은 휴리스틱은 언어·자료구조·입력·실행 환경에 따라 크게 달라지므로 상한을 정한 뒤 실제 복잡도와 benchmark로 확인한다.

## 3. 시간 & 공간 복잡도 (Time & Space)

시간 복잡도만 보면 절반이다. **공간 복잡도** — 추가 메모리, 재귀 호출 스택, 보조 자료구조 — 도 함께 분석해야 한다. 둘 사이엔 흔히 **Trade-off**가 있다.

### Time-Space Trade-off 예시

| 기법 | 시간 | 공간 | 설명 |
| --- | --- | --- | --- |
| **Memoization** | ↓ (중복 계산 제거) | ↑ (캐시 저장) | Fibonacci O(2ⁿ)→O(n), 대신 O(n) 메모리 |
| **Hash Index** | ↓ 조회 O(1) | ↑ 해시 테이블 | DB 인덱스: 조회 빠르게, 저장공간·쓰기 비용 증가 |
| **In-place 정렬** | = | ↓ O(1) | Heap Sort: 메모리 아끼지만 캐시 비친화 |

### 재귀의 공간 복잡도 — 흔한 함정

```
// 재귀 깊이 = 공간 복잡도(호출 스택)
int sum(int n) {            // 공간 O(n) — 스택 프레임 n개 쌓임
    if (n == 0) return 0;
    return n + sum(n - 1);  // 꼬리 재귀지만 JVM은 TCO 미지원 → 스택 누적
}
// n이 크면 StackOverflowError → 반복문 O(1) 공간으로 변환 필요

```

> **⚠️ 함정 — "시간만 보고 공간을 잊는다"**
>
> 재귀 DFS/분할정복은 시간이 O(n log n)이어도 호출 스택이 O(깊이)를 먹는다. 대규모 입력에서 OOM·StackOverflow의 원인. 면접에서 복잡도를 답할 때 **시간과 공간을 항상 쌍으로** 말하면 시니어 인상을 준다.

## 4. 분할상환 분석 (Amortized Analysis)

개별 연산은 가끔 비싸지만, **연산 시퀀스 전체로 평균을 내면** 싼 경우가 있다. 최악 한 번이 아니라 "긴 호출열의 평균 비용"을 본다 — 평균(average)과는 다른 개념(확률 가정 없음).

```mermaid
flowchart LR
    A["append 여러 번각 O(1)"] --> B["용량 초과 시 확장→ O(n) 복사 가능"]
    B --> C["이후 append다시 O(1)"]
    C --> D["전체 n번 평균= amortized O(1)"]

    style B fill:#fef2f2,stroke:#dc2626
    style D fill:#dcfce7,stroke:#059669
```

*Dynamic Array — 가끔 O(n) 복사가 일어나지만, 전체로 평균 내면 분할상환 O(1)*

| 연산 | 최악(단일) | 분할상환 | 이유 |
| --- | --- | --- | --- |
| Dynamic Array `append` | O(n) | O(1) | 2배 확장: 복사 비용이 다음 n번에 분산 |
| HashMap `put` | O(n) | O(1) | Rehashing 비용이 전체에 분산 |
| Union-Find `find` | O(log n) | ~O(α(n)) | 경로 압축 + rank → 거의 상수 |

> **🎯 면접 — "ArrayList add는 O(1)인가?"**
>
> 정확한 답: **분할상환(amortized) O(1)** 이고, 리사이징이 걸리는 그 순간은 O(n)이다. 그래서 크기를 알면 `new ArrayList<>(capacity)` 로 미리 잡아 복사를 없앤다. "amortized"라는 단어를 정확히 쓰면 깊이를 증명한다.

## 5. DP / 그리디 / 분할정복 복잡도

| 패러다임 | 핵심 | 복잡도 분석법 | 대표 예 (복잡도) |
| --- | --- | --- | --- |
| **분할정복(Divide & Conquer)** | 쪼개서 풀고 합침 | 마스터 정리(점화식) | Merge Sort T(n)=2T(n/2)+O(n)=O(n log n) |
| **동적계획법(DP)** | 부분문제 + 메모이제이션 | 상태 수 × 전이 비용 | 0/1 Knapsack O(nW), LCS O(nm) |
| **그리디(Greedy)** | 매 단계 국소 최적 선택 | 정렬 + 선형 스캔이 흔함 | 활동 선택 O(n log n), Dijkstra는 조건 충족 시 O(E log V) |
| **백트래킹(Backtracking)** | 탐색 + 가지치기 | 분기 × 깊이(지수적, 가지치기로 완화) | N-Queens O(n!), 부분집합 O(2ⁿ) |

### 마스터 정리 (Master Theorem) 직관

```
T(n) = a·T(n/b) + O(n^d)   (a≥1, b>1)

비교 d vs log_b(a):
  d > log_b(a)  →  T(n) = O(n^d)           (분할 비용이 지배)
  d = log_b(a)  →  T(n) = O(n^d · log n)    (균형)  ← Merge Sort: a=2,b=2,d=1
  d < log_b(a)  →  T(n) = O(n^(log_b a))    (재귀가 지배)

```

> **💡 DP vs 그리디 — 언제 그리디가 맞나**
>
> 그리디는 **탐욕적 선택 속성**과 **최적 부분 구조**가 증명될 때만 정답을 보장한다. Dijkstra는 음수 가중치가 없다는 조건이 필요하고 MST도 문제 정의·간선 비교 조건을 확인한다. 증명 없이 그리디를 쓰면 반례에 깨진다 — 동전 거스름돈이 대표적이다. 면접에서 그리디를 제안하면 **왜 국소 최적이 전역 최적인지** 한 줄 근거를 붙여라.

## 6. 자료구조 연산 복잡도표 (Cheat Sheet)

면접에서 즉답해야 하는 핵심 표. 평균 / 최악을 구분해서 외우되, **왜**를 함께 기억하라.

| 자료구조 | 접근 | 탐색 | 삽입 | 삭제 | 공간 | 비고 |
| --- | --- | --- | --- | --- | --- | --- |
| **Array** | O(1) | O(n) | O(n) | O(n) | O(n) | 인덱스 즉시, 중간 삽입 시 이동 |
| **Dynamic Array** | O(1) | O(n) | O(1)† | O(n) | O(n) | † amortized, 끝 삽입 |
| **Linked List** | O(n) | O(n) | O(1)* | O(1)* | O(n) | * 위치 알 때 |
| **Stack / Queue** | O(n) | O(n) | O(1) | O(1) | O(n) | 끝/앞 전용 접근 |
| **HashMap** | — | O(1) / O(n)‡ | O(1) / O(n)‡ | O(1) / O(n)‡ | O(n) | ‡ 평균 / 최악(충돌·리사이즈) |
| **TreeMap (R-B)** | — | O(log n) | O(log n) | O(log n) | O(n) | 정렬·Range 보장 |
| **Heap (PQ)** | O(1) peek | O(n) | O(log n) | O(log n) | O(n) | min/max 특화 |
| **Trie** | — | O(L) | O(L) | O(L) | O(Σ·N) | L=키 길이, 접두사 검색 |
| **B+Tree** | — | O(log n) | O(log n) | O(log n) | O(n) | 디스크 친화, DB 인덱스 |
| **Union-Find** | — | O(α(n)) | O(α(n)) | — | O(n) | 경로압축+rank, 사실상 상수 |

> **🎯 면접 — 표를 외우지 말고 "왜"로 재구성하라**
>
> Array 접근이 O(1)인 이유는 **연속 메모리 + 주소 산술** 이고, LinkedList 탐색이 O(n)인 이유는 **포인터 추적** 이다. TreeMap이 O(log n)인 이유는 **균형 트리 높이** , B+Tree가 같은 O(log n)이어도 DB에 쓰이는 이유는 **높은 fan-out으로 디스크 I/O 횟수가 적기** 때문. 원리를 알면 표는 저절로 복원된다.

## Q&A 연습

아래 질문에 직접 답변을 작성하세요. 자동 저장되며 피드백 요청 시 복사할 수 있습니다.

```text
n=1,000,000일 때 대략적인 연산 규모
O(log n)  ≈ 20
O(n)      = 1,000,000
O(n log n)≈ 20,000,000
O(n²)     = 1,000,000,000,000 (기계·구현에 따라 실제 가능 여부가 달라짐)
```

## 7. 실패 흐름과 분석 경계

- Big-O만 같아도 상수·메모리 접근·캐시·I/O·할당량이 다르면 실제 성능 순서가 달라질 수 있다. 입력 분포와 측정 구간을 함께 기록한다.
- Memoization은 상태 키가 잘못되거나 캐시가 무한히 커지면 정확성과 메모리를 잃는다. 상태 정의·기저 조건·eviction 필요성을 먼저 검증한다.
- DP의 O(상태 수 × 전이 수)는 상태 중복 제거가 정확할 때만 성립한다. 숨은 차원·큰 정수 overflow·불가능 상태의 sentinel 충돌을 점검한다.
- 분할상환 O(1)은 호출열 전체의 비용 분석이지 모든 단일 호출이 O(1)이라는 뜻이 아니다. 용량 확장 정책과 메모리 복사·GC 영향을 포함해 측정한다.
- 그리디·Dijkstra·Union-Find의 복잡도는 자료구조와 조건에 의존한다. 음수 간선, rank/경로 압축 유무, 힙 구현을 명시하지 않고 숫자만 제시하지 않는다.

## 8. 참고 자료

- [Java SE 21 ArrayList](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/ArrayList.html)
- [Java SE 21 HashMap](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/HashMap.html)
- [Java SE 21 Arrays](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Arrays.html)
- [Java SE 21 StackOverflowError](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/StackOverflowError.html)
- [CLRS 4th edition](https://mitpress.mit.edu/9780262046305/introduction-to-algorithms/)$review_23_cs_05_complexity$
WHERE slug = 'cs-05-complexity' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_cs_06_interview_fundamentals$## 1. 이 라운드의 규칙 — 15~20분, 꼬리 질문으로 깊이를 잰다

CS 면접 라운드는 지식의 **넓이**가 아니라 **깊이**를 잰다. 면접관은 누구나 아는 단골 질문("URL 치면?", "프로세스 vs 스레드?")을 던진 뒤, 답변의 **가장 얕은 지점을 파고드는 꼬리 질문**으로 컷라인을 그린다. 6년차에게 표준 답변은 통과 기준이 아니라 시작점일 뿐이다.

```mermaid
flowchart TD
    Q0["단골 질문(넓이 확인)"] --> A0["표준 답변— 여기까진 누구나"]
    A0 --> Q1["꼬리 1— 왜 그렇게 설계됐나?"]
    Q1 -->|막힘| Junior["🟡 주니어 컷용어는 알지만원리 설명 불가"]
    Q1 -->|통과| Q2["꼬리 2— 실무에서 어떻게 터지나?"]
    Q2 -->|막힘| Middle["🟢 미들동작은 알지만장애 경험 부족"]
    Q2 -->|통과| Q3["꼬리 3— 대안과 Trade-off는?"]
    Q3 -->|통과| Senior["🔵 시니어정량 근거 + 실무 상흔+ 대안 비교"]

    style Junior fill:#fef3c7,stroke:#d97706
    style Middle fill:#dcfce7,stroke:#059669
    style Senior fill:#dbeafe,stroke:#2563eb
```

*이 카드는 개념 나열이 아니라, 실제로 이어지는 꼬리 질문 체인을 그대로 재현한다.*

> **🎯 면접 포인트**
>
> 꼬리 질문의 목적은 "당신이 이 지식을 **암기했는지 vs 이해했는지**"를 가르는 것이다. 표준 답변까지는 만점이 아니라 0점 방어일 뿐이다. 매 답변 끝에 "왜 이렇게 설계됐는지"를 한 문장 덧붙이는 습관이 컷라인을 넘긴다.

---

## 2. 네트워크 체인 — "브라우저에 URL 치면?"

가장 유명한 질문. 표준 답변(DNS→TCP→TLS→HTTP)은 **통과가 아니라 입장권**이다. 진짜 평가는 그 다음 4개의 꼬리에서 갈린다.

```mermaid
sequenceDiagram
    participant B as 브라우저
    participant R as DNS Resolver
    participant S as 서버
    B->>R: coupang.com A? (캐시 미스 시 재귀 질의)
    R-->>B: 1.2.3.4 (TTL)
    Note over B,S: TCP 3-way (1 RTT)
    B->>S: SYN
    S->>B: SYN-ACK
    B->>S: ACK
    Note over B,S: TLS 1.3 (1 RTT)
    B->>S: ClientHello + key_share
    S->>B: ServerHello + Cert + Finished
    B->>S: Finished
    Note over B,S: HTTP 요청 (1 RTT)
    B->>S: GET / (HTTP/2 스트림 다중화)
    S->>B: 200 OK
```

*첫 화면의 왕복 수는 DNS 캐시·TCP/TLS 버전·연결 재사용·HTTP 응답 구조에 따라 달라진다. RTT 숫자는 문제에서 주어진 가정으로 계산하고 실제 경로는 도구로 측정한다.*

**꼬리 질문 체인:**

1. **꼬리 1 — "DNS는 캐시 미스면 몇 번을 왕복하죠?"**
   Root→TLD(.com)→Authoritative 3단계 재귀. 그래서 첫 접속이 느리다. TTL 캐싱으로 두 번째부터 즉답. `dig +trace`로 경로를 직접 본 적 있다고 답하면 강하다.
   → *여기서 "그냥 IP 받아와요"만 답하면 주니어.*

2. **꼬리 2 — "HTTP/2로 멀티플렉싱했는데도 느릴 수 있는 이유는?"**
   **TCP 레벨 HOL Blocking(Head-of-Line Blocking, 대기열 선두 막힘)**. HTTP/2는 한 TCP 연결에 여러 스트림을 다중화하지만, 그 아래 TCP는 **바이트 스트림 하나**다. 패킷 하나가 유실되면 TCP는 순서 보장을 위해 뒤따르는 모든 스트림의 데이터를 커널 버퍼에 붙잡아 둔다. 앱 레벨 HOL은 풀었지만 전송 레벨 HOL이 남는다.
   → *여기서 "HTTP/2면 다 해결됐죠"라 답하면 미들 컷.*

3. **꼬리 3 — "그럼 HTTP/3는 그걸 어떻게 풀죠?"**
   **QUIC(UDP 기반)**은 스트림별 전송을 분리해 한 스트림의 손실이 다른 스트림의 전달을 같은 방식으로 막지 않게 한다. TLS 1.3을 사용하며, full handshake·재개·HelloRetryRequest에 따라 왕복 수가 달라진다. 0-RTT early data는 replay 가능한 요청을 구분해야 하고, Connection Migration도 경로·서버 정책에 따라 검증한다.

4. **꼬리 4 — "백엔드 서버 간 통신에선 이게 어떻게 연결되죠?"**
   서버↔서버는 매 요청마다 3-way + TLS를 다시 하면 RTT 낭비 + `TIME_WAIT` 소켓 폭증. 그래서 **Keep-Alive 커넥션 풀**로 연결을 재사용한다. HikariCP·Netty·gRPC 채널이 모두 이 원리. keep-alive idle timeout과 서버의 timeout을 맞추지 않으면 "서버가 이미 닫은 소켓을 풀이 재사용 → `Connection reset`" 장애가 난다.

> **⚠️ 실무 함정**
>
> "TCP는 신뢰성 있으니 데이터 손실 없다"는 반쪽 진실이다. TCP가 보장하는 건 **세그먼트 전달**이지 애플리케이션 처리가 아니다. 서버가 ACK를 보낸 뒤 크래시하면 데이터는 유실된다. 그래서 결제·주문은 반드시 **애플리케이션 레벨 ACK + 멱등키(Idempotency-Key)**로 별도 보장한다. 이 구분을 못 하면 시니어 라운드에서 바로 걸린다.

> **💡 팁**
>
> RTT는 문제에서 주어진 가정으로 계산하고, TLS 재개·HTTP 연결 재사용·서버 처리 시간을 분리해 말한다. 관찰 도구도 함께 제시한다: `tcpdump -i any port 443`, `ss -ti`(RTT·cwnd 확인), `curl -w '%{time_connect} %{time_appconnect}'`.

---

## 3. OS 체인 — "프로세스 vs 스레드"

표준 답변(주소 공간 공유 여부)은 교과서다. 꼬리는 **비용**과 **한계**로 파고든다.

```mermaid
flowchart LR
    Q["프로세스 vs 스레드?"] --> A["스레드는 Heap·Code 공유Stack·레지스터만 독립"]
    A --> T1["꼬리: 스위칭 비용 차이는?"]
    T1 --> B["주소 공간·실행 상태 전환 비용은 CPU·커널·워크로드에 의존"]
    B --> T2["꼬리: 스레드 1만 개 만들면?"]
    T2 --> C["스택 예약·실제 사용량·runnable 수·컨텍스트 전환 측정"]
    C --> T3["꼬리: 그럼 어떻게 풀지?"]
    T3 --> D["이벤트 루프 / 가상 스레드"]

    style C fill:#fef2f2,stroke:#dc2626
    style D fill:#dcfce7,stroke:#059669
```

**꼬리 질문 체인:**

1. **꼬리 1 — "컨텍스트 스위칭 비용이 왜 다르죠?"**
   프로세스 전환에는 주소 공간 전환이 추가될 수 있지만, 모든 TLB 항목이 항상 비워지거나 이후 접근이 모두 miss가 되는 것은 아니다. 스레드 전환도 레지스터·스케줄링 상태와 캐시 영향이 있어 비용을 0으로 볼 수 없다. CPU 기능, 커널, 실행·대기 패턴에 따라 차이가 달라지므로 고정된 마이크로초 수치를 외우기보다 실제 워크로드에서 측정한다.
   → *"스레드가 더 싸요"만 답하고 이유를 못 대면 주니어.*

2. **꼬리 2 — "스레드 1만 개 만들면 어떻게 되죠?"**
   ① **메모리**: 플랫폼 스레드마다 스택 예약과 네이티브 자원이 필요하다. 스택 예약 크기와 실제 committed/RSS는 JVM·OS·옵션에 따라 다르므로 고정된 1MiB로 계산하지 않는다. ② **스케줄링**: 많은 runnable 스레드는 경합과 전환 비용을 키울 수 있지만 대부분 I/O 대기라면 양상이 다르다. 실제 스택 크기·RSS·runnable 수·전환 횟수·처리량을 측정한다.
   → *숫자를 쓸 때는 가정과 예약·실사용의 차이를 함께 밝힌다.*

3. **꼬리 3 — "그럼 동시 접속 10만을 어떻게 처리하죠?"**
   두 갈래. ① **이벤트 루프(Reactor 패턴)**: 소수 스레드가 준비된 소켓 이벤트를 다중화한다. ② **가상 스레드(JDK 21)**: I/O 대기가 많은 코드를 스레드별로 작성하되 대기 중 캐리어를 다른 작업에 쓸 수 있게 한다. 둘 다 연결 수만으로 처리량이 보장되지는 않으며, CPU·메모리·파일 디스크립터·다운스트림 한도가 남는다.

4. **꼬리 4 — "이벤트 루프와 가상 스레드, 뭘 언제 쓰죠?"**
   이벤트 루프는 적은 스레드로 준비된 I/O를 다중화하지만 콜백에서 블로킹하면 해당 loop의 진행을 막는다. 가상 스레드는 명령형 blocking 코드의 동시성을 높일 수 있지만 CPU·메모리·파일 디스크립터·다운스트림 한도를 없애지 않는다. JDK 21에서는 `synchronized` 또는 native 구간의 pinning 가능성을 문서와 관측으로 확인하고, 다른 JDK 버전의 동작을 JDK 21과 동일하다고 가정하지 않는다.

> **⚠️ 실무 함정**
>
> "멀티스레드면 빨라진다"는 Amdahl's Law를 무시한 오해다. 직렬 구간 비율이 5%라는 가정에서는 이상적인 최대 speedup이 20배지만, 실제로는 Lock 경합·메모리 대역폭·스케줄링·I/O가 더 낮춘다. `ThreadPoolExecutor` 크기 공식은 출발점일 뿐이며 CPU-bound·I/O-bound를 구분해 queue, downstream concurrency, latency, CPU pressure로 튜닝한다.

```java
// I/O 대기가 연산의 9배라는 가정의 출발점 예시
// poolSize ≈ cores × (1 + wait/compute) 이후 부하 측정으로 조정
int cores = Runtime.getRuntime().availableProcessors(); // 8
double waitRatio = 9.0; // (대기시간 / 연산시간)
int poolSize = (int) (cores * (1 + waitRatio)); // 예: 80, 실제 값은 측정으로 결정
// 하지만 가상 스레드라면 이 계산 자체가 불필요 —
// executor = Executors.newVirtualThreadPerTaskExecutor();
```

> **💡 팁**
>
> "스레드 몇 개가 적정?"에 공식만 읊지 말고 "실측해서 튜닝한다"를 덧붙여라. `pidstat -w`로 자발적/비자발적 스위치를 구분하고, 비자발적이 많으면 CPU 과부하 신호라 스레드를 **줄인다**고 답하면 운영 경험이 드러난다.

---

## 4. 자료구조 체인 — "HashMap은 어떻게 동작하죠?"

가장 흔한 자료구조 질문. 표준 답변(해시 함수 → 버킷 → 충돌 시 체이닝)은 기본기. 꼬리는 **최악 복잡도**와 **동시성**으로 간다.

```mermaid
flowchart TD
    Q["HashMap put/get은 O(1)?"] --> A["평균 O(1)해시 → 버킷 인덱스"]
    A --> T1["꼬리: 충돌하면?"]
    T1 --> B["체이닝: 같은 버킷에 리스트최악 O(n)"]
    B --> T2["꼬리: 그래서 JDK 8이 바꾼 건?"]
    T2 --> C["버킷당 8개 초과 시Red-Black Tree로 → 최악 O(log n)"]
    C --> T3["꼬리: resize 중 동시 put하면?"]
    T3 --> D["JDK 7: 무한 루프JDK 8: 유실 가능"]
    D --> T4["꼬리: ConcurrentHashMap은?"]
    T4 --> E["bin 단위 synchronized + CAS전체 락 아님"]

    style B fill:#fef3c7,stroke:#d97706
    style D fill:#fef2f2,stroke:#dc2626
    style E fill:#dcfce7,stroke:#059669
```

**꼬리 질문 체인:**

1. **꼬리 1 — "그럼 HashMap은 O(1)이 보장되나요?"**
   아니다. **평균 O(1), 최악 O(n)**이라는 설명은 키 분포와 구현을 전제로 한다. 충돌이 많거나 resize가 반복되면 지연이 커질 수 있다. JDK 8 이후 OpenJDK `HashMap`의 tree bin 임계값·용량 조건은 구현 세부사항이므로 Java 21 문서와 실제 JDK를 확인하고 다른 언어·버전에 일반화하지 않는다.
   → *"O(1)이요"만 답하고 최악을 못 대면 주니어.*

2. **꼬리 2 — "resize는 정확히 언제, 무슨 일이 일어나죠?"**
   threshold를 넘으면 구현이 용량과 버킷 배치를 바꾸고 엔트리를 재배치할 수 있다. 이때 **O(n) 수준의 순간 비용**이 생길 수 있다. 크기를 알면 Java 문서의 capacity·load factor 의미를 확인해 초기 용량을 정하되, 메모리 예약과 실제 키 분포를 함께 측정한다.

3. **꼬리 3 — "resize 도중 다른 스레드가 put하면요?"**
   여기가 진짜 컷라인. JDK 7 계열의 역사적 OpenJDK 구현에서는 동시 resize에서 순환 링크 사례가 보고됐고, 이후 구현은 이를 바꾸었지만 `HashMap`이 thread-safe가 된 것은 아니다. 현재 JDK에서도 동시 put·resize는 데이터 유실·관찰 불일치·예외를 만들 수 있으므로 버전별 내부 구현을 일반 API 계약처럼 외우지 말고 동기화된 자료구조를 사용한다.
   → *"동시성 문제 나요"라고만 하지 말고, 역사적 구현 차이와 현재 API의 thread-safety 경계를 구분한다.*

4. **꼬리 4 — "그래서 ConcurrentHashMap은 어떻게 안전하죠?"**
   **JDK 7 계열 구현**은 Segment 기반 구조를 사용했지만 segment 수와 동작은 구현 세부사항이다. **JDK 8 이후 OpenJDK 구현**은 bin 헤드 동기화와 CAS를 활용하는 구조로 바뀌었지만, API 계약은 내부 락 방식·경합·처리량을 보장하지 않는다. Java 21 문서와 소스, workload 측정으로 `get`·update·resize 특성을 확인한다.

> **⚠️ 실무 함정**
>
> "동시성 필요하면 HashMap을 `Collections.synchronizedMap`으로 감싸면 되죠"는 반쪽이다. 그건 **모든 연산을 단일 락**으로 직렬화해 경합이 심하면 ConcurrentHashMap보다 훨씬 느리다. 또 iteration 중에는 여전히 수동 동기화가 필요하다. 읽기가 많은 워크로드는 ConcurrentHashMap이 정답.

> **💡 팁**
>
> 해시 관련 질문엔 "쓰기/읽기 비율, 키 분포, 크기 예측 가능 여부"를 되물어라. "읽기 위주면 ConcurrentHashMap, 불변이면 `Map.of`, 순서 필요하면 LinkedHashMap"처럼 상황별로 자료구조를 고르는 사고가 시니어의 자료구조 감각이다.

---

## 5. 좋은 답변 vs 나쁜 답변

| 질문 | 🔴 나쁜 답변 (컷) | 🟢 좋은 답변 (통과) |
| --- | --- | --- |
| HTTP/2인데 왜 느리죠? | "HTTP/2면 다 해결됐는데요?" | "앱 레벨 HOL은 풀었지만 TCP는 바이트 스트림 하나라 패킷 유실 시 전 스트림이 대기. HTTP/3의 QUIC이 스트림 독립으로 해결." |
| 스레드 1만 개는? | "좀 느려질 것 같아요" | "플랫폼 스레드의 스택 예약·runnable 경합·파일 디스크립터·다운스트림 한도를 측정하고, 이벤트 루프나 가상 스레드를 조건에 맞게 비교." |
| HashMap은 O(1)? | "네, O(1)입니다" | "평균 O(1), 최악 O(n). JDK 8은 버킷 8개 초과 시 트리화로 O(log n) 방어." |
| resize 중 동시 put? | "동시성 문제 나요" | "JDK 7/8의 역사적 구현 차이를 구분하되 현재 JDK의 HashMap은 thread-safe가 아니므로 ConcurrentHashMap의 API 계약·구현을 확인." |
| TCP는 신뢰성 있죠? | "네, 손실 없어요" | "세그먼트 전달은 보장하지만 앱 처리는 별개. ACK 후 크래시 시 유실 → 멱등키로 앱 레벨 보장." |

> **🎯 면접 포인트**
>
> 나쁜 답변의 공통점은 "결론만 있고 메커니즘이 없다"는 것. 좋은 답변의 공통점은 "**한계 → 원인 → 대안**"의 3박자를 담는다. 면접관은 결론이 아니라 그 사이의 사고 과정을 듣고 싶어 한다.

---

## 6. 평가 루브릭 — 나는 어디쯤인가

| 축 | 🟡 주니어 (컷) | 🟢 미들 (통과) | 🔵 시니어 (합격 우위) |
| --- | --- | --- | --- |
| **정확성** | 용어는 알지만 원리 설명 불가 | 표준 동작을 정확히 서술 | 최악/평균 복잡도, 버전별 차이까지 |
| **정량 근거** | 숫자 없음("빠르다/느리다") | 대략적 비용 인지 | RTT·µs·MB 단위로 근거 제시 |
| **실무 연결** | 교과서 지식에 머묾 | 프레임워크 사용 경험 | 실제 장애·튜닝·관찰 도구 경험 |
| **대안 비교** | 하나의 답만 암기 | 대안 존재는 인지 | Trade-off를 조건부로 제시 |
| **꼬리 대응** | 2번째 꼬리에서 막힘 | 3번째까지 버팀 | 4번째 대안·한계까지 파고듦 |

**셀프 진단 기준:**

- 각 체인에서 **꼬리 2까지** 막힘없이 답하면 미들 통과선.
- **꼬리 4(대안·한계)**까지 정량 근거를 대며 답하면 시니어.
- 관찰 도구(`tcpdump`·`ss`·`vmstat`·`pidstat`·`jstack`)를 실제로 써본 경험을 자연스럽게 섞으면 결정적 우위.

> **⚠️ 실무 함정**
>
> 루브릭에서 6년차가 가장 많이 걸리는 지점은 "정량 근거" 축이다. 동작 원리는 알지만 "그래서 몇 µs? 몇 RTT? 몇 MB?"에서 침묵하면 미들에 갇힌다. 평소 성능 튜닝할 때 숫자를 손에 익혀두는 것이 유일한 대비책이다.

> **💡 팁**
>
> 막혔을 때 침묵보다 "정확히는 기억 안 나지만, 방향은 이럴 것 같습니다 — ...이니까요"라고 추론 과정을 소리 내는 편이 낫다. 면접관은 정답 여부만큼 **사고 방식**을 평가한다. 단, 확실한 것과 추측을 명확히 구분해서 말하라.

---

## Q&A 연습

위 세 체인(네트워크 HOL, 스레드 1만 개, HashMap resize)을 실제 면접처럼 소리 내어 답해보세요. 각 체인의 꼬리 4까지 정량 근거를 붙여 답할 수 있으면 시니어 라운드 대비가 된 것입니다. 아래 질문에 직접 답변을 작성하면 자동 저장됩니다.

## 7. 버전·환경에 따른 실패 경계

- HTTP/2·HTTP/3의 왕복 수와 HOL 동작은 연결 재사용·손실·0-RTT 요청 종류·경로에 따라 달라진다. 문제의 RTT를 실제 네트워크 성능으로 일반화하지 않는다.
- Linux의 스케줄러·TCP·cgroup 동작은 커널 버전·설정·컨테이너 런타임에 의존한다. `CFS`, `EEVDF`, congestion control을 모든 Linux 환경의 동일한 기본값으로 말하지 않는다.
- 플랫폼 스레드와 virtual thread는 같은 방식으로 자원을 쓰지 않는다. JDK 21의 pinning·스택·scheduler 설명을 현재 JDK의 변경사항과 섞지 않고, 파일 디스크립터·DB pool·메모리·CPU pressure를 함께 측정한다.
- JDK HashMap의 resize·tree bin·ConcurrentHashMap 내부 구조는 구현 세부사항이다. 현재 API의 thread-safety 계약과 역사적 OpenJDK 구현의 장애 사례를 구분하고, 내부 구조를 근거로 성능을 보장하지 않는다.
- 면접 수치는 가정일 때만 계산한다. 실제 장애의 원인은 `ss`, `tcpdump`, `jstack`, JFR, `vmstat`, `/proc`, 메트릭과 trace를 조합해 확인하고, 재시작·강제 GC·무지성 scale-out으로 증거를 먼저 지우지 않는다.

## 8. 참고 자료

- [RFC 9114 — HTTP/3](https://www.rfc-editor.org/rfc/rfc9114.html)
- [RFC 9000 — QUIC](https://www.rfc-editor.org/rfc/rfc9000.html)
- [RFC 8446 — TLS 1.3](https://www.rfc-editor.org/rfc/rfc8446.html)
- [Java SE 21 Thread](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/Thread.html)
- [JEP 444: Virtual Threads](https://openjdk.org/jeps/444)
- [Java SE 21 HashMap](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/HashMap.html)
- [Java SE 21 ConcurrentHashMap](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/concurrent/ConcurrentHashMap.html)
- [Linux kernel EEVDF Scheduler](https://docs.kernel.org/scheduler/sched-eevdf.html)
- [Linux kernel TCP sysctl](https://docs.kernel.org/networking/ip-sysctl.html)$review_23_cs_06_interview_fundamentals$
WHERE slug = 'cs-06-interview-fundamentals' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_cs_09_os_network_interview$## 1. DNS에서 Handler까지: 프로토콜과 구현 경계를 구분한다

먼저 대상 이름을 주소로 해석한다. 연결이 새로 필요하다면 전송 계층을 수립하고 TLS로 서버 신원을 검증한 뒤 HTTP 요청을 보낸다. 단, HTTPS가 반드시 TCP인 것은 아니다. HTTP/3은 QUIC을 사용하므로 면접에서는 **HTTP 버전과 연결 재사용 여부를 먼저 가정**한다. 프록시·로드밸런서가 있다면 각 홉의 연결과 대기열도 별도로 센다.

서버 측에서는 네트워크 스택이 패킷을 처리하고 소켓에 읽을 데이터를 전달한다. 애플리케이션의 이벤트 루프 또는 워커가 준비된 연결을 읽고, 요청을 파싱·라우팅해 Handler를 실행한다. `read`가 항상 디스크 읽기인 것은 아니다. 소켓 수신, 애플리케이션의 파일 읽기, DB 요청은 서로 다른 경계이며 각각 대기 원인이 다르다. 아래는 **새 TCP 연결을 쓰는 HTTP/1.1·2의 예시 경로**다.

```text
DNS → TCP 연결 → TLS → HTTP 요청 → 프록시/서버 소켓
    → 이벤트 루프 또는 워커 → 라우팅 → Handler → DB/파일/외부 API
```

첫 질문의 답에서는 `DNS`, `connect`, `TLS`, `TTFB`, Handler, 다운스트림 시간을 분리해 측정하겠다고 말한다. 여러 단계를 합친 총 응답 시간만으로는 어느 대기열이 병목인지 알 수 없다.

```mermaid
flowchart LR
    A[이름 해석·기존 연결 확인] --> B{새 연결과 HTTP 버전}
    B -->|HTTP/1.1·2| C[TCP 연결과 TLS]
    B -->|HTTP/3| D[QUIC 연결과 TLS]
    B -->|연결 재사용| E[HTTP 요청]
    C --> E
    D --> E
    E --> F[프록시·서버 소켓]
    F --> G[이벤트 루프·워커]
    G --> H[Handler·다운스트림]
```

## 2. 낮은 CPU와 긴 지연을 함께 해석한다

CPU 평균이 낮아도 한 코어만 포화됐거나, 태스크가 I/O·락·외부 응답을 기다릴 수 있다. 아래 지표는 원인을 **확정하는 값이 아니라 다음 조사를 고르는 증거**다.

| 관찰 | 추가로 확인할 증거 | 다음 판단 |
|---|---|---|
| CPU 낮음·지연 증가 | 코어별 사용률, runnable 태스크, CPU pressure | 실행할 준비가 된 작업이 밀리는가 |
| I/O 지연 증가 | `iowait`, I/O pressure, 디스크/파일시스템 지연, blocked 태스크 | CPU 집계와 요청별 대기를 구분했는가 |
| 락 대기 의심 | 스레드 덤프, 락 대기 시간, 임계 구역 | 특정 락에 요청이 직렬화되는가 |
| 서버 수치 정상 | DNS·연결·TLS·다운스트림 분포 | 측정하지 않은 경계에서 기다리는가 |

Linux PSI는 CPU·메모리·I/O 자원 부족으로 태스크가 지연된 시간을 보여준다. `/proc/stat`의 `iowait`는 CPU 시간 집계값이며 특정 요청이 I/O를 기다린 시간을 직접 나타내지 않는다. 멀티코어와 태스크 이동 때문에 이 값 하나로 병목을 확정하기도 어렵다. `procs_blocked`, I/O PSI, 블록 장치·파일시스템 지연과 요청 추적을 함께 본다. `load average`나 컨텍스트 스위치 수 하나만 보고 원인을 단정하지 않는다. 요청 ID로 구간별 p95/p99를 연결하고, 같은 시간대의 호스트 지표와 스레드 상태를 대조한다. 예를 들어 Handler CPU 시간은 5ms인데 전체 900ms이고 DB 연결 풀 대기가 700ms라면, CPU 최적화보다 풀·DB 병목부터 조사한다. 이 숫자는 진단 설명을 위한 가상 사례다.

## 3. Page Cache를 통제한 파일 읽기 실험

Linux의 일반 파일 읽기는 Page Cache의 영향을 받는다. 첫 읽기가 스토리지에서 데이터를 가져온 뒤 같은 파일의 반복 읽기가 캐시에서 처리되면, 후속 측정은 저장 장치 성능이 아니라 캐시·메모리 복사 비용을 주로 보여줄 수 있다. 반대로 다른 프로세스의 읽기나 메모리 압박이 캐시 상태를 바꾸면 결과가 흔들린다.

파일 크기, 읽기 패턴·블록 크기, 동시성, 파일시스템, 캐시 상태를 기록한다. 워밍업 전후 결과를 분리하고 반복 측정한다. 운영 서버의 전체 캐시를 비우는 방식은 다른 작업에 영향을 주므로 격리된 환경에서만 실험 조건으로 검토한다. `direct I/O`도 정렬 제약과 애플리케이션 동작 차이가 있으므로 일반 읽기와 같은 실험으로 취급하지 않는다.

> **답변 점검** — 세 질문 모두 경로·관측값·반례·다음 실험을 이어서 설명한다. 프로토콜 버전이나 캐시 상태 같은 가정을 먼저 밝히면 구현 세부 차이에도 답이 유지된다.

### 근거 자료

- [RFC 9110 — HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110.html): HTTPS URI, 요청·응답 의미와 전송 독립성.
- [RFC 9114 — HTTP/3](https://www.rfc-editor.org/rfc/rfc9114.html): QUIC 기반 HTTP/3.
- [Linux Kernel — Pressure Stall Information](https://docs.kernel.org/accounting/psi.html): CPU·메모리·I/O 대기 지표.
- [Linux Kernel — procfs](https://docs.kernel.org/filesystems/proc.html): `/proc/stat`의 `iowait` 해석 주의.
- [Linux Kernel — Block layer statistics](https://docs.kernel.org/block/stat.html): 장치 I/O 계측.
- [Linux Kernel — Page Cache](https://docs.kernel.org/mm/page_cache.html): 파일 읽기와 페이지 캐시의 관계.$review_23_cs_09_os_network_interview$
WHERE slug = 'cs-09-os-network-interview' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_cs_11_data_structures_interview$## 1. Hash Table의 O(1)에는 분포와 재배치 비용이 숨어 있다

해시 조회의 평균 상수 시간은 키가 버킷에 고르게 퍼지고 부하율을 적절히 관리한다는 가정 위에 있다. 다른 키가 같은 버킷으로 몰리면 충돌 처리에 추가 비교가 필요하다. 특정 언어·구현의 트리화 같은 방어 장치가 있을 수 있지만 모든 Hash Table에 일반화할 수 없다. 면접에서는 **키 분포, 해시 함수, 동등성 비교 비용, 구현체**를 먼저 묻는다.

항목이 늘면 버킷 배열을 확장하며 기존 항목을 재배치한다. 일반 연산의 분할 상환 비용이 낮아도 확장이 일어나는 단일 삽입은 오래 걸릴 수 있다. 고정된 p99 지연이 중요한 서비스라면 초기 용량, 예상 최대 크기, 메모리 사용량을 함께 검토한다. 순서 조회나 범위 검색이 핵심이면 해시보다 트리·정렬 배열이 적합할 수도 있다.

```text
입력: 키 1만 개의 hashCode가 거의 같은 버킷으로 몰림
관찰: 평균 조회 시간이 기대보다 증가하고 삽입 시 확장 비용이 겹침
판단: 분포와 구현의 충돌 처리 확인 → 키/해시 설계 또는 자료구조 재검토
```

이는 고의로 만든 가상 반례이며, 실제 성능 수치는 언어·구현·키 분포에 따라 달라진다.

## 2. LRU는 조회만으로도 순서를 바꾼다

정확한 LRU를 Map과 이중 연결 리스트로 구현하면 Map은 키에서 노드를 찾고, List는 최근 사용 순서를 관리한다. 조회한 노드를 맨 앞으로 옮기고, 용량 초과 시 맨 뒤 노드를 Map과 List에서 함께 제거한다. 핵심 불변식은 **Map의 모든 키가 List에 정확히 한 번 존재하고 순서가 마지막 사용 시각을 반영한다**는 것이다.

동시 요청에서 `get`도 순서를 수정한다. Map만 동시성 자료구조로 바꾸어도 List 포인터와 제거 작업이 보호되지 않으면 노드 유실, 중복, 이미 제거한 노드의 재삽입이 생긴다. 가장 단순한 설계는 조회·삽입·제거의 Map+List 변경 구간을 하나의 락으로 묶는 것이다. 이때 동시성이 높으면 락 대기가 병목이 된다. 분할 캐시는 경합을 낮추지만 전역적으로 정확한 LRU 순서를 보장하지 않을 수 있다. 정확성 요구가 낮다면 근사 제거 정책도 비교한다.

Java의 `LinkedHashMap`은 access-order와 가장 오래된 항목 제거 훅을 제공하지만 자체적으로 동기화하지 않는다. `ConcurrentHashMap` 하나만으로 전역 LRU 순서를 구현했다고 말해서는 안 된다. 경쟁 테스트에서는 동시에 같은 키를 넣기, 조회와 제거가 겹치기, 용량 경계에서 여러 삽입이 겹치기를 확인한다.

```mermaid
flowchart LR
    A[키 조회] --> B[Map에서 노드 찾기]
    B --> C[같은 동기화 경계에서 List 위치 변경]
    C --> D[가장 최근 사용 위치로 이동]
    E[용량 초과] --> F[List의 가장 오래된 노드 제거]
    F --> G[Map의 같은 키 제거]
```

## 3. 그래프 표현은 밀도와 질의 패턴으로 선택한다

정점 수를 `V`, 간선 수를 `E`라 두면 인접 목록은 대체로 `O(V+E)` 공간을 쓰고 한 정점의 이웃 순회가 `O(degree)`다. 두 정점이 바로 연결됐는지는 이웃 목록 검색 방식에 따라 비용이 달라진다. 인접 행렬은 `O(V²)` 공간을 쓰지만 간선 존재 조회가 `O(1)`이고 한 정점의 모든 이웃을 훑는 데 `O(V)`가 든다. 행렬의 `O(1)`은 인덱스 접근의 계산 복잡도이며 실제 캐시·메모리 비용까지 뜻하지 않는다.

희소 그래프에서 모든 정점 쌍의 슬롯을 할당하면 낭비가 크므로 인접 목록이 유리한 경우가 많다. 밀집 그래프에서 간선 존재를 매우 자주 검사하면 행렬이 단순하다. 가중치, 방향, 중복 간선, 간선 변경 빈도, 정점 ID의 연속성도 선택에 영향을 준다. 예를 들어 `V=100,000`이면 행렬 슬롯은 `10^10`개이므로, 간선이 수십만 개뿐인 그래프에 행렬을 택하기 전에 메모리 예산을 계산해야 한다. 이 숫자는 설계 판단을 위한 가상 입력이다.

| 표현 | 공간 | 간선 존재 확인 | 한 정점의 이웃 순회 |
| --- | --- | --- | --- |
| 인접 목록 | `O(V+E)` | 목록의 탐색 방식에 따라 다름 | `O(degree)` |
| 인접 행렬 | `O(V²)` | `O(1)` 인덱스 접근 | `O(V)` |

> **답변 점검** — 세 문제 모두 평균 복잡도만 암기하지 말고 입력 분포, 불변식, 최악 또는 꼬리 지연, 메모리 한도를 연결해 설명한다.

### 근거 자료

- [Java SE 21 — HashMap](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/HashMap.html): 초기 용량·부하율·재해시와 충돌.
- [Java SE 21 — LinkedHashMap](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/LinkedHashMap.html): access-order와 동기화 조건.
- [Java SE 21 — ConcurrentHashMap](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/concurrent/ConcurrentHashMap.html): 동시 조회·갱신 특성.
- [Boost Graph Library — Graph Data Structures](https://www.boost.org/doc/libs/latest/libs/graph/doc/html/graph/graph_classes/overview.html): 인접 목록·행렬의 공간과 연산 복잡도.$review_23_cs_11_data_structures_interview$
WHERE slug = 'cs-11-data-structures-interview' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_database_01_index_explain$> **검수 기준 — 2026-09-27**
>
> MySQL InnoDB 8.4와 PostgreSQL 17을 기준으로 일반 원리와 예외를 구분한다. 실행계획·성능 수치는 예시이며 데이터 분포와 설정으로 달라진다.
> 참고: [PostgreSQL 복합 인덱스](https://www.postgresql.org/docs/17/indexes-multicolumn.html), [Index-Only Scan](https://www.postgresql.org/docs/17/indexes-index-only-scans.html), [플래너 통계](https://www.postgresql.org/docs/17/planner-stats.html), [MySQL ICP](https://dev.mysql.com/doc/refman/8.4/en/index-condition-pushdown-optimization.html).

## 1. B+Tree 인덱스 구조와 Clustered vs Secondary

MySQL InnoDB의 clustered/secondary index와 PostgreSQL의 기본 B-tree access method는 정렬된 키를 이용한 **범위 검색(Range Scan)과 일부 ORDER BY**에 강하다. 다만 InnoDB는 PK leaf에 행이 함께 놓이는 clustered 구조인 반면 PostgreSQL은 일반적으로 heap table과 B-tree index가 분리되어 있다. Hash·GiST·GIN 등 다른 access method도 있으므로 DBMS와 연산자에 맞춰 선택한다.

- 내부 페이지는 탐색에 필요한 키와 downlink를, leaf 페이지는 키와 행 위치 또는 행 자체를 보관한다. 정확한 페이지 포맷은 엔진별로 다르다.
- B-tree는 sibling page 방향과 정렬 키를 이용해 범위를 스캔하지만, 모든 DBMS의 leaf를 동일한 이중 연결 리스트로 모델링하지 않는다. 이상적인 논리 비용은 `O(log n + k)`로 생각하되 실제 I/O·visibility·cache를 측정한다.

```
                 [Root]
              [ 50 | 100 ]              내부 노드: 탐색 키만
             /     |      \
       [20|35]  [60|80]  [120|160]      내부 노드
       /  |  \   ...        ...
  [10,15,20][25,30,35] ...              리프 노드: 실제 row(clustered) 또는 PK 포인터
     |          |            |
  (리프끼리 Linked List 연결 → BETWEEN / ORDER BY / 범위 스캔이 빠른 이유)

```

> **정량 감각 — 고정된 I/O 공식으로 읽지 않는다**
>
> 페이지 크기·키 폭·포인터 폭·fill factor·압축·행 분포에 따라 fan-out과 높이가 달라진다. 트리 높이가 낮더라도 페이지가 버퍼에 있는지, 보조 인덱스에서 테이블로 재방문하는지, PostgreSQL visibility map을 확인해야 하므로 “항상 3~4번 디스크 I/O” 같은 수치로 성능을 보장하지 않는다.

```mermaid
flowchart TB
    R["루트 노드\n50 | 100"]
    I1["내부 노드\n20 | 35"]
    I2["내부 노드\n60 | 80"]
    I3["내부 노드\n120 | 160"]
    L1["리프\n10,15,20"]
    L2["리프\n25,30,35"]
    L3["리프\n60,70,80"]
    L4["리프\n120,140,160"]
    R --> I1 & I2 & I3
    I1 --> L1 & L2
    I2 --> L3
    I3 --> L4
    L1 -. next .-> L2 -. next .-> L3 -. next .-> L4
    style R fill:#fef3c7,stroke:#d97706
    style I1 fill:#fff7ed,stroke:#d97706
    style I2 fill:#fff7ed,stroke:#d97706
    style I3 fill:#fff7ed,stroke:#d97706
```

*B-tree — 정렬 키와 sibling 탐색으로 범위 스캔을 수행하며 실제 페이지 구조는 엔진별로 다르다.*

### Clustered Index vs Secondary Index

InnoDB는 **PK가 곧 Clustered Index(클러스터드 인덱스)**다. 리프 노드에 행 전체가 PK 순으로 정렬 저장된다. 반면 **Secondary Index(보조 인덱스)**의 리프는 인덱스 키 + **PK 값**만 가진다.

```mermaid
flowchart LR
    subgraph SEC["Secondary Index: email"]
        S1["email a@x.com\n→ PK 1024"]
        S2["email b@x.com\n→ PK 2048"]
    end
    subgraph CLU["Clustered Index: PK"]
        C1["PK 1024\n행 전체 데이터"]
        C2["PK 2048\n행 전체 데이터"]
    end
    S1 -->|"Bookmark Lookup\nPK로 재탐색"| C1
    S2 -->|"Bookmark Lookup"| C2
    style SEC fill:#dbeafe,stroke:#3b82f6
    style CLU fill:#fef3c7,stroke:#d97706
```

*Secondary Index 조회는 PK를 들고 Clustered Index를 한 번 더 탐색(Bookmark Lookup)한다*

> **PK 폭과 키 순서는 엔진별 비용이다**
>
> InnoDB secondary index는 일반적으로 clustered PK를 leaf에 포함하므로 넓은 PK가 보조 인덱스 크기·cache 효율에 영향을 준다. PostgreSQL의 일반 secondary index는 heap TID를 사용하므로 같은 문장을 그대로 적용하면 안 된다. 단조 키는 오른쪽 끝 쓰기 지역성을 얻을 수 있지만 hot page·추측 가능한 ID·분산 생성 요구를 고려해야 하고, UUIDv7·ULID도 자동 정답이 아니다.

## 2. 복합 인덱스와 선두 컬럼 원칙(Leftmost Prefix)

복합 인덱스 `(a, b, c)`는 사전순으로 정렬된다. 선두 컬럼의 등치 조건과 그 다음 범위 조건이 있으면 **탐색 범위를 좁히기 유리**하다. 이를 Leftmost Prefix(선두 컬럼 원칙)로 설명한다. 선두 조건이 없다고 인덱스 사용 자체가 불가능한 것은 아니다. 전체 인덱스 스캔·커버링, DBMS와 버전에 따른 Skip Scan 가능성을 구분하고 실제 계획을 확인한다.

```sql
-- 물류 주문 테이블
CREATE INDEX idx_ws_status_date
  ON orders (warehouse_id, status, created_at);
```

| WHERE / ORDER BY | 인덱스 사용 | 이유 |
| --- | --- | --- |
| `warehouse_id=1` | ✅ 선두 1컬럼 | 선두 컬럼부터 일치 |
| `warehouse_id=1 AND status='PAID'` | ✅ 2컬럼 | 연속 선두 |
| `warehouse_id=1 AND status='PAID' AND created_at>?` | ✅ 풀 활용 | 마지막에 범위 1개 |
| `status='PAID'` 단독 | ⚠️ 좁은 범위 탐색에 불리 | 선두 누락. 전체 인덱스 스캔·커버링·버전별 Skip Scan 여부 확인 |
| `warehouse_id=1 AND created_at>?` | ⚠️ 주 탐색 범위는 warehouse_id | created_at은 인덱스 내 필터 등에 쓰일 수 있음 |
| `warehouse_id>1 AND status='PAID'` | ⚠️ 주 탐색 범위는 warehouse_id | 뒤 컬럼 조건은 필터링 등에 활용 가능. 범위 축소와 구분 |

> **면접 포인트 — 범위 조건은 인덱스의 끝에**
>
> 단일 탐색 범위를 줄이는 출발점으로 **등치 조건을 앞에, 범위 조건을 뒤에** 둔다. 뒤 컬럼이 탐색 구간을 줄이지 못해도 MySQL Index Condition Pushdown(인덱스 조건 푸시다운) 등 필터링에는 활용될 수 있다. ORDER BY 충족 여부는 등치로 고정된 선두 키, 정렬 방향과 전체 키 순서를 보고 판단한다.

```sql
-- 아래 EXPLAIN 행은 교육용 예시다. key_len·rows·filtered는 실제 DDL의
-- 자료형/문자셋, 인덱스 정의, 통계, 데이터 분포에 따라 달라진다.
EXPLAIN SELECT * FROM orders
WHERE warehouse_id=1 AND status='PAID' AND created_at > '2026-07-01';

+----+--------+-------+--------------------+--------------------+---------+------+------+----------+-----------------------+
| id | table  | type  | possible_keys      | key                | key_len | ref  | rows | filtered | Extra                 |
+----+--------+-------+--------------------+--------------------+---------+------+------+----------+-----------------------+
|  1 | orders | range | idx_ws_status_date | idx_ws_status_date | 13      | NULL |  812 |   100.00 | Using index condition |
+----+--------+-------+--------------------+--------------------+---------+------+------+----------+-----------------------+
```

## 3. 커버링 인덱스(Covering Index)와 Index-Only Scan

**Covering Index(커버링 인덱스)**는 질의에 필요한 컬럼을 인덱스가 모두 포함하는 경우다. 행 데이터를 얻기 위한 테이블 재방문을 줄일 수 있다. MySQL의 `Extra: Using index`, PostgreSQL의 `Index Only Scan`을 확인한다. 다만 PostgreSQL에서는 Visibility Map(가시성 맵)의 all-visible 비트가 없으면 MVCC 가시성 확인을 위해 heap에 접근하므로 `Heap Fetches`도 확인해야 한다. 커버링 구조와 실제 I/O 0회는 같은 뜻이 아니다.

```sql
-- 운송장 상태 조회: 매우 빈번한 읽기 (수천만 건/일)
SELECT status, updated_at
FROM waybill
WHERE tracking_no = '6012345678';

-- 커버링 인덱스: SELECT 대상 컬럼까지 포함
CREATE INDEX idx_tracking_cover
  ON waybill (tracking_no, status, updated_at);
```

```mermaid
sequenceDiagram
    participant App as 애플리케이션
    participant Sec as 보조 인덱스
    participant Clu as 클러스터드 테이블
    Note over App,Clu: 일반 보조 인덱스 (커버링 아님)
    App->>Sec: tracking_no 탐색
    Sec-->>App: PK 반환
    App->>Clu: PK로 행 전체 재탐색 (랜덤 I/O)
    Clu-->>App: status, updated_at
    Note over App,Sec: 커버링 인덱스
    App->>Sec: tracking_no 탐색
    Sec-->>App: status, updated_at 반환 (가시성 조건 충족 시 테이블 재방문 생략)
```

*필요한 컬럼을 인덱스에서 얻는 경로. 실제 테이블 접근은 DBMS와 가시성 조건을 확인한다.*

```sql
EXPLAIN SELECT status, updated_at FROM waybill WHERE tracking_no='6012345678';

| table   | type | key                | Extra       |
| waybill | ref  | idx_tracking_cover | Using index |   <- Using index = 커버링 성공
```

> **실무 — 운송장 추적 API에 강력**
>
> 가상의 운송장 추적 API가 `tracking_no`로 상태·시각만 반복 조회한다고 가정하자. 필요한 컬럼을 인덱스에 포함하면 테이블 재방문을 줄일 수 있다. 자주 갱신되는 컬럼을 추가하면 쓰기 비용·메모리가 늘고 PostgreSQL 가시성 맵에도 영향을 준다. 실제 기업의 구현 사실이 아닌 설계 예제이며, **실행계획과 실측 I/O로 판단**한다.

## 4. Cardinality(카디널리티)와 Selectivity(선택도)

컬럼의 Distinct Cardinality(고유값 수)와 **조건 선택도**를 구분한다. 이 카드에서 조건 선택도는 `조건을 만족하는 행 수 / 전체 행 수`이며 작을수록 적은 행을 선택한다. `고유값 수 / 전체 행 수`는 고유도 지표일 뿐, 특정 값의 빈도나 질의 선택도를 직접 나타내지 않는다. 값의 편향이 크면 고유값이 적은 컬럼도 희소 값을 찾는 인덱스로 유용할 수 있다.

| 컬럼 | 예시 고유값 수 | 조건 예시 | 인덱스 판단 |
| --- | --- | --- | --- |
| `order_id` (PK) | = 전체 행 | 등치 조건은 최대 1행 | 단건 탐색에 유리 |
| `tracking_no` | 거의 unique | 등치 조건은 보통 소수 행 | 단건 탐색에 유리 |
| `user_id` | 수백만 | 사용자별 주문 수에 따라 다름 | 빈도 분포 확인 |
| `status` (enum 6종) | 6 | PENDING이 0.1%일 수도 있음 | 희소 상태 조회에 유용할 수 있음 |
| `is_deleted` (boolean) | 2 | true/false 비중에 따라 다름 | 희소 값·부분 인덱스 검토 |

> **면접 포인트 — "인덱스 있는데 왜 풀스캔?"**
>
> 인덱스 탐색과 테이블 재방문의 예상 비용이 순차 스캔보다 크면 풀스캔을 선택할 수 있다. **20~30% 같은 고정 임계값은 없다.** 테이블 크기·행 폭·캐시·상관도·커버링·비용 설정에 따라 달라진다. 복합 인덱스나 PostgreSQL Partial Index(부분 인덱스)를 검토하되 통계와 실제 실행 결과로 확인한다.

## 5. EXPLAIN 실행계획 읽기

### MySQL — type 열 (가장 중요)

| type | 의미 | 평가 |
| --- | --- | --- |
| `const / system` | PK/Unique 단일 행 | 최고 |
| `eq_ref` | 조인 시 PK/Unique로 1행씩 | 매우 좋음 |
| `ref` | 비고유 인덱스 등치 매칭 | 좋음 |
| `range` | 인덱스 범위 스캔(BETWEEN, >) | 양호 |
| `index` | 인덱스 풀스캔(리프 전부) | 주의 — 커버링이면 OK |
| `ALL` | 테이블 풀스캔 | 큰 테이블의 선택적 조회라면 조사. 작은 테이블·넓은 조회에는 합리적일 수 있음 |

#### 핵심 보조 열

- `key`: 실제 선택된 인덱스. `NULL`이면 인덱스 미사용.
- `rows`: 옵티마이저가 예상한 스캔 행 수(추정치).
- `filtered`: WHERE로 걸러질 비율(%). 낮으면 인덱스로 충분히 못 거른 것.
- `Extra`: `Using index`(커버링·좋음), `Using filesort`·`Using temporary`(정렬/임시테이블·주의), `Using index condition`(ICP·양호).

### PostgreSQL — EXPLAIN (ANALYZE, BUFFERS)

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE warehouse_id = 1 AND status = 'PAID';

                                  QUERY PLAN
-----------------------------------------------------------------------------
 Index Scan using idx_ws_status_date on orders
   (cost=0.43..812.10 rows=820 width=210)
   (actual time=0.05..2.10 rows=812 loops=1)        <- estimated 820 ≈ actual 812 (통계 정상)
   Index Cond: ((warehouse_id = 1) AND (status = 'PAID'))
   Buffers: shared hit=215                           <- 디스크 안 가고 캐시 hit
 Planning Time: 0.18 ms
 Execution Time: 2.40 ms
```

> **estimated vs actual 괴리 = 통계 문제**
>
> PostgreSQL에서 estimated rows와 actual rows가 크게 어긋나면 통계 최신성뿐 아니라 **데이터 편향·컬럼 상관관계·추정 모델의 한계**를 조사한다. `ANALYZE` 후에도 차이가 크면 통계 정밀도와 확장 통계를 검토한다. 스캔 종류에는 보편적인 성능 순위가 없고, `Bitmap Heap Scan`은 하나의 인덱스 비트맵으로도 실행된다. 노드별 실제 행 수·loops·버퍼 접근·실행 시간을 함께 읽는다.

## 6. 인덱스가 안 타는 경우 8가지

| 안티패턴 | 예시 | 대안 |
| --- | --- | --- |
| 컬럼에 함수 적용 | `WHERE DATE(created_at)='2026-07-01'` | 범위 전개 또는 함수 기반 인덱스 |
| 묵시적 형변환 | `WHERE tracking_no = 6012345678` (컬럼은 VARCHAR) | 타입 맞추기 (문자열은 따옴표) |
| 앞부분 와일드카드 LIKE | `WHERE name LIKE '%서울%'` | Full-text / 역인덱스(Inverted Index) |
| 부정 조건 | `WHERE status != 'DONE'`, `NOT IN` | 긍정 조건으로 재작성, enum 나열 |
| OR 양쪽 미인덱스 | `WHERE a=? OR b=?` (b 미색인) | UNION 분리 또는 각각 인덱스 |
| 복합 인덱스 선두 누락 | `(a,b)`인데 `WHERE b=?`만 | 선두 포함 또는 `(b,a)` 추가 검토 |
| 저선택도 | `WHERE is_deleted=0` (대부분 0) | Partial Index `WHERE is_deleted=1` |
| 통계 미갱신 | 대량 적재 직후 옵티마이저 오판 | `ANALYZE TABLE` / autovacuum |

> **가장 흔한 실수 — 날짜 함수 감싸기**
>
> `WHERE DATE(created_at) = '2026-07-01'` 는 모든 행에 함수를 적용해야 하므로 인덱스가 무력화된다. 반드시 **범위(Sargable) 조건** 으로: `WHERE created_at >= '2026-07-01 00:00:00' AND created_at < '2026-07-02 00:00:00'`

## 7. 실패 입력 → 판단 → 복구

`orders(warehouse_id, status, created_at)` 인덱스가 있는데 `WHERE status='PAID' AND created_at > :cutoff`가 `ALL` 또는 넓은 스캔으로 실행된다고 하자. 먼저 이 인덱스의 선두 `warehouse_id` 조건이 없다는 사실, 반환 행 수와 실제 분포, 커버링 여부를 확인한다. PostgreSQL은 `EXPLAIN (ANALYZE, BUFFERS)`의 estimated/actual rows와 heap fetch를, MySQL은 `EXPLAIN ANALYZE`의 actual rows·key·Extra를 확인한다.

추정치가 틀렸으면 통계를 갱신하고 데이터 편향·컬럼 상관관계를 점검한다. 계획 자체는 맞지만 후보 행이 많으면 `(status, created_at)`가 실제 업무 질의에 맞는지 비교하되, 쓰기·저장 비용과 다른 질의 회귀를 함께 측정한다. 조회가 짧아져도 인덱스 강제 힌트를 바로 남기지 않고 배포 분포에서 재현한 뒤 필요할 때만 범위를 좁힌다.

참고: [MySQL EXPLAIN](https://dev.mysql.com/doc/refman/8.4/en/explain.html), [PostgreSQL Using EXPLAIN](https://www.postgresql.org/docs/17/using-explain.html)

## 이해도 확인 Q&A

아래 질문에 직접 답변을 작성하세요. 자동 저장되며, 버튼으로 복사해 코치에게 피드백을 요청할 수 있습니다.$review_23_database_01_index_explain$
WHERE slug = 'database-01-index-explain' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_database_04_sharding_partitioning_replication$> **검수 기준 — 2026-09-27**
>
> 파티션·샤드·복제의 용어와 일관성은 DBMS와 배포 토폴로지에 따라 달라진다. 아래 SQL과 수치는 학습용 예시이며 실제 버전·설정·데이터 분포로 확인한다.
> 참고: [PostgreSQL Partitioning](https://www.postgresql.org/docs/17/ddl-partitioning.html), [MySQL Partitioning](https://dev.mysql.com/doc/refman/8.4/en/partitioning.html), [PostgreSQL Streaming Replication](https://www.postgresql.org/docs/17/warm-standby.html)

## 1. 파티셔닝(Partitioning) — 수평/수직

**Partitioning(파티셔닝)**은 한 논리 테이블을 더 작은 조각으로 나누는 DB 기능이다. 많은 단일 노드 DB에서는 같은 인스턴스 안에 두지만, 제품에 따라 파티션 배치와 분산 방식이 다르므로 이를 보편 규칙으로 말하지 않는다. **Sharding(샤딩)**은 애플리케이션 라우터나 분산 DB가 데이터를 여러 노드·그룹에 배치하는 확장 전략이다. 한 시스템에서 두 개념을 함께 사용할 수도 있다.

- **수평 파티셔닝(Horizontal)**: 행을 기준으로 분할. Range / List / Hash / Composite.
- **수직 파티셔닝(Vertical)**: 컬럼을 기준으로 분할(자주 안 읽는 큰 BLOB 분리 등).

```mermaid
flowchart TB
    T["orders 테이블"]
    T --> P1["p_2026_05\ncreated_at 5월"]
    T --> P2["p_2026_06\ncreated_at 6월"]
    T --> P3["p_2026_07\ncreated_at 7월"]
    P1 -. "보관기한 경과" .-> D["DROP PARTITION\n(대량 삭제 대신 즉시)"]
    style T fill:#fef3c7,stroke:#d97706
    style D fill:#fee2e2,stroke:#ef4444
```

*Range 파티셔닝 — 월별로 나누면 오래된 파티션을 DROP으로 즉시 정리(대량 DELETE 회피)*

```sql
-- 물류 주문: 월별 Range 파티셔닝
CREATE TABLE orders (
  order_id BIGINT, created_at DATETIME, ...,
  PRIMARY KEY (order_id, created_at)
)
PARTITION BY RANGE (TO_DAYS(created_at)) (
  PARTITION p_2026_06 VALUES LESS THAN (TO_DAYS('2026-07-01')),
  PARTITION p_2026_07 VALUES LESS THAN (TO_DAYS('2026-08-01')),
  PARTITION p_max     VALUES LESS THAN MAXVALUE
);
-- 보관정책: 오래된 파티션 즉시 정리
ALTER TABLE orders DROP PARTITION p_2026_06;
```

| 방식 | 분할 기준 | 장점 | 주의 |
| --- | --- | --- | --- |
| Range | created_at 등 범위 | 기간 조회·보관정리 쉬움 | 최근 파티션에 쓰기 집중(핫스팟) |
| List | region 등 목록 | 지역별 격리 | 값 분포 불균형 |
| Hash | hash(key) % N | 균등 분산 | 범위 조회 비효율, N 변경 어려움 |
| Composite | Range + Hash 등 | 두 장점 결합 | 설계·관리 복잡 |

> **Pruning(파티션 가지치기)**
>
> WHERE에 파티션 키의 범위가 있으면 옵티마이저가 관련 파티션만 스캔할 가능성이 커진다. 함수·형변환·파라미터 형태·DBMS 버전에 따라 pruning이 실패할 수 있고, 파티션 키 없는 조회는 여러 파티션을 읽을 수 있다. 파티션 키를 PK/Unique에 포함해야 하는 제약은 MySQL과 PostgreSQL에서 다르므로 해당 DBMS DDL을 확인한다. EXPLAIN에서 실제 대상 파티션과 제거된 파티션을 확인한다.

## 2. Sharding Key(샤딩 키) 선택

샤딩 키는 샤딩 설계의 거의 전부다. 판단 기준은 **카디널리티 · 분포 균등성 · 핫스팟 · 조인/조회 지역성**이다. 잘못 고르면 한 샤드만 터지거나(핫스팟), 모든 쿼리가 전 샤드로 흩어진다(Scatter-gather).

| 후보 키 | 분포 | 지역성(한 유저 데이터가 한 샤드) | 핫스팟 위험 | 적합성 |
| --- | --- | --- | --- | --- |
| `user_id` (hash) | 균등 | ✅ 좋음(유저 단위 조회 1샤드) | 낮음 | 이커머스 주문에 권장 |
| `order_date` (range/date 기반) | 시간 편중 | ❌ 최근 범위가 한 샤드 | 🚨 높음(오늘 주문 폭주) | 비권장(시계열 분석엔 별도) |
| `order_id` (auto-inc) | 단조 증가 | — | 🚨 마지막 샤드 집중 | 비권장 |
| 복합 `(seller_id, ...)` | 판매자별 | 판매자 단위 조회 유리 | 대형 셀러 편중 | B2B 정산 등 |

```mermaid
flowchart LR
    Q["쿼리: user_id=7777"] --> Router["샤드 라우터\nshard = hash(user_id) % 4"]
    Router --> S0["Shard 0"]
    Router --> S1["Shard 1"]
    Router --> S2["Shard 2"]
    Router -->|"hash → 2"| S2
    XQ["user_id 없는 집계"] -.->|"Scatter-Gather\n전 샤드 fan-out"| Router
    style Router fill:#fef3c7,stroke:#d97706
    style S2 fill:#dcfce7,stroke:#16a34a
```

*샤드 라우팅 — 샤드 키가 있으면 1샤드, 없으면 전 샤드로 흩어지는 Scatter-Gather(비싸다)*

> **면접 포인트 — `user_id` vs `order_date`**
>
> 사용자 단위 조회·트랜잭션이 지배적이면 `user_id`가 한 샤드 지역성을 줄 수 있지만, 대형 사용자·판매자 편향과 cross-user 업무를 확인해야 한다. 시간 범위 조회·보관 삭제가 지배적이면 `order_date`가 pruning과 retention에 유리할 수 있지만 최근 쓰기와 최신 파티션 hot spot을 측정해야 한다. 어떤 키도 모든 쿼리를 최적화하지 않으므로 OLTP 라우팅과 분석용 집계를 별도 파이프라인으로 설계한다.

> **샤딩의 대가**
>
> Cross-shard JOIN 불가, 분산 트랜잭션(2PC/Saga) 복잡도, 글로벌 유니크/시퀀스 어려움, 리샤딩 고통. **먼저 파티셔닝·읽기복제·캐시로 버틸 수 없는지** 검토하고, 정말 단일 노드 쓰기 한계에 부딪힐 때 샤딩한다.

## 3. Consistent Hashing(일관성 해시) — 리밸런싱 최소화

단순 `hash(key) % N`은 노드 수 N이 바뀌면 거의 모든 키가 재배치된다. **Consistent Hashing(일관성 해시)**은 노드와 키를 같은 해시 링(0~2³²) 위에 올리고, 키를 시계방향 첫 노드에 할당한다. 노드 추가/제거 시 **인접 구간의 키만 이동**하며, 균등한 단순 링에서 한 노드를 추가할 때의 기대 이동량은 대략 `1/(N+1)`, 제거할 때는 대략 `1/N` 수준이다. 실제 이동량은 vnode/token 수, 가중치, 리밸런싱 정책과 키 분포에 따라 달라진다.

```mermaid
flowchart TB
    subgraph Ring["해시 링 (시계방향 첫 노드에 할당)"]
        N0["Node A\n(+ vnode A1..A150)"]
        N1["Node B\n(+ vnode)"]
        N2["Node C\n(+ vnode)"]
        K1["key1 → A"]
        K2["key2 → B"]
        K3["key3 → C"]
    end
    NewN["Node D 추가"] -. "인접 구간 키만 이동" .-> Ring
    style N0 fill:#dbeafe,stroke:#3b82f6
    style N1 fill:#dcfce7,stroke:#16a34a
    style N2 fill:#fef3c7,stroke:#d97706
    style NewN fill:#ede9fe,stroke:#8b5cf6
```

*일관성 해시 — Virtual Node(가상 노드)로 분포를 고르게, 노드 변동 시 이동 키 최소화*

> **Virtual Node로 분포를 조정한다**
>
> 링에 물리 노드를 하나만 올리면 구간 크기가 편중될 수 있어 virtual node/token을 여러 개 배치해 분산을 조정한다. 다만 제품마다 토큰 링·고정 슬롯·분할/리밸런싱 알고리즘이 다르다. Cassandra의 token ring과 Redis Cluster의 16,384 hash slot은 같은 “데이터 분산” 문제를 풀지만 구현과 운영 절차가 같지 않으며, DynamoDB 같은 관리형 서비스의 내부 배치 구현을 일관성 해시라고 단정하지 않는다.

## 4. Replication(복제) — 동기 vs 비동기, 그리고 지연

복제는 **읽기 확장**과 **고가용성(HA)**을 위해 데이터를 여러 노드에 복사한다. Primary가 쓰기를 받고, Replica가 읽기를 분담한다. 핵심 트레이드오프는 **일관성 vs 가용성/지연**이다.

| 방식 | 커밋 조건 | 일관성 | 지연/가용성 | 데이터 손실 위험 |
| --- | --- | --- | --- | --- |
| 비동기(Async) | Primary만 쓰면 커밋 | 약함(복제 지연) | 빠름·가용성 높음 | 장애 시 미전파분 손실 가능 |
| 반동기(Semi-sync) | Replica 1개 수신 확인 | 중간 | 중간 | 크게 감소 |
| 동기(Sync) | 설정된 Replica/정족수의 확인 | 설정된 범위에서 강함 | 지연·가용성 비용 | 확인된 복제본 수와 장애 모델에 따라 달라짐 |

```mermaid
sequenceDiagram
    participant App as 앱
    participant P as Primary
    participant R as Replica (지연 200ms)
    App->>P: UPDATE 주문 상태=PAID / COMMIT
    P-->>App: OK
    App->>R: SELECT 주문 상태 (방금 그 유저)
    R-->>App: 아직 PENDING (복제 지연!)
    Note over App,R: Read-your-writes 깨짐 → 사용자 혼란
```

*Replication lag — 쓰기 직후 Replica를 읽으면 옛 값. 라우팅 전략으로 보정 필요*

> **Replication Lag(복제 지연)과 Read-your-writes**
>
> 비동기 복제에선 쓰기 직후 Replica를 읽으면 **자기가 쓴 값이 안 보인다(Read-your-writes 위반)** . 해법: ① 쓰기 직후 일정 시간/세션은 **Primary로 읽기 강제** , ② 복제 위치(GTID/LSN) 기반으로 "충분히 따라온 Replica"만 라우팅, ③ 사용자 본인 데이터만 Primary. 물류에서 "주문하자마자 주문내역이 안 보임" 같은 클레임이 이 문제다.

> **면접 포인트 — MySQL vs PostgreSQL 복제**
>
> **MySQL** : binlog 기반(row/statement/mixed). 비동기 기본, semi-sync 옵션. binlog는 CDC(Change Data Capture)의 소스이기도 해 Debezium→Kafka로 검색·캐시·DW 동기화에 쓰인다. **PostgreSQL** : WAL 기반 **streaming replication** (physical, 바이트 단위 그대로) + **logical replication** (테이블 단위 선택 복제, 버전 이종 가능). 동기 복제는 `synchronous_standby_names` 로 정족수 지정. Failover 시 split-brain 방지를 위해 fencing/합의(예: Patroni)를 둔다.

## 5. 실패 입력 → 판단 → 복구

주문을 Primary에 커밋한 직후 읽기 Replica로 주문내역을 조회했는데 아직 `PENDING`으로 보인다고 하자. 먼저 복제 위치와 요청의 write timestamp/LSN을 비교해 실제 lag인지, 라우터가 다른 Tenant·샤드로 보낸 것인지, 읽기 Cache가 오래된 것인지 분리한다. 일정한 시간 동안 Primary를 읽는 것은 단순 UX 보정이지만, 세션이 여러 노드로 이동하면 충분하지 않을 수 있다.

Read-your-writes가 업무 요구라면 ① 쓰기 응답 뒤 세션/사용자 범위를 Primary로 보내기, ② write position을 전달해 해당 위치까지 재생한 Replica만 선택하기, ③ 해당 화면을 Primary 또는 강한 일관성 경로로 읽기의 비용과 장애 모드를 비교한다. 동기 복제라고 자동으로 모든 읽기 경로의 최신성이 보장되는 것도 아니며, failover 뒤 fencing·epoch·중복 처리까지 확인해야 한다. 샤딩 환경에서는 라우팅 키가 누락된 집계가 모든 샤드로 fan-out될 수 있으므로 비동기 분석 경로와 OLTP를 분리한다.

## 이해도 확인 Q&A

아래 질문에 직접 답변을 작성하세요. 자동 저장되며, 버튼으로 복사해 코치에게 피드백을 요청할 수 있습니다.$review_23_database_04_sharding_partitioning_replication$
WHERE slug = 'database-04-sharding-partitioning-replication' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_database_06_query_tuning$> **검수 기준 — 2026-09-27**
>
> MySQL·PostgreSQL·ORM 예시는 서로 다른 옵티마이저와 Driver 동작을 가질 수 있다. SQL의 행 수·지연·Buffer 접근은 데이터 분포와 실행 시점에 따라 달라지므로 예시 수치를 보장으로 읽지 않는다.
> 참고: [PostgreSQL EXPLAIN](https://www.postgresql.org/docs/17/using-explain.html), [PostgreSQL LIMIT/OFFSET](https://www.postgresql.org/docs/17/queries-limit.html), [Hibernate fetching](https://docs.jboss.org/hibernate/orm/6.5/querylanguage/html_single/Hibernate_Query_Language.html#association-fetching), [MySQL slow query log](https://dev.mysql.com/doc/refman/8.4/en/slow-query-log.html)

## 1. 슬로우쿼리 분석 프로세스

튜닝의 출발점은 "느린 쿼리를 데이터로 특정하는 것"이다. 감으로 인덱스를 추가하지 않는다.

### 관측 도구

- **MySQL**: `slow_query_log=ON`과 `long_query_time=<워크로드별 임계값>`으로 임계 초과 쿼리를 수집한다. `0.5초`는 빠른 API를 관찰할 때 사용할 수 있는 예시일 뿐 MySQL의 보편 기본값이나 모든 서비스의 권장값이 아니다. 로그를 **pt-query-digest(Percona Toolkit)**로 정규화·집계하면 "총 시간 기여도 1위 쿼리"가 나온다. `performance_schema.events_statements_summary_by_digest`도 동일 목적.
- **PostgreSQL**: **pg_stat_statements** 확장으로 쿼리별 총 호출수·총시간·평균을 누적 집계. 느린 쿼리를 자동 로깅하려면 **auto_explain**(`auto_explain.log_min_duration`)으로 임계 초과 시 실행계획까지 로그에 남긴다.

> **팁 — 평균이 아니라 총량으로 보라**
>
> 한 번에 5초 걸리는 쿼리보다, 10ms지만 초당 5천 번 도는 쿼리가 시스템엔 더 큰 부하다. pt-query-digest와 pg_stat_statements가 **"총 누적 시간(total time) 순"** 으로 정렬해 주는 이유다. *호출 빈도 × 1회 비용* 으로 우선순위를 잡아라.

### 병목 찾기 — EXPLAIN ANALYZE BUFFERS

후보를 좁혔으면 실행계획으로 병목을 짚는다. PostgreSQL은 `BUFFERS`로 실제 읽은 페이지(buffer hit/read)까지 보여줘 I/O 병목을 정량화할 수 있다.

```sql
-- PostgreSQL: 추정이 아니라 실제 실행 + I/O 측정
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT * FROM shipment WHERE status='IN_TRANSIT' AND hub_id=42;

-- 읽는 법 (핵심 신호)
-- Seq Scan on shipment  (cost=0..18500 rows=120 width=80)
--   (actual time=0.3..210 rows=98000 loops=1)   ← estimated 120 vs actual 98000 괴리!
--   Buffers: shared hit=200 read=17800           ← 17800 페이지 디스크 read = I/O 병목
-- Planning Time / Execution Time
```

여기서 `rows=120`(추정) vs `actual rows=98000`의 큰 괴리는 통계·데이터 편향·컬럼 상관관계 또는 조건 추정의 한계를 조사할 신호다. `Seq Scan` + 많은 `read`가 곧 인덱스 부재를 뜻하지는 않는다. 넓은 범위 조회·낮은 선택도·작은 테이블에서는 순차 스캔이 합리적일 수 있으므로 Buffers와 대안 계획을 함께 비교한다.

```mermaid
flowchart TD
    A[느리다는 신고/알람] --> B[슬로우쿼리 수집\nslow_log·pg_stat_statements]
    B --> C[총 누적시간 순 정렬\npt-query-digest]
    C --> D[1순위 쿼리 선정]
    D --> E[EXPLAIN ANALYZE BUFFERS]
    E --> F{estimated vs\nactual 괴리?}
    F -->|크다| G[ANALYZE 통계 갱신\nhistogram 점검]
    F -->|작다| H{Seq Scan·랜덤 I/O?}
    H -->|yes| I[인덱스·커버링 검토\n조건 sargable화]
    H -->|no| J[조인순서·조인알고리즘\n재작성 검토]
    G --> E
    I --> K[재측정·회귀 확인]
    J --> K
    style E fill:#fef3c7,stroke:#d97706
    style K fill:#f0fdf4,stroke:#16a34a
```

*튜닝은 수집→정렬→실행계획→가설→교정→재측정의 반복 루프다.*

> **실무 함정 — 인덱스를 무력화하는 조건**
>
> `WHERE DATE(created_at)='2026-07-01'` 처럼 컬럼을 함수로 감싸면 인덱스를 못 탄다(non-sargable). `created_at >= '2026-07-01' AND created_at < '2026-07-02'` 로 풀어야 한다. `LIKE '%검색어%'` 의 선행 와일드카드, 암묵적 형변환(varchar 컬럼에 숫자 비교)도 같은 함정이다.

## 2. N+1 문제

**N+1 문제**는 ORM(Object-Relational Mapping)에서 가장 흔한 성능 사고다. 부모 N건을 가져오는 쿼리 1번 + 각 부모의 연관 자식을 가져오는 쿼리 N번 = 총 N+1번의 쿼리가 나간다. 주문 100건의 배송정보를 lazy loading으로 순회하면 1 + 100 = 101개 쿼리가 발생한다.

```mermaid
sequenceDiagram
    participant App as 애플리케이션\n(JPA)
    participant DB as DB
    App->>DB: SELECT * FROM orders LIMIT 100
    DB-->>App: 주문 100건
    loop 각 주문마다 (Lazy)
        App->>DB: SELECT * FROM shipment WHERE order_id=?
        DB-->>App: 배송 1건
    end
    Note over App,DB: 쿼리 1 + 100 = 101회\n네트워크 왕복 비용이 지배
```

*주문 목록 + 배송정보를 순회하면 lazy loading이 행마다 쿼리를 날려 N+1이 된다.*

### 해법

물류 도메인에서 "주문 목록 + 배송 현황"을 한 화면에 보여줄 때 N+1이 전형적으로 터진다. 해법은 데이터를 *미리 묶어 가져오는* 것이다.

```sql
// 1) Fetch join — 한 방 쿼리로 조인해 가져옴
@Query("SELECT o FROM Order o JOIN FETCH o.shipment WHERE o.status = :st")
List<Order> findWithShipment(@Param("st") OrderStatus st);

// 2) @EntityGraph — 어떤 연관을 즉시 로딩할지 선언
@EntityGraph(attributePaths = {"shipment", "items"})
List<Order> findByStatus(OrderStatus status);

// 3) Batch size — IN 절로 N번을 1번에 (application.yml)
//    hibernate.default_batch_fetch_size: 100
//    → SELECT * FROM shipment WHERE order_id IN (?,?,...,?)  (100개씩 묶음)

// 4) DTO projection — 필요한 컬럼만 조인해 평면 DTO로 (가장 가벼움)
@Query("SELECT new com.x.OrderShipDto(o.id, o.status, s.trackingNo) " +
       "FROM Order o JOIN o.shipment s WHERE o.status = :st")
List<OrderShipDto> findDto(@Param("st") OrderStatus st);
```

| 해법 | 쿼리 수 | 주의점 |
| --- | --- | --- |
| Fetch join | 1 | 컬렉션 fetch join + paging 동시 사용 시 메모리 paging(전체 로딩) 발생. 컬렉션은 1개만. |
| @EntityGraph | 구현·연관 형태에 따라 다름 | fetch 계획과 페이징·컬렉션 중복을 실제 SQL로 확인한다. 선언적이라 가독성은 좋지만 1쿼리를 보장하지 않는다. |
| Batch size(IN) | 1 + ceil(N/batch) | 컬렉션 여러 개를 한 번에 join하지 않아 카티전 곱을 줄일 수 있다. Batch 크기와 IN 제한은 Driver·DBMS로 확인한다. |
| DTO projection | 1 | 영속성 컨텍스트 이점은 없지만 가장 적은 데이터·메모리. 조회 전용 화면에 최적. |

> **면접 포인트**
>
> "Fetch join이 항상 정답인가요?" → 아니다. **컬렉션(1:N) fetch join에 페이징을 붙이면** Hibernate가 DB 페이징을 포기하고 전체를 메모리로 끌어와 잘라낸다( `HHH000104` 경고). 이 경우 **Batch size(IN 절 묶기)** 가 정석이다. 둘의 차이를 설명하면 시니어 점수.

## 3. 커서 페이지네이션

`LIMIT 20 OFFSET 100000`은 정렬·인덱스·실행계획에 따라 앞 행을 읽고 버리는 비용이 커질 수 있어 깊은 페이지에서 악화되기 쉽다. 항상 정확히 100,020행을 디스크에서 읽는다는 뜻은 아니며, EXPLAIN과 실제 Buffer/실행 시간을 확인한다.

```sql
-- (느림) OFFSET 방식: 앞 10만 행을 읽고 버림
SELECT * FROM shipment_history
ORDER BY id DESC
LIMIT 20 OFFSET 100000;
-- EXPLAIN: 접근 경로에 따라 offset+limit에 가까운 행을 읽고 버릴 수 있음.
-- 실제 rows/buffers와 깊이별 증가 여부는 실행계획과 데이터로 확인한다.

-- (빠름) Keyset / Cursor 방식: 마지막으로 본 키를 기준으로 그 다음만
SELECT * FROM shipment_history
WHERE id < :lastSeenId          -- 직전 페이지 마지막 id를 커서로 전달
ORDER BY id DESC
LIMIT 20;
-- EXPLAIN: 조건·정렬과 맞는 인덱스가 있으면 offset 증가를 피할 수 있음.
-- 실제 읽기 행 수는 선택도·가시성·동시 변경·실행계획에 따라 달라진다.
```

| 관점 | OFFSET 100000, LIMIT 20 | Keyset/Cursor (WHERE id < ?) |
| --- | --- | --- |
| 스캔 행 수 | 앞 행을 읽고 버리는 비용이 커질 수 있음 | 조건·인덱스가 맞으면 다음 행 중심 |
| 응답시간 | 데이터·정렬·캐시에 따라 깊이와 함께 증가 가능 | 커서 조건·분포·동시 변경에 따라 측정 |
| 임의 페이지 점프 | 가능(N페이지로 바로) | 불가(다음/이전만) — 무한스크롤에 적합 |
| 정렬 안정성 | 중간 삽입/삭제 시 행 밀림·중복 가능 | 커서 키 기준이라 안정적 |
| 적합 사례 | 관리자 페이지 등 얕은 페이징 | 운송장 이력 무한스크롤, 피드 |

> **물류 사례 — 운송장 이력 무한스크롤**
>
> 배송 추적 화면에서 운송장(tracking) 스캔 이력을 무한스크롤로 보여줄 때, 깊은 페이지(오래된 이력)에서 OFFSET은 치명적이다. 마지막 이벤트의 `(event_at, id)` 복합 커서를 내려주고 `WHERE (event_at, id) < (:lastAt, :lastId)` 로 잇는다. 동률 타임스탬프를 id로 깨야 누락·중복이 없다. `(event_at, id)` 복합 인덱스가 전제다.

> **실무 함정 — COUNT(*) 동반**
>
> 페이지네이션마다 전체 건수를 위해 `SELECT COUNT(*)` 를 같이 날리면 대용량에서 그 자체가 슬로우쿼리가 된다. 무한스크롤은 총건수가 필요 없는 경우가 많으니 빼고, 꼭 필요하면 근사치(추정 통계, PostgreSQL의 `reltuples` )나 캐시를 쓴다.

## 4. 실패 입력 → 판단 → 복구

주문 100건을 조회한 뒤 화면 코드가 `order.items`와 `order.shipment`를 순서대로 접근해 N+1이 발생했다고 하자. 먼저 SQL 로그에서 호출 수·총 시간·반환 행을 확인하고, 목록의 1:1 정보는 DTO 또는 제한된 fetch로, 1:N 항목은 배치 조회·별도 Endpoint·집계로 분리한다. 컬렉션 fetch join을 페이지 쿼리에 무조건 추가하면 행이 주문 수보다 늘어나거나 ORM이 메모리에서 페이지를 자르는 문제가 생길 수 있다.

운송장 이력에서 동률 `event_at`을 `WHERE event_at < :last`만으로 커서 처리하면 같은 시각의 행이 누락될 수 있다. `(event_at, id)`를 유일한 정렬 키로 정하고 `(event_at, id)` 복합 인덱스와 동일한 반열린 조건을 사용한다. 다만 해당 행이 삭제·수정되는 동안 화면의 일관성은 별도 정책이므로 snapshot, immutable event, 또는 “새 이벤트가 위로 추가될 수 있음”을 UX에 명시한다.

추정 rows가 실제 90만 행으로 100배 차이 난다면 힌트를 먼저 넣지 않는다. 통계 갱신, 컬럼 상관관계, parameterized plan, 조건의 sargability, 조인 순서와 대안 Hash/Index plan을 순서대로 확인하고 수정 후 동일 workload에서 p95·Buffers·쓰기 영향까지 재측정한다.

## 5. 카디널리티 추정과 옵티마이저

옵티마이저(Optimizer)는 비용 기반(Cost-based)으로 실행계획을 고른다. 그 비용 계산의 핵심 입력이 **Cardinality(카디널리티, 조건을 통과하는 추정 행 수)**이고, 카디널리티는 **통계(Statistics)**에서 나온다. 통계가 낡으면 추정이 틀리고, 추정이 틀리면 잘못된 플랜을 고른다.

### 통계와 히스토그램

- **통계 갱신**: PostgreSQL은 `ANALYZE`(autovacuum이 자동 수행), MySQL은 `ANALYZE TABLE` 또는 InnoDB의 자동 통계. 대량 적재(bulk load) 직후엔 수동 갱신이 안전하다.
- **Histogram(히스토그램)**: 값의 분포가 한쪽으로 치우친(skewed) 컬럼에서 균등 분포 가정을 보정한다. 예) `status` 컬럼이 99% `DELIVERED`, 1% `IN_TRANSIT`이면 히스토그램 없이는 옵티마이저가 두 값을 비슷하게 보고 오판한다.
- **estimated vs actual rows 괴리**: `EXPLAIN ANALYZE`에서 둘의 차가 수십~수백 배면 통계 문제이거나, 컬럼 간 상관관계(correlation)를 모델이 못 잡은 경우다.

### 조인 순서와 조인 알고리즘

옵티마이저는 **조인 순서(어느 테이블을 먼저 줄일지)**와 **조인 알고리즘**을 함께 고른다. 알고리즘 선택은 대체로 양쪽 입력 크기와 인덱스 유무로 갈린다.

| 조인 알고리즘 | 유리한 상황 | 특징 |
| --- | --- | --- |
| **Nested Loop** | 외부(outer) 결과가 작고, 내부(inner)에 조인키 인덱스가 있을 때 | 외부 1행마다 내부를 인덱스로 lookup. 소량 조인의 OLTP 기본. MySQL의 주력. |
| **Hash Join** | 한쪽이 크고 동등 조인(=)이며 인덱스가 없을 때 | 작은 쪽으로 해시 테이블 만들고 큰 쪽을 probe. 대량 조인·분석 쿼리에 강함. PostgreSQL이 적극 사용(MySQL 8.0.18+도 지원). |
| **Merge Join** | 양쪽이 조인키로 이미 정렬돼 있을 때(인덱스 정렬 활용) | 두 정렬 스트림을 병합. 범위 조인·정렬 필요 시 유리. |

```sql
-- 통계가 틀려 Nested Loop를 잘못 고른 사례 진단
EXPLAIN ANALYZE
SELECT o.id, s.tracking_no
FROM orders o JOIN shipment s ON s.order_id = o.id
WHERE o.created_at >= '2026-06-01';
-- Nested Loop  (rows=100 estimated)  (actual rows=900000)  ← 100배 괴리
--   → 옵티마이저는 100건 조인인 줄 알고 NL을 골랐지만 실제 90만건
--   → Hash Join이 나았을 것. 원인: created_at 통계 낡음

ANALYZE orders;   -- 통계 갱신 후 재측정
```

> **면접 포인트**
>
> "옵티마이저가 인덱스를 안 타는데 힌트로 강제하면 되지 않나요?" → 힌트( `FORCE INDEX` , `/*+ ... */` )는 **최후의 수단** 이다. 데이터 분포가 바뀌면 그 강제가 오히려 독이 된다. 먼저 *통계 갱신·히스토그램·인덱스 설계·쿼리 재작성(sargable화)* 으로 옵티마이저가 옳게 고르도록 유도하라. 힌트를 박는 건 근본 원인을 덮는 것일 수 있다.

## 6. 이해도 확인 Q&A$review_23_database_06_query_tuning$
WHERE slug = 'database-06-query-tuning' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_database_09_index_access_optimization$> **검수 기준 — 2026-09-27**
>
> Index Merge·Skip Scan·ICP·MRR은 MySQL의 특정 버전·스토리지 엔진·옵티마이저 조건에 따라 선택되는 실행 전략이다. 존재한다고 항상 사용되거나 더 빠른 것은 아니며 `EXPLAIN ANALYZE`와 실제 데이터로 확인한다.

## 1. 네 전략은 서로 다른 낭비를 줄인다

MySQL 옵티마이저는 통계와 비용 모델을 바탕으로 접근 경로를 고른다. 각 최적화가 존재한다고 해서 항상 선택되는 것은 아니며, 최종 판단은 실제 데이터 분포에서 `EXPLAIN ANALYZE`로 확인한다.

| 전략 | 줄이는 비용 | 잘 맞는 상황 | 경계 |
|---|---|---|---|
| Index Merge | 한 테이블의 여러 인덱스 결과 결합 | 서로 다른 컬럼의 OR/AND 조건 | 후보 집합 병합과 테이블 조회 비용 |
| Skip Scan | 복합 인덱스 선두값별 반복 탐색 | 선두 컬럼 Cardinality가 낮음 | 선두값 종류가 많으면 반복 비용 증가 |
| ICP | 스토리지 엔진 단계에서 인덱스 조건 평가 | 인덱스만으로 일부 조건 필터 가능 | 인덱스에 없는 조건은 테이블에서 평가 |
| MRR | 랜덤한 테이블 페이지 접근을 묶음·정렬 | Secondary Index가 많은 행을 가리킴 | 버퍼링·정렬 자체의 비용 |

```mermaid
flowchart TD
    Q[WHERE 조건] --> OPT[Cost-based Optimizer]
    OPT --> IM[Index Merge\n여러 range 결과 병합]
    OPT --> SS[Skip Scan\n선두값별 range 반복]
    OPT --> RANGE[Range Scan]
    RANGE --> ICP[ICP\n인덱스 레코드에서 조기 필터]
    ICP --> MRR[MRR\nRow ID를 모아 페이지 순서 접근]
    IM --> ROW[Base Table Rows]
    SS --> ROW
    MRR --> ROW
```

## 2. 실행계획을 읽는 최소 실험

```sql
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_region_created ON orders(region, created_at);

EXPLAIN ANALYZE
SELECT *
FROM orders
WHERE status = 'READY' OR customer_id = 42;

EXPLAIN ANALYZE
SELECT *
FROM orders
WHERE created_at >= CURRENT_DATE - INTERVAL 1 DAY;
```

첫 쿼리는 두 단일 인덱스의 Index Merge 후보가 될 수 있다. 하지만 `(status, customer_id)` 복합 인덱스가 OR 조건을 자동 해결하는 것은 아니며, 조건 형태와 선택도에 따라 쿼리 분리 후 `UNION ALL`이 더 명확할 수도 있다. 두 번째 쿼리는 `region` 종류가 매우 적고 통계·비용 모델이 유리하다고 판단하면 `(region, created_at)`을 선두값별로 탐색하는 Skip Scan 후보가 될 수 있다. MySQL이 해당 Access Path를 선택하지 않거나 다른 DBMS에서는 기능·이름이 다를 수 있으므로 계획을 직접 확인한다.

ICP(Index Condition Pushdown, 인덱스 조건 푸시다운)는 인덱스 레코드를 읽은 시점에 조건을 먼저 평가해 Base Table 접근 횟수를 줄인다. MRR(Multi-Range Read, 다중 범위 읽기)은 Secondary Index에서 얻은 Row ID를 모아 데이터 페이지 순서에 가깝게 접근함으로써 랜덤 I/O를 줄인다.

> **실무 함정** — `type=index_merge`가 보인다고 최적이라고 판단하면 안 된다. 예상 행과 실제 행의 차이, 반복 루프, Base Table 접근 수, 임시 정렬 비용을 함께 본다. 통계가 오래됐거나 컬럼 상관관계가 크면 비용 모델이 틀릴 수 있다.

## 3. 실패 입력 → 판단 → 복구

`status='READY' OR customer_id=42`에서 Index Merge가 선택됐지만 응답이 느리다고 하자. 두 인덱스에서 반환되는 후보 행의 합·중복 제거·Base Table 재방문·정렬 비용을 `EXPLAIN ANALYZE`로 비교한다. 선택도가 낮아 후보가 넓으면 조건을 업무 의미에 맞게 분리한 `UNION ALL`이나 실제 조회 패턴에 맞는 복합 인덱스를 검토하되, 중복 제거 조건을 보존한다.

선두 `region`의 값이 수만 개로 늘어난 뒤 Skip Scan이 선택되면 선두값별 반복 탐색 비용이 커질 수 있다. 통계와 실제 rows/loops가 맞는지 확인하고 `(created_at, ...)` 또는 별도 파티션·정렬 경로가 더 적합한지 비교한다. ICP가 기대한 만큼 Base Table 접근을 줄이지 않거나 MRR의 버퍼링 비용이 더 크면 기능을 강제하지 말고 같은 데이터에서 대안 계획·p95·I/O를 재측정한다.

참고: [MySQL 8.4 Index Merge Optimization](https://dev.mysql.com/doc/refman/8.4/en/index-merge-optimization.html), [MySQL 8.4 Skip Scan Range Access Method](https://dev.mysql.com/doc/refman/8.4/en/range-optimization.html), [MySQL 8.4 Index Condition Pushdown](https://dev.mysql.com/doc/refman/8.4/en/index-condition-pushdown-optimization.html), [MySQL 8.4 Multi-Range Read](https://dev.mysql.com/doc/refman/8.4/en/mrr-optimization.html)

## 4. 튜닝 순서

1. 필요한 행 수와 반환 컬럼을 줄인다.
2. 실제 조건·정렬에 맞는 복합 인덱스를 먼저 검토한다.
3. `EXPLAIN ANALYZE`로 추정치와 실측치를 비교한다.
4. Index Merge·Skip Scan·ICP·MRR은 결과로 관찰하고, 힌트로 강제할 때는 배포 데이터 분포 변화까지 감시한다.

> **면접 포인트** — 인덱스 개수를 늘리는 것이 답이 아니다. 옵티마이저가 읽은 인덱스 레코드 수와 Base Table 페이지 수를 분리해 설명하면 각 최적화의 목적이 선명해진다.

## 참고

- [MySQL 8.4 Index Merge Optimization](https://dev.mysql.com/doc/refman/8.4/en/index-merge-optimization.html)
- [MySQL 8.4 SELECT Optimization](https://dev.mysql.com/doc/refman/8.4/en/select-optimization.html)$review_23_database_09_index_access_optimization$
WHERE slug = 'database-09-index-access-optimization' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_database_10_index_write_cost$> **검수 기준 — 2026-09-27**
>
> 인덱스 유지·페이지 분할·온라인 DDL은 엔진별 구현이 다르다. WAL은 PostgreSQL 용어이고 InnoDB는 redo/undo·binlog 등 별도 로그를 사용하므로 하나의 보편 경로로 설명하지 않는다. 비용·크기·잠금은 같은 데이터와 버전에서 실측한다.

## 1. 인덱스는 쓰기마다 유지되는 구조다

행 하나를 INSERT하면 테이블/heap과 관련 인덱스에 키를 추가한다. UPDATE가 인덱스 키를 바꾸면 엔진에 따라 기존 index entry의 삭제 표시와 새 entry 삽입, MVCC 정리 또는 page rewrite가 발생할 수 있다. PostgreSQL의 WAL과 InnoDB의 redo/undo·binlog는 목적과 기록 시점이 다르지만, 인덱스가 늘면 CPU·I/O·로그·복제량이 늘 수 있다는 비용 경계는 공통으로 관측한다.

```mermaid
flowchart LR
    SQL[INSERT / UPDATE / DELETE] --> TABLE[Table or Heap Page]
    SQL --> PK[Primary/Clustered Index]
    SQL --> I1[Secondary Index A]
    SQL --> I2[Secondary Index B]
    TABLE --> LOG[Engine-specific Log]
    I1 --> LOG
    I2 --> LOG
    I1 --> SPLIT[Possible Page Split or Bloat]
```

| 비용 | 원인 | 관측 지표 |
|---|---|---|
| CPU | 키 비교·정렬·압축·MVCC 처리 | DB CPU, rows written/sec |
| I/O | 데이터·인덱스·로그 페이지 쓰기 | write IOPS, WAL/redo bytes |
| 캐시 | 인덱스 페이지가 버퍼를 점유 | buffer hit ratio, eviction |
| 공간 | 키·포인터·여유 공간·bloat | index size, dead tuples |
| 복제 | 변경 로그 전송·재생 | Replica Lag, replay rate |

인덱스 2개에서 10개가 되었다고 INSERT 비용이 정확히 5배가 되는 것은 아니다. 인덱스 키 분포·페이지 cache hit·동시성·변경 컬럼·배치 크기와 엔진의 로그 압축이 함께 비용을 결정한다.

## 2. 페이지 분할과 키 분포

랜덤 키는 여러 leaf page를 건드리고 중간 삽입에서 split·분산 I/O를 만들 수 있지만, 실제 영향은 page fill, cache, 엔진 구현과 workload에 따라 달라진다. 시간 정렬 키는 쓰기 지역성을 높일 수 있어도 오른쪽 끝 hot page·예측 가능한 식별자·동시 생성 순서·분산 노드 시계 문제를 검토한다. UUIDv7을 도입한다면 “항상 빠르다”가 아니라 같은 부하에서 page split·p95·index size를 비교한다.

```sql
SELECT indexrelname, idx_scan,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE relname = 'orders'
ORDER BY pg_relation_size(indexrelid) DESC;
```

> **실무 함정** — 조회 하나가 빨라졌다는 이유만으로 인덱스를 추가하면 모든 쓰기 경로와 Replica에 지속 비용을 부과한다. 사용량이 낮은 인덱스도 Unique·FK·장애 경로를 보호할 수 있으므로 사용 횟수만으로 삭제하지 않는다.

## 3. 안전한 추가·삭제

대형 인덱스 빌드는 기존 데이터를 읽고 정렬·페이지를 생성하며 변경 로그와 디스크 임시 공간을 사용할 수 있다. PostgreSQL `CREATE INDEX CONCURRENTLY`, MySQL `ALGORITHM`/`LOCK` 옵션처럼 이름이 비슷한 기능도 잠금 범위·실패 잔여물·쓰기 영향이 다르므로 해당 버전 문서를 확인한다. 예상 크기·최대 시간·Replica Lag·중단 기준과 롤백/재시도 절차를 먼저 정한다.

### 실패 입력 → 판단 → 복구

운영 중 `tracking_no` 인덱스를 추가했는데 빌드가 길어지고 Replica Lag이 증가했다고 하자. 먼저 새 인덱스가 실제 장애 Query에 필요한지와 현재 DDL 단계·Lock wait·디스크 여유를 확인한다. 읽기 지연이 개선되지 않으면 작업을 계속 밀어붙이지 않고 중단 가능 여부와 실패 후 남은 객체를 확인한다. 완료 후에도 p95 읽기·p95 쓰기·로그량·Replica replay·index size를 전후 비교하고, Partial/필요 컬럼만 포함하는 대안을 검토한다.

참고: [PostgreSQL CREATE INDEX](https://www.postgresql.org/docs/17/sql-createindex.html), [MySQL Online DDL](https://dev.mysql.com/doc/refman/8.4/en/innodb-online-ddl-operations.html)

> **면접 포인트** — 인덱스 설계는 읽기 쿼리 목록과 쓰기 예산의 협상이다. 추가 전후 p95 쓰기 지연, 로그 증가량, 인덱스 크기, 잠금·복제 상태를 함께 제시한다.$review_23_database_10_index_write_cost$
WHERE slug = 'database-10-index-write-cost' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_database_11_clustered_index_pk$> **검수 기준 — 2026-09-27**
>
> “Clustered Index”의 의미는 DBMS별로 다르다. InnoDB는 PK clustered index를 사용하지만 PostgreSQL의 일반 테이블은 heap과 index가 분리되어 있다. 키 폭·순서·공개 가능성은 실제 엔진과 부하에서 함께 평가한다.
> 참고: [MySQL InnoDB clustered and secondary indexes](https://dev.mysql.com/doc/refman/8.4/en/innodb-index-types.html), [PostgreSQL Indexes](https://www.postgresql.org/docs/17/indexes.html)

## 1. 기본 키는 저장 배치와 참조 비용에 영향을 준다

InnoDB에서는 PK leaf에 행이 함께 저장되는 clustered 구조이고 secondary index가 clustered PK를 참조하므로 PK 폭이 보조 인덱스 크기에 영향을 준다. PostgreSQL의 일반 secondary index는 heap tuple 위치를 참조하므로 InnoDB 설명을 그대로 적용하지 않는다. SQL Server 등 다른 제품은 별도 clustered 설정을 가질 수 있다.

```mermaid
flowchart LR
    PK[Engine-specific primary/clustered key] --> R[(Row or Heap Pages)]
    S1[Secondary: email] -->|PK or tuple locator| R
    S2[Secondary: status,time] -->|engine-specific locator| R
```

| 키 형태 | 장점 | 비용 |
|---|---|---|
| 단조 정수 | 작은 키·쓰기 지역성 | 끝 Page 경합·순서 노출 |
| 랜덤 UUID | 분산 생성·비예측 | 페이지 분산·키 폭·cache 비용 가능 |
| 시간 정렬 ID | 대략적 삽입 지역성 | 시간·노드 정보 노출·시계/동시성 검토 |
| 자연 키 | 업무 의미 직접 표현 | 변경·폭·외부 규칙 의존 |

```sql
CREATE TABLE orders (
  id BIGINT PRIMARY KEY,
  public_id UUID NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL
);
```

내부 물리 키와 외부 공개 ID를 분리하면 공개 식별자 변경·추측 위험을 줄일 수 있지만, Unique Index와 두 ID의 대사 비용이 추가된다. 두 키 중 하나가 항상 빠르다고 가정하지 말고 조회·삽입·복제·보안 요구를 수치화한다.

## 2. 실제 실행 계획으로 검증한다

카디널리티와 분포, Page Split 또는 PostgreSQL bloat, Index 크기, Buffer 적중, secondary-to-row lookup을 운영 부하와 유사한 데이터로 측정한다. PK 변경은 FK·참조·보조 인덱스·CDC payload에 영향을 주므로 초기에 선택 근거와 마이그레이션 비용을 기록한다.

### 실패 입력 → 판단 → 복구

랜덤 UUID를 PK로 교체한 뒤 InnoDB insert p95와 인덱스 크기가 증가했다고 하자. 곧바로 “UUID는 느리다”고 결론 내리지 말고 기존/신규 키 폭, insert 분포, page split, cache hit, secondary index 크기와 동시성을 같은 데이터로 비교한다. 시간 정렬 ID를 선택하더라도 외부에 순서를 노출해도 되는지, 여러 노드의 시계가 역전될 때 유일성과 정렬이 유지되는지 확인한다.

PostgreSQL에서 clustered라는 용어를 보고 PK가 행을 물리적으로 정렬한다고 가정하면 안 된다. heap과 index plan, `Index Only Scan`의 visibility 조건을 직접 확인하고, 장기간 물리 정렬이 필요하다면 제품별 `CLUSTER`/재작성 비용과 유지 정책을 별도로 검토한다.

> **면접 포인트** — “UUID는 느리다” 같은 단정 대신 엔진의 저장 방식, 키 폭, 쓰기 분포, tuple lookup, 외부 공개 요구와 장애·마이그레이션 비용을 분리한다.$review_23_database_11_clustered_index_pk$
WHERE slug = 'database-11-clustered-index-pk' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_database_12_zero_downtime_migration$> **검수 기준 — 2026-09-27**
>
> “무중단”은 DDL 한 줄의 보장이 아니라 혼합 애플리케이션 버전·트래픽·복제·백필·롤백을 포함한 운영 목표다. Lock과 default/NOT NULL의 동작은 DBMS·버전·테이블 크기로 확인한다.
> 참고: [PostgreSQL ALTER TABLE](https://www.postgresql.org/docs/17/sql-altertable.html), [PostgreSQL CREATE INDEX CONCURRENTLY](https://www.postgresql.org/docs/17/sql-createindex.html#SQL-CREATEINDEX-CONCURRENTLY), [MySQL Online DDL](https://dev.mysql.com/doc/refman/8.4/en/innodb-online-ddl-operations.html)

## 1. 배포 한 번에 의미를 바꾸지 않는다

먼저 호환 가능한 새 컬럼·테이블·Index를 추가한다. 구버전과 신버전이 동시에 실행되는 기간을 가정해 읽기·쓰기 계약을 유지하고, 새 경로가 관측과 대사를 통과한 뒤 읽기를 전환한다. 마지막에 모든 Writer·배치·CDC 소비자가 구 경로를 사용하지 않는지 확인하고 Contract를 수행한다.

```mermaid
flowchart LR
    E[Expand compatible schema] --> W[Deploy compatible writer]
    W --> B[Throttle idempotent backfill]
    B --> V[Reconcile + Shadow Read]
    V --> R[Gradual Read Cutover]
    R --> C[Contract after all readers stop]
```

| 단계 | 보호 장치 | 롤백 |
|---|---|---|
| Expand | Lock·rewrite·disk 확인 | 미사용 구조 유지 |
| Write 전환 | 동일 트랜잭션/CDC·멱등 변환 | 구 Writer 또는 dual-read 유지 |
| Backfill | 작은 Batch·throttle·checkpoint | 중단 후 재개 |
| Read 전환 | shadow diff·canary·freshness | 구 읽기로 즉시 복귀 |
| Contract | 구 버전 0·배치 중단 확인 | 삭제 전 유예·백업 |

```sql
UPDATE orders
SET normalized_code = normalize(legacy_code),
    normalized_version = :migration_version
WHERE id > :cursor AND id <= :end
  AND normalized_code IS NULL
  AND legacy_code = :expected_legacy_code;
```

Cursor만으로 최신 쓰기를 보호할 수 없다. Backfill 시점의 기대값·row version·updated_at을 조건에 넣고 영향 행 수를 기록한다. Dual Write를 두 번의 독립 요청으로 보내면 불일치가 생길 수 있으므로 같은 DB 트랜잭션·생성 컬럼·Outbox/CDC 중 어떤 원천에서 파생할지 정한다.

## 2. 완료를 데이터로 증명한다

Null 수, 구·신 값 불일치, 변환 실패, Backfill 속도, 재시작 checkpoint, 복제 지연, Lock 대기를 관측한다. 읽기 전환은 전체 평균이 아니라 표본·고위험 행·Tenant별 shadow diff와 freshness를 확인한 뒤 단계적으로 진행한다. Contract는 모든 실행 버전·배치·CDC consumer가 구 필드를 읽거나 쓰지 않는다는 증거가 있을 때만 수행한다.

### 실패 입력 → 판단 → 복구

큰 테이블에 새 `NOT NULL` 컬럼과 default를 한 번에 추가했더니 긴 Lock 대기와 Replica Lag이 발생했다고 하자. 즉시 DDL을 반복하지 말고 해당 DBMS가 metadata-only인지 table rewrite인지, 현재 transaction·Lock holder·디스크·Replica 상태를 확인한다. Expand는 nullable로 작게 진행하고, 애플리케이션 호환 Writer를 배포한 뒤 idempotent Backfill과 검증을 수행한다. Backfill 중 최신 Writer가 값을 바꾸면 expected version 조건에서 제외해 재조회·대사 Queue로 보내고, 읽기 회귀가 발생하면 구 읽기로 Rollback한다.

> **면접 포인트** — DDL 문법보다 혼합 버전 기간, Lock/rewrite 차이, 데이터 대사, 재시작 가능한 Cursor, 최신 쓰기 보호, 읽기 전환과 삭제의 비가역성을 설명한다.$review_23_database_12_zero_downtime_migration$
WHERE slug = 'database-12-zero-downtime-migration' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_database_13_index_antipattern_review$> **검수 기준 — 2026-09-27**
>
> 인덱스 사용 통계·숨김·삭제 기능은 DBMS별로 다르다. `EXPLAIN ANALYZE`는 일반적으로 Query를 실제 실행하지만, PostgreSQL의 `ANALYZE` 명령은 통계를 수집한다. 두 명령을 혼동하지 않고 운영 부하와 부작용을 확인한다.
> 참고: [PostgreSQL EXPLAIN](https://www.postgresql.org/docs/17/using-explain.html), [PostgreSQL pg_stat_user_indexes](https://www.postgresql.org/docs/17/monitoring-stats.html), [MySQL Invisible Indexes](https://dev.mysql.com/doc/refman/8.4/en/invisible-indexes.html)

## 1. 인덱스 목록만 보지 않는다

실제 Query 형태, 조건 분포, 정렬, 반환 행 수와 실행 계획을 연결한다. 복합 인덱스의 Prefix가 단일 인덱스를 대체할 수 있어도 covering 여부·키 순서·크기·DBMS access method·다른 Query의 정렬 요구를 확인한다.

```mermaid
flowchart TD
    D[DDL·Index 목록] --> Q[Query·빈도·업무 중요도]
    Q --> P[실행 계획·실측]
    P --> W[쓰기·저장·복제 비용]
    W --> C{유지·통합·비활성·삭제}
    C --> M[변경 후 회귀 관측]
```

| 리뷰 냄새 | 확인할 반례 | 개선 후보 |
|---|---|---|
| 모든 컬럼 인덱스 | 쓰기 많은 테이블·낮은 사용률 | 핵심 Query와 제약만 유지 |
| 낮은 선택도 단독 | 특정 값만 희소·Partial/filtered 가능 | 조건부·복합 인덱스 |
| 중복 Prefix | Covering·정렬·크기 차이 | 통합 전 계획 회귀 검증 |
| 미사용 통계 | 짧은 관측 기간·배치·Failover 역할 | 숨김/비활성 후 삭제 |

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, created_at
FROM orders
WHERE user_id = :user
ORDER BY created_at DESC
LIMIT 20;
```

`EXPLAIN ANALYZE`는 부작용 Query가 실제 실행될 수 있으므로 읽기 Query라도 운영 부하와 개인정보를 고려한다. PostgreSQL `ANALYZE`는 통계 수집 명령이며 Query를 실행한다는 뜻이 아니다. MySQL의 invisible index와 PostgreSQL의 가능한 대체 실험 도구도 기능 범위가 같지 않다.

## 2. 삭제도 단계적으로 한다

충분한 관측 기간에 배치·월말·장애 복구 Query와 제약 역할을 포함해 사용 여부를 확인한다. 지원하는 엔진에서는 먼저 invisible/비활성 상태로 optimizer 회귀를 관찰하고, 그렇지 않으면 별도 환경에서 계획을 재현한다. 삭제 뒤 Lock·복제 지연·재생성 시간·디스크를 감시하고 즉시 복구 가능한 DDL 절차를 준비한다.

### 실패 입력 → 판단 → 복구

사용 통계가 0인 `idx_orders_status`를 삭제하려고 하자. 먼저 통계가 수집된 기간과 failover/월말 Query, Unique·FK 보조 역할을 확인한다. MySQL에서 invisible로 바꾼 뒤 p95와 오류율이 악화되면 즉시 되돌리고, PostgreSQL이라면 동일한 기능이 있다고 가정하지 말고 테스트 환경에서 계획을 비교한다. 삭제 후 장애 Query가 발견되면 원래 DDL·대체 인덱스·복제 상태를 확인해 재생성하며, 단순히 “사용 횟수 0”을 근거로 영구 삭제하지 않는다.

> **면접 포인트** — 인덱스는 읽기 최적화 구조이자 모든 쓰기가 유지해야 할 복제 데이터다. 통계의 관측 한계와 DBMS별 비활성/삭제·복구 절차까지 설명한다.$review_23_database_13_index_antipattern_review$
WHERE slug = 'database-13-index-antipattern-review' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_database_14_statistics_histogram$> **검수 기준 — 2026-09-27**
>
> 통계·히스토그램·다중 컬럼 통계의 이름과 자동 갱신 방식은 DBMS마다 다르다. 통계 갱신이 정확한 실행계획을 보장하는 것도 아니므로 추정치·실측치·데이터 분포를 함께 확인한다.
> 참고: [PostgreSQL Planner Statistics](https://www.postgresql.org/docs/17/planner-stats.html), [PostgreSQL Extended Statistics](https://www.postgresql.org/docs/17/planner-stats.html#PLANNER-STATS-EXTENDED), [MySQL Histograms](https://dev.mysql.com/doc/refman/8.4/en/optimizer-statistics.html)

## 1. 실행 계획은 추정 위에 세워진다

Optimizer는 테이블·인덱스 통계로 각 연산의 행 수와 비용을 추정한다. 오래되거나 편향을 표현하지 못한 통계는 좋은 인덱스가 있어도 잘못된 Scan, Join 순서, Join 알고리즘과 메모리 크기를 고르게 할 수 있다. 그러나 실제 조건이 넓거나 테이블이 작으면 Seq Scan이 올바른 선택일 수 있다.

```mermaid
flowchart LR
    D[데이터 분포] --> S[통계·Histogram·Extended Stats]
    S --> C[Cardinality 추정]
    C --> P[Join 순서·Access Path]
    P --> E[실제 실행]
    E -->|추정/실제 차이| S
```

| 통계 | 표현하는 것 | 한계 |
|---|---|---|
| Row Count | 테이블 규모 | 조건 분포 없음 |
| NDV | Distinct 수 | 값의 편향·꼬리 분포 숨김 |
| Histogram | 값 구간·빈도 | Bucket 해상도·변경 시점 |
| 다중 컬럼 통계 | 일부 컬럼 상관관계 | DBMS별 기능·조합 관리 비용 |

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders
WHERE status = 'FAILED' AND region = 'SEOUL';
```

`EXPLAIN ANALYZE`는 Query를 실제 수행할 수 있지만, 통계 수집 명령인 `ANALYZE`와 같은 뜻이 아니다. 쓰기 Query에서는 부작용과 운영 부하를 확인하고, 가능하면 읽기 전용 복제 환경·샘플 데이터·안전한 실행 방법을 사용한다.

## 2. 추정과 실제를 비교한다

노드별 Estimated Rows와 Actual Rows의 비율이 처음 크게 벌어지는 지점을 찾는다. 통계 갱신만 반복하지 말고 값 편향, NULL, Parameter 값, 컬럼 상관관계, predicate 형태, 데이터 변화 시점을 확인한다. PostgreSQL extended statistics나 MySQL histogram 같은 기능을 사용하더라도 버전·통계 대상·적용 계획을 확인한다.

### 실패 입력 → 판단 → 복구

`status='FAILED' AND region='SEOUL'`의 estimated rows가 100인데 actual rows가 900,000이면 Nested Loop나 작은 메모리 Hash 계획이 실제로는 비쌀 수 있다. 먼저 노드별 첫 괴리와 조인 입력·loops·Buffers를 확인하고, 통계가 오래됐는지와 두 컬럼이 상관되는지 조사한다. 통계를 갱신한 뒤에도 차이가 남으면 다중 컬럼 통계·히스토그램·쿼리 분리·인덱스 설계를 비교하고 동일 Parameter와 데이터에서 다시 측정한다.

강제 Index Hint는 데이터 분포가 바뀌면 반대의 회귀를 만들 수 있다. 계획이 틀렸다는 이유로 바로 힌트를 영구화하지 말고, 원인·재현 조건·변경 감시 지표와 Rollback을 함께 기록한다.

> **면접 포인트** — 강제로 특정 Index를 쓰기 전에 Optimizer가 왜 오판했는지 통계·분포·상관관계·실제 Buffer와 함께 설명하고, 수정 후 첫 괴리 노드와 p95를 재확인한다.$review_23_database_14_statistics_histogram$
WHERE slug = 'database-14-statistics-histogram' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_database_15_query_antipattern_review$> **검수 기준 — 2026-09-27**
>
> Sargability와 암묵 형변환은 DBMS·타입·collation·함수 인덱스 지원에 따라 동작이 다르다. SQL을 기계적으로 고치지 말고 결과 의미와 실제 계획을 함께 비교한다.
> 참고: [PostgreSQL Indexes on Expressions](https://www.postgresql.org/docs/17/indexes-expressional.html), [MySQL Range Optimization](https://dev.mysql.com/doc/refman/8.4/en/range-optimization.html), [PostgreSQL Type Conversion](https://www.postgresql.org/docs/17/typeconv.html)

## 1. Index가 답할 수 있는 조건인지 본다

인덱스 컬럼에 함수를 적용하면 원래 정렬 순서로 범위를 찾기 어려울 수 있다. 날짜 전체를 찾을 때는 시작 이상·다음 날 미만의 반열린 구간이 경계와 정밀도를 명확히 한다. 단, 함수 기반/표현식 Index가 의도적으로 있거나 데이터가 작으면 함수 조건도 합리적일 수 있으므로 실행계획을 확인한다.

```mermaid
flowchart TD
    Q[SQL·Parameter Type·Timezone] --> S{Sargable 조건?}
    S -->|아니오| R[범위·타입·표현식 Index 검토]
    S -->|예| P[EXPLAIN + 실제 측정]
    R --> P
    P --> D[읽은 행·Buffer·전송량·결과 동등성]
```

| 리뷰 냄새 | 위험 | 개선 후보 |
|---|---|---|
| `date(column)=?` | 범위 Index 활용 저하 가능 | 반열린 시간 범위 또는 표현식 Index |
| 타입 불일치 | 컬럼 변환·추정·비교 의미 변화 | Parameter 타입 정렬 |
| 거대한 `IN` | Parse·계획·전송·메모리 비용 | 임시 집합 Join·Batch·배치 기준 |
| `SELECT *` | I/O·네트워크·Covering 방해 | 필요한 열 명시 |

```sql
WHERE created_at >= :day_start
  AND created_at < :next_day_start
```

## 2. 의미 보존을 먼저 검증한다

재작성 전 Timezone·DST, Null, 중복, Collation·대소문자, Parameter 타입과 inclusive/exclusive 경계가 같은지 확인한다. 수천 개 `IN` 목록도 항상 나쁜 것은 아니며 집합 크기·임시 테이블 통계·재사용·네트워크 비용과 실행계획으로 판단한다. `SELECT *`도 짧은 내부 Query에서는 문제가 작을 수 있지만 API 계약과 스키마 변경에 취약하다.

### 실패 입력 → 판단 → 복구

`DATE(created_at)=:day`를 반열린 범위로 바꿨는데 애플리케이션 timezone이 UTC이고 사용자의 day가 KST였다고 하자. 먼저 두 쿼리의 결과 집합을 동일 기준 시각으로 비교하고 DST·Null·경계값을 확인한다. 결과가 다르면 Index 성능보다 의미 회귀를 우선 Rollback하고 명시적인 timezone 변환·저장 규칙을 정한다.

문자열 `tracking_no`에 숫자 Parameter를 넘겨 implicit cast가 발생하면 실제 DBMS가 어느 쪽을 변환하는지, collation과 Index 사용을 EXPLAIN으로 확인한다. 수천 개 ID를 `IN`에서 임시 테이블 Join으로 바꿀 때도 중복 제거·트랜잭션 수명·통계와 임시 테이블 정리 비용을 포함해 p95·Buffer·전송량을 비교한다.

> **면접 포인트** — SQL 모양을 고치는 데서 끝내지 말고 데이터 타입, timezone·collation 의미, 분포, Index 순서, 실행계획, 반환 행과 쓰기 비용을 연결한다.$review_23_database_15_query_antipattern_review$
WHERE slug = 'database-15-query-antipattern-review' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_infra_01_aws_core$## 1. Region(리전) / Availability Zone(가용영역)

> **한 줄 정의** — Region(리전) = 지리적 위치(서울 ap-northeast-2), AZ(가용영역) = 리전 안의 *물리적으로 격리된* 데이터센터 묶음.

AZ는 리전 안에서 독립적인 전원·네트워크 장애 도메인으로 운영된다. AZ 간 연결성과 실제 장애 범위는 리전·서비스별 문서를 확인해야 한다. 따라서 **가용성 설계의 출발점은 단일 장애 도메인에 핵심 경로를 몰아넣지 않는 것**이며, 필요한 AZ 수는 RTO/RPO와 서비스별 배치 제약으로 결정한다.

```mermaid
flowchart TB
    subgraph Region["🌏 Region: ap-northeast-2 (서울)"]
        subgraph AZa["AZ-a"]
            A1["EC2 / RDS Primary"]
        end
        subgraph AZc["AZ-c"]
            A2["EC2 / RDS Standby"]
        end
        subgraph AZd["AZ-d"]
            A3["EC2"]
        end
    end
    Users(["👤 사용자"]) --> R53["Route 53 + ELB"]
    R53 --> A1
    R53 --> A2
    R53 --> A3
    A1 -. "동기 복제" .-> A2

    style Region fill:#f8fafc,stroke:#94a3b8
    style A1 fill:#dbeafe,stroke:#3b82f6
    style A2 fill:#fef3c7,stroke:#f59e0b
    style A3 fill:#dcfce7,stroke:#22c55e
```

*단일 리전 / Multi-AZ 구성 — 면접 단골: "왜 Multi-AZ가 기본인가"*

### Multi-AZ vs Multi-Region — RTO/RPO 로 결정

무작정 Multi-Region(다중 리전)으로 가면 비용·복잡도가 폭발한다. **RTO(Recovery Time Objective, 복구 목표 시간)**와 **RPO(Recovery Point Objective, 복구 목표 시점=허용 데이터 손실)**를 숫자로 정해야 한다.

| 전략 | RTO | RPO | 비용·복잡도 | 적합 워크로드 |
| --- | --- | --- | --- | --- |
| 단일 AZ | 백업·복구 절차에 의존 | 마지막 백업 또는 복제 지점 | 기준 비용은 서비스별 산정 | 개발/스테이징, 비핵심 배치 |
| Multi-AZ | 서비스별 자동 전환 시간 | 복제 방식에 따라 다름 | 추가 리소스·전송·운영 복잡도 | AZ 장애를 견뎌야 하는 프로덕션 |
| Multi-Region Active-Passive | 복구 자동화 수준에 의존 | 보통 비동기 복제 지연의 영향을 받음 | 두 리전 리소스와 페일오버 절차 | 리전 장애까지 요구되는 핵심 경로 |
| Multi-Region Active-Active | 트래픽 전환·충돌 해결 설계에 의존 | 쓰기 모델과 복제 방식에 의존 | 가장 높은 데이터·운영 복잡도 | 글로벌 지연 또는 리전 연속성이 요구되는 경우 |

> **🎯 면접 포인트**
>
> "고가용성 어떻게 설계?"에 **"서버 2대 띄운다"** 는 미흡. 두 서버가 **같은 AZ면 의미 없다** . "최소 2 AZ, RDS는 Multi-AZ, ELB가 AZ별 헬스체크 후 라우팅"까지 말해야 시니어 눈높이. 그리고 "리전 장애까지 막을지는 RTO/RPO와 비용으로 판단한다"로 마무리. 🔥(Deep-dive)

## 2. VPC / Subnet / Security Group

> **한 줄 정의** — VPC(Virtual Private Cloud, 가상 사설망) = AWS 안에 내가 만드는 격리된 네트워크. 그 안을 Public/Private *Subnet(서브넷)*으로 쪼갠다.

```mermaid
flowchart TB
    IGW["🌐 Internet Gateway"]
    subgraph VPC["VPC 10.0.0.0/16"]
        subgraph Pub["Public Subnet 10.0.1.0/24"]
            ALB["ALB"]
            NAT["NAT Gateway"]
        end
        subgraph Priv["Private Subnet 10.0.10.0/24"]
            APP["App (ECS/EKS)"]
        end
        subgraph Data["Private Subnet 10.0.20.0/24 (DB)"]
            RDS[("RDS")]
        end
        VEP["VPC Endpoint → S3"]
    end
    Internet(["인터넷"]) --> IGW --> ALB --> APP
    APP --> RDS
    APP -->|"아웃바운드 (패치 등)"| NAT --> IGW
    APP -.->|"S3 트래픽은 NAT 우회"| VEP

    style Pub fill:#dbeafe,stroke:#3b82f6
    style Priv fill:#dcfce7,stroke:#22c55e
    style Data fill:#fef3c7,stroke:#f59e0b
    style VEP fill:#ede9fe,stroke:#8b5cf6
```

*표준 3-tier VPC — ALB만 Public, App/DB는 Private. S3는 VPC Endpoint로 NAT 비용 회피*

### Public Subnet vs Private Subnet

- **Public**: Route table(라우팅 테이블)에 `0.0.0.0/0 → IGW` 경로가 있는 서브넷. 여기엔 ALB, NAT Gateway, Bastion만 둔다.
- **Private**: IGW 직결 경로가 없다. 외부에서 직접 접근 불가. App 서버·DB는 전부 여기. 아웃바운드가 필요하면 **NAT Gateway**를 경유.

### Security Group(보안그룹) vs NACL — 가장 헷갈리는 비교

| 관점 | Security Group(보안그룹) | NACL(Network ACL) |
| --- | --- | --- |
| 적용 레벨 | ENI(인스턴스 단위) | Subnet(서브넷 단위) |
| Stateful 여부 | **Stateful(상태 추적)** — 인바운드 허용하면 응답 아웃바운드 자동 허용 | **Stateless(상태 비저장)** — 인/아웃 각각 규칙 필요 |
| 규칙 종류 | Allow만 가능 | Allow + Deny 가능 |
| 평가 순서 | 전체 규칙 평가 | 번호 순 (낮은 번호 우선) |
| 주 용도 | 일상 방화벽 (이걸 주력으로) | 특정 IP 블랙리스트, 서브넷 경계 보강 |

> **⚠️ 실무 함정**
>
> S3·DynamoDB처럼 VPC endpoint 경로를 지원하는 서비스는 NAT를 우회하는 Gateway Endpoint를 후보로 둔다. 그 밖의 AWS API는 Interface Endpoint 또는 NAT가 필요할 수 있으며, endpoint·NAT·리전·트래픽 요금은 현재 가격표와 경로별 데이터 처리량으로 계산한다. `0.0.0.0/0` 허용은 목적·포트·소스가 불명확한 규칙이므로 최소 권한 SG와 라우팅 검토를 우선한다. 🔥(Deep-dive)

## 3. EC2 / ECS / EKS — 컴퓨트 선택

"컨테이너 띄우려면 EKS 쓰세요"로 끝내면 안 된다. 팀 규모·운영 역량·워크로드 특성에 따라 **단일 EC2 → ECS Fargate → EKS** 스펙트럼에서 선택한다.

| 옵션 | 운영 부담 | 유연성 | 비용 | 적합한 팀/상황 |
| --- | --- | --- | --- | --- |
| **EC2 (직접)** | 높음 (OS 패치·스케일 직접) | 최고 | 인스턴스·라이선스·운영비를 별도 산정 | 특수 워크로드, 레거시, GPU |
| **ECS on Fargate** | **낮음 (서버리스 컨테이너)** | 중 | 중상 (vCPU·메모리 단위 과금) | K8s 운영 인력 없는 중소 팀, 대부분의 웹 API |
| **ECS on EC2** | 중 | 중상 | 노드 용량·예약·운영비를 별도 산정 | 컨테이너 밀도와 노드 제어가 중요한 경우 |
| **EKS** | 높음 (K8s 자체 운영) | 최고 (CNCF 생태계) | 중상 (+ 컨트롤플레인 시간당 요금) | 대규모, 멀티팀, K8s 표준 필요 |
| **Lambda** | 최저 | 낮음 (실행·동시성·패키지 제약) | 요청·실행 시간·옵션별 산정 | 이벤트 처리, 간헐적 워크로드 |

> **💡 실무 의사결정**
>
> ECS Fargate와 EKS의 선택은 팀의 Kubernetes 운영 역량, 요구하는 제어면 기능, 워크로드 제약, 현재 가격표를 함께 비교한다. 특정 인원 수나 회사 사례를 기준으로 일반화하지 말고, 운영 소유권과 장애 대응 능력을 결정 근거로 남긴다.

### Lambda 운영 함정

- **Cold start(콜드 스타트)**: 실행 환경 생성 시간이 요청 지연에 영향을 줄 수 있다. 지연 목표가 있으면 초기화 코드·패키지 크기·동시성 설정을 측정하고 Provisioned Concurrency 같은 선택지를 검토한다.
- **VPC 연결**: VPC 리소스에 접근해야 할 때만 연결하고, 서브넷·보안그룹·DNS·네트워크 경로를 함께 검증한다.
- **실행 한도**: 장시간 작업은 Lambda의 현재 서비스 한도와 워크로드 시간을 비교하고, 초과하면 ECS Task·Step Functions 등 다른 실행 모델을 검토한다.

## 4. ELB — ALB vs NLB vs API Gateway

```mermaid
flowchart LR
    C(["클라이언트"]) --> ALB["ALB (L7)\nHTTP 라우팅·경로기반"]
    C --> NLB["NLB (L4)\nTCP·초저지연·고정 IP"]
    C --> APIGW["API Gateway\n인증·쓰로틀·매핑"]
    ALB --> S1["/orders → 주문 서비스"]
    ALB --> S2["/track → 추적 서비스"]
    NLB --> S3["gRPC / TCP 백엔드"]
    APIGW --> L["Lambda / 백엔드"]

    style ALB fill:#dbeafe,stroke:#3b82f6
    style NLB fill:#fef3c7,stroke:#f59e0b
    style APIGW fill:#ede9fe,stroke:#8b5cf6
```

*로드밸런서 3종 선택 — L7 라우팅이면 ALB, L4 초저지연이면 NLB, API 관리 기능이면 API Gateway*

| 관점 | ALB (Application LB) | NLB (Network LB) | API Gateway |
| --- | --- | --- | --- |
| OSI 레벨 | L7 (HTTP/HTTPS) | L4 (TCP/UDP) | L7 (관리형) |
| 라우팅 | 경로/호스트/헤더 기반 | 없음 (단순 분배) | 리소스·메서드 단위 |
| 지연 | 네트워크·TLS·규칙 구성에 의존 | 네트워크·프로토콜에 의존 | 기능·통합 구성에 의존 |
| 강점 | WAF·SSL 종료·콘텐츠 라우팅 | 극단적 처리량, gRPC | API 유형별 인증·쓰로틀·요청 변환·사용량 플랜 |
| 비용 | 중 (LCU 단위) | 중 | 요청당 (트래픽 크면 비쌈) |

API Gateway의 기능은 API 유형(REST API·HTTP API·WebSocket API)에 따라 다르다. 특히 **usage plan과 API key 기반 사용량·클라이언트별 throttling은 REST API 기능**으로 분류해 확인하고, HTTP API를 같은 기능 집합으로 가정하지 않는다. 선택 전 [REST API와 HTTP API 비교 문서](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-vs-rest.html)와 [usage plan 문서](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-api-usage-plans.html)를 현재 리전·요구사항에 맞춰 확인한다.

> **⚠️ 실무 함정**
>
> API Gateway와 ALB의 비용은 요청 수, 데이터 처리량, 기능, 리전, 인증·WAF 구성에 따라 달라진다. 고빈도 폴링이라면 현재 가격표와 예상 요청·응답량으로 두 경로를 계산하고, API Gateway의 인증·쓰로틀·정책 기능을 직접 구현·운영할 비용까지 포함해 결정한다.

## 5. RDS / Aurora / S3 — 데이터 계층

### RDS Multi-AZ vs Read Replica — 자주 혼동

아래 표는 **RDS Multi-AZ DB instance 배포의 단일 standby**와 Read Replica를 비교한 것이다. RDS의 Multi-AZ DB cluster는 별도 모델로, writer와 두 개의 readable reader 인스턴스 및 reader endpoint를 제공할 수 있으므로 같은 “standby는 읽지 못한다” 규칙으로 일반화하지 않는다. 실제 엔진·리전·배포 유형은 [Multi-AZ DB instance 문서](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZSingleStandby.html)와 [Multi-AZ DB cluster 문서](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/multi-az-db-clusters-concepts.html)에서 확인한다.

| 관점 | Multi-AZ Standby | Read Replica(읽기 복제본) |
| --- | --- | --- |
| 목적 | **가용성** (장애 시 Failover) | **읽기 확장** (조회 부하 분산) |
| 복제 방식 | 동기 (Synchronous) | 비동기 (Asynchronous, 지연 존재) |
| 트래픽 수용 | Standby는 평소 트래픽 안 받음 | 읽기 쿼리 직접 받음 |
| 승격 | 서비스·엔진 구성에 따른 자동 전환 | 읽기 복제본을 승격하는 별도 절차 |

| 별도 배포 모델 | Multi-AZ DB cluster | 기존 Multi-AZ DB instance standby와 구분 |
| --- | --- | --- |
| 읽기 경로 | reader 인스턴스·reader endpoint를 사용할 수 있음 | 단일 standby가 평소 애플리케이션 트래픽을 받는 모델로 보지 않음 |
| 복제·전환 | 세부 동작·지원 엔진은 공식 문서와 배포 유형을 확인 | 서비스·엔진 구성에 따라 자동 전환 |

### Aurora — 공유 스토리지 아키텍처

Aurora는 컴퓨트와 분산 스토리지 계층을 분리하고, 여러 DB 인스턴스가 클러스터 스토리지를 공유하는 구조다. 복제·장애 전환·지원 엔진의 세부 동작과 한도는 엔진·리전·현재 공식 문서를 확인한다. RDS와 Aurora의 비용·기능 차이는 워크로드와 현재 가격표로 비교한다.

### S3 — 스토리지 클래스 수명주기

```mermaid
flowchart LR
    Up["업로드"] --> Std["S3 Standard\n자주 접근"]
    Std -->|"정책 기준일 후"| IA["Standard-IA\n가끔 접근"]
    IA -->|"정책 기준일 후"| Gla["Glacier 계열\n아카이브"]
    Gla -->|"수명주기 만료"| Del["삭제"]

    style Std fill:#dbeafe,stroke:#3b82f6
    style IA fill:#fef3c7,stroke:#f59e0b
    style Gla fill:#ede9fe,stroke:#8b5cf6
    style Del fill:#fee2e2,stroke:#ef4444
```

*S3 Lifecycle(수명주기) — 접근 패턴·보존 정책에 따라 저장 클래스를 전환*

> **💡 물류 연결 — 배송 사진(POD) 보관**
>
> 배송 증빙(Proof of Delivery, 배송완료 사진)은 보존 기간, 조회 빈도, 법적·계약상 삭제 요구를 먼저 정의한다. 그 뒤 Standard·Infrequent Access·Glacier 계열과 복원 시간·요금을 현재 S3 문서와 가격표로 비교해 Lifecycle 규칙을 만든다.

## 6. SQS / SNS — 메시징 / 비동기

```mermaid
sequenceDiagram
    participant Prod as 주문 서비스
    participant SNS as SNS (Topic)
    participant SQS1 as SQS: 알림 큐
    participant SQS2 as SQS: 정산 큐
    participant W1 as 알림 워커
    participant W2 as 정산 워커

    Prod->>SNS: publish(OrderPlaced)
    SNS->>SQS1: fan-out
    SNS->>SQS2: fan-out
    SQS1->>W1: poll
    SQS2->>W2: poll
    Note over SQS1,W1: 실패 시 재시도 → DLQ(Dead Letter Queue)
```

*SNS Fan-out + SQS — 한 이벤트를 여러 소비자에게. Pub/Sub + 버퍼링의 표준 조합*

| 관점 | SQS | SNS |
| --- | --- | --- |
| 모델 | Queue (1:1 소비, 풀) | Pub/Sub Topic (1:N, 푸시) |
| 순서/중복 | Standard(순서X) / FIFO(순서·중복제거) | FIFO Topic 지원 |
| 버퍼링 | O (소비자 다운돼도 메시지 보존) | X (구독자에게 즉시 전달) |
| 대표 용도 | 작업 큐, 부하 평탄화 | 이벤트 팬아웃 |

> **🎯 면접 포인트**
>
> "SQS와 Kafka 차이?" → SQS는 **완전관리형 작업 큐** (메시지 소비 후 삭제, 운영 부담 없음). Kafka(MSK)는 **로그 기반 스트림** (오프셋으로 재처리·다중 컨슈머 그룹, 높은 처리량·순서 보장 강력하나 운영 복잡). 수천만 TrackingEvent/일을 여러 소비자가 재처리해야 하면 Kafka, 단순 작업 분배·버퍼면 SQS. 🔥(Deep-dive)

## 7. CloudFront — CDN / 엣지

**CloudFront(CDN, Content Delivery Network)**는 전 세계 엣지 로케이션에 콘텐츠를 캐싱해 사용자 가까이서 응답한다. 정적 자원(이미지·JS·CSS)은 물론 동적 API도 캐시 키 설정으로 일부 캐싱 가능.

- **오리진 보호(OAC, Origin Access Control)**: S3 버킷을 직접 공개하지 말고 CloudFront만 접근하게. S3는 비공개 유지.
- **Cache key(캐시 키)**: 어떤 헤더·쿼리스트링을 캐시 분리 기준으로 쓸지. 잘못 잡으면 캐시 히트율 폭락 또는 사용자별 콘텐츠가 섞임.
- **Lambda@Edge / CloudFront Functions**: 엣지에서 헤더 조작·AB 테스트·리다이렉트.

> **⚠️ 실무 함정**
>
> 캐시 키에 `Authorization` 헤더나 사용자 토큰을 무심코 넣으면 **캐시 히트율이 0에 수렴** 해 CDN 의미가 사라진다. 반대로 사용자별로 달라야 할 응답을 공용 캐싱하면 **다른 사람 데이터 노출** 이라는 보안 사고. 캐시 가능 여부를 응답 헤더( `Cache-Control` )로 명확히 분리하라.

## 8. 물류 시스템을 AWS로 — 종합 매핑

```mermaid
flowchart TB
    U(["📱 고객 앱"]) --> CF["CloudFront"]
    CF --> ALB["ALB (Public Subnet)"]
    ALB --> OMS["주문 서비스\n(ECS Fargate, Private)"]
    OMS --> RDS[("RDS Aurora\nMulti-AZ")]
    OMS -->|"OrderPlaced"| SNS["SNS Topic"]
    SNS --> Q1["SQS: 재고 큐"]
    SNS --> Q2["SQS: 추적 큐"]
    Q1 --> WMS["WMS 워커 (Fargate)"]
    Q2 --> TRK["추적 파이프라인 (Fargate)"]
    TRK --> DDB[("DynamoDB\n추적 이벤트")]
    WMS --> S3["S3: POD 사진"]

    style ALB fill:#dbeafe,stroke:#3b82f6
    style OMS fill:#dbeafe,stroke:#3b82f6
    style WMS fill:#fef3c7,stroke:#f59e0b
    style TRK fill:#dcfce7,stroke:#22c55e
    style SNS fill:#ede9fe,stroke:#8b5cf6
```

*주문→재고→추적 파이프라인의 AWS 매핑 — Multi-AZ Aurora + SNS/SQS 팬아웃 + DynamoDB 추적*

> 예고된 주문 폭주에서는 실제 QPS·요청 크기·DB 커넥션·워커 처리량을 부하 모델로 검증한다. ECS 오토스케일의 감지·기동 시간은 구성과 용량에 따라 달라지므로 사전 확장과 큐의 보존·재시도·DLQ 정책을 함께 설계한다. SNS/SQS가 지연을 흡수해도 재고·결제의 지속 가능 처리량을 늘리지는 않는다.

```text
VPC
├─ public subnet: ALB, NAT Gateway
├─ private app subnet: ECS/EKS workload
└─ isolated data subnet: RDS/ElastiCache
```

## 9. 실패 흐름과 검증 순서

- Private Subnet의 외부 API 호출이 실패하면 라우팅 테이블, NAT 경로, 보안그룹·NACL, DNS, 외부 API의 허용 IP를 순서대로 확인한다. S3 요청이 예상치 않게 NAT를 타면 endpoint 정책·라우팅·버킷 정책을 함께 확인하고, 경로를 바꾼 뒤 비용만으로 성공을 판단하지 않는다.
- Multi-AZ 장애 전환 중 DB 연결이 끊길 수 있으므로 애플리케이션은 연결 재수립, 지수 백오프, 요청 멱등성을 갖춘다. Read Replica의 지연을 무시하고 즉시 읽으면 최신성 요구를 위반할 수 있어 읽기 일관성 정책을 분리한다.
- SQS 표준 큐의 중복 전달과 순서 비보장을 전제로 소비자는 멱등키, visibility timeout, DLQ, 재처리 관찰 지표를 갖춘다. FIFO를 선택할 때는 메시지 그룹과 중복 제거 범위를 요구사항과 맞춘다.
- CloudFront 캐시가 잘못된 대상을 공유하면 사용자 데이터가 노출될 수 있다. 캐시 정책·origin request policy·응답 `Cache-Control`을 함께 검토하고, 개인정보 응답은 캐시 금지 또는 사용자별 키를 명시한다.

## 10. 참고 자료

- [AWS Global Infrastructure: Regions and Availability Zones](https://docs.aws.amazon.com/global-infrastructure/latest/regions/aws-regions.html)
- [Amazon VPC endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html) 및 [NAT gateways](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html)
- [Amazon ECS on AWS Fargate](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html) 및 [AWS Lambda quotas](https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html)
- [Elastic Load Balancing](https://docs.aws.amazon.com/elasticloadbalancing/latest/userguide/what-is-load-balancing.html)
- [Amazon RDS Multi-AZ deployments](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.html)
- [Amazon RDS Multi-AZ DB instance deployments](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZSingleStandby.html)
- [Amazon RDS Multi-AZ DB cluster deployments](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/multi-az-db-clusters-concepts.html)
- [Amazon API Gateway REST APIs and HTTP APIs](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-vs-rest.html)
- [Amazon API Gateway usage plans](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-api-usage-plans.html)
- [Amazon S3 object Lifecycle Management](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html)
- [Amazon SQS at-least-once delivery](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/standard-queues-at-least-once-delivery.html)
- [CloudFront Origin Access Control](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html)$review_23_infra_01_aws_core$
WHERE slug = 'infra-01-aws-core' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_infra_02_kubernetes$## 1. 왜 Kubernetes인가 — 제어 루프(Reconciliation Loop)

> **핵심 멘탈 모델** — "원하는 상태(Desired State)"를 선언하면 K8s가 "현재 상태(Current State)"와 끊임없이 비교해 *차이를 메운다*. Pod이 죽으면 다시 띄우는 것도 이 루프.

```mermaid
flowchart LR
    Spec["사용자 선언\nreplicas: 3"] --> API["API Server (etcd)"]
    API --> CM["Controller\n원하는 상태 vs 현재 비교"]
    CM -->|"차이 발견"| Sched["Scheduler\n노드 배정"]
    Sched --> Kubelet["Kubelet\nPod 기동"]
    Kubelet -->|"현재 상태 보고"| API
    CM -.->|"Pod 죽음 감지 → 재생성"| Sched

    style API fill:#dbeafe,stroke:#3b82f6
    style CM fill:#fef3c7,stroke:#f59e0b
    style Sched fill:#ede9fe,stroke:#8b5cf6
    style Kubelet fill:#dcfce7,stroke:#22c55e
```

*K8s 제어 루프 — 명령형(서버에 직접 명령)이 아니라 선언형(상태를 선언하고 수렴 맡김)*

> **🎯 면접 포인트**
>
> "K8s가 self-healing(자가 치유)된다는 게 무슨 뜻?" → "Pod이 죽으면 ReplicaSet 컨트롤러가 원하는 replica 수와 현재 수의 차이를 감지해 자동 재생성한다"는 **제어 루프** 로 답해야 한다. "알아서 살려준다"는 표현은 원리를 모른다는 신호.

## 2. Pod / ReplicaSet / Deployment

| 오브젝트 | 책임 | 비유 |
| --- | --- | --- |
| **Pod** | 컨테이너 1개 이상을 묶은 **최소 배포 단위**. 같은 네트워크·볼륨 공유 | 실행 중인 프로세스 한 묶음 |
| **ReplicaSet** | 지정한 수만큼 Pod을 유지 (죽으면 재생성) | "항상 N개 켜둬" |
| **Deployment** | ReplicaSet을 관리하며 **롤링 업데이트·롤백** 제공 | 버전 배포 관리자 |

실무에선 Pod이나 ReplicaSet을 직접 만들지 않고 **Deployment**를 선언한다. Deployment가 새 버전 ReplicaSet을 만들고 옛 것을 줄이며 무중단 전환한다.

> **💡 Pod 안에 컨테이너 여러 개? (Sidecar)**
>
> 한 Pod = 한 컨테이너가 기본이지만, **Sidecar(사이드카) 패턴** 으로 로그 수집기·프록시(Envoy)·메트릭 익스포터를 같이 둔다. 같은 `localhost` 로 통신하고 생명주기를 공유한다. Service Mesh가 이 방식.

## 3. Service / Ingress — 트래픽 들어오는 길

```mermaid
flowchart TB
    U(["🌐 외부 사용자"]) --> ING["Ingress\n(L7 라우팅, /orders /track)"]
    ING --> SVC1["Service: order-svc\n(ClusterIP)"]
    ING --> SVC2["Service: track-svc\n(ClusterIP)"]
    SVC1 --> P1["Pod"]
    SVC1 --> P2["Pod"]
    SVC2 --> P3["Pod"]
    SVC2 --> P4["Pod"]

    style ING fill:#ede9fe,stroke:#8b5cf6
    style SVC1 fill:#dbeafe,stroke:#3b82f6
    style SVC2 fill:#dbeafe,stroke:#3b82f6
```

*Ingress → Service → Pod. Service는 변하는 Pod IP들 앞의 안정적 가상 IP + 로드밸런싱*

| Service 타입 | 노출 범위 | 용도 |
| --- | --- | --- |
| **ClusterIP** | 클러스터 내부만 | 서비스 간 내부 통신 (기본) |
| **NodePort** | 노드 IP:포트 | 간단 외부 노출 (실무엔 잘 안 씀) |
| **LoadBalancer** | 클라우드 LB 프로비저닝 | 외부 노출; 구현은 클라우드·컨트롤러에 의존 |
| **Ingress** | L7 경로/호스트 라우팅 | 여러 서비스를 공통 진입점으로 연결; Ingress controller 필요 |

> **⚠️ 실무 함정**
>
> 서비스마다 `type: LoadBalancer`를 만들면 클라우드 컨트롤러가 여러 외부 로드밸런서를 만들 수 있다. Ingress를 선택할 때는 지원하는 IngressClass, 장애 도메인, TLS·라우팅 정책, 로드밸런서 비용을 현재 클라우드 문서와 함께 검토한다.

## 4. ConfigMap / Secret — 설정 분리

**12-Factor App** 원칙: 설정은 코드에서 분리해 환경에 주입한다. K8s는 `ConfigMap`(비민감 설정)과 `Secret`(민감 정보)으로 이를 제공.

- **ConfigMap**: 환경변수·설정파일 (예: 로그 레벨, 외부 URL).
- **Secret**: DB 비밀번호·API 키. 기본은 **base64 인코딩일 뿐 암호화 아님**. etcd 암호화(KMS) + RBAC로 접근 제한 필요.

> **⚠️ 실무 함정**
>
> Secret을 Git에 평문/base64로 커밋하면 누구나 원문을 복원할 수 있다. Kubernetes Secret 자체의 저장·전송 보호, RBAC, 외부 secret manager 연동, 키 회전 절차를 환경에 맞게 설계한다. 환경변수와 파일 마운트 중 어떤 방식이 안전한지는 애플리케이션·런타임의 로그와 덤프 처리까지 확인해 결정한다. 🔥(Deep-dive)

## 5. Requests / Limits — 스케줄링과 OOM의 핵심

> **정의** — **requests** = 스케줄러가 노드 배치 시 보장하는 최소 자원. **limits** = 초과 시 제한(CPU는 throttle, 메모리는 *OOMKill*).

### QoS Class — 노드 압박 시 제거될 가능성

| QoS Class | 조건 | 일반적인 제거(Evict) 경향 |
| --- | --- | --- |
| **Guaranteed** | 모든 컨테이너의 CPU·메모리 requests와 limits가 설정되고 서로 같음 | 사용량이 requests를 넘지 않으면 상대적으로 뒤로 밀릴 수 있음 |
| **Burstable** | requests 또는 limits가 일부 설정되거나 서로 다름 | 사용량이 requests를 넘는 정도·Priority 등에 따라 달라짐 |
| **BestEffort** | requests·limits 미설정 | 사용량이 requests를 넘는 것으로 취급되어 먼저 대상이 되기 쉬움 |

QoS Class만으로 고정된 eviction 순서를 정할 수 없다. 노드 압박 eviction은 Pod의 실제 자원 사용량이 requests를 넘는지, Pod Priority, requests 대비 사용량 등을 함께 보고 순위를 정하며, **Guaranteed도 노드 압박이나 다른 종료 원인에서 면제되지 않는다**. 따라서 이 표는 일반적인 경향으로만 사용하고 [node-pressure eviction 공식 문서](https://kubernetes.io/docs/concepts/scheduling-eviction/node-pressure-eviction/)의 현재 kubelet 동작을 확인한다.

> **🎯 면접 포인트**
>
> "Pod이 자꾸 OOMKilled 되는데 원인은?" → 컨테이너 메모리 사용이 `limits.memory` 를 초과해 커널 OOM Killer가 죽인 것. 해결: ① 실제 사용량을 메트릭으로 측정해 limit 상향 ② 메모리 누수 점검 ③ JVM이면 `-Xmx` 를 limit보다 낮게(헤드룸 확보). **limit을 아예 안 걸면 Pod 하나가 노드 전체 메모리를 먹어 노드가 죽는다** — 더 위험. 🔥(Deep-dive)

## 6. HPA — Horizontal Pod Autoscaler (수평 오토스케일)

```mermaid
flowchart LR
    M["Metrics Server\n(CPU/메모리/커스텀)"] --> HPA["HPA 컨트롤러"]
    HPA -->|"목표 70% 초과"| Up["replicas ↑"]
    HPA -->|"목표 미만 지속"| Down["replicas ↓"]
    Up --> Dep["Deployment"]
    Down --> Dep
    Dep --> Nodes["노드에 Pod 분산"]
    CA["Cluster Autoscaler / Karpenter"] -.->|"노드 부족 시 노드 추가"| Nodes

    style HPA fill:#dcfce7,stroke:#22c55e
    style CA fill:#fef3c7,stroke:#f59e0b
```

*HPA(Pod 수 조절) + Cluster Autoscaler(노드 수 조절) — 두 층이 함께 동작해야 진짜 탄력*

### 스케일링 3종 비교

| 스케일러 | 무엇을 조절 | 기준 |
| --- | --- | --- |
| **HPA** | Pod **개수** (수평) | CPU·메모리·커스텀 메트릭(QPS·큐 길이) |
| **VPA** | Pod의 **requests/limits** (수직) | 실사용량 학습 |
| **Cluster Autoscaler / Karpenter** | **노드** 개수 | 스케줄 못 된 Pending Pod 존재 여부 |

> **💡 커스텀 메트릭으로 진짜 부하 반영**
>
> CPU 기반 HPA만으로는 I/O 대기나 큐 backlog를 충분히 표현하지 못할 수 있다. **처리해야 할 큐의 age·backlog, 요청률, 동시 작업 수** 같은 워크로드 메트릭을 서비스 처리량과 연결해 선택한다. KEDA를 쓰면 외부·이벤트 메트릭으로 스케일할 수 있지만, 메트릭 수집 지연·0까지 축소·인증 실패·하위 시스템 포화까지 함께 검증해야 한다.

## 7. 롤링 업데이트 + Probe — 무중단 배포

```mermaid
sequenceDiagram
    participant D as Deployment
    participant RSnew as 새 ReplicaSet (v2)
    participant RSold as 옛 ReplicaSet (v1)
    participant SVC as Service

    D->>RSnew: Pod v2 1개 생성 (maxSurge)
    RSnew->>SVC: readinessProbe 통과 후 트래픽 편입
    D->>RSold: Pod v1 1개 종료 (maxUnavailable)
    Note over D: 위 과정 반복 → 전부 v2로
    Note over RSold: 문제 시 rollout undo → v1 ReplicaSet 복귀
```

*롤링 업데이트 — maxSurge/maxUnavailable과 readiness 상태로 전환 폭을 제어한다. readiness 통과 전에는 일반적으로 Service 엔드포인트에서 제외된다.*

### 3종 Probe 구분 — 가장 많이 틀리는 부분

| Probe | 질문 | 실패 시 |
| --- | --- | --- |
| **livenessProbe** | "이 Pod 살아있나? (데드락 아닌가)" | 컨테이너 **재시작** |
| **readinessProbe** | "트래픽 받을 준비 됐나?" | Service에서 **트래픽 제외** (재시작 X) |
| **startupProbe** | "기동 완료됐나? (느린 시작)" | 완료까지 liveness 유예 |

> **⚠️ 실무 함정 — Probe 혼동이 장애를 만든다**
>
> **livenessProbe를 공격적으로** 설정하면 일시적 부하나 하위 시스템 지연에도 Pod이 계속 재시작되는 재시작 루프가 생길 수 있다. liveness는 프로세스가 복구 불가능한 상태인지, readiness는 현재 트래픽을 받을 수 있는지를 구분하고, 느린 초기화는 startupProbe로 보호한다. probe가 실패할 때 재시작·트래픽 제외·배포 중단이 어떻게 연쇄되는지 관찰한다. 🔥(Deep-dive)

## 8. 물류 연결 — 새벽 주문 폭주 오토스케일

> **💡 시나리오**
>
> 예고된 마감 직전 주문 증가를 평균 배율로만 표현하지 말고, 관측된 요청률·큐 backlog·처리량·DB 연결 상한을 입력으로 삼는다. 주문 API는 반응형 HPA와 사전 capacity를 비교하고, 재고 워커는 CPU보다 큐 age/backlog 기반 메트릭을 검토한다. 새 노드가 준비되기 전까지 Pending Pod이 쌓일 수 있으므로 Cluster Autoscaler 또는 다른 노드 프로비저너의 지연·실패 경로를 포함한다. 스케일 아웃이 하위 DB·결제·재고의 처리량을 초과하면 큐잉·rate limit·load shedding으로 입장을 제한한다.

```mermaid
flowchart TB
    Peak["예고된 주문 증가\n처리량 한도 확인"] --> HPA["HPA: 요청·처리량 메트릭"]
    Peak --> KEDA["KEDA: 재고 워커\n(큐 길이 기반)"]
    HPA --> CA["노드 프로비저너\nPending Pod 처리"]
    KEDA --> CA
    CA --> Done["✅ Cut-off 내 처리"]

    style Peak fill:#fee2e2,stroke:#ef4444
    style HPA fill:#dcfce7,stroke:#22c55e
    style KEDA fill:#dbeafe,stroke:#3b82f6
    style CA fill:#fef3c7,stroke:#f59e0b
```

*Cut-off 폭주 대응 — Pod 오토스케일 + 큐 기반 워커 스케일 + 노드 오토스케일 3층 협력*

## 9. 자주 나오는 함정 정리

| 함정 | 증상 | 해결 |
| --- | --- | --- |
| liveness/readiness 혼동 | 재시작 루프 또는 미준비 Pod에 트래픽 | 역할 분리, liveness는 관대하게 |
| memory limit 미설정 | 노드 전체 OOM, 연쇄 Eviction | requests/limits 항상 설정 |
| `latest` 태그 사용 | 어떤 이미지인지 불명, 롤백 불가 | 불변 태그(커밋 SHA) 사용 |
| graceful shutdown 누락 | 배포 중 진행 요청 끊김 | `preStop` + `terminationGracePeriod` |
| PVC를 Deployment에 | 여러 Pod이 같은 볼륨 경합 | 상태 있으면 StatefulSet |

```yaml
resources:
  requests: { cpu: "250m", memory: "256Mi" }
limits: { memory: "512Mi" }
readinessProbe:
  httpGet: { path: /api/v1/health, port: 8080 }
```

## 10. 실패 흐름과 운영 경계

- 새 ReplicaSet의 이미지 pull 또는 startupProbe가 실패하면 readiness를 통과하지 못한 Pod이 Service에 들어가지 않도록 하고, Deployment 진행이 멈추는 조건과 이전 ReplicaSet 유지 조건을 확인한다. `maxUnavailable`을 무리하게 올리면 정상 용량까지 줄어들 수 있다.
- readiness가 통과한 뒤 애플리케이션이 즉시 종료되면 진행 중 요청이 끊길 수 있다. `preStop`, `terminationGracePeriodSeconds`, 애플리케이션의 drain 신호, Service endpoint 전파 지연을 함께 측정한다.
- HPA가 외부 메트릭을 읽지 못하면 마지막 desired replica를 유지하거나 축소 정책이 예상과 달라질 수 있다. 메트릭 어댑터·KEDA 인증 실패, backlog 감소 지연, 노드 부족을 별도 알람으로 둔다.
- limit 초과로 OOMKilled 된 Pod은 limit만 올리면 메모리 누수와 노드 포화를 숨길 수 있다. requests·limits·QoS·노드 여유·heap 설정을 같이 확인하고, 변경 전후의 재시작과 eviction을 관찰한다.
- Secret 또는 이미지 자격증명 오류는 Pod가 `Pending`·`ImagePullBackOff`에 머무르게 할 수 있다. RBAC와 registry 접근권한을 확인하면서 비밀값을 로그에 출력하지 않는다.

## 11. 참고 자료

- [Kubernetes Concepts](https://kubernetes.io/docs/concepts/overview/)
- [Services and Ingress](https://kubernetes.io/docs/concepts/services-networking/service/) 및 [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Resource Management for Pods and Containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/) 및 [Pod QoS](https://kubernetes.io/docs/concepts/workloads/pods/pod-qos/)
- [Liveness, Readiness, and Startup Probes](https://kubernetes.io/docs/concepts/configuration/liveness-readiness-startup-probes/)
- [Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [KEDA concepts](https://keda.sh/docs/latest/concepts/)$review_23_infra_02_kubernetes$
WHERE slug = 'infra-02-kubernetes' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_infra_03_iac_terraform$## 1. 왜 IaC(Infrastructure as Code, 코드형 인프라)인가

> **한 줄 정의** — 인프라(VPC·서버·DB·보안그룹)를 *코드로 선언*해, 버전관리·리뷰·재현·자동화 대상으로 만든다.

| 관점 | 콘솔 수동(ClickOps) | IaC (Terraform) |
| --- | --- | --- |
| 재현성 | "누가 뭘 클릭했는지" 모름 | 코드로 동일 환경 재생성 |
| 변경 추적 | 없음 (감사 불가) | Git 히스토리 = 변경 이력 |
| 리뷰 | 불가 | PR 리뷰로 사전 검증 |
| 장애 복구 | 기억에 의존 | `apply`로 재구축 |
| 휴먼 에러 | 잦음 | `plan`으로 사전 차단 |

> **🎯 면접 포인트**
>
> "왜 콘솔로 안 하고 Terraform을 쓰나?" → 핵심 키워드는 **재현성·버전관리·코드 리뷰·감사 추적** . 한 단계 더: "DR(재해 복구) 리전을 코드 재사용으로 빠르게 구성할 수 있고, 변경을 `plan` 으로 미리 검토해 휴먼 에러를 막는다"까지.

## 2. plan / apply 워크플로

```mermaid
sequenceDiagram
    participant Dev as 개발자
    participant TF as Terraform CLI
    participant State as State 백엔드
    participant AWS as AWS API

    Dev->>TF: terraform plan
    TF->>State: 현재 상태 읽기
    TF->>AWS: 실제 리소스 조회 (refresh)
    TF-->>Dev: 차이(diff) 출력 (생성/변경/삭제)
    Note over Dev: 👀 plan 리뷰 — 필수!
    Dev->>TF: terraform apply
    TF->>AWS: 변경 적용
    TF->>State: 새 상태 저장
```

*plan(미리보기) → 리뷰 → apply(적용). plan 없이 apply하면 사고 — 면접에서 강조할 것*

```bash
# 표준 워크플로
terraform init      # 백엔드·프로바이더 초기화
terraform plan      # 변경 미리보기 (생성 +, 변경 ~, 삭제 -)
terraform apply     # 실제 적용 (plan 결과 재확인 후 yes)
terraform destroy   # 리소스 정리
```

> **⚠️ 실무 함정 — plan의 함정 신호**
>
> `plan` 출력에서 **destroy/recreate(삭제 후 재생성)** 표시( `-/+` )를 무심코 지나치면, 데이터가 있는 리소스가 교체될 수 있다. 어떤 속성 변경이 교체를 유발하는지는 provider와 리소스 문서를 확인한다. plan을 리뷰하고, 정말 삭제되면 안 되는 리소스에는 `prevent_destroy`를 보조 안전장치로 둔다. 이 설정도 모든 삭제 경로를 막는 것은 아니므로 백업·복구 절차를 함께 검증한다. 🔥(Deep-dive)

## 3. State(상태) — Terraform의 심장

> **왜 중요한가** — State 파일은 "코드가 선언한 리소스 ↔ 실제 클라우드 리소스 ID"의 *매핑 장부*. 이게 깨지면 Terraform이 현실을 못 본다.

```mermaid
flowchart TB
    Code["main.tf\n(원하는 상태)"] --> TF["Terraform"]
    AWS["실제 AWS 리소스\n(현재 상태)"] --> TF
    TF <--> State["State 파일\n(매핑 장부)"]
    State -.->|"Remote Backend"| S3[("공유 Backend + Lock")]

    style State fill:#ede9fe,stroke:#8b5cf6
    style S3 fill:#fef3c7,stroke:#f59e0b
```

*State는 코드·실제·장부 3자 간 진실. 팀 작업이면 반드시 Remote Backend + Lock*

### Local State vs Remote Backend

| 관점 | Local (로컬 파일) | Remote Backend (공유 저장소 + Lock) |
| --- | --- | --- |
| 협업 | 불가 (각자 다른 상태) | 공유 상태 |
| 동시 실행 | 충돌 위험 | **State Lock**으로 직렬화 |
| 민감정보 | 로컬 디스크 노출 | 암호화 저장 + 접근 제어 |
| 권장도 | 개인 실습만 | **팀/프로덕션 필수** |

> **⚠️ 실무 함정 — State 충돌**
>
> 공유 backend에 동시 실행 제어가 없으면 두 사람이 동시에 apply해 상태 저장과 실제 리소스 변경이 엇갈릴 수 있다. 사용 중인 backend의 공식 locking 방식을 활성화하고, backend의 버전 관리·암호화·접근 제어·복구를 별도로 설정한다. AWS S3 backend에서는 현재 문서의 `use_lockfile` 방식과 기존 DynamoDB locking 지원·폐기 일정을 확인해 적용한다. State에는 민감한 값이 포함될 수 있으므로 Git에 커밋하지 않고, 읽기 권한도 최소화한다. 🔥(Deep-dive)

## 4. 모듈(Module) — 재사용

**Module(모듈)**은 리소스 묶음을 함수처럼 재사용하는 단위. 같은 VPC 구조를 dev/staging/prod에 반복하지 말고 모듈로 추출한다.

```
module "vpc" {
  source = "./modules/vpc"
  cidr   = "10.0.0.0/16"
  azs    = ["ap-northeast-2a", "ap-northeast-2c"]
  env    = "prod"
}
```

- **Workspace**: 같은 코드로 여러 환경 상태를 분리 (단, 복잡 환경엔 디렉토리 분리가 더 명확).
- **Terragrunt**: Terraform 위 래퍼. DRY(반복 제거)·backend 설정 자동화·환경별 변수 관리에 유리.

> **💡 실무 권장**
>
> 모듈을 너무 잘게 쪼개면 추상화 비용이 커진다. **"네트워크 / 컴퓨트 / 데이터"** 정도의 굵은 경계로 모듈화하고, 환경별 차이는 변수로 흡수하는 게 유지보수에 좋다.

## 5. 멱등성(Idempotency) / 불변 인프라(Immutable Infrastructure)

> **멱등성이란** — 같은 구성과 실제 입력을 반복 적용했을 때 의도하지 않은 추가 리소스나 변경이 생기지 않도록 선언 상태로 수렴하는 성질이다. provider의 외부 변경·시간·랜덤 값·순서 의존성이 있으면 반복 실행 결과가 달라질 수 있다.

Terraform은 구성·state·provider가 읽은 실제 상태의 차이를 계산해 적용한다. 따라서 "원하는 상태와 현재 상태가 항상 자동으로 같아진다"고 가정하지 말고, provider의 refresh 오류·부분 실패·외부 변경을 plan과 운영 절차로 다룬다.

### 불변 인프라 원칙

- 서버를 **수정(mutate)하지 말고 교체(replace)**한다. 패치는 새 AMI/이미지를 굽고 인스턴스를 갈아끼운다.
- 장점: 환경 드리프트 제거, 롤백이 "이전 이미지로 교체"로 단순, 재현성↑.

> **🎯 면접 포인트**
>
> "멱등성이 왜 중요?" → 재시도 안전성. CI 파이프라인이 같은 apply를 중복 실행해도 인프라가 망가지지 않는다. 불변 인프라와 엮으면: "서버를 고치는 대신 교체하니 '내 서버에선 됐는데' 문제(드리프트)가 사라진다."

## 6. Drift(드리프트) 관리

**Drift** = 코드(State)와 실제 리소스가 어긋난 상태. 보통 누군가 콘솔에서 수동 변경해 발생한다.

```mermaid
stateDiagram-v2
    [*] --> InSync : apply 완료
    InSync --> Drifted : 누군가 콘솔 수동 변경
    Drifted --> Detected : plan/drift detection으로 발견
    Detected --> InSync : apply로 코드 상태 강제 복원
    Detected --> CodeUpdate : 변경이 정당하면 코드에 반영
    CodeUpdate --> InSync
```

*Drift 라이프사이클 — 수동 변경 금지 + 주기적 탐지 + 코드로 수렴*

> **⚠️ 실무 함정**
>
> "급해서 콘솔에서 SG 규칙 하나만 손댐" → 다음 apply 때 Terraform이 구성대로 되돌리거나, 반대로 코드가 실제 변경을 덮어써 장애가 날 수 있다. 변경 경로를 한 곳으로 정하고, 긴급 변경은 승인·기록 후 코드와 state에 반영한다. 주기적 plan이나 별도 drift detection은 탐지 수단이지 자동 복구의 안전성을 보장하지 않으므로 변경 영향과 롤백을 먼저 검토한다.

## 7. Terraform vs CDK vs Pulumi

| 도구 | 언어 | 강점 | 약점/선택 기준 |
| --- | --- | --- | --- |
| **Terraform** | HCL (선언형 DSL) | 멀티클라우드, 생태계·모듈 풍부, 표준 | 복잡 로직엔 표현력 한계 |
| **AWS CDK** | TS/Python/Java | AWS 깊은 통합, 친숙한 언어·추상화 | AWS 종속 (CloudFormation 기반) |
| **Pulumi** | TS/Python/Go | 범용 언어 + 멀티클라우드 | 생태계가 Terraform보다 작음 |

> **💡 선택 기준**
>
> 멀티클라우드·팀 표준·인프라 전담이면 **Terraform** . AWS 단일 + 개발자가 직접 인프라 코드를 쓰고 친숙한 언어를 원하면 **CDK** . "쿨하다고 Pulumi" 같은 결정은 생태계 성숙도·팀 역량을 먼저 따져라.

## 8. GitOps 개요

> **한 줄 정의** — **Git을 단일 진실 원천(Single Source of Truth)**으로 삼아, 선언된 상태를 동기화(주로 Pull 기반)한다. 자동 동기화는 controller와 정책에서 선택적으로 켠다.

```mermaid
flowchart LR
    Dev["개발자"] -->|"PR + merge"| Git["Git 저장소\n(원하는 상태)"]
    Git -->|"감지 & Pull"| Agent["ArgoCD / Flux\n(클러스터 내 에이전트)"]
    Agent -->|"동기화"| K8s["Kubernetes 클러스터\n(실제 상태)"]
    K8s -.->|"Drift 감지 → (self-heal 설정 시) 자동 복원"| Agent

    style Git fill:#dcfce7,stroke:#22c55e
    style Agent fill:#ede9fe,stroke:#8b5cf6
    style K8s fill:#dbeafe,stroke:#3b82f6
```

*GitOps — 자동 sync 정책이 켜진 ArgoCD/Flux에서는 Git 변경을 감지해 클러스터를 그 상태로 수렴. 배포가 Git 커밋을 입력으로 삼을 수 있음*

### Push 배포 vs Pull(GitOps) 배포

| 관점 | Push (CI가 클러스터에 kubectl apply) | Pull (GitOps, ArgoCD) |
| --- | --- | --- |
| 자격증명 | CI가 클러스터 접근 권한 보유 (위험) | 에이전트가 클러스터 안에서 Pull (외부 노출↓) |
| Drift 처리 | 수동 | 감지는 가능하며 복원은 controller·sync/self-heal 정책에 따름 |
| 롤백 | 스크립트 | **Git revert 후 자동 sync가 켜져 있으면** 원하는 상태로 수렴 |
| 감사 | 분산 | Git 히스토리 일원화 |

> **🎯 면접 포인트**
>
> "GitOps가 일반 CI/CD 배포와 뭐가 다른가?" → 선언적 구성과 Git 변경 이력을 배포의 입력으로 삼고, pull agent가 실제 상태를 수렴시키는 운영 모델이다. 자격증명 노출이 줄어들 수 있지만 agent 권한·저장소 신뢰·비밀값 전달·drift 정책을 별도로 설계해야 한다. Terraform과 Kubernetes GitOps의 경계는 조직과 도구에 따라 정하되, 같은 리소스를 두 시스템이 동시에 소유하지 않게 한다.

Argo CD는 수동 sync가 기본이며 자동 sync, self-heal, prune을 별도 정책으로 설정한다. 예를 들어 다음은 자동 sync와 drift 복원·고아 리소스 정리를 모두 켠 예시일 뿐, 모든 환경에 적용할 기본값은 아니다.

```yaml
spec:
  syncPolicy:
    automated:
      enabled: true
      selfHeal: true
      prune: true
```

## 9. 실패 흐름과 복구 경계

- `plan`이 provider 조회 오류로 불완전한 결과를 만들거나 refresh 중 권한 오류가 난 경우에는 결과를 승인하지 않는다. provider 버전·자격증명·대상 계정·state lock을 확인하고 정상 plan을 다시 생성한다.
- apply가 일부 리소스만 만든 뒤 실패할 수 있다. 즉시 `destroy`를 실행하지 말고 state와 실제 리소스를 조회해 이미 반영된 변경, 재시도 가능 작업, 수동 조정이 필요한 작업을 구분한다.
- `-/+` 교체가 표시되면 백업·복구·대체 리소스·트래픽 전환을 확인한 뒤 별도 승인한다. `prevent_destroy`는 보호 장치이며, state를 삭제하거나 다른 workspace를 적용하는 사고까지 막아주지 않는다.
- state lock을 획득하지 못하면 lock을 강제로 지우기 전에 해당 apply가 실제로 종료됐는지 확인한다. stale lock을 잘못 해제하면 동시 apply가 가능해진다.
- 콘솔 drift를 코드로 되돌릴지 코드에 반영할지 결정하지 않은 채 apply하지 않는다. 보안그룹·라우팅·데이터베이스 같은 리소스는 현재 트래픽과 데이터 영향부터 확인한다.

## 10. 참고 자료

- [Terraform plan command](https://developer.hashicorp.com/terraform/cli/commands/plan)
- [Terraform state](https://developer.hashicorp.com/terraform/language/state)
- [Terraform S3 backend and locking](https://developer.hashicorp.com/terraform/language/backend/s3)
- [Terraform lifecycle meta-arguments](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle)
- [Terraform backends](https://developer.hashicorp.com/terraform/language/backend)
- [OpenGitOps principles](https://opengitops.dev/)
- [Argo CD automated sync policy](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/)$review_23_infra_03_iac_terraform$
WHERE slug = 'infra-03-iac-terraform' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_infra_04_cicd_deploy_strategy$## 1. CI/CD 파이프라인 — 전체 흐름

```mermaid
flowchart LR
    Code["커밋/PR"] --> Build["Build\n빌드"]
    Build --> Test["Test\n단위·통합"]
    Test --> Scan["Scan\nSAST·SCA·이미지"]
    Scan --> Art["Artifact\n이미지 레지스트리"]
    Art --> Deploy["Deploy\n배포"]
    Deploy --> Smoke["Smoke\n핵심 경로 검증"]
    Smoke --> Mon["Monitor\n메트릭·알림"]
    Mon -.->|"이상 시"| RB["자동 롤백"]

    style Build fill:#dbeafe,stroke:#3b82f6
    style Scan fill:#fef3c7,stroke:#f59e0b
    style Deploy fill:#ede9fe,stroke:#8b5cf6
    style Mon fill:#dcfce7,stroke:#22c55e
    style RB fill:#fee2e2,stroke:#ef4444
```

*표준 파이프라인 — Build → Test → Scan → Artifact → Deploy → Smoke → Monitor. 마지막 Monitor가 롤백 트리거*

- **SAST(Static Application Security Testing, 정적 분석)**: 소스코드 취약점.
- **SCA(Software Composition Analysis)**: 의존 라이브러리 취약점(CVE).
- **Container scan**: 베이스 이미지 OS 패키지 취약점.

> **⚠️ 실무 함정**
>
> Smoke test(배포 후 핵심 경로 자동 검증)와 모니터링이 없으면, 배포는 "성공"인데 실제 서비스는 죽어있는 상황을 한참 뒤에야 안다. **Deploy의 마지막 게이트는 항상 "관측"** 이어야 한다.

## 2. CI / Continuous Delivery / Continuous Deployment

| 용어 | 의미 | 사람 개입 |
| --- | --- | --- |
| **CI (Continuous Integration, 지속적 통합)** | 커밋마다 빌드·테스트 자동화 | — |
| **Continuous Delivery (지속적 전달)** | 언제든 배포 가능한 상태 유지, **배포 버튼은 사람이** | 승인 1회 |
| **Continuous Deployment (지속적 배포)** | 테스트 통과 시 **자동으로 프로덕션까지** | 없음 (완전 자동) |

> **💡 DORA 4 지표로 변화 관찰**
>
> **Deployment Frequency(배포 빈도), Lead Time(변경 리드타임), Change Failure Rate(변경 실패율), MTTR(Mean Time To Restore, 평균 복구 시간)**를 팀의 기간·서비스 범위·측정 정의와 함께 기록한다. 특정 조직의 목표 수치를 그대로 복사하지 말고, 변경 크기와 복구 가능성을 낮추는 방향으로 개선한다.

## 3. Rolling Update(롤링 업데이트)

구버전 인스턴스를 **조금씩 신버전으로 교체**. K8s Deployment 기본 전략.

```mermaid
flowchart LR
    subgraph Before["진행 중"]
        A1["v1"]
        A2["v1 → v2"]
        A3["v2"]
    end
    Note["한 번에 N개씩 교체\n(maxSurge / maxUnavailable)"]

    style A1 fill:#dbeafe,stroke:#3b82f6
    style A2 fill:#fef3c7,stroke:#f59e0b
    style A3 fill:#dcfce7,stroke:#22c55e
```

*Rolling — 점진 교체. 용량 여유와 정책에 따라 추가 인스턴스가 필요할 수 있다. 배포 중 v1·v2가 공존한다.*

- **장점**: 트래픽을 점진적으로 옮기고 용량 정책에 맞춰 자원을 조절할 수 있음.
- **단점**: 배포 중 **두 버전 공존** → API 하위호환·DB 스키마 호환 필수. 롤백이 또 다른 롤링이라 느림.

## 4. Blue-Green Deployment(블루-그린 배포)

현재(Blue)와 똑같은 신버전 환경(Green)을 **통째로 띄운 뒤, 트래픽을 한 번에 전환**.

```mermaid
flowchart TB
    LB["로드밸런서 / DNS"]
    LB -->|"현재 100%"| Blue["🟦 Blue (v1)"]
    LB -.->|"검증 후 전환"| Green["🟩 Green (v2)"]
    Green -.->|"문제 시 즉시 Blue 복귀"| LB

    style Blue fill:#dbeafe,stroke:#3b82f6
    style Green fill:#dcfce7,stroke:#22c55e
```

*Blue-Green — 트래픽 스위치 한 번. 롤백이 "다시 Blue로" 라 즉각적*

- **장점**: 즉각적 전환·롤백, 배포 중 단일 버전만 노출, Green에서 충분히 검증 가능.
- **단점**: 두 환경을 동시에 유지하는 동안 추가 자원이 필요할 수 있음. DB는 공유하거나 분리할 수 있으므로 스키마·데이터 전환 호환성을 별도로 설계해야 한다.

## 5. Canary Deployment(카나리 배포)

신버전에 **정한 비율 또는 대상 집합의 일부 트래픽만 점진적으로** 흘리며 메트릭을 보고 확대/중단한다. 단계와 관찰 시간은 서비스 위험도·트래픽·판정 신뢰도에 맞춰 설정한다.

```mermaid
sequenceDiagram
    participant LB as 트래픽 분배
    participant V1 as v1 (안정)
    participant V2 as v2 (카나리)
    participant Mon as 모니터링

    LB->>V2: 정한 일부 트래픽
    LB->>V1: 나머지 트래픽
    V2->>Mon: 에러율·지연 측정
    Mon-->>LB: 정상 → 다음 단계로 확대
    Mon-->>LB: 이상 → 0%로 롤백 + 알림
    Note over LB,Mon: Argo Rollouts / Flagger가 자동 판정
```

*Canary — 폭발 반경을 정한 대상 집합으로 제한하고, 분석 결과에 따라 확대·중단을 결정*

> **🎯 면접 포인트**
>
> "Canary와 Blue-Green 차이?" → Blue-Green은 두 환경 사이의 전환을 중심으로 하고, Canary는 대상 집합·비율을 나눠 점진적으로 노출한다. Canary의 안전성은 트래픽 라우팅, 메트릭 분석, 세션·캐시·데이터 호환성에 달려 있으며 Argo Rollouts·Flagger·Service Mesh 같은 도구 사용 여부는 환경에 따라 정한다. 🔥(Deep-dive)

## 6. 배포 전략 비교표

| 전략 | 추가 비용 | 롤백 속도 | 폭발 반경 | 버전 공존 | 적합 상황 |
| --- | --- | --- | --- | --- | --- |
| **Rolling** | 거의 없음 | 느림 (역롤링) | 중 | O | 일반 무상태 서비스 기본 |
| **Recreate** | 없음 | 느림 | 전체 (다운타임) | X | 다운타임 허용·동시 버전 불가 |
| **Blue-Green** | 두 환경 유지 비용·용량 필요 | 트래픽 전환 방식에 의존 | 전환 범위 전체 | 구현에 따라 공존 | 즉각 전환 중요, 추가 용량 확보 가능 |
| **Canary** | 라우팅·관측·일부 용량 필요 | 대상 비율을 줄이는 방식 | 정한 대상 집합 | O | 고트래픽·고위험 변경 |

## 7. 롤백(Rollback) 전략

> **⚠️ 실무 함정 — "앞으로만 가는" 배포**
>
> 롤백 전략 없이 배포하면, 장애 시 "급하게 핫픽스 또 배포"라는 도박을 한다. **모든 배포는 롤백 경로가 먼저 정의** 돼야 한다. K8s면 `kubectl rollout undo` , GitOps면 `git revert` , Blue-Green이면 트래픽 스위치 복귀.

### DB 마이그레이션과 롤백 — 가장 위험한 지점

> **🎯 면접 포인트 (최상위 단골)**
>
> "배포 롤백했는데 DB는 이미 마이그레이션됐다면?" → 코드는 되돌려도 **스키마 변경은 비가역** 일 수 있다. 해법은 **Expand-Contract(확장-수축) 패턴** : ① 컬럼 추가는 nullable로(구버전 호환) ② 신버전 배포·안정화 ③ 그 다음 배포에서 구컬럼 제거. **"배포와 동시에 파괴적 마이그레이션 실행"은 절대 금지** — 롤백 불가 상태를 만든다. 🔥(Deep-dive)

## 8. Feature Flag(피처 플래그) — 배포 ≠ 릴리스

> **핵심 개념** — **Deploy(배포)**는 코드를 서버에 올리는 것, **Release(릴리스)**는 사용자에게 기능을 켜는 것. 피처 플래그가 이 둘을 *분리*한다.

```mermaid
stateDiagram-v2
    [*] --> Deployed : 코드 배포 (플래그 OFF)
    Deployed --> InternalOnly : 내부 직원만 ON
    InternalOnly --> Percentage : 일부 사용자 ON
    Percentage --> FullRelease : 100% ON
    Percentage --> KillSwitch : 문제 발생 → 즉시 OFF
    KillSwitch --> Deployed
    FullRelease --> [*]
```

*피처 플래그 — 배포된 코드를 점진 노출. 문제 시 재배포 없이 즉시 끄는 Kill Switch*

- **장점**: 배포 리스크 분리, A/B 테스트, 즉시 끄기(Kill Switch), 점진 노출.
- **도구**: LaunchDarkly, Unleash, 자체 구현.
- **주의**: 플래그가 쌓이면 기술 부채. 수명 다한 플래그는 제거(flag debt 관리).

## 9. 물류 연결 — 라스트마일 배차 로직 무중단 배포

> **💡 시나리오 — 새 배차 알고리즘 출시**
>
> 라스트마일 배차(기사에게 주문 할당) 로직을 새 알고리즘(v2)으로 바꾼다. 잘못되면 **기사 동선이 꼬여 배송 지연**이 발생할 수 있다. **Canary + 피처 플래그 조합**으로 정한 권역·고객·주문 집합에 v2를 적용하고, 배차 성공률·재할당·지연·취소 같은 업무 지표를 v1과 같은 정의로 비교한다. 지표가 악화되면 플래그를 끄되 이미 기록된 기사-주문 매핑을 자동으로 재계산하지 않는다. 진행 중 배차는 버전·결정 ID를 기록하고, 신규 주문만 전환할지 기존 건도 보상할지 정책을 둔다.

```mermaid
flowchart LR
    New["새 배차 v2"] --> Flag["피처 플래그\n(권역·비율 제어)"]
    Flag -->|"정한 대상 집합"| V2["v2 배차"]
    Flag -->|"나머지"| V1["v1 배차"]
    V2 --> KPI["KPI 비교\n동선·지연·처리량"]
    KPI -->|"악화"| Off["플래그 OFF\n즉시 v1"]
    KPI -->|"양호"| Up["다음 단계로 확대"]

    style Flag fill:#ede9fe,stroke:#8b5cf6
    style V2 fill:#dcfce7,stroke:#22c55e
    style Off fill:#fee2e2,stroke:#ef4444
```

*배차 로직 Canary + 피처 플래그 — 폭발 반경을 권역·비율로 이중 제한*

```yaml
release-gates:
  error_rate: "서비스 SLO·기준선과 비교"
  p99_latency: "서비스 SLO·기준선과 비교"
  canary_duration: "트래픽·위험도에 맞춘 관찰 창"
  rollback: automatic
```

## 10. 실패 흐름과 복구 경계

- 새 버전이 readiness를 통과했어도 기능·데이터 호환성 오류가 있을 수 있다. 에러율뿐 아니라 대상별 성공률, 지연, 비즈니스 불변식과 로그·트레이스를 함께 확인한다.
- 롤백 중에도 구버전과 신버전이 잠시 공존할 수 있다. 요청·이벤트·DB 스키마가 양쪽에서 읽히고 쓰이는지 확인한 뒤 트래픽을 줄인다. 파괴적 스키마 변경은 코드 롤백만으로 되돌리지 말고 롤 포워드 또는 보상 절차를 사용한다.
- Canary 분석기가 메트릭 수집 실패를 정상으로 오판하면 확대 사고가 난다. 관측 데이터가 없거나 기준선이 불완전하면 확대를 중단하고 수동 검토 상태로 둔다.
- 피처 플래그 저장소가 지연·장애를 일으킬 때의 기본값, 캐시 수명, 긴급 kill switch, 권한 변경을 명시한다. 플래그 OFF가 이미 생성된 작업·예약·배차 상태를 되돌리는 것은 아니므로 후속 정합성 절차가 필요하다.
- 배포 파이프라인의 artifact digest, 환경, 승인자, 판정 근거를 기록한다. 태그 재사용으로 롤백 대상을 잃지 않도록 불변 식별자를 사용한다.

## 11. 참고 자료

- [DORA metrics](https://dora.dev/guides/dora-metrics-four-keys/)
- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Kubernetes rollout status and undo](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_rollout/)
- [Kubernetes probes](https://kubernetes.io/docs/concepts/configuration/liveness-readiness-startup-probes/)
- [Martin Fowler: Blue-Green Deployment](https://martinfowler.com/bliki/BlueGreenDeployment.html)
- [Martin Fowler: Canary Release](https://martinfowler.com/bliki/CanaryRelease.html)$review_23_infra_04_cicd_deploy_strategy$
WHERE slug = 'infra-04-cicd-deploy-strategy' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_infra_05_observability_stack$## 1. 왜 관측성(Observability)인가 — 3 Pillars

> **멘탈 모델** — Metrics(무엇이 잘못됐나) → Logs(왜 그랬나) → Traces(어디서 그랬나). 세 기둥을 *연결*해야 진짜 디버깅이 된다.

```mermaid
flowchart TB
    App["애플리케이션 / 인프라"] --> M["📊 Metrics\n수치·시계열\n(에러율·지연·QPS)"]
    App --> L["📜 Logs\n이벤트 상세\n(구조화 JSON)"]
    App --> T["🔗 Traces\n요청 경로·구간 지연\n(분산 추적)"]
    M -->|"이상 감지"| Alert["알림"]
    M -.->|"TraceId로 점프"| T
    T -.->|"같은 TraceId 로그"| L

    style M fill:#dbeafe,stroke:#3b82f6
    style L fill:#fef3c7,stroke:#f59e0b
    style T fill:#ede9fe,stroke:#8b5cf6
    style Alert fill:#fee2e2,stroke:#ef4444
```

*3 Pillars — Metrics가 알람을 울리면 TraceId로 Trace와 Log를 연결해 근본 원인까지*

| Pillar | 답하는 질문 | 대표 도구 | 비용 민감 포인트 |
| --- | --- | --- | --- |
| **Metrics** | "지금 정상인가? 추세는?" | Prometheus + Grafana | 고cardinality 라벨(폭증) |
| **Logs** | "무슨 일이 있었나?" | Loki / ELK / OpenSearch | 로그 양·보존 기간 |
| **Traces** | "요청이 어디서 느렸나?" | OTel + Tempo / Jaeger | 샘플링 비율 |

## 2. Metrics — Prometheus (Pull 기반)

**Prometheus**는 각 타깃의 `/metrics` 엔드포인트를 주기적으로 **Pull(긁어오기)**한다. 시계열 DB에 저장하고 PromQL로 질의.

```mermaid
flowchart LR
    A1["서비스 A\n/metrics"] --> P["Prometheus\n(스크레이프 + TSDB)"]
    A2["서비스 B\n/metrics"] --> P
    Exp["Node Exporter\n(노드 지표)"] --> P
    P --> G["Grafana\n시각화"]
    P --> AM["Alertmanager\n알림"]

    style P fill:#dbeafe,stroke:#3b82f6
    style G fill:#dcfce7,stroke:#22c55e
    style AM fill:#fee2e2,stroke:#ef4444
```

*Prometheus Pull 모델 — 서비스가 메트릭을 노출하면 Prometheus가 주기적으로 수집*

> **⚠️ 실무 함정 — Cardinality(카디널리티) 폭발**
>
> 메트릭 라벨에 **user_id·order_id·trace_id처럼 값이 무한한 것** 을 넣으면 시계열 수가 폭증해 Prometheus 메모리·비용이 터진다. 라벨은 **유한한 차원** (서비스명·HTTP 상태·엔드포인트 패턴)만. 고유 식별자는 Logs/Traces로. 🔥(Deep-dive)

## 3. Logs — Loki vs ELK

| 관점 | Loki | ELK / OpenSearch |
| --- | --- | --- |
| 인덱싱 | 라벨만 인덱싱 (본문 미인덱싱) | 전문(full-text) 인덱싱 |
| 비용·운영 | 라벨·보존·저장량에 따라 산정 | 인덱스·저장·검색량에 따라 산정 |
| 검색력 | 라벨 + grep식 | **강력한 전문 검색·집계** |
| Grafana 통합 | 네이티브 (Prometheus와 한 화면) | Kibana 별도 |

> **🎯 면접 포인트 — 구조화 로그 + TraceId**
>
> "장애 시 로그로 디버깅이 안 됐던 경험?" → 원인은 보통 **비구조화 평문 로그 + TraceId 누락** . 해법: ① **구조화 JSON 로그** (필드로 질의 가능) ② 모든 로그에 `trace_id` 포함 → Trace에서 클릭 한 번으로 관련 로그 전부 모임. 🔥(Deep-dive)

## 4. Traces — OpenTelemetry + Tempo

분산 시스템에서 한 요청이 여러 서비스를 거치며 어디서 느렸는지 보려면 **분산 추적(Distributed Tracing)**이 필요하다.

```mermaid
sequenceDiagram
    participant GW as API Gateway
    participant OMS as 주문 서비스
    participant INV as 재고 서비스
    participant DB as DB

    Note over GW,DB: trace_id=abc123 (W3C Trace Context 전파)
    GW->>OMS: span1 (12ms)
    OMS->>INV: span2 (8ms)
    INV->>DB: span3 (180ms ← 병목!)
    DB-->>INV: 응답
    INV-->>OMS: 응답
    OMS-->>GW: 응답
```

*분산 추적 — 같은 trace_id로 span을 엮어 어느 구간이 느린지(DB 180ms) 시각화*

- **OpenTelemetry(OTel)**: 벤더 중립 표준. 계측(instrumentation)을 한 번 하면 Tempo/Jaeger/Datadog 등 어디로든 보낼 수 있다.
- **W3C Trace Context**: 서비스 간 `traceparent` 헤더로 trace_id를 전파해야 끊기지 않는다.
- **샘플링**: 전수 추적과 저장은 비용·용량·민감정보 노출을 늘릴 수 있다. 트래픽과 장애 진단 요구에 맞는 head/tail sampling 정책을 정하고, 오류·고위험 경로 보존 규칙을 별도로 검증한다.

## 5. RED / USE 메서드 — 무엇을 측정할까

| 메서드 | 대상 | 측정 항목 |
| --- | --- | --- |
| **RED** (서비스 관점) | 요청 단위 서비스 | **R**ate(요청률) · **E**rrors(에러율) · **D**uration(지연) |
| **USE** (자원 관점) | 인프라 자원 | **U**tilization(사용률) · **S**aturation(포화) · **E**rrors(에러) |

> **💡 면접에서 바로 쓰기**
>
> "어떤 메트릭을 대시보드에 둘까?"에 막연히 답하지 말고, "서비스는 **RED** (요청률·에러율·지연 p50/p95/p99), 자원은 **USE** (CPU·메모리 사용률, 큐 포화, 디스크 에러)"로 체계적으로 답하면 시니어 인상을 준다.

## 6. 대시보드 — Grafana

Grafana는 Prometheus(메트릭)·Loki(로그)·Tempo(트레이스)를 **한 화면에서 연결**한다. 지연 그래프에서 스파이크를 클릭 → 해당 시간대 로그 → trace_id로 트레이스까지 한 흐름으로 내려간다.

> **⚠️ 실무 함정 — 대시보드 묘지**
>
> 패널 100개짜리 대시보드는 장애 때 아무도 안 본다. **"이 서비스 정상인가?"에 30초 안에 답하는 핵심 대시보드** (RED 4~6개 패널) + 드릴다운용 상세를 분리하라. 측정만 하고 행동 못 하는 메트릭은 노이즈.

## 7. 알림 — SLO 기반 (Alert fatigue 방지)

```mermaid
flowchart LR
    M["메트릭"] --> Rule["알림 규칙\n(SLO 기반)"]
    Rule -->|"사람 행동 필요"| Page["📟 PagerDuty\n(긴급 호출)"]
    Rule -->|"인지만"| Slack["💬 Slack\n(비긴급)"]
    Rule -->|"정보"| Ticket["🎫 티켓"]

    style Page fill:#fee2e2,stroke:#ef4444
    style Slack fill:#dbeafe,stroke:#3b82f6
    style Ticket fill:#fef3c7,stroke:#f59e0b
```

*알림 라우팅 — 사람을 깨우는 페이지는 "지금 행동이 필요한 것"만. 나머지는 비긴급 채널*

> **🎯 면접 포인트 — CPU 알람 vs SLO 알람**
>
> "알람을 어떻게 설계?" → **"CPU 80% 넘으면 알람"은 안티패턴** . CPU가 높아도 사용자가 멀쩡하면 깨울 이유 없고, CPU가 낮아도 에러율이 치솟으면 장애다. **SLO(사용자 체감 지표) 기반 + Error Budget 소진 속도** 로 알람을 건다. 그래야 Alert fatigue(알람 피로 — 너무 많아 무시하게 됨)를 막는다. 🔥(Deep-dive)

> **⚠️ Observability 비용 폭주**
>
> 관측성 자체가 비용 폭탄이 될 수 있다. **로그 양·고cardinality 라벨·전수 트레이싱** 이 주범. 로그 샘플링·보존 기간 정책·라벨 통제로 관리하라. "측정 비용 > 측정 가치"가 되면 본말전도.

## 8. 물류 연결 — 배송 추적 파이프라인 디버깅

> **💡 시나리오 — "고객 앱에 배송 상태가 안 뜬다"**
>
> 라스트마일 추적 이벤트(스캔 → 메시지 스트림 → 추적 서비스 → 앱)가 지연된다는 CS 인입. **Metrics**에서 consumer lag과 처리율의 변화를 확인하고, **Traces**에서 느린 요청의 DB upsert 구간을 찾는다. **Logs**에서 같은 `trace_id`와 이벤트 키를 검색해 중복 이벤트·락 경합 같은 가설을 검증한다. 세 Pillar를 같은 상관관계 ID로 연결하면 메트릭 이상 → 트레이스 병목 → 로그 근본원인의 순서로 좁힐 수 있다.

```mermaid
flowchart LR
    Lag["📊 컨슈머 lag 급증\n(Metrics 알람)"] --> Trace["🔗 느린 trace 열기\nDB 구간 병목"]
    Trace --> Log["📜 trace_id 로그\n중복 이벤트 → 락 경합"]
    Log --> Fix["멱등성 키 추가\n+ upsert 인덱스 개선"]

    style Lag fill:#dbeafe,stroke:#3b82f6
    style Trace fill:#ede9fe,stroke:#8b5cf6
    style Log fill:#fef3c7,stroke:#f59e0b
    style Fix fill:#dcfce7,stroke:#22c55e
```

*3 Pillars 연계 디버깅 — trace_id가 메트릭·트레이스·로그를 하나로 꿰뚫는다*

```json
{
  "level": "ERROR",
  "trace_id": "4bf92f...",
  "service": "order-api",
  "error_code": "INVENTORY_TIMEOUT"
}
```

## 9. 실패 흐름과 데이터 경계

- 메트릭 수집기가 중단되면 대시보드의 빈 값이 정상으로 보일 수 있다. scrape 실패·exporter 장애·수집 지연을 별도 메트릭으로 감시하고, 알 수 없음과 정상 상태를 구분한다.
- 라벨에 사용자·주문·운송장 같은 고유값을 넣으면 cardinality와 저장량이 예측을 벗어날 수 있다. 유한한 라벨만 남기고 개별 식별자는 로그·트레이스의 검색 필드로 보낸다. 이미 폭증한 시계열은 수집 설정을 바꿔도 기존 데이터가 즉시 사라지지 않으므로 보존·삭제 정책을 함께 적용한다.
- 로그 수집 지연이나 샘플링으로 원인 로그가 빠질 수 있다. 오류·보안 사건·결제·재고 같은 핵심 경로의 보존 규칙과 개인정보 마스킹을 먼저 정한다.
- 추적 헤더가 신뢰 경계를 넘어 전파될 때는 허용 헤더와 샘플링 정책을 확인한다. 외부 입력을 그대로 로그·트레이스 속성에 넣으면 개인정보와 로그 주입 문제가 생길 수 있다.
- SLO 알람이 실제 사용자 영향과 연결되지 않거나 알림 대상이 없으면 page하지 않는다. 알람은 행동·담당자·Runbook·중복 억제·복구 확인을 함께 갖춘다.

## 10. 참고 자료

- [Prometheus data model](https://prometheus.io/docs/concepts/data_model/) 및 [metric and label naming](https://prometheus.io/docs/practices/naming/)
- [Prometheus alerting rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
- [OpenTelemetry observability primer](https://opentelemetry.io/docs/concepts/observability-primer/)
- [OpenTelemetry sampling](https://opentelemetry.io/docs/concepts/sampling/)
- [W3C Trace Context](https://www.w3.org/TR/trace-context/)
- [Google SRE: Alerting on SLOs](https://sre.google/workbook/alerting-on-slos/)$review_23_infra_05_observability_stack$
WHERE slug = 'infra-05-observability-stack' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_infra_06_sre_incident$## 1. SRE(Site Reliability Engineering)란

> **한 줄 정의** — 신뢰성(Reliability)을 *측정 가능한 목표*로 정의하고, 그 목표를 충족하는 한도 내에서 *최대한 빨리 기능을 출시*하도록 운영을 자동화한다.

핵심 철학: **100% 가용성은 보통 현실적인 운영 목표가 아니다**. 신뢰성 목표가 높아질수록 설계·운영·복구 비용과 변경 제약이 커질 수 있으므로, 사용자 영향·규제·비즈니스 요구에 맞는 SLO를 정한다. 남는 여유(Error Budget)는 변경과 학습에 사용할 수 있다.

## 2. SLI / SLO / SLA — 셋의 관계

| 용어 | 정의 | 예시 | 주체 |
| --- | --- | --- | --- |
| **SLI** (Service Level Indicator, 지표) | 실제 측정한 신뢰성 수치 | "성공 요청 비율 99.95%" | 측정값 |
| **SLO** (Service Level Objective, 목표) | SLI의 **내부 목표치** | "99.9% 이상" | 팀 내부 약속 |
| **SLA** (Service Level Agreement, 협약) | 고객과의 **계약 + 위약 패널티** | "99.5% 미달 시 환불" | 대외 계약 |

```mermaid
flowchart LR
    SLI["📏 SLI\n실제 측정값"] -->|"측정 → 목표 정의"| SLO["🎯 SLO\n내부 목표"]
    SLO -->|"목표 → 계약·구제 조건"| SLA["📜 SLA\n고객 계약"]
    Note["SLO를 SLA보다 엄격하게 두는 것은\n계약 전 안전 여유를 두는 정책 예시"]

    style SLI fill:#dbeafe,stroke:#3b82f6
    style SLO fill:#fef3c7,stroke:#f59e0b
    style SLA fill:#fce7f3,stroke:#ec4899
```

*SLI는 측정값이고 SLO·SLA는 목표·계약의 역할이다. SLO를 SLA보다 엄격하게 두는 것은 내부 안전 여유를 확보하려는 정책 예시*

> **🎯 면접 포인트**
>
> 세 용어를 섞어 쓰면 감점. **SLI는 측정값, SLO는 내부 목표, SLA는 대외 계약** . 그리고 "SLO를 SLA보다 엄격하게 잡아야, SLO를 어겨도 고객 계약 위반(패널티)은 막을 버퍼가 생긴다"까지 말하면 실무 이해도 인증.

## 3. Error Budget(오류 예산)

> **정의** — 가용성처럼 성공 비율로 표현한 SLO라면 **Error Budget = 1 − SLO target**으로 계산한다. SLO가 99.9%면 허용 실패 비율은 0.1%다. 지연시간·가중치·요청 기반 SLO는 해당 서비스가 정의한 분모와 허용 miss 비율로 계산해야 하며, 모든 SLO에 같은 식을 기계적으로 적용하지 않는다.

예를 들어 30일 동안 항상 측정 가능한 가용성 SLO가 99.9%라면, 허용 오류 예산은 전체 관측 시간의 0.1%다. 30일을 분 단위로 계산할 때 약 43.2분이지만, 실제 예산은 요청 기반·가중치·제외 시간·유지보수 정책에 따라 달라진다. 계산식을 고정하고 측정 범위를 문서화해야 개발팀과 운영팀이 같은 숫자를 본다.

```mermaid
stateDiagram-v2
    [*] --> Healthy : 예산 충분
    Healthy --> ShipFast : 정책상 변경 허용
    ShipFast --> Healthy : 안정적
    ShipFast --> Burning : 장애로 예산 소진
    Burning --> Freeze : 정책상 변경 제한 또는 승인
    Freeze --> Stabilize : 안정화·기술부채 상환에 집중
    Stabilize --> Healthy : 예산 회복
```

*Error Budget 정책 예시 — 예산과 burn rate에 따라 출시·안정화 규칙을 사전에 정할 수 있음*

> **💡 갈등을 규칙으로**
>
> "개발은 빨리 출시하려 하고 운영은 막으려 한다"는 갈등을, Error Budget은 **예산과 burn rate를 기준으로 출시·완화·안정화 규칙을 합의하는 방식**으로 다룬다. 예산 소진 시 변경 동결이나 추가 승인을 요구할 수 있지만, 예외·완화·승인 절차는 조직 정책이므로 자동 동결을 보편 규칙으로 가정하지 않는다.

## 4. Toil(토일, 반복 운영 업무) 감소

**Toil** = 수동적·반복적·자동화 가능하지만 안 한·서비스 성장에 비례해 늘어나는 운영 업무. (예: 매번 손으로 하는 배포, 수동 인증서 갱신, 반복 알람 대응)

- Toil의 양이 팀의 개선·복구 역량을 잠식하는지 추적하고, 자동화 투자 판단은 반복 빈도·오류 위험·자동화 비용·절감 시간을 함께 비교한다.

> **⚠️ 실무 함정**
>
> Toil을 "원래 운영은 그런 것"이라며 방치하면, 팀이 불 끄기에만 매달려 개선·자동화에 쓸 시간이 사라지는 악순환에 빠진다. Toil 비율을 측정하고 상한선을 정하라.

## 5. Incident(장애) 대응 — Runbook & 역할 분리

```mermaid
flowchart TB
    Detect["🚨 감지\n(SLO 알람)"] --> Triage["분류\n심각도(Sev) 판정"]
    Triage --> Roles["역할 배정"]
    Roles --> IC["IC\nIncident Commander\n(지휘·의사결정)"]
    Roles --> Comms["Comms\n(대내외 커뮤니케이션)"]
    Roles --> Ops["Ops\n(실제 조치·복구)"]
    IC --> Mitigate["완화\n(롤백·차단·우회)"]
    Mitigate --> Resolve["해결"]
    Resolve --> PM["포스트모템"]

    style Detect fill:#fee2e2,stroke:#ef4444
    style IC fill:#ede9fe,stroke:#8b5cf6
    style Comms fill:#dbeafe,stroke:#3b82f6
    style Ops fill:#fef3c7,stroke:#f59e0b
    style PM fill:#dcfce7,stroke:#22c55e
```

*Incident Command — IC/Comms/Ops 역할 분리. 한 사람이 다 하면 지휘가 무너진다*

> **🎯 면접 포인트 — 복구가 원인 규명보다 먼저**
>
> "장애 나면 뭐부터?" → **"원인부터 찾는다"는 흔한 오답** . 우선순위는 ① **완화(Mitigation) — 일단 사용자 영향 멈추기** (롤백·트래픽 차단·우회), ② 그 다음 원인 규명. 근본 원인은 복구 후 포스트모템에서. 면접에선 "MTTR(평균 복구 시간)을 줄이려면 원인 규명보다 완화를 먼저"라고 답하라. 🔥(Deep-dive)

### Graceful Degradation / Back-pressure / Shed load

- **Graceful degradation(우아한 성능 저하)**: 추천 서비스 죽으면 추천 없이라도 주문은 받기.
- **Back-pressure(배압)**: 다운스트림이 못 따라오면 상류에 "천천히" 신호.
- **Shed load(부하 차단)**: 과부하 시 일부 요청을 빠르게 거절해 전체 붕괴 방지.

## 6. Postmortem(포스트모템) — Blameless

> **핵심 원칙** — **Blameless(비난 없는)** — "누가 잘못했나"보다 "어떤 시스템·프로세스가 그 실수를 가능하게 했나"를 묻는다. 개인의 고의·보안 위반과 시스템 개선을 같은 절차로 처리하지 않도록 조직 정책을 명확히 한다.

### 포스트모템 표준 구성

| 섹션 | 내용 |
| --- | --- |
| **Summary** | 무슨 일이, 얼마나 영향(사용자·시간·매출) |
| **Timeline** | 감지→완화→해결까지 시각별 사건 |
| **Root Cause** | 근본 원인 (5 Whys 등) |
| **Action Items** | 재발 방지 — **담당자·기한 명시** |
| **Lessons Learned** | 잘된 점·아쉬운 점·운 좋았던 점 |

> **⚠️ 실무 함정**
>
> 포스트모템이 **"담당자 문책"으로 끝나면** , 다음부터 사람들이 장애를 숨긴다 → 더 큰 사고. Action Item이 "조심하자" 같은 추상론이면 무의미 — **구체적·검증 가능·담당자/기한 있는** 개선만 유효하다.

## 7. Chaos Engineering(카오스 엔지니어링) 개요

장애를 **일부러 주입**해 시스템이 견디는지 사전에 검증한다. "장애는 일어난다"를 전제로, 통제된 환경에서 약점을 미리 찾는다.

```mermaid
flowchart LR
    H["가설\n'AZ 하나 죽어도 정상'"] --> E["실험\n(AZ 장애 주입)"]
    E --> O["관측\n(SLO 영향 측정)"]
    O -->|"견딤"| Conf["신뢰 확보"]
    O -->|"무너짐"| Fix["약점 개선"]
    Fix --> H

    style H fill:#dbeafe,stroke:#3b82f6
    style E fill:#fef3c7,stroke:#f59e0b
    style O fill:#ede9fe,stroke:#8b5cf6
    style Fix fill:#fee2e2,stroke:#ef4444
```

*Chaos Engineering — 가설→실험→관측→개선*

> **💡 성급히 뛰어들기 전에**
>
> 카오스 엔지니어링은 **관측성·SLO·중단 기준·롤백이 먼저 갖춰진 뒤** 의미 있다. 측정하지 못하는 시스템에 장애를 주입하면 통제되지 않은 장애가 된다. 작은 범위의 Gameday(통제된 모의 장애 훈련)부터 시작하고, 실험 중단 조건과 영향 범위를 사전에 승인한다.

## 8. 물류 연결 — Cut-off 직전 주문 서비스 장애

> **💡 시나리오 — 새벽배송 마감 10분 전 주문 API 지연**
>
> 22:50, Cut-off(23:00) 10분 전에 주문 API p99 지연이 5초로 치솟고 에러율 급증. 사용자가 주문을 못 넣으면 **곧바로 매출 손실 + 익일 배송 실패** . **완화 우선**: 원인 규명 전, 직전 배포를 즉시 롤백(혹은 피처 플래그 OFF). MTTR 단축이 최우선. **Graceful degradation**: 추천·쿠폰 추천 같은 비핵심 호출을 차단(Shed load)해 주문 핵심 경로 자원 확보. **역할**: IC가 "Cut-off를 10분 연장할지"를 비즈니스와 즉시 결정(Comms), Ops는 복구 집행. **Error Budget**: 이번 장애로 이달 예산이 소진되면, 다음 스프린트는 기능 동결하고 주문 경로 안정화(부하 테스트·Shed load 정교화)에 투자. **Postmortem**: Blameless로 "왜 Cut-off 직전 배포가 가능했나"를 묻고, Action Item으로 **피크 시간대 배포 동결(freeze window)**을 규칙화. **Trade-off** : Cut-off 연장은 고객 경험을 지키지만 창고·간선·기사 스케줄 전체를 밀어 비용이 든다. SLO·매출 영향·운영 비용을 IC가 저울질해 결정한다.

```text
SEV-1 타임라인
22:50 감지·Incident Commander 지정
22:53 직전 배포 롤백
22:56 비핵심 경로 차단
23:02 오류율 정상화·모니터링
```

## 9. 실패 흐름과 운영 경계

- SLI가 측정되지 않거나 분모가 바뀌면 error budget을 계산할 수 없다. 성공·실패 정의, 요청 제외 규칙, 집계 창, 데이터 지연을 문서화하고 대시보드와 알람이 같은 정의를 쓰게 한다.
- 알람이 울려도 담당자·Runbook·권한·연락 경로가 없으면 완화가 지연된다. page는 즉시 행동이 필요한 조건으로 제한하고, 비긴급 신호는 티켓·대시보드로 분리한다.
- 롤백이 데이터 변경을 되돌리지 못할 수 있다. 완화 단계에서 트래픽 차단·기능 플래그·읽기 전용 전환·롤 포워드 가능성을 검토하고, 복구 후 데이터 대사와 재처리를 별도 작업으로 추적한다.
- 장애 중 재시도와 자동 확장이 하위 시스템을 더 압박할 수 있다. deadline·지수 백오프·재시도 예산·서킷 브레이커·큐 용량을 확인하고, 포화 시 우선순위가 낮은 작업부터 차단한다.
- 포스트모템 Action Item은 소유자·기한·검증 방법을 갖추고, 완료 여부를 다시 확인한다. 같은 장애가 재발하면 개인의 주의가 아니라 탐지·배포·권한·복구 설계의 결함을 다시 본다.

## 10. 참고 자료

- [Google SRE: Service Level Objectives](https://sre.google/sre-book/service-level-objectives/)
- [Google SRE: Error Budgets](https://sre.google/workbook/error-budget-policy/)
- [Google SRE: Being On-Call](https://sre.google/sre-book/being-on-call/)
- [Google SRE: Postmortem Culture](https://sre.google/sre-book/postmortem-culture/)
- [NIST SP 800-61 Rev. 2: Computer Security Incident Handling Guide](https://csrc.nist.gov/pubs/sp/800/61/r2/final)
- [Principles of Chaos Engineering](https://principlesofchaos.org/)$review_23_infra_06_sre_incident$
WHERE slug = 'infra-06-sre-incident' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_infra_07_interview_incident$## 1. 면접 시나리오 개요 — "새벽 3시, 당신의 폰이 울렸다"

이 카드는 개념 암기가 아니라 **압박 속 판단 순서**를 본다. 시니어 인프라/SRE 면접은 대부분 시나리오 롤플레이다. 면접관이 상황을 던지고, 당신이 조치를 말하면 **바로 그 조치가 부른 새로운 문제**를 다시 던진다.

> **🎯 면접 포인트 — 이 롤플레이가 진짜로 채점하는 것**
>
> 지식의 양이 아니라 **의사결정의 순서**다. "원인 규명 vs 사용자 영향 완화" 중 무엇을 먼저 하는가, "재시작 vs 관측" 중 무엇을 먼저 하는가. 시니어는 **불확실성 속에서도 안전한 되돌릴 수 있는 조치부터** 집는다. 개념(SLO·HPA·Canary)은 이미 안다고 가정하고, 그걸 **언제 어떤 순서로 꺼내는지**를 본다.

```mermaid
sequenceDiagram
    participant P as 폰(PagerDuty)
    participant Me as 당신(온콜)
    participant Dash as 대시보드
    participant IC as Incident Commander
    P->>Me: "03:00 p99 SLO 위반 알림"
    Me->>Dash: 메트릭부터 확인(재시작 금지)
    Dash-->>Me: p99 800ms, 특정 엔드포인트 집중
    Me->>IC: "Sev2 선언, 완화 착수"
    Note over Me,IC: 원인 규명보다 사용자 영향 차단 먼저
    Me->>Dash: 직전 배포 롤백 → 지표 회복 관측
    Dash-->>IC: p99 90ms 복귀, 근본원인은 PM에서
```

*온콜 타임라인 — 알림→관측→완화→회복. 원인 규명은 회복 이후*

이번 세션은 4라운드. 각 라운드마다 **모범 답변 포인트**와 **흔한 오답**을 함께 제시한다. 실제 면접에선 답을 말한 뒤 후속 압박이 들어온다고 생각하고 읽어라.

---

## 2. Round 1 — "p99 지연이 갑자기 10배 튀었다. 어디부터 보나?"

> **면접관** — "평소 p99 80ms이던 주문 조회 API가 800ms로 뛰었다. 아직 원인은 모른다. 지금 5분 줄 테니 어디부터 볼 건지 순서대로 말해봐."

### 모범 답변 포인트 — 관측성 삼각측량(Observability Triangulation)

메트릭(Metric) → 로그(Log) → 트레이스(Trace)의 **깔때기** 순서로 좁힌다. 넓게 보고 점점 좁힌다.

```mermaid
flowchart TB
    M["1. Metric(넓게)\n어디가·언제부터 아픈가"] --> Q1{"특정 엔드포인트?\n특정 AZ?\n배포 시점과 일치?"}
    Q1 -->|"범위 확인"| L["2. Log(좁게)\n에러 메시지·스택·상태코드"]
    L --> Q2{"타임아웃?\n커넥션 풀 고갈?\n특정 쿼리?"}
    Q2 -->|"가설 수립"| T["3. Trace(콕 집어)\n요청 스팬별 구간 지연"]
    T --> R["병목 구간 확정\n(예: DB 호출 700ms)"]
    style M fill:#dbeafe,stroke:#3b82f6
    style L fill:#fef3c7,stroke:#f59e0b
    style T fill:#ede9fe,stroke:#8b5cf6
    style R fill:#dcfce7,stroke:#22c55e
```

*삼각측량 — Metric으로 범위 좁히고, Log로 가설 세우고, Trace로 병목 구간 확정*

1. **Metric 먼저(RED 메서드)** — Rate(요청량)·Errors(에러율)·Duration(지연). 대시보드에서 확인할 것:
   - **언제부터?** 급등 시각을 배포/설정 변경/트래픽 급증 이벤트와 대조 → 대개 여기서 범인의 8할이 잡힌다.
   - **어디가?** 전체 엔드포인트인가 특정 하나인가. 전체 AZ인가 한 AZ인가.
   - **상류인가 하류인가?** 앱 CPU는 멀쩡한데 지연만 늘면 → 하류(DB·캐시·외부 API) 의심.
2. **Log** — 좁혀진 범위의 구조화 로그에서 에러 메시지·상태코드·`traceId` 확인. "connection pool exhausted", "context deadline exceeded" 같은 문구가 바로 가설이 된다.
3. **Trace** — 느린 요청 하나를 골라 스팬별로 본다. `app 20ms → db 700ms → app 30ms`처럼 **어느 구간이 먹었는지** 콕 집는다.

```bash
# 진단 순서 예시 (K8s + Prometheus + Loki)
# 1) 메트릭: p99 급등이 특정 pod/AZ에 몰렸나
kubectl top pods -n order --sort-by=cpu
# PromQL: 엔드포인트별 p99
# histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, route))

# 2) 로그: 좁혀진 pod의 에러 패턴 (traceId 포함 구조화 로그 전제)
kubectl logs -n order deploy/order-api --since=10m | grep -E "timeout|pool|deadline"

# 3) 최근 배포/변경 상관관계 — 급등 시각과 대조
kubectl rollout history deploy/order-api -n order
```

> **⚠️ 실무 함정 — "일단 재시작"과 "일단 스케일 아웃"**
>
> 압박받으면 나오는 최악의 두 반사행동. **① Pod 재시작**은 증거(메모리 상태·연결 상태)를 날리고, 원인이 트래픽/하류면 재시작해도 곧바로 재발한다. **② 무지성 스케일 아웃**은 DB 커넥션만 더 늘려 하류를 더 죽인다. 관측으로 "상류 문제인지 하류 문제인지" 판별하기 전엔 손대지 마라. 단, 관측 결과 명백히 특정 pod만 병든 상태(메모리 릭)면 **그 pod만 격리(cordon/drain)**하는 건 정당한 완화다.

> **면접관의 후속 압박** — "메트릭 봤더니 CPU는 정상인데 p99만 튀고, 로그에 `connection pool exhausted`가 찍혀. 이제 뭐?"
>
> → 하류(DB) 병목 확정. 완화: ① 커넥션 풀 사이즈보다 **느린 쿼리/락**을 의심(DB 쪽 slow query·lock wait 확인), ② 방금 배포가 원인이면 롤백, ③ 특정 N+1 쿼리가 원인이면 해당 기능 피처 플래그 OFF. **풀 사이즈를 무작정 늘리는 건 오답** — DB max_connections를 넘기면 DB 자체가 죽는다.

### 흔한 오답 vs 모범 답변

| 구분 | 흔한 오답 | 모범 답변 |
| --- | --- | --- |
| 첫 행동 | "서버 재시작 / 스케일 아웃" | "메트릭으로 범위·상류/하류 판별 먼저" |
| 순서 | 트레이스부터 열어 헤맴 | 메트릭(넓게)→로그→트레이스(좁게) |
| 배포 상관 | 언급 안 함 | "급등 시각을 배포 이력과 대조" 최우선 |
| 하류 판단 | CPU만 보고 스케일 아웃 | "CPU 정상+지연만 상승 → 하류 병목" |

---

## 3. Round 2 — "트래픽 5배 이벤트가 예고됐다. HPA만 믿으면 되나?"

> **면접관** — "다음 주 프로모션으로 평소 대비 5배 트래픽이 예고됐다. 'HPA(Horizontal Pod Autoscaler) 켜놨으니 알아서 늘겠죠'라고 하면 나 실망할 텐데. HPA로 **못 막는 것**을 말해봐."

### 모범 답변 포인트 — HPA는 만병통치약이 아니다

HPA는 **반응형(reactive)**이라 트래픽이 튄 **다음에** 늘어난다. 스파이크에는 항상 늦다.

```mermaid
sequenceDiagram
    participant U as 트래픽 5배 유입
    participant HPA as HPA(설정된 주기)
    participant CA as Cluster Autoscaler
    participant Pod as 새 Pod
    participant DB as DB 커넥션 풀
    U->>HPA: 부하 급증
    Note over HPA: 메트릭 수집·판정·ready 대기 지연
    HPA->>CA: replica 증가 요청
    Note over CA: 노드 부족 시 프로비저닝·스케줄 지연
    CA->>Pod: 새 Pod 스케줄 + 이미지 pull + 워밍업
    Pod->>DB: 커넥션 요청 폭증
    Note over DB: max_connections 한계 → 여기서 2차 장애
```

*HPA 스케일 아웃 지연 사슬 — 판정→노드 기동→이미지 pull→워밍업. 그 사이 사용자는 이미 에러를 본다*

**HPA로 못 막는 것 3가지 (면접 핵심):**

| 한계 | 왜 문제인가 | 대책 |
| --- | --- | --- |
| **스케일 아웃 지연** | 메트릭 판정부터 새 Pod ready까지 구성별 지연. 스파이크엔 늦을 수 있음 | 이벤트 전 **사전 예열(pre-warming)**, `minReplicas` 상향 |
| **노드 부족** | Pod는 늘려도 얹을 노드가 없으면 Pending | Cluster Autoscaler/**Karpenter**로 노드도 사전 확보 |
| **DB 커넥션 풀 고갈** | 앱은 무한 확장돼도 DB `max_connections`는 유한 → 하류가 먼저 죽음 | **Stateful 계층은 스케일 아웃 안 됨**, 커넥션 풀·읽기 복제본·캐시로 대비 |

**사전 예열 체크리스트 (예고된 피크의 정석):**
- `minReplicas`를 이벤트 전에 상향해 콜드 스타트와 노드 대기 시간을 줄인다. 값은 용량 모델로 결정한다.
- Cluster Autoscaler/Karpenter로 **노드를 미리 확보**(over-provisioning pause pod 트릭).
- CDN·캐시 워밍, DB 읽기 복제본(Read Replica) 추가, ElastiCache 워밍.
- **부하 테스트(Load test)로 병목을 미리 발견** — k6/Locust로 5배 트래픽 리허설.
- **Shed load(부하 차단)·큐잉** 준비 — 한계 초과 시 우아하게 거절.

```yaml
# HPA + PodDisruptionBudget — 스케일은 하되, 축소 시 급락 방지
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: order-api
  namespace: order
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: order-api
  minReplicas: 2           # 예시: 실제 값은 용량 모델로 결정
  maxReplicas: 20          # 예시: 하위 시스템 한도와 함께 결정
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 60   # 예시: 기준선·처리량 검증 필요
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0    # 늘릴 땐 즉시
      policies:
        - type: Percent
          value: 100                   # 예시: 정책·용량으로 조정
          periodSeconds: 60
      scaleDown:
        stabilizationWindowSeconds: 300  # 예시: 축소 플래핑 방지 정책
```

> **⚠️ 실무 함정 — HPA `averageUtilization: 80`**
>
> CPU 목표 하나만으로는 트래픽·큐 backlog·하위 시스템 포화를 설명하지 못한다. 예고된 피크에는 목표치와 `minReplicas`를 실제 처리량·ready 시간으로 검증하고, 반응형 HPA가 늦을 경우 사전 용량·입장 제어·큐를 함께 사용한다.

> **💡 팁 — "5배"를 숫자로 되받아쳐라**
>
> 면접관이 "5배"라고 하면 평소·피크 QPS, 읽기·쓰기 비율, pod별 연결 수, DB·외부 API의 지속 가능 처리량을 되묻는다. 연결 풀의 상한은 pod 수와 함께 계산하되, 실제 DB 설정값을 확인하지 않고 특정 숫자를 일반 규칙으로 가정하지 않는다. 평균 배율보다 시간대별 피크 분포와 backlog를 용량 모델에 넣는다.

> **면접관의 후속 압박** — "노드도 미리 늘리고 minReplicas도 올렸어. 근데 새벽에 DB가 커넥션 한계로 죽었어. 왜?"
>
> → 앱 계층만 스케일 아웃한 전형적 함정. 관계형 DB의 쓰기 경로와 연결 상한은 앱처럼 무한히 늘지 않을 수 있다. 읽기는 복제본·캐시로 분산할 수 있지만 일관성·지연을 확인하고, 연결 풀러·back-pressure·큐로 하위 시스템을 보호한다. 앱만 늘리면 하류가 죽을 수 있다는 점을 용량 모델로 설명한다.

---

## 4. Round 3 — "배포 직후 에러율 급증. 롤백? 카나리?"

> **면접관** — "정기 배포 5분 뒤 에러율이 0.1%에서 7%로 튀었다. Error Budget은 이달 30% 남았어. 롤백할래, 카나리로 계속 지켜볼래? 그리고 이미 실행된 DB 마이그레이션은 어쩔 거야?"

### 모범 답변 포인트 — 완화 우선, 그다음 원인

```mermaid
stateDiagram-v2
    [*] --> Detected : 배포 후 에러율 급증
    Detected --> Assess : 폭발 반경 판정
    Assess --> Rollback : "이미 100% 배포됐다 → 즉시 롤백"
    Assess --> HaltCanary : "카나리 5%였다 → 트래픽 0%로 중단"
    Rollback --> DBCheck : 코드는 되돌렸다. DB는?
    HaltCanary --> DBCheck
    DBCheck --> Safe : "Expand 단계라 구버전 호환 → 안전"
    DBCheck --> Danger : "파괴적 마이그레이션 실행됨 → 롤백 불가"
    Danger --> ForwardFix : 롤백 불가 → 롤 포워드(핫픽스)
    Safe --> [*]
    ForwardFix --> [*]
```

*배포 실패 의사결정 — 배포 방식(전면 vs 카나리)과 DB 상태(호환 vs 파괴적)에 따라 갈린다*

**답변의 뼈대:**
1. **완화 먼저.** 원인 분석은 나중. 사용자가 7% 에러를 계속 맞고 있으면 Error Budget이 분 단위로 타들어간다. 30% 남았어도 7% 에러율이면 **몇 시간이면 소진**된다.
   - 전면(Rolling/Blue-Green 100%) 배포였다면 → **즉시 롤백**(`kubectl rollout undo`, Blue-Green이면 트래픽 스위치 복귀).
   - 카나리 5%였다면 → **트래픽 0%로 중단**. 애초에 카나리였으면 폭발 반경이 5%로 제한돼 있었다는 점을 어필.
2. **"이런 위험한 배포는 애초에 카나리였어야"** — 배포 방식 선택 자체가 평가 대상. 되돌릴 수 있게 설계했느냐.
3. **DB 마이그레이션이 결정적 분기.** 코드는 롤백돼도 스키마는 비가역일 수 있다.
   - **Expand 단계**(컬럼 추가·nullable)로만 나갔다면 구버전이 그대로 호환 → 롤백 안전.
   - **Contract(컬럼 삭제)가 배포와 동시에** 나갔다면 → 구버전 코드가 없는 컬럼을 찾다 죽어 **롤백 불가** → 어쩔 수 없이 **롤 포워드(roll forward, 앞으로 핫픽스)**.

> **🎯 면접 포인트 — Error Budget으로 결정을 정당화하라**
>
> "롤백할까요?"를 감으로 답하지 마라. 현재 오류율·요청량·SLO 분모·남은 error budget을 같은 정의로 계산해 완화 속도를 정당화한다. 예시 SLO가 99.9%인 경우에도 실제 예산은 요청 기반인지 시간 기반인지, 제외 시간이 있는지에 따라 달라진다. 🔥(Deep-dive)

> **⚠️ 실무 함정 — "롤백했으니 끝"이라 답하는 순간**
>
> 롤백은 **완화**지 **해결**이 아니다. 면접관은 반드시 "근본 원인은?"과 "재발 방지는?"을 묻는다. 답: Blameless Postmortem에서 5 Whys로 근본 원인 규명 → Action Item(구체·담당자·기한). 그리고 **"왜 이 배포가 카나리 없이 100%로 나갔나", "왜 파괴적 마이그레이션이 배포와 동시에 실행됐나"**라는 프로세스 결함까지 파고들어야 시니어다.

### 좋은 답변 vs 나쁜 답변

| 상황 | 나쁜 답변 (감점) | 좋은 답변 (시니어) |
| --- | --- | --- |
| 첫 조치 | "원인부터 로그 분석" | "완화 먼저 — 롤백/카나리 중단으로 사용자 영향 차단" |
| 결정 근거 | "일단 롤백이 안전하니까" | "에러율×시간으로 Budget 소진 속도 계산해 즉시 결정" |
| DB 고려 | 언급 없음 | "Expand-Contract 상태 확인, 파괴적이면 롤 포워드" |
| 마무리 | "롤백 완료" | "완화 후 Blameless PM + 배포 방식/마이그레이션 프로세스 개선" |

> **💡 팁** — Round 3의 진짜 함정은 **"롤백 = 항상 안전"**이라는 착각이다. DB 상태에 따라 롤백이 더 큰 장애를 부를 수 있음을 아는지가 미들/시니어를 가른다. `infra-04` 카드의 Expand-Contract를 여기서 **압박 상황의 실시간 판단**으로 꺼내 쓸 수 있어야 한다.

---

## 5. Round 4 — "AZ 하나가 통째로 죽었다"

> **면접관** — "AWS ap-northeast-2a AZ(Availability Zone, 가용 영역)가 통째로 죽었다는 상태 페이지가 떴다. 네 서비스는 어떻게 되고, 뭘 해야 하나?"

### 모범 답변 포인트 — "이미 대비돼 있어야 한다"

이 라운드의 정답은 **장애 시점의 영웅적 조치가 아니라, 사전 설계**다. Multi-AZ면 대부분 자동 처리되고, 단일 AZ였다면 이미 늦었다.

```mermaid
flowchart TB
    AZa["❌ AZ-a 다운\n(EC2·RDS Standby·일부 노드)"]
    subgraph Survive["살아남는 설계"]
        ALB["ALB\n(다중 AZ 헬스체크)"]
        AZb["✅ AZ-b\n앱 노드·트래픽 흡수"]
        AZc["✅ AZ-c\n앱 노드·트래픽 흡수"]
        RDS["RDS Multi-AZ\nStandby로 자동 페일오버"]
    end
    AZa -.->|"헬스체크 실패→라우팅 제외"| ALB
    ALB --> AZb
    ALB --> AZc
    AZa -.->|"Primary 다운"| RDS
    RDS -->|"서비스별 페일오버 완료 후"| AZb
    style AZa fill:#fee2e2,stroke:#ef4444
    style AZb fill:#dcfce7,stroke:#22c55e
    style AZc fill:#dcfce7,stroke:#22c55e
    style RDS fill:#dbeafe,stroke:#3b82f6
```

*AZ 장애 격리 — ALB가 죽은 AZ를 헬스체크로 제외, RDS Multi-AZ가 Standby로 페일오버. 나머지 AZ가 트래픽 흡수*

**답변 뼈대:**
1. **설계가 방어한다** — Multi-AZ 전제라면:
   - **ALB**가 죽은 AZ의 타깃을 헬스체크로 자동 제외 → 트래픽이 살아있는 AZ로.
   - **RDS Multi-AZ**와 같은 관리형 데이터베이스의 페일오버 동작·완료 시간은 엔진·구성·장애 유형별 공식 문서를 확인하고, 애플리케이션은 연결 재수립을 처리한다.
   - Cluster Autoscaler가 살아있는 AZ에 부족분 노드 보충.
2. **당신이 할 일** — 자동 복구를 **관측·검증**하고, 남은 AZ가 트래픽을 감당하는지 확인.
3. **결정적 함정 — 용량 헤드룸(capacity headroom).** 3-AZ에 각 33%로 딱 맞게 돌렸다면, 1개 AZ가 죽는 순간 남은 2개가 각 50%씩 받아야 한다. **여유 없이 운영했으면 남은 AZ도 연쇄 과부하로 죽는다.** N+1 여유(각 AZ가 다른 하나의 몫까지 감당할 헤드룸)를 미리 확보해야 한다.

> **🎯 면접 포인트 — RTO/RPO로 답하라**
>
> "AZ 죽으면 어떻게 되냐"에 "괜찮아요 Multi-AZ라서"는 부족하다. **RTO(Recovery Time Objective, 목표 복구 시간)와 RPO(Recovery Point Objective, 목표 복구 시점)**, 장애 전환 중 실패할 요청, 읽기·쓰기 정합성, 애플리케이션의 연결 재수립을 함께 답한다. RPO가 0인지 여부도 복제 방식과 커밋 시점으로 확인하며, 진행 중인 트랜잭션 재시도에는 **멱등성(Idempotency)**을 둔다.

> **⚠️ 실무 함정 — "Multi-AZ면 무조건 안전"**
>
> 세 가지 구멍: **① 용량 헤드룸 없음** — 남은 AZ가 과부하로 도미노. **② 상태 저장소가 단일 AZ** — 앱은 Multi-AZ인데 Redis/Kafka가 단일 AZ면 거기서 끊긴다. **③ 페일오버 미검증** — Gameday로 실제 AZ 장애를 주입해본 적 없으면 "될 거야"는 희망사항. Chaos Engineering으로 **평소에 AZ 하나를 일부러 죽여봐야** 진짜 방어된다.

> **면접관의 최종 압박** — "그럼 Multi-Region은? AZ로 부족하니 리전 이중화 하자고 하면?"
>
> → **성급하면 감점.** 먼저 RTO/RPO, 리전 장애 범위, 데이터 복제·충돌 모델, 규제·계약 요구를 확인한다. Multi-Region은 추가 리소스와 데이터·페일오버 복잡도를 만들므로 필요성을 입증한 뒤 선택한다. 요구사항 없이 Multi-Region부터 지르는 것은 오버엔지니어링일 수 있다. **필요성을 먼저 되묻는 것**이 시니어의 답이다.

---

## 6. 종합 평가 루브릭 — 당신은 어느 레벨인가

| 역량 | 주니어 (Junior) | 미들 (Middle) | 시니어 (Senior) |
| --- | --- | --- | --- |
| **첫 조치** | "재시작/스케일 아웃" 반사행동 | 관측 후 조치 | 관측→**완화(되돌릴 수 있는 것)**→원인, 순서가 몸에 뱀 |
| **진단** | 로그만 뒤짐 | 메트릭→로그 | **삼각측량 + 배포/변경 상관관계**를 먼저 |
| **오토스케일** | "HPA 켜면 됨" | HPA 지연 인지 | **Stateful 한계·사전 예열·DB 병목**을 정량으로 |
| **배포/롤백** | "롤백하면 됨" | 카나리·폭발 반경 이해 | **DB 상태 따라 롤백 불가 판단**, 롤 포워드 결정 |
| **AZ 장애** | "Multi-AZ면 됨" | ALB·RDS 페일오버 설명 | **용량 헤드룸·RTO/RPO·상태저장소 구멍**까지 |
| **정량 근거** | 감으로 판단 | 일부 숫자 | Error Budget·QPS·RTO/RPO로 **모든 결정 정당화** |
| **오버엔지니어링** | 유행 기술 선호 | 상황 따라 | **필요성을 먼저 되묻고** Trade-off로 절제 |

> **💡 팁 — 면접장에서 즉시 점수 올리는 3문장**
>
> ① "먼저 되돌릴 수 있는 완화부터 하고 원인은 그다음에 보겠습니다." ② "그 결정을 Error Budget/RTO 숫자로 정당화하면…" ③ "이건 요구사항(SLA·RPO)을 먼저 확인해야 과잉설계를 피할 수 있습니다." 이 세 문장은 어느 시나리오에도 통하는 **시니어의 사고 프레임**이다.

## 7. 물류 맥락 — 명절/프로모션 피크의 4라운드 압축

> **💡 시나리오 — 추석 전날 밤, 주문 폭주 중 장애**
>
> 추석 D-1, 평소 10배 주문이 3시간에 집중된다(피크 분포 — 평균이 아니다). **R1**: 주문 조회 p99가 튄다 → 메트릭으로 "특정 AZ의 DB 읽기 지연"임을 삼각측량. **R2**: HPA로 앱은 늘렸지만 RDS 커넥션이 한계 → **미리 Read Replica 증설·RDS Proxy·minReplicas 사전 상향**을 안 해둔 게 화근. Stateful 계층은 사전 예열이 답. **R3**: 하필 이 피크에 배포가 나가 에러율 급증 → **피크 시간대 배포 동결(freeze window)**이 규칙이었어야. 롤백 시 재고 차감 마이그레이션이 파괴적이면 롤 포워드. **R4**: AZ 하나가 죽어도 남은 AZ가 10배 피크를 흡수할 **헤드룸**이 있었는지가 생사를 가른다. **Trade-off**: 피크 대비 상시 헤드룸은 비용이다. 명절 같은 예고된 피크는 **상시가 아니라 이벤트 전 스케줄 스케일 업**으로 비용과 안정성을 저울질한다 — 이게 시니어의 답이다.

## 8. 실패 흐름과 인터뷰 답변 경계

- 메트릭·로그·트레이스가 서로 다른 시간대·샘플링·분모를 사용하면 삼각측량이 틀어진다. 먼저 데이터 신선도와 상관관계 ID를 확인하고, 관측 공백을 정상으로 해석하지 않는다.
- HPA가 원하는 replica를 계산해도 노드·이미지 registry·Pod startup·DB 연결이 막히면 사용자 용량은 늘지 않는다. 각 단계의 Pending·ImagePullBackOff·readiness 실패를 분리해 설명한다.
- 롤백 명령이 성공해도 파괴적 DB 변경·외부 이벤트·이미 전송된 주문을 되돌리지는 못한다. Expand-Contract, 롤 포워드, 보상·대사 절차를 구분한다.
- AZ 장애 시 자동 페일오버를 기다리는 동안 앱의 기존 연결과 진행 중 트랜잭션이 실패할 수 있다. 재시도 폭주를 막는 deadline·backoff·idempotency와 남은 AZ 용량을 함께 확인한다.
- 면접의 수치(예: 오류율·트래픽 배율)는 판단 연습을 위한 가정이다. 실제 운영 수치·클라우드 페일오버 시간·HPA 주기는 서비스 구성과 공식 문서·관측값으로 검증한다.

## 9. 참고 자료

- [Kubernetes Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Kubernetes Deployments and rollout](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Google SRE: Service Level Objectives](https://sre.google/sre-book/service-level-objectives/)
- [Google SRE: Monitoring](https://sre.google/sre-book/monitoring/)
- [AWS Regions and Availability Zones](https://docs.aws.amazon.com/global-infrastructure/latest/regions/aws-regions.html)
- [Amazon RDS Multi-AZ deployments](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.html)$review_23_infra_07_interview_incident$
WHERE slug = 'infra-07-interview-incident' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_infra_10_commerce_spike_design$## 1. 가장 약한 의존성을 기준으로 입구를 제한한다

정적 상품 조회는 CDN과 캐시로 분리하고, 구매 경로는 재고 예약·결제의 지속 가능한 처리량을 기준으로 입장시킨다. Queue는 일시적인 burst를 흡수할 뿐 무한한 용량이나 처리량을 만들지 않는다.

```mermaid
flowchart LR
    U[Users] --> E[CDN·Waiting Room]
    E --> G[Gateway·Rate Limit]
    G --> O[Order Intake]
    O --> Q[(Bounded Queue)]
    Q --> W[Workers]
    W --> I[Inventory]
    W --> P[Payment]
```

| 계층 | 보호 수단 | 과부하 신호 |
|---|---|---|
| Edge | Waiting Room·Bot 제한 | 대기 시간·거절률·우회 시도 |
| API | 사용자별 제한·Deadline | 동시 요청·꼬리 지연 |
| Queue | 크기·Age 한도 | Oldest Message Age |
| Worker | 동시성·Retry Budget | 하위 오류·포화도 |

```text
admission_rate <= min(inventory_sustainable_rate, payment_sustainable_rate)
retry_budget is shared across all attempts, not reset per service
```

> **설계 원칙** — 주문이 약속 시간 안에 처리될 수 없으면 Queue에 계속 쌓지 말고, 신규 입장 제한·명확한 거절·취소·환불 정책을 적용한다. 이미 접수된 주문은 상태와 고객 안내를 보존한다.

## 2. 사전 확장과 단계적 복구

예고 이벤트는 Warm Capacity, 연결 Pool, DB 한도, Cache를 사전 검증한다. 장애 후 제한을 한 번에 해제하지 않고 Canary 비율로 올리며 Backlog와 하위 시스템 회복을 확인한다.

> **면접 포인트** — 최대 QPS보다 입장 제어, 멱등 주문, 결과 미상 조회, 재시도 감쇠와 고객 경험을 종단으로 설계한다.

## 3. 실패 흐름과 보호 경계

- Waiting Room·rate limit이 우회되거나 설정 저장소가 지연되면 보호 계층이 무력화될 수 있다. 기본 거절·fail closed 여부, 신뢰할 프록시 헤더, 사용자·IP·기기별 키를 명시한다.
- 주문 접수 응답이 타임아웃되어도 주문이 저장됐을 수 있다. 클라이언트 재시도는 같은 idempotency key로 묶고, 주문·예약·결제의 결과 조회 경로를 제공한다.
- Queue가 가득 차면 오래된 메시지와 새 메시지를 무조건 같은 방식으로 버리지 않는다. 주문 만료 시각, 우선순위, 결제 승인 여부, 고객 보상 정책을 기준으로 보존·거절·DLQ를 결정한다.
- 워커 재시도가 재고·결제를 다시 호출하면 Retry Storm이 된다. 전체 시도 예산, 지수 백오프·jitter, circuit breaker, 하위 시스템 deadline과 멱등 키를 공유한다.
- 재고 예약은 성공했지만 결제가 실패하거나, 결제는 성공했지만 응답이 유실될 수 있다. 예약 만료·결제 결과 조회·보상 해제·수동 대사 상태를 명시하고, 자동 취소가 고객 약속과 충돌하지 않는지 확인한다.
- 단계적 복구에서 backlog와 하위 시스템 포화가 줄어드는지 확인한 뒤 admission rate를 올린다. 큐 길이만 보고 제한을 풀면 지연된 작업이 한꺼번에 downstream을 압박한다.

## 4. 참고 자료

- [AWS Well-Architected Reliability Pillar](https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/welcome.html)
- [Amazon SQS visibility timeout](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-visibility-timeout.html)
- [Amazon SQS dead-letter queues](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-dead-letter-queues.html)
- [Google SRE: Handling Overload](https://sre.google/sre-book/handling-overload/)
- [RFC 6585: Additional HTTP Status Codes](https://www.rfc-editor.org/rfc/rfc6585)$review_23_infra_10_commerce_spike_design$
WHERE slug = 'infra-10-commerce-spike-design' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_infra_13_warehouse_edge_design$## 1. 단절 모드를 정상 상태로 설계한다

스캔·라벨·작업 지시는 WAN 단절이 발생해도 일정 시간 지속되어야 한다. Edge는 필요한 작업 Snapshot과 로컬 불변 로그를 유지하고 중앙 권한이 필수인 결제·전역 재고 이동은 제한한다.

```mermaid
flowchart LR
    D[Scanner·PLC] --> E[Edge API]
    E --> L[(Local Durable Log)]
    E --> C[(Local Work Cache)]
    L --> S[Sync Agent]
    S <-->|WAN 복구| H[Central Platform]
    O[Local Operator] --> E
```

| 상태 | Edge 동작 | 중앙 복구 후 |
|---|---|---|
| 정상 | 낮은 지연 처리·가능한 경우 즉시 동기화 | 확인된 sequence·checksum 기록 |
| WAN 단절 | 허용 명령·로컬 Append | 순서·중복 검증 전송 |
| 중앙 데이터 충돌 | 위험 작업 보류 | 정책 기반 병합·운영 승인 |
| Edge 장애 | 이중화 또는 수동 절차 | 로그 복구·대사 |

```text
event_id = site_id + device_id + durable_sequence
sync resumes from acknowledged sequence with checksum reconciliation
```

> **설계 원칙** — Last-Write-Wins로 재고를 합치면 물리 이동을 잃을 수 있다. 원본 이벤트를 보존하고 충돌을 업무 규칙으로 해결한다. 로컬 시계나 네트워크 도착 순서를 물리적 사건 순서로 간주하지 않는다.

## 2. Fleet 운영을 포함한다

센터별 버전, 인증서, 디스크 사용량, 동기화 지연을 중앙에서 관측한다. 서명된 Artifact, 단계적 배포, 자동 Rollback과 현장 수동 운영 Runbook을 함께 준비한다.

> **면접 포인트** — 작은 Cloud 복제본이 아니라 단절, 현장 장비, 제한된 운영 인력과 물리 흐름까지 포함한 시스템으로 설명한다.

## 3. 실패 흐름과 안전 경계

- WAN이 끊기면 Edge가 중앙 권한·재고 최신성·가격 정책을 확인할 수 없다. 스캔·포장·작업 완료처럼 로컬에서 안전하게 기록할 작업과 재고 이동 승인·결제·고객 약속 변경처럼 중앙 확인이 필요한 작업을 명령 종류별로 나눈다.
- 로컬 로그가 디스크를 다 쓰거나 손상되면 스캔을 성공으로 표시하고 잃어버릴 수 있다. append 성공 확인, 디스크 임계치, 보존·압축·오프로드, 읽기 전용 전환, 수동 스캔 절차를 설계한다.
- 동기화 재시도 중 응답이 끊기면 중앙에 이벤트가 적용됐는지 알 수 없다. `event_id`와 sequence를 그대로 재전송하고, 중앙의 적용 결과·checksum·누락 범위를 조회한 뒤 다음 offset을 전진시킨다.
- 동일 상품에 대해 중앙과 Edge에서 상충하는 이동이 발생하면 마지막 쓰기 승리로 덮지 않는다. 물리 스캔 증거·작업자·장비·시각·문서 상태를 묶어 충돌 큐로 보내고, 업무 담당자가 대사한다.
- Edge 업그레이드가 중단되면 스캔 업무가 계속되어야 한다. 서명된 artifact, 호환 가능한 데이터 형식, 이전 버전 유지, health check와 자동 rollback, 현장 수동 runbook을 준비하고, 중앙이 새 버전의 상태를 확인하기 전에는 다음 센터로 확대하지 않는다.
- 인증서 만료·중앙 시간 불일치·장비 교체는 단절과 별개로 동기화를 막을 수 있다. 키 회전, 단조 증가 sequence, 시간 보정 허용 범위, 장비 등록·폐기 절차를 함께 관측한다.

## 4. 참고 자료

- [AWS IoT Greengrass developer guide](https://docs.aws.amazon.com/greengrass/v2/developerguide/what-is-gg.html)
- [The Update Framework (TUF)](https://theupdateframework.io/security/)
- [SQLite Atomic Commit](https://sqlite.org/atomiccommit.html)
- [NIST SP 800-82 Rev. 3: Guide to Operational Technology Security](https://csrc.nist.gov/pubs/sp/800/82/r3/final)$review_23_infra_13_warehouse_edge_design$
WHERE slug = 'infra-13-warehouse-edge-design' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_system_design_01_fundamentals$> **검수 경계** — 가용성·지연·일관성 수치는 제품 계약과 측정 창에 따라 달라진다. 아래 숫자는 계산 연습용이며 특정 기업의 내부 SLO를 증명하지 않는다.

## 1. Scalability (확장성) — 수직 vs 수평

> **정의** — 트래픽·데이터가 늘어날 때, *비례하는 자원 추가만으로* 성능을 유지할 수 있는 능력

**Scale-up(수직 확장, Vertical Scaling)**은 한 대의 머신을 더 강하게(CPU·RAM·디스크 증설) 만드는 것이고, **Scale-out(수평 확장, Horizontal Scaling)**은 같은 역할의 머신 대수를 늘리는 것이다. 대규모 시스템 설계의 기본 전제는 "수평 확장 가능하게 설계한다"이며, 그 핵심 조건이 **Stateless(무상태) 설계**다.

```mermaid
flowchart TB
    subgraph UP["⬆️ Scale-up (수직)"]
        S1["1대 서버\n4 vCPU / 16GB"] --> S2["1대 서버\n32 vCPU / 256GB"]
    end
    subgraph OUT["➡️ Scale-out (수평)"]
        LB["L7 Load Balancer"]
        LB --> A1["App #1"]
        LB --> A2["App #2"]
        LB --> A3["App #3"]
        LB --> AN["App #N ...무한 증설"]
    end
    UP -.->|"한계: 단일 머신 상한·SPOF·비용 급증"| OUT

    style S1 fill:#dbeafe,stroke:#3b82f6
    style S2 fill:#dbeafe,stroke:#3b82f6
    style LB fill:#ede9fe,stroke:#8b5cf6
    style A1 fill:#dcfce7,stroke:#22c55e
    style A2 fill:#dcfce7,stroke:#22c55e
    style A3 fill:#dcfce7,stroke:#22c55e
    style AN fill:#dcfce7,stroke:#22c55e
```

*수직 확장은 빠르지만 천장이 낮고 SPOF(Single Point of Failure, 단일 장애점)가 된다. 수평 확장은 Stateless가 전제.*

### 왜 Stateless 가 수평 확장의 핵심인가

세션·장바구니 같은 상태를 **App 서버의 메모리에 들고 있으면**, Load Balancer가 다음 요청을 다른 서버로 보냈을 때 상태가 사라진다(Sticky session으로 막으면 특정 서버에 트래픽이 쏠려 확장성이 깨짐). 그래서 상태는 외부(Redis 세션 스토어, DB)로 빼고 App은 "들어온 요청을 어느 서버가 처리해도 동일한 결과"가 나오도록 만든다. 대규모 서비스의 API 계층은 Stateless로 만들 수 있지만, 특정 회사의 실제 내부 구성은 공개 자료가 없으면 단정하지 않는다.

| 관점 | Scale-up (수직) | Scale-out (수평) |
| --- | --- | --- |
| 한계 | 단일 머신 최대 사양(천장 존재) | 이론상 무제한(조율 복잡도만 증가) |
| 가용성 | 그 머신이 죽으면 전체 다운(SPOF) | 일부 노드 죽어도 나머지가 서비스 |
| 비용 곡선 | 고사양일수록 비선형 급증 | 상용 머신 다수 → 선형에 가까움 |
| 적합 | RDBMS 마스터, 강한 정합성 필요한 단일 노드 | Stateless API, 캐시, 큐 컨슈머 |
| 난점 | 다운타임 동반 증설 | 데이터 일관성·분산 트랜잭션·샤딩 |

> **💡 팁 — 현실은 하이브리드**
>
> App 계층은 수평, DB는 마스터를 한 번 수직으로 키운 뒤(읽기는 Read Replica로 수평) 한계가 오면 샤딩으로 수평 전환하는 게 일반적 순서다. "처음부터 샤딩"은 과설계(Over-engineering).

> **🎯 면접 포인트**
>
> "트래픽 10배를 어떻게 감당하죠?" → **"서버를 키우면 됩니다"** 는 약하다. *"App은 Stateless라 LB 뒤에서 오토스케일, 상태는 Redis로 분리, DB는 Read Replica로 읽기 분산하다 한계 시 샤딩"* 까지 한 문장으로 나와야 시니어 눈높이. 🔥(Deep-dive)

## 2. Availability · Reliability · Durability 구분

이 셋은 면접에서 가장 자주 **혼용**되는 단어다. 정확히 분리해야 한다.

| 개념 | 질문 | 측정 | 예시 |
| --- | --- | --- | --- |
| **Availability(가용성)** | "지금 요청하면 응답하나?" | Uptime 비율 (%, 9의 개수) | 결제 API가 99.99% 시간 동안 정상 응답 |
| **Reliability(신뢰성)** | "오랜 기간 올바르게, 고장 없이 동작하나?" | MTBF(Mean Time Between Failures), 오류율 | 한 달간 데이터 손상·오작동 없이 정확한 결과 |
| **Durability(내구성)** | "한 번 저장한 데이터가 안 사라지나?" | 데이터 손실 확률 (예: 11 nines) | S3 객체 내구성 99.999999999%(11 nines) |

### 한 줄 직관

- **Availability**: 문을 열어 두고 있는가 (응답 가능성)
- **Reliability**: 문을 열어 두되 *매번 제대로* 동작하는가 (정확성·무고장)
- **Durability**: 맡긴 물건을 *절대 잃어버리지 않는가* (영속성)

가용한데 신뢰성이 낮을 수 있다(서버는 200을 주는데 잘못된 잔액을 반환). 신뢰성 높은 단일 서버라도 가용성은 낮을 수 있다(한 대뿐이라 죽으면 끝). 저장소 서비스의 공개 계약도 가용성(읽을 수 있는가)과 내구성(저장한 데이터가 보존되는가)을 별도 지표로 제시한다. 잠깐 못 읽을 수 있어도 데이터 자체를 잃지 않는 설계를 별도로 검증해야 한다.

> **🎯 면접 함정 #1 — 가용성과 신뢰성 혼동**
>
> "가용성 5 nines로 만들겠습니다"라고만 하고 **왜·어떻게(Multi-AZ, Failover, Health check, Circuit breaker)** 가 없으면 감점. 또 "가용성 높으면 데이터 안전하죠?"는 **틀린 등치** — 그건 Durability의 영역. 🔥(Deep-dive)

## 3. 가용성 "9의 개수"와 다운타임

가용성은 보통 "나인(nines)"으로 말한다. 표의 값은 계산식을 적용한 참고값으로 사용하고, 실제 목표는 서비스의 측정 창과 계약에서 확인한다. 계산식은 단순하다: `연간 다운타임 = 365.25일 × (1 − 가용성)`.

| 가용성 | 호칭 | 연간 다운타임 | 월간 다운타임 | 주간 다운타임 |
| --- | --- | --- | --- | --- |
| **90%** | one nine | 36.5 일 | 72 시간 | 16.8 시간 |
| **99%** | two nines | 3.65 일 | 7.2 시간 | 1.68 시간 |
| **99.9%** | three nines | 8.76 시간 | 43.8 분 | 10.1 분 |
| **99.99%** | four nines | 52.6 분 | 4.38 분 | 1.01 분 |
| **99.999%** | five nines | 5.26 분 | 26.3 초 | 6.05 초 |

> **💡 암산 트릭**
>
> "3 nines = 약 9시간/년, 4 nines = 약 1시간/년(정확히 52.6분), 5 nines = 약 5분/년." 9를 하나 더 붙일 때마다 다운타임은 **1/10** 로 준다. 99.999%(5분/년)는 사람이 알아채고 수동 대응하기엔 너무 짧아 **완전 자동 Failover** 가 필수다.

### 컴포넌트 직렬 연결: 가용성은 곱해진다

여러 컴포넌트를 **직렬(series)**로 의존하면 전체 가용성은 각 가용성의 *곱*이다. 의존 컴포넌트가 많을수록 전체 가용성은 떨어진다.

```mermaid
flowchart LR
    U([요청]) --> LB["LB\n99.99%"]
    LB --> APP["App\n99.95%"]
    APP --> CACHE["Cache\n99.9%"]
    CACHE --> DB["DB\n99.95%"]
    DB --> R([응답])

    style LB fill:#ede9fe,stroke:#8b5cf6
    style APP fill:#dcfce7,stroke:#22c55e
    style CACHE fill:#fef3c7,stroke:#f59e0b
    style DB fill:#dbeafe,stroke:#3b82f6
```

*직렬 의존 전체 가용성 = 0.9999 × 0.9995 × 0.999 × 0.9995 ≈ **0.9979 (99.79%)** → 연 약 18.4시간 다운. 각자는 3~4 nines인데 합치면 떨어진다.*

그래서 가용성을 높이려면 **중요 컴포넌트를 병렬(redundant)로 이중화**한다. 병렬 두 대(각 99.9%)의 가용성은 `1 − (1 − 0.999)² = 99.9999%`로 급상승한다. 이것이 Multi-AZ·Active-Active 구성의 수학적 근거다.

> **⚠️ 실무 함정**
>
> "각 서비스 99.99%니까 전체도 99.99%"는 틀림 — 직렬이면 곱해져 **더 낮아진다** . 마이크로서비스가 호출 체인을 길게 만들수록 이 효과가 누적된다. 그래서 **Circuit Breaker(회로 차단기)** · **Graceful degradation(우아한 성능 저하)** 으로 한 컴포넌트 장애가 전체를 끌어내리지 않게 격리한다.

## 4. Consistency (일관성) — Strong vs Eventual

**Strong Consistency(강한 일관성)**는 "쓰기가 끝난 직후 모든 읽기가 그 최신 값을 본다". **Eventual Consistency(최종 일관성)**는 "쓰기 직후엔 노드마다 다를 수 있지만, 충분한 시간이 지나면 모두 같아진다". 분산 시스템에선 `CAP(Consistency, Availability, Partition tolerance) 정리`상 네트워크 분할 시 일관성과 가용성 중 하나를 양보해야 하므로, 많은 대규모 시스템이 가용성을 위해 최종 일관성을 택한다.

```mermaid
sequenceDiagram
    participant C as Client
    participant P as Primary
    participant R as Replica
    Note over C,R: Strong Consistency
    C->>P: write(x=10)
    P->>R: replicate(x=10)
    R-->>P: ack
    P-->>C: OK (복제 확인 후 응답)
    C->>R: read(x)
    R-->>C: 10  ✅ 항상 최신

    Note over C,R: Eventual Consistency
    C->>P: write(x=10)
    P-->>C: OK (즉시 응답)
    C->>R: read(x)
    R-->>C: 9  ⚠️ 아직 복제 전 (옛값)
    P-->>R: replicate(x=10) (나중에)
```

*Strong은 복제 확인 후 응답(지연↑·정합성↑), Eventual은 즉시 응답(지연↓·일시적 stale 허용).*

### 어디에 무엇을 쓰나 — Trade-off

- **강한 일관성이 중요한 예**: 결제 잔액, 재고 차감(Oversell 방지), 좌석·쿠폰 발급. 특정 회사의 코어 구현으로 일반화하지 말고 불변식과 실패 비용을 먼저 정의한다.
- **최종 일관성 허용**: 좋아요 수, 조회수, 라스트마일 `TrackingEvent` 전파, 타임라인 피드. 제품 계약이 수 초 지연을 허용한다면 조회 모델을 비동기로 갱신할 수 있다.
- **읽기 의미 보장**: `Read-your-writes(자기 쓰기 읽기)`(내가 쓴 건 내가 즉시 본다), `Monotonic read(단조 읽기)`(한 번 본 최신값보다 과거로 안 돌아간다) — 최종 일관성 위에서도 UX를 지키는 절충안.

> **💡 물류 맥락**
>
> 라스트마일 추적 API는 **최종 일관성** 이 합리적이다. 기사 스캔이 Kafka로 Fan-out(팬아웃)되어 읽기 모델에 반영되기까지 수백 ms~수 초 지연은 허용. 반대로 같은 시스템의 **재고 예약(Reserve)** 은 강한 일관성(조건부 UPDATE/락)으로 Oversell을 막아야 한다 — *한 도메인 안에서도 데이터별로 일관성 수준이 다르다.*

## 5. Latency vs Throughput · Tail Latency

| 개념 | 정의 | 단위 | 비유 |
| --- | --- | --- | --- |
| **Latency(지연)** | 요청 1건이 응답까지 걸린 시간 | ms | 한 대의 차가 톨게이트 통과하는 시간 |
| **Throughput(처리량)** | 단위 시간당 처리한 요청 수 | QPS / RPS | 1분에 톨게이트 통과한 차량 대수 |

둘은 독립적이다. 배치를 키우면 처리량은 오르지만 개별 지연은 늘 수 있다(Trade-off). **QPS(Queries Per Second, 초당 쿼리 수)**가 시스템 용량의 척도라면, 지연은 사용자 체감의 척도다.

### 왜 평균(p50)이 아니라 p99를 봐야 하나

지연은 분포다. `p50(중앙값)`·`p95`·`p99`는 "요청의 50%/95%/99%가 이 시간 안에 끝난다"는 분위수(percentile)다. **Tail latency(꼬리 지연)** = p99/p99.9 같은 꼬리 구간이 사용자 경험과 SLO를 좌우한다.

```mermaid
flowchart LR
    REQ([1000건 요청]) --> SORT["응답시간 오름차순 정렬"]
    SORT --> P50["p50 = 20ms\n(500번째)"]
    SORT --> P95["p95 = 80ms\n(950번째)"]
    SORT --> P99["p99 = 300ms\n(990번째)\n← 꼬리"]
    P99 --> WHY["원인: GC, 락 경쟁,\n콜드 캐시, 큐 대기,\n느린 디스크/네트워크"]

    style P50 fill:#dcfce7,stroke:#22c55e
    style P95 fill:#fef3c7,stroke:#f59e0b
    style P99 fill:#fef2f2,stroke:#dc2626
    style WHY fill:#fff7ed,stroke:#ea580c
```

*평균만 보면 p99의 300ms를 놓친다. 한 페이지가 100개 마이크로서비스를 호출하면 그중 하나가 p99에 걸릴 확률이 커져 **전체 응답이 꼬리에 끌려간다(Tail amplification)**.*

> **🎯 면접 함정 #2 — 평균 지연만 보고 p99 무시**
>
> "평균 응답 30ms입니다"는 거의 의미 없다. 면접관은 **"p99는요? Tail latency 원인과 대응은?"** 을 노린다. 답: 원인은 GC·락 경쟁·콜드 캐시·큐잉·느린 노드. 대응은 *Timeout + Retry(주의: Retry storm), Hedged request(여분 요청), 캐시 워밍, 백프레셔(Back-pressure), Load shedding* . 🔥(Deep-dive)

> **💡 출처의 한계**
>
> 특정 회사의 지연 증가와 사업 지표의 상관관계는 회사·서비스·측정 방법별 공식 자료가 필요하다. 여기서는 평균 대신 p95/p99를 측정해 사용자 영향을 확인해야 한다는 원칙만 사용한다.

## 6. SLA / SLO / SLI 구분

세 단어는 계층 관계다. **SLI(Service Level Indicator, 서비스 수준 지표)**로 측정하고 → **SLO(Service Level Objective, 서비스 수준 목표)**로 내부 목표를 세우고 → **SLA(Service Level Agreement, 서비스 수준 협약)**로 고객과 계약(위반 시 보상)한다.

```mermaid
flowchart TB
    SLI["📏 SLI (지표)\n실제 측정값\n예: 가용성 99.97%,\np99 = 280ms,\n오류율 0.03%"]
    SLO["🎯 SLO (목표)\n내부 목표선\n예: 가용성 ≥ 99.95%,\np99 ≤ 300ms"]
    SLA["📜 SLA (협약)\n고객과의 계약\n예: 가용성 99.9% 미달 시\n요금 10% 크레딧"]
    EB["⛽ Error Budget\n= 1 − SLO\n예: 0.05% (월 21.6분)\n이 예산 안에서 배포·실험"]

    SLI -->|"이 측정으로"| SLO
    SLO -->|"여유를 두고 약속"| SLA
    SLO --> EB

    style SLI fill:#dcfce7,stroke:#22c55e
    style SLO fill:#dbeafe,stroke:#3b82f6
    style SLA fill:#ede9fe,stroke:#8b5cf6
    style EB  fill:#fef3c7,stroke:#f59e0b
```

*SLI로 재고 → SLO로 목표 → SLA로 약속. SLA는 보통 SLO보다 **느슨하게** 잡는다(버퍼).*

| 항목 | 의미 | 대상 | 위반 결과 | 예 |
| --- | --- | --- | --- | --- |
| **SLI** | 측정 지표(사실) | 모니터링/관측성 | — | 이번 달 결제 성공률 99.97% |
| **SLO** | 내부 목표 | 엔지니어링 팀 | Error Budget 소진 → 배포 동결 | 결제 API 가용성 ≥ 99.95%, p99 ≤ 300ms |
| **SLA** | 고객 계약 | 법무/영업/고객 | 요금 크레딧·배상 | 월 가용성 99.9% 미달 시 사용료 10% 환급 |

### 실제 예시

- **AWS 계약을 예로 들 때**는 서비스와 배포 조건을 함께 적는다. EC2의 99.99% Region-Level SLA는 여러 AZ/리전에 인스턴스를 배치하는 조건이고, 단일 인스턴스 SLA는 별도 기준이다. S3 Standard 계열의 월간 가용성 약속은 99.9%지만 storage class·측정 방식·SLA 제외 조건을 확인해야 한다. 이는 *고객 계약(SLA)*의 예시이며 내부 SLO는 더 빡빡하게 정할 수 있다.
- 결제·재고처럼 실패 비용이 큰 코어 경로는 일반 조회보다 엄격한 내부 SLO를 둘 수 있지만, 목표값과 SLA는 제품 계약·측정 방법으로 정한다. 내부 SLO에 SLA보다 여유를 두면 계약 위반 전에 완화할 시간을 확보할 수 있다.

> **💡 물류 맥락 — 라스트마일 추적 API의 SLO 예시**
>
> **SLI** : 추적 조회 성공률, 조회 p99 지연, *이벤트 전파 지연(스캔→조회 반영까지)* . **SLO** : 조회 가용성 ≥ 99.95%, 조회 p99 ≤ 200ms, 전파 지연 p95 ≤ 3초. **Error Budget** : 0.05%(월 약 21.6분). 이 예산이 남아 있으면 신규 배포·실험을 허용하고, 다 쓰면 안정화에 집중 — 이것이 SRE(Site Reliability Engineering)의 의사결정 방식.

> **🎯 면접 포인트 — Error Budget**
>
> "SLO를 100%로 잡으면 되지 않나요?"는 함정 답. 100%는 **혁신 속도 0** (배포 자체가 위험)을 뜻한다. **Error Budget = 1 − SLO** 를 "허용된 실패 예산"으로 쓰는 사고가 핵심. 신뢰성과 배포 속도의 Trade-off를 수치로 관리한다고 말하면 시니어 인상. 🔥(Deep-dive)

```text
monthly_minutes = 30 * 24 * 60 = 43,200
99.9% SLO error budget  = 43.2 minutes
99.99% SLO error budget = 4.32 minutes
```

## 검수 경계와 실패 흐름

- SLI의 측정 구간·분모·제외 조건을 먼저 고정하고, 같은 창에서 SLO와 실제 error budget 소비를 계산한다.
- 직렬 의존성은 가용성을 곱하지만 장애 도메인이 독립이라는 뜻은 아니다. AZ·전원·배포·DNS 같은 공통 원인을 별도 failure mode로 기록한다.
- 의존 서비스가 느려지거나 실패하면 retry storm이 생길 수 있으므로 deadline·backoff·circuit breaker·load shedding·fallback의 순서를 정한다.
- 캐시 우회나 replica 장애가 원장에 만드는 추가 QPS를 용량 예산에 넣고, 정상 상태뿐 아니라 복구 중 p95/p99와 error budget을 함께 검증한다.

## 공식·1차 출처

- [https://sre.google/sre-book/service-level-objectives/](https://sre.google/sre-book/service-level-objectives/)
- [https://sre.google/sre-book/handling-overload/](https://sre.google/sre-book/handling-overload/)
- [https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/welcome.html](https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/welcome.html)
- [https://aws.amazon.com/compute/sla/](https://aws.amazon.com/compute/sla/)
- [https://aws.amazon.com/s3/sla/](https://aws.amazon.com/s3/sla/)$review_23_system_design_01_fundamentals$
WHERE slug = 'system-design-01-fundamentals' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_system_design_02_capacity_estimation$> **검수 경계** — DAU·QPS·피크 배율·지연시간 표의 값은 가상 입력과 환경 의존적 참고값이다. 실제 용량은 요청 크기·버스트·하드웨어·부하 테스트로 재산정한다.

## 1. 왜·언제 추정하나

> **목적** — 숫자로 *설계의 규모(scale)*를 잡아, 적절한 아키텍처 선택을 정당화한다.

추정의 진짜 가치는 정밀도가 아니라 **자릿수(order of magnitude)**다. "이게 초당 100건짜리 문제냐, 100만 건짜리 문제냐"가 정해지면 설계가 완전히 달라진다.

- **QPS가 단일 DB benchmark 범위 이내** → 캐시 + Read Replica가 충분할 수 있으며 샤딩은 보류
- **피크 QPS가 benchmark를 초과** → 캐시 적중률·샤딩·큐·CDN을 workload에 맞춰 비교
- **5년 스토리지가 수십 TB급** → 단일 노드의 디스크·복구 시간을 검증하고 파티셔닝·콜드 스토리지 계층화를 검토

> **🎯 면접 포인트**
>
> 추정을 건너뛰고 바로 아키텍처를 그리면 "왜 캐시를 넣었죠? 왜 샤딩이 필요하죠?"에 답을 못 한다. **숫자 → 결정** 의 인과를 보여주는 게 시니어 신호. 가정(assumption)을 *먼저 소리 내어 선언* 하고 시작하라. 🔥(Deep-dive)

## 2. 추정 절차 — DAU에서 대역폭까지

```mermaid
flowchart TB
    A["① 가정 선언\nDAU, 사용자당 요청수,\nRead:Write 비율,\n객체 크기, 보관기간"]
    B["② QPS 계산\n평균 QPS = DAU × 요청수 ÷ 86,400\n피크 QPS = 평균 × 2~10"]
    C["③ 스토리지\n일일 = 쓰기건수 × 객체크기\n× (1+복제/인덱스 오버헤드)\n→ 연/5년 누적"]
    D["④ 대역폭\nIngress = 쓰기 QPS × 객체크기\nEgress = 읽기 QPS × 객체크기"]
    E["⑤ 캐시/메모리\n핫셋 = 일일 읽기의 20%\n(80/20 법칙)"]
    F["⑥ 결정 도출\n캐시? 샤딩? 큐? CDN?"]

    A --> B --> C --> D --> E --> F

    style A fill:#fef3c7,stroke:#f59e0b
    style B fill:#dbeafe,stroke:#3b82f6
    style C fill:#ede9fe,stroke:#8b5cf6
    style D fill:#dcfce7,stroke:#22c55e
    style E fill:#fce7f3,stroke:#ec4899
    style F fill:#f0fdf4,stroke:#16a34a
```

*표준 추정 파이프라인 — 이 순서를 외워 두면 어떤 문제든 같은 틀로 풀 수 있다.*

> **💡 팁 — 항상 가정부터**
>
> "DAU를 1,000만으로 가정하겠습니다. 사용자당 하루 5번 조회, Read:Write = 100:1로 보겠습니다." 처럼 **가정을 명시** 하고 시작하면, 숫자가 틀려도 면접관이 "그럼 DAU를 5,000만으로 바꿔보죠"라고 대화를 이어갈 수 있다. 가정 없는 숫자는 검증 불가.

## 3. 2의 거듭제곱 표 & 라운딩 트릭

| 2의 거듭제곱 | 근사값 | 이름 | 바이트 단위 |
| --- | --- | --- | --- |
| 210 | ≈ 1 천 (1.024×10³) | Kilo | 1 KB |
| 220 | ≈ 1 백만 (10⁶) | Mega | 1 MB |
| 230 | ≈ 10 억 (10⁹) | Giga | 1 GB |
| 240 | ≈ 1 조 (10¹²) | Tera | 1 TB |
| 250 | ≈ 10¹⁵ | Peta | 1 PB |

### 시간·인구 라운딩 트릭

| 대상 | 정확값 | 암산용 라운딩 |
| --- | --- | --- |
| 하루 초 수 | 86,400 s | **≈ 105 (= 100,000)** |
| 한 달 초 수 | 2,592,000 s | ≈ 2.5×10⁶ |
| 1년 | 365.25 일 | ≈ 400 일 (계산 편의) 또는 365 |
| 대한민국 인구 | 약 5,100만 | ≈ 5×10⁷ |
| 전 세계 인터넷 사용자 | 약 50억 | ≈ 5×10⁹ |

> **💡 핵심 암산 트릭 — 1 day ≈ 86,400s ≈ 10⁵**
>
> "하루 = 8.64만 초"를 **10만(10⁵)** 으로 반올림하면 나눗셈이 즉시 끝난다. 예) DAU 1억(10⁸) × 요청 1회 ÷ 10⁵ = **10³ = 1,000 QPS** . 정확히는 ÷86,400 = 1,157 QPS지만, 자릿수는 동일. 면접에선 1,000으로 가도 충분하다.

> **⚠️ 면접 함정 #1 — 정확한 숫자에 집착**
>
> 86,400으로 손계산하다 시간을 다 쓰는 지원자가 많다. 면접관이 보는 건 **자릿수와 사고 과정** 이지 소수점이 아니다. **과감히 라운딩** 하고 "대략 1천 QPS급"이라고 말한 뒤 다음 단계로 넘어가라.

## 4. 참고 지연시간 표 (환경 의존)

설계가 "메모리에서 끝나는 일인지, 디스크/네트워크를 타는 일인지"를 판단하려면 자릿수 감각이 도움이 된다. 아래 값은 하드웨어·네트워크·동시성에 따라 달라지므로 상대적인 출발점으로만 쓰고 부하 테스트로 검증한다.

| 연산 | 대략 지연 | 상대 감각 |
| --- | --- | --- |
| L1 캐시 참조 | ≈ 0.5 ns | 기준 |
| 분기 예측 실패 | ≈ 5 ns | — |
| L2 캐시 참조 | ≈ 7 ns | L1의 14배 |
| **메인 메모리 참조** | **≈ 100 ns** | L1의 200배 |
| 1 KB Snappy 계열 압축(예시 benchmark) | ≈ 3 μs | — |
| 1 Gbps로 1 KB 전송 | ≈ 10 μs | — |
| **SSD random read** | **≈ 0.1 ~ 0.15 ms (100~150 μs)** | 메모리의 약 1,000배 |
| **DC(데이터센터) 내부 round trip** | **≈ 0.5 ms (500 μs)** | — |
| 메모리에서 1 MB 순차 읽기 | ≈ 0.25 ms | — |
| SSD에서 1 MB 순차 읽기 | ≈ 1 ms | — |
| **디스크(HDD) seek** | **≈ 10 ms** | SSD seek의 약 100배 |
| 디스크에서 1 MB 순차 읽기 | ≈ 20~30 ms | — |
| **대륙 간(예: 서울↔미국) round trip** | **≈ 150 ms** | DC 내부의 약 300배 |

> **💡 외울 핵심 5개**
>
> **메모리·SSD·데이터센터 RTT·디스크·대륙간 RTT의 상대 크기**를 출발점으로 삼되, 실제 설계에서는 측정 환경의 p95/p99 값을 사용한다. "캐시 히트는 메모리(0.1μs), 미스는 SSD(0.1ms)면 1,000배 차이 → 캐시 적중률이 곧 성능"이라는 결론이 여기서 나온다.

> **⚠️ 실무 함정 — 대륙간 RTT를 무시**
>
> 글로벌 서비스에서 단일 리전 DB에 모든 읽기를 보내면 멀리 있는 사용자는 RTT 150ms를 매번 먹는다. 그래서 **CDN·엣지 캐시·멀티 리전 읽기 복제** 가 필요하다는 결론이 이 숫자에서 도출된다.

## 5. QPS 산정 공식과 피크 배율

**QPS(Queries Per Second, 초당 쿼리 수)**는 용량의 핵심 지표다. 공식은 단순하다.

> **공식** — 평균 QPS = (DAU × 사용자당 요청 수) ÷ 86,400 · 피크 QPS = 평균 QPS × (2 ~ 10)

```mermaid
flowchart LR
    DAU["DAU\n예: 5,000만\n5×10⁷"]
    REQ["× 사용자당 요청\n예: 10회/일"]
    SEC["÷ 86,400\n(≈10⁵)"]
    AVG["평균 QPS\n≈ 5,000 ~ 5,800"]
    PEAK["× 피크배율 (2~10)\n점심·저녁·이벤트"]
    RES["피크 QPS\n≈ 1만 ~ 5만"]

    DAU --> REQ --> SEC --> AVG --> PEAK --> RES

    style DAU fill:#fef3c7,stroke:#f59e0b
    style AVG fill:#dbeafe,stroke:#3b82f6
    style PEAK fill:#fce7f3,stroke:#ec4899
    style RES fill:#fef2f2,stroke:#dc2626
```

*평균 QPS는 24시간을 균등 분배한 가상의 값. 실제 부하는 특정 시간대에 몰리므로 **피크 QPS로 용량을 산정**해야 한다.*

### 피크 배율을 정하는 감각

- **완만한 서비스**(사내 도구, B2B): 피크 ≈ 평균 × 2~3
- **일반 소비자 앱**: 점심·저녁 집중 → 평균 × 3~5
- **이벤트성 스파이크**(식사 시간, 배송 마감, 티켓팅 등): 평균 × 10 이상일 수도 있다. 서비스별 트래픽 기록으로 별도 모델링한다.

> **⚠️ 면접 함정 #2 — 피크 트래픽 무시**
>
> 평균 QPS만으로 인프라를 산정하면 특정 시간대 피크에서 용량이 부족할 수 있다. **피크 기준으로 용량을 잡고**, 평소 부하는 오토스케일·큐로 흡수하는 가정을 명시한다.

## 6. 실전 예제 ① — 주문 시스템

> 아래 DAU·주문율·객체 크기·보존 기간은 설계 연습을 위한 가정이며 특정 서비스의 실측이 아니다.

#### Step 0 · 가정 선언

- DAU = **500만** (5×10⁶)
- 주문 전환: 활성 사용자 중 하루 **1건 주문** → 일일 주문 = 500만 건
- 조회(메뉴·매장·주문조회) : 주문 = **Read:Write ≈ 30:1**
- 주문 1건 저장 크기 ≈ **2 KB** (주문 헤더 + 메뉴 라인 + 결제·주소 메타)
- 주문 데이터 보관 = **5년**

#### Step 1 · 쓰기 QPS (주문)

평균 쓰기 QPS = 500만 ÷ 86,400 ≈ **57.8 ≈ 약 58 QPS**. 주문 시간대가 집중된다는 가정으로 피크 배율 **×10** 적용 → 피크 쓰기 ≈ **580 QPS**.

#### Step 2 · 읽기 QPS (조회)

일일 조회 = 500만 × 30 = **1.5억(1.5×10⁸)**. 평균 읽기 QPS = 1.5×10⁸ ÷ 10⁵ ≈ **1,500 QPS** → 피크 ×10 ≈ **15,000 QPS**.

#### Step 3 · 스토리지 (5년 누적)

- 일일 = 500만 × 2 KB = 10,000,000 KB = **약 10 GB/일** (십진 단위)
- 연간 = 10 GB × 365 ≈ **3.65 TB/년**
- 5년 = **≈ 18 TB** (인덱스·복제 오버헤드 ×3 가정 시 **≈ 55 TB**)

#### Step 4 · 대역폭

- 쓰기 Ingress(피크) = 580 QPS × 2 KB ≈ **1.16 MB/s** (작음)
- 읽기 Egress(피크) = 15,000 QPS × 2 KB ≈ **30 MB/s ≈ 240 Mbps**

#### Step 5 · 결정 도출

> **💡 숫자 → 설계 결정**
>
> **읽기 15,000 QPS**가 단일 RDBMS의 benchmark·connection·p99 latency budget을 초과하는지 먼저 측정하고, 초과할 경우 **Redis 캐시 + Read Replica**·쿼리 최적화·샤딩을 비교한다. 메뉴·매장 정보는 변동 빈도와 조회 분포를 측정해 캐시 적중률을 검증한다. **쓰기 580 QPS**도 단일 마스터가 항상 감당한다고 단정하지 말고 피크 지속시간과 transaction latency를 검증한다. 피크 스파이크는 **주문 접수 큐(Kafka)**로 흡수해 백프레셔(Back-pressure)를 만들 수 있다. **5년 18~55 TB**는 인덱스·복제 오버헤드를 포함한 가정이므로 실제 보존·복구 목표를 반영해 샤딩·콜드 스토리지 계층화를 결정한다.

> **🎯 면접 포인트**
>
> "피크 ×10"을 임의의 상수로 외우지 말고 시간대별 요청 기록으로 정당화한다. 쓰기와 읽기의 비율을 분리해 캐시 우선순위를 정하는 것이 핵심이다. 🔥(Deep-dive)

## 7. 실전 예제 ② — 라스트마일 TrackingEvent

> **문제 정의** — 전국 배송 스캔이 만드는 *대량 쓰기(write-heavy) 이벤트 스트림*의 용량을 잡아라.

#### Step 0 · 가정

- 일일 `TrackingEvent` = **5,000만 건** (5×10⁷) — 집하·간선·허브 경유·OFD·배송완료 등 운송장 1건당 여러 스캔
- 이벤트 1건 크기 = **300 B** (운송장ID, 상태코드, 위치, 타임스탬프, 기사ID)
- 보관 = **1년** (이후 콜드 스토리지)
- 조회: 고객·CS의 추적 조회 = 이벤트 쓰기의 약 **3배** (Read:Write ≈ 3:1, 한 운송장을 여러 번 새로고침)

#### Step 1 · 쓰기 QPS

평균 쓰기 QPS = 5×10⁷ ÷ 10⁵ = **500 QPS**. 라스트마일은 배송 시작(오전)·완료(저녁) 시간대 집중 → 피크 ×5 ≈ **2,500 QPS**.

#### Step 2 · 읽기 QPS

일일 조회 = 5×10⁷ × 3 = 1.5×10⁸ → 평균 = 1.5×10⁸ ÷ 10⁵ = **1,500 QPS** → 피크 ×5 ≈ **7,500 QPS**.

#### Step 3 · 스토리지

- 일일 = 5×10⁷ × 300 B = 1.5×10¹⁰ B = **15 GB/일**
- 연간 = 15 GB × 365 ≈ **5.475 TB/년** (≈ 5.5 TB)
- 인덱스(운송장ID·시간 복합 인덱스) + 복제 ×3 → **≈ 16 TB/년**

#### Step 4 · 대역폭

- 쓰기 Ingress(피크) = 2,500 QPS × 300 B = **0.75 MB/s**
- 읽기 Egress(피크) = 7,500 QPS × 300 B ≈ **2.25 MB/s**

#### Step 5 · 결정 도출

> **💡 숫자 → 설계 결정**
>
> **Write-heavy + 시계열**: 2,500 쓰기 QPS의 append-only 스트림 → **Kafka로 수집** 후 컨슈머가 배치 적재. 동기 DB 직접 쓰기는 피크에 위험. **시계열 저장**: 운송장ID로 파티셔닝 + 시간 정렬. RDBMS보다 **Cassandra/시계열 DB**나 파티셔닝된 테이블이 유리. **조회 7,500 QPS**: "마지막 상태"는 핫데이터 → **Redis에 운송장별 최신 상태 캐시**. 전체 이력은 콜드 조회. **Fan-out**: 한 스캔이 고객 푸시·CS·OMS 동기화로 퍼짐 → Kafka Topic으로 멀티 컨슈머. `Idempotency(멱등성)`로 중복 이벤트 흡수. 🔥(Deep-dive)

> **⚠️ 실무 함정 — 평균만 보고 큐를 뺀다**
>
> 평균 500 쓰기 QPS만 보면 "DB 직접 쓰기로 충분"이라 착각한다. 하지만 배송 피크·기사 앱 오프라인 동기화(지하·산간 후 재접속 시 누적 이벤트 일괄 전송) 때 순간 폭주가 발생 → **큐로 버퍼링** 해야 DB가 보호된다. 평균이 아닌 **버스트** 를 봐야 한다.

```text
peak_qps       = DAU × actions_per_day × peak_factor / 86,400
daily_storage  = events_per_day × bytes_per_event × replication_factor
queue_backlog  = ingress_rate - processing_rate
drain_seconds  = backlog / spare_processing_rate
```

## 검수 경계와 실패 흐름

- DAU·평균 QPS·피크 배율·요청 크기·보존 기간은 입력 가정으로 표에 적고, 실제 workload와 부하 테스트 결과로 갱신한다.
- cache hit rate가 떨어지거나 producer가 재전송하면 origin QPS와 큐 backlog가 동시에 늘어난다. `origin_qps = total_qps × (1 - hit_rate)`와 `drain_seconds = backlog / spare_processing_rate`를 다시 계산한다.
- consumer 처리량이 유입보다 낮아지면 lag·retention·DLQ·throttle을 함께 보고, 큐가 backlog를 숨기는 장치가 되지 않게 oldest age를 알람으로 둔다.
- 장애 복구 중에는 평균값 대신 p95/p99, burst, 재처리 중복, connection pool 고갈을 측정해 캐시·replica·queue 선택을 재검증한다.

## 공식·1차 출처

- [https://docs.aws.amazon.com/wellarchitected/latest/performance-efficiency-pillar/welcome.html](https://docs.aws.amazon.com/wellarchitected/latest/performance-efficiency-pillar/welcome.html)
- [https://sre.google/sre-book/handling-overload/](https://sre.google/sre-book/handling-overload/)$review_23_system_design_02_capacity_estimation$
WHERE slug = 'system-design-02-capacity-estimation' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_system_design_03_networking$> **검수 경계** — DNS·CDN·LB·Gateway·프로토콜에는 하나의 정석이 없다. 브라우저 제약, 캐시 가능성, 보안 경계, 장애 도메인과 운영 역량으로 선택한다.

## 0. 요청 경로 한눈에

시스템 디자인 면접에서 "사용자가 서비스 도메인을 입력하면 어떻게 되나요?"는 요청 경로를 설명하는 워밍업 질문이다. 아래 흐름을 머릿속에 그릴 수 있어야 모든 빌딩블록의 위치가 보인다.

```mermaid
flowchart TB
    Client(["📱 Client\n브라우저 / 앱"])
    DNS["🧭 DNS\nDomain Name System\n도메인 → IP 변환\n(GeoDNS로 가장 가까운 엣지 반환)"]
    CDN["🌐 CDN\nContent Delivery Network\n엣지 캐싱 (정적 자원·이미지)"]
    LB["⚖️ Load Balancer\nL4/L7 부하 분산\nHealth check + 알고리즘"]
    GW["🚪 API Gateway\n인증·라우팅·Rate limit·집계"]
    SvcA["🟦 Order Service"]
    SvcB["🟧 Inventory Service"]
    SvcC["🟪 Delivery Service"]

    Client -->|"① 도메인 조회"| DNS
    DNS -->|"② IP 응답 (TTL 캐싱)"| Client
    Client -->|"③ 정적 자원 요청"| CDN
    CDN -.->|"Cache miss → Origin"| LB
    Client -->|"④ 동적 API 요청"| LB
    LB --> GW
    GW --> SvcA
    GW --> SvcB
    GW --> SvcC

    style Client fill:#f1f5f9,stroke:#94a3b8
    style DNS fill:#dbeafe,stroke:#3b82f6,color:#1e3a8a
    style CDN fill:#dcfce7,stroke:#22c55e,color:#14532d
    style LB  fill:#fef3c7,stroke:#f59e0b,color:#78350f
    style GW  fill:#ede9fe,stroke:#8b5cf6,color:#3b0764
    style SvcA fill:#dbeafe,stroke:#3b82f6
    style SvcB fill:#fef3c7,stroke:#f59e0b
    style SvcC fill:#ede9fe,stroke:#8b5cf6
```

*Client → DNS → CDN → LB → API Gateway → 서비스. 정적 트래픽은 CDN에서 끝나고, 동적 트래픽만 Origin까지 내려간다.*

> **💡 팁 — "정적 vs 동적" 분기를 먼저 말하라**
>
> 면접에서 이 경로를 설명할 때, **정적 자원(이미지·JS·CSS)은 CDN에서 차단하고 동적 요청만 Origin으로 보낸다** 는 분기를 먼저 언급하면 트래픽 규모 감각이 있다는 인상을 준다. 상품 이미지가 매 요청마다 Origin을 거치면 대역폭과 원본 부하가 커질 수 있다.

## 1. 🧭 DNS — Domain Name System

> **핵심 책임** — 사람이 읽는 도메인(`coupang.com`)을 기계가 쓰는 IP(`23.x.x.x`)로 변환하는 분산 디렉터리.

### 동작 흐름 — 재귀 질의(Recursive Query)

```mermaid
sequenceDiagram
    participant C as Client
    participant R as Recursive Resolver\n(통신사/8.8.8.8)
    participant Root as Root NS
    participant TLD as TLD NS (.com)
    participant Auth as Authoritative NS

    C->>R: coupang.com A 레코드?
    Note over R: 로컬 캐시 확인 (TTL 유효 시 즉시 응답)
    R->>Root: .com 은 어디?
    Root-->>R: TLD NS 주소
    R->>TLD: coupang.com 은 어디?
    TLD-->>R: Authoritative NS 주소
    R->>Auth: coupang.com A 레코드 주세요
    Auth-->>R: 23.x.x.x (GeoDNS: 가장 가까운 엣지)
    R-->>C: 23.x.x.x (TTL 동안 캐싱)
```

*DNS 재귀 질의 — 한 번 해석하면 TTL 동안 Resolver/OS/브라우저가 캐싱하므로 매 요청마다 전체 경로를 타지 않는다.*

### 트래픽 분산·라우팅 정책

- **Round-robin DNS(라운드로빈)**: 하나의 도메인에 여러 A 레코드를 등록해 순환 응답. 가장 단순한 분산이지만 **서버 상태를 모른다** — 죽은 서버 IP도 그대로 반환할 수 있다.
- **GeoDNS(지리 기반 DNS)**: 클라이언트의 Resolver IP 위치를 보고 가장 가까운 리전/엣지의 IP를 반환. 한국 사용자는 서울 엣지, 미국 사용자는 버지니아 엣지.
- **Weighted / Latency-based(가중치·지연 기반)**: AWS Route 53의 정책처럼 가중치나 실측 지연으로 트래픽 비율 조정 — 카나리 배포·재해 복구에 활용.

### TTL(Time To Live) — 양날의 검

TTL은 레코드를 얼마나 캐싱할지 정하는 초 단위 값이다.

- **긴 TTL(예: 86400s)**: 질의 부하·지연 감소. 그러나 장애 시 트래픽을 죽은 IP에서 떼어내는 데 최대 TTL만큼 걸린다.
- **짧은 TTL(예: 30~60s)**: Failover(장애 전환)가 빠르지만 DNS 질의량 증가. 보통 Failover가 중요한 엔드포인트는 짧게 둔다.

> **⚠️ 실무 함정 — TTL은 "최댓값"일 뿐, 강제 만료가 안 된다**
>
> 배포 전환을 위해 TTL을 줄여도, **이미 캐싱된 레코드는 남은 TTL이 지나야 만료** 된다. 그래서 IP 변경 전 며칠 전부터 TTL을 미리 낮춰두는 "TTL lowering" 사전작업이 표준이다. 또한 일부 Resolver/브라우저는 TTL을 무시하고 자체 정책으로 캐싱하므로 100% 통제는 불가능.

> **🎯 면접 함정**
>
> "DNS로 부하 분산하면 LB 필요 없지 않나요?" → **오답.** DNS Round-robin은 (1) 서버 헬스를 모르고, (2) 캐싱 때문에 분산이 고르지 않으며, (3) 세션 친화성(Sticky)을 제어 못 한다. DNS는 *리전 단위 거친 분산* , LB는 *리전 내 정밀 분산* 으로 역할이 다르다고 답해야 한다.

## 2. 🌐 CDN — Content Delivery Network

> **핵심 책임** — 사용자와 물리적으로 가까운 *엣지 서버(Edge / PoP)*에 콘텐츠를 캐싱해 지연과 Origin 부하를 동시에 줄인다.

### Pull vs Push

| 방식 | 동작 | 장점 | 단점·적합한 상황 |
| --- | --- | --- | --- |
| **Pull CDN** (Origin Pull) | 첫 요청 때 Cache miss → CDN이 Origin에서 끌어와 캐싱. 이후 TTL 동안 엣지가 응답 | 운영 단순(자동 캐싱), 스토리지 절약 | 첫 요청은 느림(Cold), Origin 보호 위해 캐시 정책 튜닝 필요. **대부분의 웹은 Pull.** |
| **Push CDN** | 운영자가 콘텐츠를 미리 엣지로 업로드(배포) | Cold miss 없음, 대용량 파일·트래픽 예측 가능 시 유리 | 업로드·동기화 관리 부담. 동영상 VOD, 게임 패치, 대규모 소프트웨어 배포에 적합 |

### 정적 가속 vs 동적 가속

- **정적 가속**: 이미지·JS·CSS·폰트·VOD처럼 변하지 않는 자원을 엣지에서 직접 응답. Cache-Control·ETag로 제어.
- **동적 가속(Dynamic Acceleration)**: API 같은 동적 응답은 캐싱이 어렵지만, CDN이 Origin까지 **최적 경로(백본 네트워크)**와 **TLS 종료·연결 재사용**으로 가속. AWS CloudFront, Cloudflare가 제공.

### 적용 사례

- 대용량 이미지·동영상은 자체 CDN 또는 관리형 CDN을 조합할 수 있다. 어떤 구성을 쓰는지는 공개된 제품 문서와 트래픽 계약으로 확인한다.
- 상품 이미지처럼 정적인 응답은 CDN으로 캐시하고, 가격·재고처럼 자주 바뀌는 응답은 짧은 TTL·버전 키·캐시 우회를 요구사항에 맞게 선택한다.

> **⚠️ 실무 함정 — 캐시 무효화(Invalidation)**
>
> "상품 이미지를 교체했는데 옛날 이미지가 계속 보여요"는 전형적 CDN 사고다. 해결: (1) 파일명에 해시를 붙이는 **버전드 URL** ( `logo.a1b2c3.png` ) — 가장 안전, (2) CDN **Purge API** 로 강제 무효화 — 전 엣지 전파에 수십 초~수 분. 가격 같은 실시간 데이터는 애초에 캐싱하지 말 것.

## 3. ⚖️ Load Balancer — 부하 분산기

> **핵심 책임** — 들어오는 요청을 여러 백엔드 인스턴스에 나눠, 단일 인스턴스 과부하·SPOF(Single Point of Failure, 단일 장애점)를 방지한다.

### L4 vs L7 — OSI 계층이 다르다

```mermaid
sequenceDiagram
    participant C as Client
    participant L4 as L4 LB\n(Transport / TCP·UDP)
    participant L7 as L7 LB\n(Application / HTTP)
    participant S as Backend

    Note over C,S: ── L4: 패킷의 IP·포트만 보고 전달 ──
    C->>L4: TCP SYN (dst :443)
    L4->>S: 그대로 포워딩 (4-tuple 해시로 서버 선택)
    Note over L4: 페이로드를 열지 않음 → 빠름, 저지연

    Note over C,S: ── L7: HTTP 내용을 파싱해 라우팅 ──
    C->>L7: GET /api/orders Host: shop.com
    Note over L7: TLS 종료 + 경로·헤더·쿠키 검사
    L7->>S: /api/orders 는 Order 서비스로
```

*L4는 4-tuple(출발/도착 IP·포트)만 보고 포워딩, L7은 HTTP 페이로드를 파싱해 경로·호스트·쿠키 기반 라우팅. 대신 L7은 연결당 비용이 크다.*

| 관점 | L4 (전송 계층) | L7 (애플리케이션 계층) |
| --- | --- | --- |
| 판단 기준 | IP·포트 (4-tuple) | URL·Host·Header·Cookie·HTTP method |
| 성능 | 매우 빠름, 낮은 지연·높은 처리량 | 파싱 오버헤드로 상대적으로 느림 |
| 기능 | 단순 포워딩 | 경로 라우팅, TLS 종료, 헤더 조작, WAF, 압축 |
| AWS 대응 | NLB (Network Load Balancer) | ALB (Application Load Balancer) |
| 적합 | 초저지연 게임·금융, gRPC/임의 TCP | 마이크로서비스 경로 라우팅, 웹 트래픽 |

> **🎯 면접 함정 — "L4/L7 차이 모름"은 즉시 감점**
>
> "L4랑 L7 LB 차이가 뭔가요?"는 거의 모든 백엔드 면접에 나온다. 핵심 한 줄: **L4는 패킷의 IP·포트만 보고 전달(내용 안 봄), L7은 HTTP 내용을 열어 경로·헤더로 라우팅한다.** 그래서 "URL `/api/v2` 만 새 버전으로 보내기" 같은 건 L7에서만 가능. gRPC를 L7 ALB 뒤에 둘 땐 HTTP/2 지원 여부를 반드시 확인.

### 분산 알고리즘

| 알고리즘 | 동작 | 장점 | 단점·적합 |
| --- | --- | --- | --- |
| **Round-robin** (라운드로빈) | 순서대로 한 대씩 순환 | 단순, 균등 분배 가정 시 충분 | 요청 처리시간이 제각각이면 불균형 — 동질 서버에 적합 |
| **Weighted RR** (가중 라운드로빈) | 서버 스펙에 비례한 가중치 | 이기종 서버 혼합 대응 | 가중치 수동 관리 |
| **Least connections** (최소 연결) | 현재 활성 연결이 가장 적은 서버로 | 롱-커넥션·요청시간 편차 큰 워크로드에 강함 | 연결 수 추적 비용. WebSocket·스트리밍에 유리 |
| **Consistent hashing** (일관성 해시) | 키(예: userId)를 해시해 같은 서버로 고정 | 캐시 지역성↑, 서버 증감 시 재배치 최소 | 키 분포 쏠리면 Hot. 세션·로컬 캐시 친화 라우팅에 적합 |
| **IP hash** | 클라이언트 IP 해시로 고정 | 간단한 Sticky 구현 | NAT 뒤 다수 사용자가 한 서버로 몰림 |

### Health check & Sticky session

- **Health check(헬스 체크)**: LB가 주기적으로 `/healthz`를 호출해 비정상 인스턴스를 풀에서 자동 제외. *Shallow*(프로세스 살아있나) vs *Deep*(DB·의존성까지 확인) 트레이드오프 — Deep은 정확하지만 의존성 장애 시 전체 인스턴스를 죽은 것으로 오판해 연쇄 장애를 부를 수 있다.
- **Sticky session(세션 고정)**: 같은 클라이언트를 같은 서버로 보내 로컬 세션을 재사용. 단점은 **확장성·재배포 시 세션 유실, 불균형**. 권장: 세션을 Redis 같은 외부 저장소로 빼서 **Stateless(무상태)** 서버를 만들고 Sticky를 제거하는 방향.

> **💡 팁 — 대규모 서비스의 트래픽 경로 멘탈모델**
>
> 대규모 이커머스의 동적 트래픽은 보통 **GeoDNS → 리전 진입 → L7 LB(ALB) → API Gateway → 서비스 메시** 순. 정적 자원은 같은 도메인이라도 CDN 엣지에서 분기돼 Origin을 거치지 않는다. "트래픽 피크 시 어디가 먼저 터지나?"를 물으면 보통 *L7 LB 연결 수 한계* 와 *DB 커넥션 풀* 을 짚는다.

## 4. 🚪 API Gateway

> **핵심 책임** — 클라이언트와 마이크로서비스 사이의 *단일 진입점(Single Entry Point)*. 횡단 관심사(인증·Rate limit·로깅)를 한곳에 모은다.

### 주요 역할

- **인증·인가(AuthN/AuthZ)**: JWT(JSON Web Token) 검증, OAuth 토큰 확인을 게이트웨이에서 처리 → 각 서비스가 중복 구현하지 않음.
- **라우팅(Routing)**: `/orders`는 Order 서비스, `/delivery`는 Delivery 서비스로 — 경로·버전 기반.
- **Rate limiting(요청 제한)**: 사용자·API key 단위로 초당 요청 제한. Token bucket·Sliding window 알고리즘.
- **집계(Aggregation / BFF)**: 한 화면에 필요한 여러 서비스 호출을 게이트웨이가 모아서 한 응답으로 — 모바일 라운드트립 절감.
- **기타**: 요청/응답 변환, 캐싱, 회로 차단(Circuit breaker), 관측성(Tracing) 주입.

### API Gateway vs Reverse Proxy — 무엇이 다른가

| 관점 | Reverse Proxy | API Gateway |
| --- | --- | --- |
| 주 관심사 | 네트워크 레벨 중계·캐싱·TLS 종료 | API 레벨 정책(인증·Rate limit·집계) |
| 추상화 수준 | HTTP 요청 전달 | 비즈니스 API·서비스 토폴로지 인지 |
| 대표 제품 | Nginx, HAProxy, Envoy | Kong, AWS API Gateway, Spring Cloud Gateway |
| 관계 | API Gateway는 사실상 **"정책 기능이 풍부한 Reverse Proxy"** — Kong은 Nginx 위에, AWS API GW도 프록시 위에 정책 계층을 얹은 형태. 둘은 배타적이 아니라 포함 관계에 가깝다. |  |

> **💡 사례 — API Gateway 설계 가설**
>
> 게이트웨이에 **인증·트래픽 제어·감사 로깅·이상 탐지**를 둘 수 있지만, 정책과 장애 격리는 제품·규제 요구에 따라 달라진다. 게이트웨이는 SPOF가 될 수 있으므로 **다중화·무상태 설계·빠른 Failover**를 부하 테스트로 검증한다.

> **⚠️ 실무 함정 — Gateway에 비즈니스 로직을 넣지 마라**
>
> 편하다고 게이트웨이에 도메인 분기·데이터 조합 로직을 쌓으면 "분산 모놀리스"가 되어 배포 병목과 SPOF를 만든다. 게이트웨이는 **횡단 관심사만** . 화면별 집계가 많으면 차라리 **BFF(Backend For Frontend)** 를 별도로 두는 게 낫다.

## 5. 🔁 Reverse Proxy (Nginx 등)

**Forward Proxy**는 클라이언트를 대신해 나가는 트래픽을 중계(사내 방화벽·필터링), **Reverse Proxy(역방향 프록시)**는 서버 앞에 서서 들어오는 트래픽을 받아 백엔드로 분배한다. 클라이언트는 진짜 서버를 모른다.

#### Reverse Proxy의 전형적 역할

- **TLS 종료(TLS termination)**: HTTPS 복호화를 프록시에서 처리해 백엔드 부담 경감.
- **정적 파일 서빙·캐싱**: Nginx가 정적 자원을 직접 응답, 동적 요청만 앱으로.
- **압축(gzip/brotli)·요청 버퍼링·연결 풀링**.
- **L7 부하 분산**: 실은 Nginx는 Reverse Proxy이자 L7 LB. 그래서 LB·프록시·게이트웨이의 경계가 제품마다 겹친다.

> **💡 팁 — 세 컴포넌트의 관계 정리**
>
> **Reverse Proxy ⊂ (L7 LB) ⊂ (API Gateway)** 로 기능이 점점 쌓인다고 보면 깔끔하다. Nginx 하나로 프록시+LB를, Envoy로 프록시+LB+관측성을, Kong으로 그 위에 API 정책까지 — 면접에선 "제품 이름"이 아니라 "어떤 책임을 어디서 처리하는가"로 답하라.

## 6. REST vs gRPC vs GraphQL

세 가지는 "서비스끼리 또는 클라이언트와 서버가 어떻게 대화하나"를 정하는 API 스타일이다. 정답은 없고 **용도에 따라 다르다.**

| 관점 | REST | gRPC | GraphQL |
| --- | --- | --- | --- |
| 전송·포맷 | HTTP/1.1 + JSON (텍스트) | HTTP/2 + Protobuf (바이너리) | HTTP/1.1 + JSON (단일 엔드포인트) |
| 스키마·계약 | 느슨(OpenAPI 선택적) | 엄격(`.proto` 강제) | 엄격(GraphQL Schema) |
| 성능·페이로드 | JSON 파싱·중복 큼 | Protobuf로 작고 빠름, 멀티플렉싱 | 필요한 필드만 받아 over-fetch 제거(서버 파싱은 비쌈) |
| 스트리밍 | 기본 없음(SSE 등 별도) | **양방향 스트리밍 1급 지원** | Subscription(WebSocket) |
| Over/Under-fetching | 흔함(고정 응답) | 고정(메시지 정의) | **클라이언트가 필드 선택** → 해결 |
| 브라우저·캐싱 | 최상(HTTP 캐시·CDN 친화) | 브라우저 직접 불가(gRPC-Web 필요) | HTTP 캐싱 약함(POST 단일 URL) |
| 대표 용도 | 공개 API, 웹·모바일 표준 | **내부 MSA 서비스 간 통신**, 저지연 | 복잡한 화면·다양한 클라이언트(앱·웹) 집계 |

### gRPC 호출 흐름 — HTTP/2 멀티플렉싱·스트리밍

```mermaid
sequenceDiagram
    participant C as Client Stub
    participant S as gRPC Server

    Note over C,S: 단일 HTTP/2 연결에서 여러 RPC 멀티플렉싱
    C->>S: Unary RPC GetOrder(orderId)
    S-->>C: Order (Protobuf 바이너리)

    Note over C,S: Server streaming — 추적 이벤트 푸시
    C->>S: TrackShipment(trackingId)
    S-->>C: Event1 InTransit
    S-->>C: Event2 OutForDelivery
    S-->>C: Event3 Delivered
    Note over C,S: 한 연결, 하나의 요청, 여러 응답 스트림
```

*gRPC는 HTTP/2의 멀티플렉싱으로 한 TCP 연결에 여러 RPC를 흘리고, Server/Client/양방향 스트리밍을 1급으로 제공한다.*

> **🎯 면접 함정 — "gRPC는 무조건 빠르다"는 오해**
>
> gRPC가 유리할 수 있는 이유는 **Protobuf 바이너리와 HTTP/2 기능**이지 마법이 아니다. 브라우저 호환성·HTTP 캐싱·운영 도구·페이로드 크기를 비교해 선택하며, 외부는 REST/GraphQL, 내부는 gRPC라는 조합은 흔한 선택지일 뿐 요구사항에 따라 바뀐다.

> **⚠️ 실무 함정 — GraphQL의 N+1과 캐싱**
>
> GraphQL은 over-fetch를 없애지만 **중첩 쿼리가 백엔드에서 N+1 쿼리 폭발** 을 일으킬 수 있어 DataLoader 배칭이 필수. 또 단일 POST 엔드포인트라 **HTTP·CDN 캐싱이 어렵고** , 클라이언트가 임의로 무거운 쿼리를 던질 수 있어 **쿼리 복잡도 제한·depth 제한** 이 필요하다.

## 7. 물류 적용 — 라스트마일 추적 API: REST vs gRPC

"운송장 추적(Tracking)" API를 어떤 프로토콜로 설계할까? 호출자가 누구냐에 따라 답이 갈린다.

| 경계 | 호출 주체 | 권장 | 이유 |
| --- | --- | --- | --- |
| **고객 앱 ↔ 추적 API** | 외부 모바일·웹 | **REST** (+ 실시간은 SSE/WebSocket) | 브라우저·CDN 친화, 공개 계약 단순. 지도 위 위치 푸시는 WebSocket 보강 |
| **기사 앱 ↔ 위치 수집** | 모바일 → 게이트웨이 | **REST/gRPC + 배치 업로드** | 오프라인 구간(지하·산간) 누적 후 재접속 시 배치 전송 + 멱등성(Idempotency) 필요 |
| **추적 서비스 ↔ OMS/알림 서비스** | 내부 마이크로서비스 | **gRPC (스트리밍) 후보** | streaming·Protobuf가 호출 패턴에 맞는지 비교하되, 처리량·지연은 payload·동시 stream·메시지 크기별 benchmark로 정한다 |

정량 감각의 예로 DAU 1,000만, 1인당 추적 화면 5회 폴링을 가정하면 하루 5,000만 조회 ≈ 평균 **580 QPS(Queries Per Second, 초당 쿼리 수)**다. 피크 배율은 관측으로 정하고, Origin DB 보호를 위해 **최신 상태를 CDN/엣지 캐시 또는 Redis**에 둘지와 TTL·Push 정책을 비교한다.

> **💡 연결 — 이 빌딩블록이 어떻게 합쳐지나**
>
> 라스트마일 추적: **GeoDNS** 로 가까운 리전 → 지도 타일·아이콘은 **CDN** → 추적 API는 **L7 LB → API Gateway** (인증·Rate limit) → 외부는 REST, 내부 이벤트 Fan-out은 **gRPC 스트리밍 + Kafka** . 한 시스템 안에서 모든 빌딩블록이 자기 자리를 갖는다.

```bash
dig tracking.example.com
curl -v --resolve tracking.example.com:443:203.0.113.10 \
  https://tracking.example.com/api/v1/shipments/W-42
```

## 검수 경계와 실패 흐름

- DNS 응답은 TTL과 resolver cache 때문에 즉시 회수되지 않을 수 있으므로 health signal·draining·전환 시간을 따로 측정한다.
- CDN/edge에는 공개·캐시 가능한 응답만 두고, 인증·개인정보·사용자별 결과는 cache key와 `Vary` 경계를 먼저 검토한다.
- gRPC/REST 호출은 deadline·retry budget·backpressure를 전파하고, timeout 뒤 재시도로 retry storm이 생기지 않는지 trace와 p95/p99로 확인한다.
- Gateway·LB·origin 중 한 계층이 실패할 때의 fallback과 rate limit을 그려 보고, 캐시 미스 폭주가 원장 DB의 connection pool을 고갈시키지 않는지 부하 테스트한다.

## 공식·1차 출처

- [https://developer.mozilla.org/en-US/docs/Glossary/DNS](https://developer.mozilla.org/en-US/docs/Glossary/DNS)
- [https://developers.cloudflare.com/cache/](https://developers.cloudflare.com/cache/)
- [https://grpc.io/docs/what-is-grpc/core-concepts/](https://grpc.io/docs/what-is-grpc/core-concepts/)
- [https://spec.graphql.org/](https://spec.graphql.org/)$review_23_system_design_03_networking$
WHERE slug = 'system-design-03-networking' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_system_design_04_data_storage$> **검수 경계** — 저장소와 샤딩 전략은 제품 이름의 우열이 아니라 질의 패턴, 트랜잭션 범위, 키 분포, 복구 목표에 따른 설계 가설이다.

## 1. SQL vs NoSQL — 언제 무엇을

> **결정 기준** — 정답은 없다. *데이터 접근 패턴(읽기/쓰기 형태)·일관성 요구·확장 축*으로 고른다.

"NoSQL이 빠르고 좋다"는 면접 즉시 감점이다. RDBMS는 **강한 일관성·복잡한 조인·트랜잭션(ACID)**에 강하고, NoSQL은 **특정 접근 패턴에 맞춰 수평 확장·고처리량**에 강하다. 핵심은 "이 데이터를 *어떻게 읽고 쓰는가*"다.

| 유형 | 모델 | 강점 | 대표 | 전형 용도 |
| --- | --- | --- | --- | --- |
| **RDBMS** | 테이블·관계·스키마 고정 | ACID 트랜잭션, 조인, 강한 일관성 | MySQL, PostgreSQL | 주문·결제·정산처럼 정합성이 생명인 OLTP |
| **Key-Value** | key → value (불투명) | O(1) 조회, 초고속·단순 | Redis, DynamoDB | 세션·캐시·카운터·Rate limit |
| **Document** | JSON 형태의 자유 문서 | 유연한 스키마, 중첩 구조 | MongoDB | 상품 카탈로그, 스키마가 자주 바뀌는 도메인 |
| **Wide-column** | row key + 동적 컬럼 | 쓰기 처리량·시계열·대용량에 강함 | Cassandra, HBase, Bigtable | 로그·이벤트·TrackingEvent 같은 append 패턴 |
| **Graph** | 노드·엣지 관계 | 다단계 관계 탐색이 빠름 | Neo4j | 소셜 그래프, 추천, 경로·관계 분석 |

> **🎯 면접 함정 — "왜 그 DB?"에 접근 패턴으로 답하라**
>
> "주문은 왜 RDBMS, 추적 이벤트는 왜 Cassandra인가?" → **주문은 결제·재고와 트랜잭션으로 묶이고 조인·정합성이 필수라 RDBMS, 추적 이벤트는 초당 수만 건 append-only·시계열 조회라 쓰기 확장에 강한 Wide-column** . "빠르니까"는 답이 아니다. 데이터의 읽기/쓰기 형태로 정당화하라.

> **💡 팁 — Polyglot Persistence(다중 저장소)**
>
> 실제 시스템은 용도별 저장소를 조합할 수 있다. 다만 특정 회사의 내부 구성을 일반화하지 말고 공개 문서 또는 요구사항에 근거해 **용도별 분리와 정합성 동기화 방법**을 설명한다.

## 2. Replication (복제) — 읽기 확장과 가용성

> **핵심 목적** — 같은 데이터를 여러 노드에 복제 → *읽기 분산·고가용성(HA)·재해 복구*. 단, 쓰기 확장은 아니다.

### Leader-Follower (Master-Slave) 복제

```mermaid
flowchart TB
    App["🟦 Application"]
    Leader["👑 Leader (Master)\n쓰기 전담"]
    F1["📖 Follower 1\n(Read replica)"]
    F2["📖 Follower 2\n(Read replica)"]
    F3["📖 Follower 3\n(Read replica)"]

    App -->|"Write (INSERT/UPDATE)"| Leader
    App -->|"Read (SELECT)"| F1
    App -->|"Read"| F2
    App -->|"Read"| F3
    Leader -.->|"replication log\n(WAL / binlog)"| F1
    Leader -.->|"비동기 복제\n→ replication lag 발생"| F2
    Leader -.->|""| F3

    style Leader fill:#fef3c7,stroke:#f59e0b,color:#78350f
    style F1 fill:#dbeafe,stroke:#3b82f6
    style F2 fill:#dbeafe,stroke:#3b82f6
    style F3 fill:#dbeafe,stroke:#3b82f6
```

*쓰기는 Leader 한 곳, 읽기는 Follower로 분산. Leader가 죽으면 Follower 하나를 승격(Failover). 읽기는 늘지만 쓰기 한계는 Leader가 그대로 가짐.*

### 동기 vs 비동기 복제

| 방식 | 동작 | 일관성·내구성 | 지연·가용성 Trade-off |
| --- | --- | --- | --- |
| **동기(Synchronous)** | Follower 확인까지 기다린 뒤 커밋 응답 | 데이터 유실 없음, 강한 내구성 | 쓰기 지연↑, Follower 하나 느리면 전체 쓰기 지연 — 보통 1개만 동기 |
| **비동기(Asynchronous)** | Leader가 즉시 응답, 복제는 백그라운드 | Leader 장애 시 **미복제분 유실 가능** | 쓰기 빠름, 그러나 **replication lag(복제 지연)** 발생 — 대부분 기본값 |

> **⚠️ 실무 함정 — Replication lag로 Read-your-writes가 깨진다**
>
> 비동기 복제에서 사용자가 글을 쓰고(Leader) 곧바로 새로고침해 Follower에서 읽으면, **아직 복제 안 된 옛 데이터** 가 보인다("방금 단 댓글이 사라졌어요"). 해결책: (1) **본인 쓰기 직후 일정 시간은 Leader에서 읽기** , (2) 쓰기 후 받은 LSN(로그 시퀀스 번호)까지 따라잡은 Follower만 사용, (3) Sticky 세션. 이게 **Read-your-writes(자기 쓰기 읽기 일관성)** 보장 기법이다. 🔥(Deep-dive)

> **💡 사례 — 금융 계좌**
>
> 금융 잔액 조회 트래픽은 막대하므로 Read replica로 분산하지만, **"방금 이체한 잔액"은 lag로 틀리면 안 되는** 대표 케이스다. 그래서 잔액 변경 직후 일정 구간은 Leader 읽기로 강제하거나, 핵심 잔액은 동기 복제·강한 일관성 경로로 둔다. 가용성보다 정합성이 먼저인 도메인.

## 3. Partitioning / Sharding — 쓰기·용량 확장

> **핵심 목적** — 데이터를 여러 노드로 *쪼개서* 분산 → 단일 노드의 쓰기·저장 용량 한계 돌파. 복제가 못 푸는 "쓰기 확장"을 해결.

용어 정리: **Partitioning(파티셔닝)**은 데이터를 조각으로 나누는 일반 개념, **Sharding(샤딩)**은 그 조각(shard)을 *여러 물리 노드*에 분산하는 것. 각 shard는 보통 자기 복제본(Leader-Follower)을 또 가진다.

```mermaid
flowchart TB
    Router["🧭 Shard Router\n(샤딩 키로 라우팅)"]
    S0["Shard 0\nuserId % 4 == 0"]
    S1["Shard 1\nuserId % 4 == 1"]
    S2["Shard 2\nuserId % 4 == 2"]
    S3["Shard 3\nuserId % 4 == 3"]

    Router --> S0
    Router --> S1
    Router --> S2
    Router --> S3

    style Router fill:#ede9fe,stroke:#8b5cf6,color:#3b0764
    style S0 fill:#dbeafe,stroke:#3b82f6
    style S1 fill:#fef3c7,stroke:#f59e0b
    style S2 fill:#dcfce7,stroke:#22c55e
    style S3 fill:#fce7f3,stroke:#ec4899
```

*샤딩 키(여기선 userId)로 어느 shard에 쓸지/읽을지 결정. 각 shard는 독립된 쓰기 노드 → 쓰기 처리량이 노드 수에 비례해 확장된다.*

### 파티셔닝 전략 비교

| 전략 | 방식 | 장점 | 단점·Hotspot 위험 |
| --- | --- | --- | --- |
| **범위 기반** (Range) | 키 범위로 분할 (예: 날짜, A~M / N~Z) | 범위 스캔 효율적, 정렬 조회 유리 | **최신 데이터 한 파티션 쏠림**(오늘 날짜·자동증가 ID) → Hot partition |
| **해시 기반** (Hash) | 키 해시 % N 으로 분할 | 균등 분산, 핫스팟 방지에 유리 | 범위 스캔 불가, **노드 증감 시 대량 재배치**(→ Consistent hashing으로 보완) |
| **디렉토리 기반** (Directory / Lookup) | 키→shard 매핑을 별도 룩업 테이블로 관리 | 유연한 재배치, 키 분포 제어 자유 | 룩업 테이블이 SPOF·병목 가능 → 캐싱·다중화 필요 |

> **🎯 면접 함정 — 샤딩 키를 monotonic id로 잡으면 Hot shard**
>
> **auto-increment ID나 timestamp를 샤딩 키로 쓰면, 항상 최신 shard로만 쓰기가 몰려** 한 노드가 죽고 나머지는 논다(Hotspot). 해결: (1) 해시 기반 분산, (2) 키에 접두 솔트·버킷을 섞기, (3) 자연스러운 고-카디널리티 키(userId, deviceId) 선택. "샤딩 키 = monotonic id"는 단골 함정이다. 🔥(Deep-dive)

> **⚠️ 실무 함정 — 분산 조인·교차 샤드 트랜잭션 비용**
>
> 샤딩하면 **여러 shard에 걸친 JOIN·트랜잭션이 비싸진다** (스캐터-개더, 2PC). 대응: (1) **함께 조회되는 데이터는 같은 샤딩 키로 co-locate** (예: 한 사용자의 주문은 같은 shard), (2) 교차 샤드 작업은 애플리케이션에서 합치거나 비정규화, (3) 분산 트랜잭션 대신 Saga. "샤딩하면 다 해결"이 아니라 "조인·트랜잭션을 잃는다"는 대가를 반드시 언급하라.

## 4. Consistent Hashing (일관성 해시)

> **해결하는 문제** — 단순 `hash % N`은 노드가 1개 늘면 *거의 모든 키가 재배치*된다. 일관성 해시는 노드 증감 시 **이동 키를 1/N 수준으로 최소화**한다.

`hash(key) % N`의 문제: 노드 수 N이 4→5로 바뀌면 나머지 연산 결과가 거의 전부 달라져 캐시 미스 폭발·대량 데이터 이동이 일어난다. 일관성 해시는 키와 노드를 **같은 해시 링(0~2³²) 위에 올리고**, 키는 "시계 방향으로 만나는 첫 노드"에 귀속시킨다.

```mermaid
flowchart TB
    subgraph Ring["🔵 Hash Ring (0 ~ 2³², 시계방향)"]
        direction LR
        N_A["노드 A\n(+ 가상노드 A1·A2·A3)"]
        N_B["노드 B\n(+ 가상노드 B1·B2·B3)"]
        N_C["노드 C\n(+ 가상노드 C1·C2·C3)"]
    end

    K1["key: order:1001"] -->|"시계방향 첫 노드"| N_B
    K2["key: order:2050"] -->|"시계방향 첫 노드"| N_C
    K3["key: user:777"] -->|"시계방향 첫 노드"| N_A

    NewNode["➕ 노드 D 추가"] -.->|"인접 구간 키만 이동\n나머지는 그대로"| N_B

    style N_A fill:#dbeafe,stroke:#3b82f6
    style N_B fill:#fef3c7,stroke:#f59e0b
    style N_C fill:#dcfce7,stroke:#22c55e
    style NewNode fill:#ede9fe,stroke:#8b5cf6,color:#3b0764
```

*키는 링에서 시계방향 첫 노드에 귀속. 노드 D를 추가해도 인접 구간 키만 이동하고 나머지는 그대로 → 재배치 최소화.*

### 가상 노드(Virtual Node)가 필요한 이유

- 물리 노드를 링에 1점씩만 올리면 **구간 크기가 들쭉날쭉**해져 일부 노드가 과부하(불균형)된다.
- 각 물리 노드를 **수십~수백 개의 가상 노드**로 링 곳곳에 흩뿌리면 부하가 고르게 분산되고, 노드 제거 시 그 부하가 **여러 노드로 골고루 재흡수**된다.
- 이종 스펙 노드는 가상 노드 수를 다르게 줘서 가중치를 표현할 수 있다.

> **💡 논문과 제품 구현을 구분하기**
>
> Dynamo 논문은 일관성 해시를 포함한 분산 저장소 설계 아이디어에 큰 영향을 줬다. 다만 **DynamoDB의 내부 파티셔닝을 consistent hashing·virtual node의 공개 계약으로 일반화하면 안 된다**. DynamoDB는 공식 문서의 partition key·uniform activity·hot partition 가이드로 설계하고, Cassandra처럼 token/partition key를 공개하는 제품은 각 제품의 데이터 모델 문서로 확인한다. Redis Cluster도 consistent hashing이 아니라 고정 hash slot과 resharding 모델을 사용한다. 제품 이름을 나열하기보다 노드 증감 시 이동 범위, hot key, 복제·트랜잭션 경계를 분리해 설명한다.

## 5. Resharding & Hotspot 회피

### 재샤딩(Resharding) — 늘어난 데이터를 다시 나누기

- 트래픽·데이터가 커지면 shard 수를 늘려야 하는데, 운영 중 무중단 재배치는 까다롭다.
- **사전 분할(Pre-splitting / 논리 샤드)**: 물리 노드보다 훨씬 많은 *논리 샤드*(예: 1024개)를 미리 만들고, 물리 노드에 매핑만 옮긴다. 노드 추가 시 데이터 재해시 없이 **논리 샤드 소유권만 이동**한다. Redis Cluster처럼 슬롯 기반 제품은 공식 문서의 재배치 모델을 별도로 확인한다.
- 일관성 해시 + 가상 노드도 재샤딩 비용을 낮추는 같은 목적의 도구.

### Hotspot(핫스팟) 회피 패턴

| 증상 | 원인 | 회피책 |
| --- | --- | --- |
| 한 shard 쓰기 폭주 | monotonic 키(시간·자동ID) | 해시 분산, 키에 버킷·솔트 접두 |
| 특정 인기 키 집중 (셀럽·핫딜 상품) | 자연 분포의 쏠림 | 해당 키만 추가 분할(샤드 스플릿), 캐시 앞단 흡수, 읽기 복제 |
| 특정 시간대 폭주 | 이벤트·세일 트래픽 | 큐로 평탄화(Back-pressure), 사전 스케일아웃 |

> **💡 사례 — 대규모 메시징 샤딩**
>
> 대규모 메시징은 채팅방·사용자 단위로 샤딩하되, **초대형 오픈채팅방 하나가 Hot shard** 가 되는 문제를 다룬다. 방 단위 분리·읽기 팬아웃 최적화·캐시로 특정 방의 부하를 분산한다. 샤딩 키(방ID vs 사용자ID) 선택이 곧 핫스팟 분포를 결정.

## 6. 물류 적용 — 풀필먼트 재고 테이블 샤딩 키

전국 100+ 풀필먼트 센터(FC)의 재고 테이블 `inventory(warehouse_id, sku, available, reserved)`를 샤딩한다면, 키를 **창고ID**로 잡을까 **SKU**로 잡을까? 접근 패턴이 답을 가른다.

| 샤딩 키 | 장점 | 단점·핫스팟 | 적합 패턴 |
| --- | --- | --- | --- |
| **창고ID (warehouse_id)** | 한 창고의 재고 조회·차감이 단일 shard에 co-locate → 트랜잭션·조인 쉬움 | **초대형 FC가 Hot shard**. 창고 수가 적으면 분산 입도 부족 | "이 창고에서 이 주문 출고" 같은 창고 중심 워크로드(WMS 피킹) |
| **SKU** | 인기 SKU가 여러 shard에 흩어져 분산 균등. SKU별 총재고 집계 쉬움 | "한 창고 전체 재고" 조회가 **교차 샤드 스캐터-개더**로 비싸짐 | 전국 단위 SKU 가용성 조회·핫딜 동시성 |
| **복합 (warehouse_id, sku)** | 해시로 균등 분산 + 핫 SKU 쏠림 완화 | 창고·SKU 어느 한 축 전체 스캔이 모두 교차 샤드 | 읽기·쓰기 모두 점조회(point lookup) 위주일 때 |

> **🎯 면접 포인트 — "정답"이 아니라 "워크로드 기준"으로 답하라**
>
> "재고 테이블 샤딩 키 뭘로?"의 모범 답: **"단일 출고 트랜잭션이 한 창고 안에서 끝나니 운영 정합성엔 warehouse_id가 유리하지만, 핫딜 때 인기 SKU 동시 차감이 한 shard로 몰리는 핫스팟이 있어, 그 SKU만 sub-shard로 쪼개거나 Redis 원자 카운터로 앞단 흡수하겠다"** — 단일 키 선택이 아니라 핫스팟까지 본 답이 시니어다.

> **⚠️ 실무 함정 — 재고는 "차감 정합성"이 먼저**
>
> 샤딩·복제로 분산하더라도 **재고 차감은 Oversell(초과판매)이 나면 안 되므로** 강한 일관성 경로가 필요하다. Read replica에서 가용재고를 읽고 차감하면 lag로 오버셀이 날 수 있다. 차감은 Leader/원자적 조건부 UPDATE처럼 불변식을 지키는 경로에 두고, 조회만 replica로 분리하는 방식을 검토한다.

```sql
UPDATE inventory
SET quantity = quantity - :qty
WHERE sku_id = :sku_id
  AND quantity >= :qty;
-- affected rows = 0이면 재고 부족
```

## 검수 경계와 실패 흐름

- 비동기 replica에서 write 직후 stale read가 생길 수 있으므로 leader read·LSN/version token·session affinity 중 보장 수준을 선택한다.
- resharding은 데이터 이동량·dual-write/read cutover·rollback 경로를 계획하고, `hash % N`처럼 노드 수 변경 때 전체 재배치가 필요한 방식과 비교한다.
- cross-shard transaction·unique constraint·재고 차감처럼 한 불변식을 여러 shard에 걸쳐 지켜야 하는 경로는 원자성 경계를 먼저 선언한다.
- monotonic key·인기 SKU·낮은 cardinality partition key로 hot shard가 생기면 key 버킷·write sharding·single-writer 경로를 선택하고 p95/p99와 재대사를 검증한다.

## 공식·1차 출처

- [https://www.postgresql.org/docs/current/warm-standby.html](https://www.postgresql.org/docs/current/warm-standby.html)
- [https://www.postgresql.org/docs/current/ddl-partitioning.html](https://www.postgresql.org/docs/current/ddl-partitioning.html)
- [https://www.mongodb.com/docs/manual/sharding/](https://www.mongodb.com/docs/manual/sharding/)
- [https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-partition-key-design.html](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-partition-key-design.html)
- [https://cassandra.apache.org/doc/stable/cassandra/architecture/overview.html](https://cassandra.apache.org/doc/stable/cassandra/architecture/overview.html)$review_23_system_design_04_data_storage$
WHERE slug = 'system-design-04-data-storage' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_system_design_05_caching$> **검수 경계** — 캐시 지연·적중률·QPS·TTL 값은 예시다. 캐시는 진실 원장을 대체하지 않으며 stale 허용 범위와 무효화 계약을 필드별로 정한다.

## 1. 캐시를 왜, 그리고 어디에

**캐시(Cache)**는 비싼 연산·느린 저장소의 결과를 빠른 저장소에 복제해 재사용하는 것이다. 핵심 동기는 두 가지다.

- **지연(Latency) 단축**: DB 디스크 조회(SSD seek ≈ 0.1ms, 인덱스 미스 시 수~수십 ms) → 메모리 캐시 hit ≈ 0.1~1ms. `p99` tail latency를 끌어내린다.
- **처리량(Throughput)·비용**: origin(원본 DB)의 QPS(Queries Per Second, 초당 쿼리 수) 부하를 흡수한다. 원본 용량을 `C`, 전체 요청을 `Q`, hit rate를 `h`라 두면 origin 부하는 대략 `Q×(1−h)`로 계산하고 실제 장치 benchmark로 `C`를 정한다.

### 캐시는 어디에나 있다 — 다층(Multi-layer) 구조

```mermaid
flowchart LR
    U(["👤 사용자"])
    BC["① Browser Cache\n로컬 디스크\nCache-Control / ETag"]
    CDN["② CDN Edge\nCloudFront / Akamai\n정적 + 일부 동적"]
    APP["③ App-level Cache\nLocal(Caffeine) +\nRemote(Redis)"]
    DBC["④ DB Cache\nBuffer Pool /\nQuery Cache"]
    DB[("Origin DB\nMySQL / Postgres")]

    U --> BC --> CDN --> APP --> DBC --> DB

    style BC fill:#dbeafe,stroke:#3b82f6
    style CDN fill:#dcfce7,stroke:#22c55e
    style APP fill:#ede9fe,stroke:#8b5cf6
    style DBC fill:#fef3c7,stroke:#f59e0b
    style DB fill:#fee2e2,stroke:#ef4444
```

*캐시 계층 — 사용자에 가까울수록 빠르고 싸지만, 무효화(invalidation) 제어가 어려워진다*

> **💡 팁 — "가장 빠른 캐시는 호출하지 않는 캐시"**
>
> 계층마다 hit rate·비용·무효화 난이도가 다르다. 브라우저/CDN은 이미 배포된 응답의 무효화 범위를 확인해야 하고, 변동이 잦은 데이터는 origin에 가까운 계층, 정적 자산은 Edge에서 캐시하는 방식을 요구사항과 관측으로 검증한다.

## 2. 캐시 패턴 5종 — 읽기/쓰기 경로 설계

패턴 선택의 본질은 두 질문이다. **(1) 캐시 미스(miss) 시 누가 DB를 읽고 채우나?** **(2) 쓰기(write)는 캐시·DB 중 어디를 먼저, 동기/비동기로?**

### Cache-aside (Lazy Loading) — 가장 흔한 기본형

```mermaid
sequenceDiagram
    participant App as Application
    participant C as Cache (Redis)
    participant DB as Origin DB

    Note over App,DB: 읽기 — Cache Miss
    App->>C: GET key
    C-->>App: nil (miss)
    App->>DB: SELECT ...
    DB-->>App: row
    App->>C: SET key, value, TTL
    App-->>App: 응답 반환

    Note over App,DB: 읽기 — Cache Hit
    App->>C: GET key
    C-->>App: value (hit)

    Note over App,DB: 쓰기 — DB 갱신 후 캐시 무효화
    App->>DB: UPDATE ...
    App->>C: DEL key
```

*Cache-aside — 애플리케이션이 캐시와 DB를 직접 오케스트레이션. 쓰기는 보통 "DB 먼저, 캐시 DEL" (write-around 변형)*

> **⚠️ 실무 함정 — Cache-aside의 미묘한 경합(Race)**
>
> "DB UPDATE 후 캐시 DEL" 사이에 다른 스레드가 **옛 값을 읽어 캐시에 SET** 하면 stale 값이 다시 박힌다. 해결: 짧은 TTL 병행, `DEL` 대신 버전드 키, 또는 변경 직후 짧은 지연 후 재삭제(double-delete). 면접에선 "캐시는 갱신이 아니라 삭제(invalidate)한다"가 핵심 답.

### 패턴 비교표

| 패턴 | 읽기 동작 | 쓰기 동작 | 장점 | 단점 / 위험 | 적합 상황 |
| --- | --- | --- | --- | --- | --- |
| **Cache-aside** (Lazy loading) | miss 시 앱이 DB 읽고 캐시 채움 | DB 쓰고 캐시 DEL | 구현 단순, 캐시 장애 시 DB로 graceful fallback | 최초 miss 지연, 위 race, stale 가능 | 읽기 多, 범용 기본값 |
| **Read-through** | 캐시 라이브러리가 miss 시 직접 DB 로드 | (읽기 전용 관점) | 앱 코드 단순화, 로딩 로직 일원화 | 캐시 계층에 DB 의존성 결합, 첫 요청 느림 | 읽기 캐시 추상화(예: Spring Cache) |
| **Write-through** | read-through와 짝 | 캐시에 쓰면 캐시가 **동기로** DB도 씀 | 캐시·DB 항상 일치(강한 일관성) | 쓰기 지연↑(2곳 동기), 안 읽힐 데이터도 캐싱 | 읽기·쓰기 모두 잦고 일관성 중요 |
| **Write-back** (Write-behind) | 캐시 우선 | 캐시에만 먼저 쓰고 DB는 **비동기 배치** | 쓰기 지연 최소, 쓰기 폭주 흡수·병합 | **캐시 다운 시 데이터 유실**, 일관성 약함 | 조회수·좋아요 등 유실 허용 카운터 |
| **Write-around** | miss 시 채움(cache-aside와 동일) | DB에만 쓰고 캐시는 건드리지 않음 | "한 번 쓰고 잘 안 읽는" 데이터 캐시 오염 방지 | 쓴 직후 읽으면 무조건 miss | 로그·이력 등 write 후 즉시 안 읽는 데이터 |

> **🎯 면접 포인트 — Write-back 유실 위험**
>
> "쓰기 성능 위해 Write-back 쓰겠다"고 답하면 면접관은 곧장 **"캐시 노드가 죽으면 아직 DB에 안 내려간 쓰기는?"** 을 묻는다. 정답 방향: 유실 허용 데이터(좋아요 수)만 적용 / AOF·복제로 위험 완화 / 결제·재고 같은 정합성 필수 데이터엔 절대 금지. Trade-off를 명시하지 못하면 감점.

## 3. Eviction(축출) 정책 — 메모리는 유한하다

캐시 메모리가 차면 무엇을 버릴지 결정해야 한다. 정책 선택은 **접근 패턴(temporal vs frequency locality)**에 달렸다.

| 정책 | 버리는 기준 | 강점 | 약점 | 대표 쓰임 |
| --- | --- | --- | --- | --- |
| **LRU** (Least Recently Used) | 가장 오래 안 쓰인 항목 | 시간 지역성(temporal locality)에 강함, 직관적 | 일회성 대량 스캔이 hot set을 밀어냄(scan 오염) | 범용 1순위, Redis 기본 후보 |
| **LFU** (Least Frequently Used) | 가장 적게 접근된 항목 | 꾸준히 인기 있는 항목 보존 | 과거 인기 항목이 자리 점유(aging 필요), 카운터 비용 | 인기 편중 큰 데이터(Redis `allkeys-lfu`) |
| **FIFO** | 먼저 들어온 항목 | 구현 가장 단순 | 접근 빈도 무시 → hit rate 낮은 편 | 단순 큐형 캐시 |
| **TTL** (Time To Live) | 만료 시각 지난 항목 | stale 상한 보장, 시간 기반 자연 무효화 | 동시 만료 시 **Stampede** 유발 | 거의 모든 패턴과 병행(필수) |

> **💡 팁 — 실무에선 TTL + LRU/LFU 조합**
>
> TTL은 "정확성 상한(얼마나 stale을 허용하나)"을, LRU/LFU는 "메모리 압박 시 누구를 버리나"를 담당한다. 둘은 배타가 아니라 **병행** 이다. Redis는 `maxmemory-policy` 로 `allkeys-lru` , `allkeys-lfu` , `volatile-ttl` (TTL 가진 키 중 가까운 것부터) 등을 선택한다.

## 4. Redis 핵심 — 캐시의 사실상 표준

> **왜 Redis인가** — 인메모리 자료구조 서버이며, 명령 처리 경로가 직렬화되어 단순 GET/SET을 넘어 *자료구조 연산을 원자적으로* 제공하는 것이 강점이다. I/O thread와 클러스터 구성은 별도 설정·버전·운영 모델로 검토한다.

#### 주요 자료구조와 캐시 활용

- `String` — 직렬화 객체, 카운터(`INCR` 원자 증가)
- `Hash` — 객체 필드 부분 갱신(전체 역직렬화 회피)
- `Sorted Set(ZSET)` — 랭킹/리더보드, 시간순 피드
- `Set` — 중복 제거, 멱등성 키 집합
- `List` — 큐, 최근 N개
- `Bitmap / HyperLogLog` — 대규모 카디널리티(UV) 근사

### 단일 스레드 모델(Single-thread)

Redis의 명령 실행 경로는 한 명령을 중간에 끼워 넣지 않고 처리하므로 **명령 단위 원자성**을 제공한다(애플리케이션 락 불필요). I/O thread를 켜더라도 큰 `O(N)` 명령(`KEYS *`, 큰 `SMEMBERS`)은 실행 경로를 오래 점유해 전체 지연을 유발할 수 있다.

> **⚠️ 실무 함정 — O(N) 명령이 루프를 막는다**
>
> 운영에서 `KEYS pattern*` 은 금지. 대신 `SCAN` (커서 기반). 단일 스레드라 한 큰 명령이 모든 클라이언트를 정체시킨다. Big key(수십 MB 값)도 동일하게 위험.

### 영속성(Persistence) — RDB vs AOF

| 방식 | 원리 | 장점 | 단점 |
| --- | --- | --- | --- |
| **RDB** (스냅샷) | 주기적으로 메모리 전체를 덤프 | 파일 작음, 복구 빠름, fork로 메인 영향 적음 | 마지막 스냅샷 이후 쓰기 유실 가능 |
| **AOF** (Append Only File) | 쓰기 명령을 로그로 추가 | 유실 최소(`fsync` 정책에 따라 1초~즉시) | 파일 큼, 복구 느림, rewrite 필요 |

실무는 보통 **RDB + AOF 병행**. 다만 "캐시는 휘발성이어도 된다"는 관점에선 영속성을 끄고 origin을 single source of truth로 두기도 한다.

### 분산 — Redis Cluster

데이터를 **16384개 해시 슬롯**으로 나눠 노드에 분배(키의 CRC16 → 슬롯). 수평 확장과 슬롯 단위 리밸런싱이 가능. 단, **멀티키 연산은 같은 슬롯에 있어야** 하므로 `{user:123}:cart` 같은 hash tag로 같은 키 그룹을 한 슬롯에 모은다.

> **🎯 면접 포인트 — "Redis는 왜 빠른가?"**
>
> 단순히 "인메모리라서"는 절반짜리 답. (1) 메모리 + (2) 직렬화된 명령 처리와 낮은 락 경합 + (3) I/O 멀티플렉싱(epoll) + (4) 효율적 자료구조 + (5) RESP 경량 프로토콜. 그리고 **긴 O(N) 명령이 전체 latency를 막을 수 있다**는 양면을 함께 말해야 시니어답다.

## 5. CDN 캐싱과 캐시 무효화(Cache Invalidation)

**CDN(Content Delivery Network)**은 origin 콘텐츠를 전 세계 edge POP(Point of Presence)에 캐싱해 사용자와의 물리 거리를 줄인다(대륙 간 RTT ≈ 150ms → edge hit는 수~수십 ms). 정적 자산(JS/CSS/이미지)이 1차 대상이지만, 캐시 가능한 API 응답도 edge에 둘 수 있다.

#### 제어 헤더

- `Cache-Control: max-age, s-maxage, no-cache, private/public` — 캐시 수명·범위
- `ETag / If-None-Match` — 변경 없으면 `304 Not Modified`(본문 절약)
- `Vary` — 캐시 키 분기(언어·인코딩 등)

### 무효화 전략 — "캐시 무효화는 어렵다"

> **🎯 면접 단골 — 컴퓨터과학 2대 난제**
>
> Phil Karlton의 격언: *"There are only two hard things in Computer Science: cache invalidation and naming things."* 면접관이 이 말을 던지면, 핵심은 **"언제·어떻게 stale을 끊을 것인가"** 를 구체 전략으로 답하는 것이다.

- **TTL 만료(Passive)** — 가장 단순, 그러나 그 시간만큼 stale 허용
- **명시적 Purge(Active)** — 변경 시 CDN API로 특정 URL/경로 무효화(전파에 수초~수십초)
- **Versioned URL / Cache busting** — `app.v37.js`, `?v=hash`로 키 자체를 바꿔 새 객체로 취급(가장 안전, 영구 캐시 가능)
- **Key invalidation by tag** — surrogate key/tag로 연관 객체를 묶어 일괄 무효화

> **💡 팁 — 무효화하지 말고 "키를 바꿔라"**
>
> 정적 자산은 무효화(purge)보다 **해시 기반 파일명(content hash)** 을 선택하면 `main.a1b2c3.js`처럼 내용이 바뀔 때 URL도 바뀐다. 다만 배포 파이프라인과 캐시 정책이 함께 검증되어야 하며 특정 회사의 빌드 방식을 일반화하지 않는다.

## 6. Thundering Herd / Cache Stampede 🔥(Deep-dive)

**Cache Stampede(쇄도)** = 인기 키 하나가 만료되는 순간, 수많은 요청이 동시에 miss → 전부 origin으로 몰려 DB가 폭주하는 현상. **Thundering Herd(천둥 같은 무리)**라고도 한다. hit rate 99%여도 1%의 동시 만료가 DB를 무너뜨릴 수 있다.

```mermaid
flowchart TB
    EXP["🔑 인기 키 TTL 동시 만료\n예: 메인 배너 캐시 60초 TTL"]
    EXP --> MISS["수천 요청 동시 MISS"]
    MISS --> HERD["전부 origin DB로 쇄도\nThundering Herd"]
    HERD --> OVER["💥 DB 커넥션 고갈\nCPU 폭주 → 연쇄 장애"]

    subgraph FIX["완화책"]
      direction LR
      F1["① TTL Jitter\n만료 시각 ±랜덤 분산"]
      F2["② Single-flight\n분산 락 — 1개만 origin 호출\n나머지는 대기/이전값"]
      F3["③ Early Recompute\nTTL 임박 시 백그라운드 갱신\n(probabilistic)"]
      F4["④ stale-while-revalidate\nstale 즉시 응답 +\n뒤에서 비동기 갱신"]
    end

    OVER -.해결.-> FIX

    style EXP fill:#fef3c7,stroke:#f59e0b
    style HERD fill:#fee2e2,stroke:#ef4444
    style OVER fill:#fee2e2,stroke:#dc2626
    style FIX fill:#f0fdf4,stroke:#16a34a
```

*Cache Stampede 발생 경로와 4가지 완화책 — 면접에선 최소 2개를 Trade-off와 함께 제시*

### 완화책 상세

- **① TTL Jitter** — TTL을 고정값이 아니라 `base ± random`으로. 같은 시각에 만든 캐시들이 한꺼번에 만료되는 걸 분산. 가장 싸고 즉효.
- **② 분산 락 / Single-flight** — miss 시 Redis `SET NX`로 락을 잡은 **한 요청만** origin을 호출하고 채운다. 나머지는 짧게 대기 후 캐시 재조회(또는 직전 stale 반환). Go의 `singleflight`, 자바 진영의 분산 락 패턴.
- **③ Early Recompute(Probabilistic)** — TTL이 다 되기 전에 확률적으로 미리 갱신(XFetch 알고리즘). 만료-순간 동시 miss 자체를 회피.
- **④ stale-while-revalidate** — 만료돼도 **stale 값을 즉시 응답**하고 백그라운드에서 갱신. HTTP `Cache-Control: stale-while-revalidate=N` 표준으로도 존재. 사용자 latency를 origin 갱신과 분리.

> **⚠️ 실무 함정 — Stampede를 아예 언급 안 하면 감점**
>
> "Redis로 캐싱하겠습니다"에서 멈추면, 면접관은 "그 인기 키가 만료되는 순간 DB는?"으로 압박한다. **Hot key + 동시 만료** 는 캐싱 설계의 필수 점검 항목. 또한 단순 락만 답하면 "락 잡은 요청이 느리거나 죽으면?"(락 타임아웃·stale 폴백)까지 이어진다.

## 7. 적용 사례 — 물류 캐시

> **가상 사례 — 읽기 중심 메뉴·검색 캐시** — 읽기:쓰기 비율과 변경 빈도를 측정해 Redis·Edge 캐시를 선택하고, 원장 변경 이벤트로 필요한 키만 무효화한다. 가격처럼 정확성이 중요한 필드는 짧은 TTL·버전 키·원본 우회를 조합한다.

> **가상 사례 — 계좌 잔액** — 금융 정합성이 필수인 데이터는 Write-back을 피하고 원장 DB를 진실의 원천으로 둔다. 캐시하더라도 즉시 무효화와 Read-your-writes 경로를 정의하며, 특정 회사의 구현으로 일반화하지 않는다.

### 물류 연결 — 라스트마일 추적 상태 캐싱

운송장 추적(`TrackingStatus`) 조회는 고객이 하루에도 수십 번 새로고침하는 **읽기 폭주** 패턴이다. 매번 origin(이벤트 저장소)을 때리면 비효율.

```mermaid
sequenceDiagram
    participant U as 고객 앱
    participant API as Tracking API
    participant C as Redis (status cache)
    participant K as Kafka (TrackingEvent)
    participant DB as Event Store

    U->>API: GET /tracking/{waybillNo}
    API->>C: GET status:{waybillNo}
    C-->>API: 캐시된 최신 상태 (hit)
    API-->>U: OUT_FOR_DELIVERY

    Note over K,C: 새 이벤트 발생 시 캐시 갱신(이벤트 기반 무효화)
    K->>API: TrackingEvent(Delivered)
    API->>C: SET status:{waybillNo} = DELIVERED
    Note over C: write-through 식 갱신 → 읽기는 항상 hit
```

*라스트마일 추적 — 읽기는 캐시 hit, 상태 변경 이벤트가 올 때만 캐시 갱신(이벤트 기반 무효화). 조회 폭주를 origin과 분리*

> **💡 팁 — 추적 캐시는 "이벤트가 쓰고, 조회가 읽는다"**
>
> 추적 상태는 변경 빈도가 조회 빈도보다 낮을 수 있다. 상태 변경 이벤트가 캐시를 갱신하는 패턴을 검토하고, 조회는 캐시로 흡수하되 갱신 실패·stale 허용·동시 만료를 별도로 정의한다.

```text
ttl = base_ttl + random(0, jitter)
cache_key = "shipment:" + waybill_id + ":v" + projection_version
negative_ttl << normal_ttl
```

## 검수 경계와 실패 흐름

- cache-aside에서 DB commit·DEL·재충전 순서가 어긋나면 stale value가 다시 들어올 수 있으므로 version/CAS·짧은 TTL·무효화 재시도를 조합한다.
- hot key 만료는 origin DB로 동시 miss를 보내므로 single-flight·lock timeout·stale-while-revalidate·TTL jitter의 실패 시 동작을 정한다.
- Redis 장애 시 cache miss가 원장 DB로 쏟아지는 경로와 개인정보가 섞인 cache key를 별도로 검토하고, fallback이 source of truth를 덮지 않게 한다.
- eviction·persistence·cluster resharding은 서로 다른 운영 문제다. hit rate·big key·eviction·p95/p99·DB 보호 지표를 함께 측정한다.

## 공식·1차 출처

- [https://redis.io/docs/latest/develop/reference/eviction/](https://redis.io/docs/latest/develop/reference/eviction/)
- [https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/](https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/)
- [https://redis.io/docs/latest/operate/oss_and_stack/management/scaling/](https://redis.io/docs/latest/operate/oss_and_stack/management/scaling/)
- [https://www.rfc-editor.org/rfc/rfc9111](https://www.rfc-editor.org/rfc/rfc9111)$review_23_system_design_05_caching$
WHERE slug = 'system-design-05-caching' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_system_design_06_messaging_async$> **검수 경계** — 메시징 제품의 선택은 전달 보장, 순서 범위, 재생, 보존, 멱등 소비와 운영 책임을 요구사항으로 비교한 결과다.

## 1. 왜 비동기 · 메시징인가

동기 호출(synchronous call)은 A가 B의 응답을 기다린다. B가 느리거나 죽으면 A도 같이 막힌다(연쇄 장애, cascading failure). 메시지 큐/스트림을 끼우면 셋이 달라진다.

- **결합도↓ (Decoupling)** — Producer는 Consumer가 누구인지·몇 개인지·살았는지 몰라도 된다. 새 소비자를 무중단으로 추가.
- **버스트 흡수 (Buffering / Load leveling)** — 순간 10배 트래픽이 와도 큐가 받아두고 Consumer가 자기 속도로 처리. 피크를 평탄화.
- **시간 분리 (Temporal decoupling)** — Consumer가 잠시 다운돼도 메시지는 큐에 보존 → 복구 후 이어서 처리. 가용성↑.

```mermaid
flowchart LR
    subgraph SYNC["❌ 동기 — 강결합"]
      A1["주문 서비스"] -->|"동기 호출\n응답 대기"| A2["알림 서비스"]
      A2 -.느려지면.-> A1
    end
    subgraph ASYNC["✅ 비동기 — 큐로 분리"]
      B1["주문 서비스"] -->|"이벤트 발행"| Q[("Queue / Topic")]
      Q --> B2["알림 서비스"]
      Q --> B3["정산 서비스"]
      Q --> B4["배송 서비스"]
    end

    style SYNC fill:#fef2f2,stroke:#ef4444
    style ASYNC fill:#f0fdf4,stroke:#16a34a
    style Q fill:#ede9fe,stroke:#8b5cf6
```

*동기 강결합 vs 비동기 분리 — 하나의 OrderPlaced 이벤트를 여러 소비자가 독립적으로 처리*

> **💡 팁 — 비동기는 공짜가 아니다**
>
> 대가로 **최종 일관성(Eventual Consistency), 디버깅 난이도, 순서·중복 문제** 를 떠안는다. "왜 동기 대신 비동기?"에 답할 때 이 Trade-off를 함께 말해야 한다. 강한 일관성과 즉시 응답이 필수면 동기가 맞다.

## 2. Message Queue vs Event Streaming

둘 다 "비동기 메시지"지만 사고방식이 다르다. 면접에서 Kafka와 RabbitMQ/SQS를 동일선상에 놓으면 감점이다.

| 관점 | Message Queue (RabbitMQ/SQS) | Event Streaming (Kafka) |
| --- | --- | --- |
| 핵심 비유 | 작업 분배 — "할 일 목록" | 분산 로그 — "사건 기록부" |
| 소비 후 | 보통 **소비 시 삭제(ack 후 제거)** | **보존(retention)** — 읽어도 안 사라짐 |
| 재생(Replay) | 어려움(이미 지워짐) | 쉬움 — offset 되감기로 과거 재처리 |
| 다중 구독 | 한 메시지 → 보통 한 워커가 처리(경쟁 소비) | 여러 Consumer Group이 **독립적으로** 전체 읽음 |
| 순서 | 큐 단위(또는 약함) | 파티션 단위 보장 |
| 적합 | 작업 분배, 태스크 큐, RPC 대체 | 이벤트 소싱, 로그 수집, 다중 소비·재처리 |

> **⚠️ 실무 함정 — "큐 = 스트림" 오해**
>
> "OrderPlaced를 알림·정산·배송 셋이 각자 처리"하려면 **다중 소비 + 재생** 이 필요 → 스트림(Kafka)이 적합. 반면 "이미지 리사이즈 작업을 워커 풀이 나눠 처리"는 **경쟁 소비 + 소비 후 삭제** → 큐(SQS)가 자연스럽다. 요구사항을 보고 둘을 구분해 답하라.

## 3. Kafka 핵심 — Topic / Partition / Offset / Consumer Group

```mermaid
flowchart LR
    P1["Producer A"] -->|"key=orderId 해싱"| T
    P2["Producer B"] --> T

    subgraph T["📚 Topic: order-events"]
      direction TB
      PA["Partition 0\n[m0 m1 m2 ...]"]
      PB["Partition 1\n[m0 m1 m2 ...]"]
      PC["Partition 2\n[m0 m1 m2 ...]"]
    end

    subgraph CG1["Consumer Group: 정산"]
      C1["Consumer 1"]
      C2["Consumer 2"]
      C3["Consumer 3"]
    end
    subgraph CG2["Consumer Group: 알림"]
      D1["Consumer 1"]
    end

    PA --> C1
    PB --> C2
    PC --> C3
    PA --> D1
    PB --> D1
    PC --> D1

    style T fill:#fef3c7,stroke:#f59e0b
    style CG1 fill:#dbeafe,stroke:#3b82f6
    style CG2 fill:#dcfce7,stroke:#22c55e
```

*Topic은 N개 Partition으로 분할 → 병렬성 단위. 각 Consumer Group은 전체를 독립적으로 소비(정산·알림이 서로 영향 없음)*

#### 핵심 개념

- **Topic** — 메시지 카테고리(예: `order-events`).
- **Partition** — Topic을 나눈 단위. **병렬성·순서의 기본 단위**. 파티션 수 = 그 그룹의 최대 동시 소비자 수.
- **Offset** — 파티션 내 메시지의 순번. Consumer가 "어디까지 읽었나"를 offset으로 커밋.
- **Consumer Group** — 같은 그룹 내 Consumer들이 파티션을 나눠 가짐. 다른 그룹은 같은 데이터를 독립 소비.
- **Retention** — 시간(`retention.ms`)·크기 기준 보존. 그 안에선 언제든 offset 되감기 재처리.

### 순서 보장은 "파티션 단위"뿐 🔥(Deep-dive)

Kafka의 순서 보장은 **한 파티션 안에서만** 성립한다. Topic 전체(여러 파티션) 순서는 보장 안 된다. 그래서 "같은 주문의 이벤트는 순서대로 처리"하려면 **같은 키(orderId)로 같은 파티션에 보내야** 한다(`partition = hash(key) % N`).

> **🎯 면접 포인트 — "Kafka는 순서를 보장한다"는 위험한 단언**
>
> 이렇게 답하면 면접관은 즉시 "Topic 전체에 대해서요?"라고 되묻는다. 정답: **파티션 내에서만 보장** . 따라서 (1) 순서가 중요한 단위(주문/사용자)를 파티션 키로 잡고, (2) 키 분포가 한쪽으로 쏠리면 **Hot partition** 이 생겨 병렬성이 깨진다는 Trade-off까지 말해야 한다. 파티션을 늘리면 순서 단위가 더 잘게 쪼개지는 것도 함께.

## 4. Pub/Sub 패턴과 Fan-out

**Pub/Sub(Publish/Subscribe, 발행/구독)**는 발행자가 특정 수신자를 모른 채 토픽에 발행하고, 관심 있는 구독자들이 받는 패턴이다. **Fan-out(팬아웃)**은 한 메시지가 여러 소비자/대상으로 퍼지는 것.

- Kafka에서는 **Consumer Group 분리**로 자연스러운 fan-out — 그룹마다 전체 스트림을 독립 소비.
- 한 이벤트(`OrderPlaced`)가 알림·정산·배송·추천·BI로 동시에 흘러가도, 각 소비자는 서로의 처리 속도/장애에 무관.

> **💡 팁 — Fan-out의 두 방식**
>
> **Fan-out on write(쓰기 시 미리 뿌리기)** vs **Fan-out on read(읽을 때 모으기)** 는 뉴스피드 설계의 대표적인 Trade-off다. 팔로워가 많은 계정에 write fan-out을 적용하면 팔로워 수에 비례한 쓰기 폭주가 생길 수 있다. 일반 계정은 write, 고차수 계정은 read로 나누는 하이브리드는 하나의 설계 선택지다.

## 5. 전달 보장(Delivery Semantics)과 멱등 소비 🔥(Deep-dive)

| 보장 | 의미 | 장점 | 단점 | 구현 키 |
| --- | --- | --- | --- | --- |
| **At-most-once** (최대 1회) | 중복 없음, 단 유실 가능 | 가장 빠름, 단순 | 메시지 잃을 수 있음 | 먼저 commit 후 처리(fire-and-forget) |
| **At-least-once** (최소 1회) | 유실 없음, 단 중복 가능 | 유실 방지, 실무 기본값 | 중복 처리 필요 | 처리 후 ack/commit, 실패 시 재시도 |
| **Exactly-once** (정확히 1회) | 유실도 중복도 없음(이상) | 이상적 정확성 | **전 구간 보장은 사실상 불가/비쌈** | Kafka 트랜잭션은 Kafka↔Kafka 한정 |

> **🎯 면접 포인트 — "Exactly-once의 허상"**
>
> "Exactly-once로 하겠습니다"라고 단언하면 거의 탈락 신호다. Kafka의 EOS(Exactly-Once Semantics)는 **Kafka 내부(read→process→write to Kafka)에 한정** 되며, 외부 시스템(DB·결제·이메일 발송)으로의 부수효과까지는 보장하지 못한다. 메일을 두 번 보내는 건 Kafka가 막아줄 수 없다. **현업 정답: At-least-once + Idempotent consumer(멱등 소비자).** 중복이 와도 결과가 같도록 소비자 쪽에서 멱등성을 보장한다(처리 결과 동일성 = effectively-once).

### At-least-once + 멱등 소비 — 실제 흐름

```mermaid
sequenceDiagram
    participant K as Kafka
    participant C as Consumer
    participant R as Redis / Dedup Store
    participant DB as DB

    K->>C: deliver msg (eventId=E1)
    C->>R: SETNX processed:E1
    alt 처음 본 eventId
        R-->>C: OK (신규)
        C->>DB: 비즈니스 처리 (재고 차감 등)
        C->>K: commit offset
    else 이미 처리됨
        R-->>C: 이미 존재 (중복)
        C->>K: commit offset (스킵)
    end

    Note over K,C: 재시도로 같은 E1이 또 와도 → 멱등하게 1회 효과
```

*중복 메시지(E1 재전송)가 와도 dedup 키로 1회만 반영 — effectively-once*

#### 멱등 소비 구현 방법

- **Dedup 키** — 이벤트마다 고유 `eventId`로 처리 여부를 Redis/DB에 기록(`SETNX` 또는 unique 제약).
- **멱등 연산** — "잔액을 100으로 **설정**"은 멱등, "100 **증가**"는 비멱등. 가능하면 멱등 연산으로 모델링.
- **Upsert + 자연키** — `INSERT ... ON CONFLICT DO NOTHING`로 DB 제약이 중복을 흡수.
- **Outbox 패턴** — DB 트랜잭션과 메시지 발행의 원자성(이중 쓰기 문제)을 Outbox 테이블 + CDC(Change Data Capture)로 해결.

## 6. Back-pressure(배압)와 Consumer Lag

**Back-pressure(배압)** = 생산 속도가 소비 속도를 초과할 때, 시스템이 무너지지 않도록 상류로 "천천히"를 전달하는 메커니즘. Kafka에선 생산이 소비를 앞서면 **Consumer Lag(아직 안 읽은 메시지 수 = latest offset − committed offset)**가 쌓인다.

```mermaid
flowchart LR
    PROD["Producer\n빠른 생산\n10k msg/s"] --> LAG{"Consumer Lag\n계속 증가?"}
    LAG -->|"방치"| BOOM["💥 지연 폭증\nretention 초과 시 유실\nSLA 위반"]
    LAG -->|"대응"| FIX

    subgraph FIX["완화"]
      direction TB
      G1["① Scale-out\n파티션·Consumer 증설\n(파티션 수가 상한)"]
      G2["② Throttle\n생산 속도 제한\nrate limit"]
      G3["③ 버퍼·배치\n처리량 최적화"]
      G4["④ Lag 모니터링·알람\nBurrow / lag exporter"]
    end

    style PROD fill:#dbeafe,stroke:#3b82f6
    style BOOM fill:#fee2e2,stroke:#dc2626
    style FIX fill:#f0fdf4,stroke:#16a34a
```

*Consumer Lag 증가 경로와 대응 — Kafka는 메시지를 보존하므로 일시적 lag은 흡수되지만, retention을 넘기면 유실*

> **⚠️ 실무 함정 — Consumer Lag 모니터링 누락**
>
> "Kafka 넣었으니 안전"이 아니다. **Lag이 꾸준히 증가** 하면 소비자가 못 따라가는 것이고, retention(예: 7일)을 넘기면 **읽지도 못한 메시지가 사라진다** . 면접·실무 모두 Lag 지표·알람(Burrow, Kafka exporter)과 scale-out 전략을 반드시 갖춰야 한다. 파티션 수가 소비 병렬성의 상한임도 기억할 것.

## 7. Kafka vs RabbitMQ vs AWS SQS

| 관점 | Kafka | RabbitMQ | AWS SQS |
| --- | --- | --- | --- |
| 모델 | 분산 로그(스트림) | 메시지 브로커(AMQP) | 완전관리형 큐 |
| 처리량 | 파티션·broker·payload·batching·복제 설정별 benchmark | broker·queue·consumer·payload별 benchmark | Standard/FIFO·API action·리전 quota와 batching을 확인 |
| 순서 | 같은 파티션 내부에서 보장 | queue·consumer·재전달 설정의 범위를 확인 | Standard는 순서 미보장, FIFO는 같은 `MessageGroupId` 내부에서 보장 |
| 재생(Replay) | 강점(offset 되감기) | 약함(소비 후 삭제) | 불가(삭제됨) |
| 라우팅 | 단순(토픽/파티션) | 강력(exchange·라우팅 키·바인딩) | 단순 |
| 운영 부담 | 높음(클러스터·ZK/KRaft 관리) | 중간 | 없음(서버리스) |
| 적합 | 이벤트 소싱·로그·대규모 fan-out·재처리 | 복잡한 라우팅·태스크 큐·낮은 지연 | AWS 환경 간단한 비동기·워커 큐 |

> **💡 팁 — 한 줄 선택 기준**
>
> **다중 소비·재처리·고처리량 → Kafka. 복잡한 라우팅·낮은 지연 태스크 큐 → RabbitMQ. AWS에서 운영 부담 없이 단순 비동기 → SQS.** "무조건 Kafka"는 over-engineering일 수 있다 — 운영 비용과 요구 처리량을 함께 따져라.

## 8. 이벤트·물류 설계 사례

> **가상 주문 이벤트 파이프라인** — 주문이 결제·재고·정산·배송·분석 컨슈머로 fan-out된다고 가정한다. Kafka의 다중 소비·재처리를 쓰더라도 각 도메인을 독립 Consumer Group으로 분리하고, 실패한 소비를 재시도·DLQ로 격리한다.

> **가상 메시징 파이프라인** — 전송·푸시 버스트는 큐로 흡수하고, at-least-once 전달과 멱등 처리로 중복을 억제한다. 정확히 한 번을 주장하기보다 사용자에게 보이는 중복과 재처리 비용을 측정한다.

> **가상 배송 상태 파이프라인** — 주문 접수부터 완료까지의 이벤트를 비동기로 흘리고 상태 순서가 중요한 키로 파티셔닝한다. 피크 배율과 컨슈머 처리량은 실제 트래픽 기록으로 산정한다.

### 물류 연결 — 대량 TrackingEvent Fan-out + 멱등 소비

라스트마일에서 스캔·배차·배송완료 등 **운송장 추적 이벤트(TrackingEvent)**가 대량 발생한다고 가정한다. 이벤트를 고객 알림·ETA 갱신·정산·분석으로 fan-out할 때 발생하는 파티션 쏠림과 중복을 설계한다.

```mermaid
flowchart LR
    SCAN["📷 기사 앱 스캔\n(지하·산간 재접속 시\n중복 전송 가능)"] --> KT
    KT["📚 Topic: tracking-events\nkey = waybillNo\n→ 같은 송장은 같은 파티션(순서)"]

    KT --> CG1["알림 Consumer Group\n→ 고객 푸시"]
    KT --> CG2["ETA Consumer Group\n→ 도착예정 갱신"]
    KT --> CG3["정산 Consumer Group"]
    KT --> CG4["BI / 분석"]

    CG1 --> DED["멱등 처리\ndedup(eventId)\n중복 푸시 차단"]

    style KT fill:#fef3c7,stroke:#f59e0b
    style DED fill:#fce7f3,stroke:#ec4899
```

*TrackingEvent fan-out — `waybillNo` 키로 송장별 순서 보장, eventId 기반 멱등 처리로 중복 알림 차단*

> **🎯 면접 포인트 — 물류 추적 설계**
>
> "대량 TrackingEvent를 어떻게 처리?"에서 핵심은 (1) **송장 키 파티셔닝** 으로 한 송장의 상태 순서 보장, (2) 기사 앱 오프라인 재접속의 **중복 전송** 을 멱등 소비로 흡수, (3) **Consumer Lag 모니터링** 으로 알림 지연 SLA 관리, (4) 키 쏠림(특정 메가허브 폭주)으로 인한 **Hot partition** 대응. 네 가지를 Trade-off와 함께 엮어야 시니어답다.

```properties
message.key=waybillId
enable.idempotence=true
acks=all
max.in.flight.requests.per.connection=5
```

## 검수 경계와 실패 흐름

- 전달 보장은 at-most-once·at-least-once·Kafka read-process-write EOS처럼 경계를 나눠 적고, 외부 결제·메일 side effect에는 idempotency와 대사를 둔다.
- 같은 주문의 순서는 partition key·consumer concurrency·retry/rebalance 경로를 포함해 검증한다. partition 간 전역 순서는 가정하지 않는다.
- consumer lag은 처리시간·외부 의존성·partition skew·rebalance로 분해하고 oldest lag age가 retention을 넘기기 전에 scale-out·throttle·DLQ를 선택한다.
- Kafka offset replay, RabbitMQ 재전달, SQS visibility timeout/FIFO group은 서로 다른 모델이다. 브로커를 바꾸면 순서·중복·재생·quota 계약을 다시 적는다.

## 공식·1차 출처

- [https://kafka.apache.org/documentation/#semantics](https://kafka.apache.org/documentation/#semantics)
- [https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/standard-queues-at-least-once-delivery.html](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/standard-queues-at-least-once-delivery.html)
- [https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/quotas-messages.html](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/quotas-messages.html)
- [https://www.rabbitmq.com/docs/reliability](https://www.rabbitmq.com/docs/reliability)$review_23_system_design_06_messaging_async$
WHERE slug = 'system-design-06-messaging-async' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_system_design_08_case_rate_limiter$> **검수 경계** — 요청량·버스트·윈도우와 허용 지연은 가상 요구사항이다. Redis 원자 연산 하나로 모든 리전의 전역 제한이 자동 보장되지는 않는다.

## 1. 요구사항 명확화 — 묻지 않으면 떨어진다

면접에서 바로 그림을 그리면 감점이다. `Rate Limiter(요청 제한기)`는 "누구당 / 무엇을 기준으로 / 몇 개를" 막을지부터 합의해야 한다.

### Functional 요구사항

- **제한 단위(key)**: `user ID` / `IP` / `API key` / 엔드포인트별 — 보통 복합 (예: API key + endpoint).
- **제한 규칙**: 예) "API key당 **100 req/sec**, IP당 **1,000 req/min**". 규칙이 다층(layered)일 수 있음.
- **초과 시 동작**: 거부(`429`) / 큐잉(throttle) / soft-limit 경고. 그리고 **클라이언트에게 언제 재시도할지 알려주기**(`Retry-After`).

### Non-functional 요구사항

| 속성 | 목표 | 이유 |
| --- | --- | --- |
| **Low latency** | Rate Limiter 자체가 p99 < 1~2ms 추가 | 모든 요청 경로에 끼므로 느리면 전체가 느려짐 |
| **분산 정확성** | 여러 서버 인스턴스가 같은 카운터를 공유 | 인스턴스별 로컬 카운터면 N대일 때 한도가 N배로 샘 |
| **High availability** | Limiter 장애 시 fail-open or fail-close 정책 명시 | Limiter가 죽었다고 전 서비스가 막히면 안 됨(보통 fail-open) |
| **정확도 vs 메모리** | 알고리즘 선택의 핵심 축 | 정밀할수록 메모리/연산 ↑ — 트레이드오프 |

> **🎯 면접 포인트 — 먼저 물어야 할 질문**
>
> "글로벌인가 리전별인가?", "제한 단위가 user인가 IP인가?", "soft/hard limit?", "Limiter가 죽으면 fail-open인가?" — 이 질문들을 먼저 던지는 것만으로 시니어 신호다. **요구사항 명확화 단계를 건너뛰고 바로 Token Bucket을 그리면 감점.**

## 2. 용량 추정 — 숫자로 메모리를 잡는다

### QPS 추정

전제: 하루 **1억(108) 요청**이 들어오는 API.

- 1 day ≈ 105 초 (정확히 86,400s).
- 평균 `QPS(Queries Per Second, 초당 쿼리 수)` = 108 / 105 = **약 1,000 QPS**.
- 피크는 평균의 5~10배 → **약 5,000 ~ 10,000 QPS**로 잡고 설계.

### 카운터 메모리 추정

제한 단위(고유 user/IP/key)별로 카운터 하나가 필요하다. 활성 사용자를 **1,000만(107)**으로 가정.

- 키 1개당 메모리: 카운터(int 8B) + 타임스탬프/만료 + Redis 키 오버헤드 ≈ **약 50~100 B**로 보수적 추정.
- 총 메모리 = 107 × 100 B = **약 1 GB**. → 단일 Redis 노드 메모리(수십 GB)로 충분히 수용.
- Sliding Window Log처럼 **요청마다 타임스탬프를 저장**하는 알고리즘은 키당 메모리가 수십~수백 배로 폭증 → 메모리가 병목이 된다(아래 비교표 참조).

> **💡 추정의 결론을 설계로 연결**
>
> "1억 req/day → 피크 1만 QPS, 카운터 메모리 ~1GB → 단일 Redis로 가능하지만 1만 QPS면 Redis가 SPOF & 병목 후보. 따라서 **Redis 클러스터 + 키 샤딩** 또는 **로컬 캐시 + 중앙 동기화 하이브리드** 를 검토한다." — 추정이 곧바로 아키텍처 결정 근거가 되어야 한다.

## 3. API / 데이터 모델

### 응답 규약

- 허용: 정상 처리, 응답 헤더에 `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`.
- 초과: HTTP `429 Too Many Requests` + `Retry-After: 5`(초). 클라이언트는 이 값만큼 백오프해야 함.

### 데이터 모델 (Redis)

- 키 설계: `rl:{scope}:{id}:{window}` 예) `rl:apikey:AK123:1719800000`.
- Fixed/Sliding Counter: 값은 정수 카운터. `INCR` + `EXPIRE`.
- Token Bucket: 값은 `{tokens, last_refill_ts}` 해시. 요청 시 경과시간만큼 토큰 충전 후 차감.
- Sliding Window Log: `ZSET`(sorted set), score=timestamp. 윈도 밖 원소 제거(`ZREMRANGEBYSCORE`) 후 `ZCARD`로 개수 확인.

> **⚠️ 실무 함정 — INCR + EXPIRE의 원자성**
>
> `INCR` 후 별도로 `EXPIRE` 를 호출하면, 그 사이 프로세스가 죽으면 **만료 없는 영구 키** 가 남아 메모리 누수가 된다. `SET key val EX 60 NX` 나 **Lua 스크립트로 INCR+EXPIRE를 원자적으로** 묶어야 한다. 면접에서 "INCR 하고 EXPIRE 걸면 됩니다"라고만 하면 이 함정을 지적당한다.

## 4. High-level 아키텍처

```mermaid
flowchart LR
    C(["📱 Client"]) --> GW["API Gateway\n(Rate Limiter 미들웨어)"]
    GW --> CHK{"카운터 조회·증가\n(원자적)"}
    CHK --> R[("🗄️ Redis\n중앙 카운터")]
    CHK -->|"한도 이내"| APP["✅ Backend 서비스"]
    CHK -->|"한도 초과"| REJ["⛔ 429 Too Many Requests\nRetry-After 헤더"]

    APP --> Resp(["응답"])
    REJ --> Resp

    style GW fill:#dbeafe,stroke:#3b82f6,color:#1e3a8a
    style R fill:#fce7f3,stroke:#ec4899,color:#831843
    style APP fill:#dcfce7,stroke:#22c55e,color:#14532d
    style REJ fill:#fee2e2,stroke:#ef4444
```

*요청 → Gateway의 Rate Limiter → Redis 중앙 카운터 → allow(서비스) / reject(429).*

### Rate Limiter를 어디에 둘까

| 위치 | 장점 | 단점 |
| --- | --- | --- |
| **API Gateway 단** (Kong, AWS API GW, Nginx) | 중앙 집중·서비스 코드 무관·운영 일원화 | 게이트웨이가 병목·SPOF 후보, 세밀한 비즈니스 규칙 표현 한계 |
| **애플리케이션 미들웨어** | 비즈니스 컨텍스트 활용(등급별 한도 등) 쉬움 | 서비스마다 중복 구현·일관성 관리 부담 |
| **사이드카(Sidecar)** (Envoy, Service Mesh) | 앱 무관·언어 무관·메시 차원 일괄 정책 | 인프라 복잡도↑, 메시 도입 전제 |

> **💡 사례 — 어디서 막나**
>
> 공개 API는 게이트웨이에서 API key별 제한을 1차로 적용하고, 결제·송금처럼 민감한 경로는 애플리케이션에서 사용자별 2차 제한을 둘 수 있다. 엣지의 거친 제한과 앱의 정밀한 제한을 함께 둘 때는 두 계층의 한도·실패 정책을 명시한다.

## 5. Deep-dive 🔥(Deep-dive)

### 5-1. 알고리즘 5종 비교 (선택 기준을 확인할 표)

| 알고리즘 | 동작 | 정확도 | 메모리 | 버스트 허용 |
| --- | --- | --- | --- | --- |
| **Token Bucket (토큰 버킷)** | 버킷에 일정 속도로 토큰 충전, 요청마다 1개 소비. 토큰 있으면 통과 | 높음 | 적음 (키당 토큰+ts) | **허용** — 쌓인 토큰만큼 순간 버스트 OK |
| **Leaky Bucket (리키 버킷)** | 큐에 쌓고 일정 속도로 처리(누수). 큐 차면 drop | 높음 | 적음 (큐 길이) | **억제** — 출력률 일정, 트래픽 평활화 |
| **Fixed Window Counter (고정 윈도)** | 1분 같은 고정 구간 카운터, 경계마다 리셋 | 낮음 | 가장 적음 (정수 1개) | **경계 버스트 위험** — 한도 2배 누출 가능 |
| **Sliding Window Log (슬라이딩 로그)** | 요청 타임스탬프를 모두 저장, 윈도 내 개수로 판정 | **가장 정확** | **가장 많음** (요청마다 1 엔트리) | 정밀 차단 |
| **Sliding Window Counter (슬라이딩 카운터)** | 현재+이전 고정 윈도 카운터를 가중 평균으로 근사 | 높음 (근사) | 적음 (카운터 2개) | 경계 문제 완화·실무 최선의 균형 |

> **🎯 면접 함정 #1 — Fixed Window 경계 버스트**
>
> 한도 "100 req/min"에서 **0:59에 100개 + 1:00에 100개** 가 오면, 윈도가 리셋되며 **2초 안에 200개** 가 통과한다 — 의도한 한도의 2배. 이 "경계(boundary) 버스트"를 모르고 Fixed Window를 추천하면 즉시 지적당한다. 해법: **Sliding Window Counter** 로 이전 윈도를 가중 반영. 이걸 설명하면 면접의 핵심 한 방을 통과한 것.

```mermaid
flowchart LR
    REQ(["요청 도착"]) --> RF["경과 시간만큼\n토큰 충전\n(refill rate × Δt)"]
    RF --> CHK{"토큰 ≥ 1 ?"}
    CHK -->|"Yes"| DEC["토큰 -1\n→ 통과(allow)"]
    CHK -->|"No"| REJ["⛔ 거부(reject)\n429 + Retry-After"]
    DEC --> OUT(["허용"])
    REJ --> OUT2(["차단"])

    style RF fill:#fef3c7,stroke:#f59e0b,color:#78350f
    style DEC fill:#dcfce7,stroke:#22c55e,color:#14532d
    style REJ fill:#fee2e2,stroke:#ef4444
```

*Token Bucket 동작 — 요청 시점에 경과시간만큼 토큰을 채우고(lazy refill), 1개 차감 가능하면 통과.*

### 5-2. 분산 환경 — race condition 🔥(Deep-dive)

서버 인스턴스가 여러 대면 로컬 카운터로는 안 된다(N대 → 한도 N배 누출). 그래서 **Redis 같은 중앙 카운터**로 모은다. 하지만 `read → 판단 → write`가 분리되면 동시 요청 사이에 **race condition**이 생긴다.

```mermaid
sequenceDiagram
    participant A as App 인스턴스 1
    participant B as App 인스턴스 2
    participant R as Redis (count=99, limit=100)

    Note over A,B: ❌ 비원자적(read-modify-write)일 때 race
    A->>R: GET count → 99
    B->>R: GET count → 99
    A->>R: SET count = 100 (통과 판정)
    B->>R: SET count = 100 (통과 판정)
    Note over R: 둘 다 통과 → 실제 101개 허용 (한도 초과 누출)

    Note over A,B: ✅ 원자적 — Lua 스크립트 / INCR
    A->>R: EVAL(incr+검사+expire) → 100, allow
    B->>R: EVAL(incr+검사+expire) → 101, reject
    Note over R: 단일 원자 연산이라 정확히 한 개만 거부
```

*분산 race condition — read-modify-write를 Lua/INCR로 원자화해야 한도가 정확히 지켜진다.*

> **⚠️ 실무 함정 — 중앙 카운터의 비용·SPOF**
>
> **① 동기화 비용** : 모든 요청이 Redis 왕복(DC 내 RTT ≈ 0.5ms) → 1만 QPS면 Redis 부하·네트워크가 병목. 완화: 로컬 토큰 선차감 후 주기적 중앙 정산(hybrid), 또는 키 샤딩. **② Redis SPOF** : 중앙 Redis가 죽으면 전 서비스 영향. 대비: Redis 복제+Sentinel/Cluster, 그리고 **fail-open** (Limiter 장애 시 일단 통과시켜 본 서비스 가용성 보호) 정책. "Redis 단일 인스턴스로 충분합니다"는 SPOF를 무시한 답.

### 5-3. Sticky vs 중앙 집중

- **Sticky 라우팅**: 같은 key를 항상 같은 인스턴스로 보내 로컬 카운터를 정확히 유지. 중앙 왕복이 없어 빠르지만, 인스턴스 추가/제거 시 리밸런싱·핫키 편중 문제.
- **중앙 집중(Redis)**: 정확하고 단순하지만 왕복 지연·SPOF. 대부분의 프로덕션은 **중앙 Redis + 원자 연산**을 기본으로, 초고QPS 경로만 하이브리드로 보강한다.

> **💡 물류 도메인 — "배차 요청 Rate Limiter"**
>
> 라스트마일에서 **기사 앱이 배차(dispatch) 요청을 폭주** 시키거나, 외부 화주사가 운송장 조회 API를 과하게 호출하면 배차 엔진이 마비된다. 여기에 Rate Limiter를 적용: • 기사 단위 `Token Bucket` (평소 잔잔, 피크엔 쌓인 토큰으로 순간 버스트 허용) → 정상적인 몰림은 흡수. • 화주 API key 단위 `Sliding Window Counter` (경계 버스트 방지) → 한 화주가 한도를 정확히 못 넘게. 초과 시 `429 + Retry-After` 로 백오프를 강제해 **retry storm(재시도 폭주)** 이 배차 엔진을 2차 가격하는 것을 막는다.

## 6. Trade-off 정리 — "정답"은 없다

| 결정 포인트 | 선택 A | 선택 B | 언제 어느 쪽 |
| --- | --- | --- | --- |
| 알고리즘 | Sliding Window Log (정확) | Sliding Window Counter (근사·저메모리) | 메모리 여유·정밀 과금이면 Log, 일반적이면 Counter |
| 버스트 | Token Bucket (버스트 허용) | Leaky Bucket (평활화) | 순간 폭주 OK면 Token, 하류 보호·일정 처리율이면 Leaky |
| 카운터 위치 | 중앙 Redis (정확·단순) | 로컬+동기화 하이브리드 (저지연) | 정확도 우선이면 중앙, 초고QPS·지연 민감이면 하이브리드 |
| 장애 정책 | fail-open (가용성 보호) | fail-close (남용 차단) | 일반 API는 fail-open, 결제/송금 등 보안 경로는 fail-close |
| 적용 위치 | API Gateway (중앙) | App/Sidecar (세밀) | 거친 1차는 Gateway, 등급별 정밀 규칙은 App — 다층 병행 |

> **🎯 마무리 한 줄 (면접 클로징)**
>
> "기본은 **중앙 Redis + Lua 원자 연산 + Sliding Window Counter** 로 정확도·메모리·경계버스트를 균형 있게 잡고, Redis는 Cluster로 SPOF를 제거하며 Limiter 장애 시 **fail-open** 으로 본 서비스 가용성을 보호합니다. 배차처럼 순간 버스트가 정상인 경로만 **Token Bucket** 으로 예외 처리합니다." — Trade-off를 한 호흡에 정리하면 합격 시그널.

```text
key = tenant_id + route + time_bucket
decision = atomic(increment(key), set_expiry_if_new)
if limiter unavailable: apply route-specific fail-open/fail-closed policy
```

## 검수 경계와 실패 흐름

- 수치와 임계값은 요구사항으로 선언하고 실제 workload·부하 테스트·관측 지표로 검증한다. 제품·기업의 내부 구현을 근거 없이 일반화하지 않는다.
- 쓰기 성공 후 이벤트/읽기 모델 갱신 실패, 응답 유실 후 재시도, 중복·순서 역전·부분 장애를 정상적인 실패 경로로 모델링한다.
- 원장과 캐시·검색·알림·분석 파생 모델의 상태를 구분하고, 멱등 키·버전·재처리 큐·대사 작업으로 수렴시킨다.
- 성능 최적화는 평균이 아니라 p95/p99, 버스트와 복구 중 부하를 함께 본다. fallback을 추가할 때 정확성·보안·개인정보·비용 trade-off를 기록한다.

## 공식·1차 출처

- [https://redis.io/learn/develop/java/spring/rate-limiting/fixed-window](https://redis.io/learn/develop/java/spring/rate-limiting/fixed-window)
- [https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/rate_limit_filter](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/rate_limit_filter)
- [https://www.rfc-editor.org/rfc/rfc6585](https://www.rfc-editor.org/rfc/rfc6585)$review_23_system_design_08_case_rate_limiter$
WHERE slug = 'system-design-08-case-rate-limiter' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_system_design_09_case_url_shortener$> **검수 경계** — 쓰기·읽기량, 보존 기간, 캐시와 키 예측 가능성은 가상 요구사항이다. 301·302와 CDN의 실제 동작은 클라이언트·캐시 정책으로 검증한다.

## 1. 요구사항 명확화 (Requirements)

> **한 줄 정의** — 긴 URL을 짧은 키로 매핑하고, 짧은 키 접근 시 원본으로 *리다이렉트*한다. 압도적 read-heavy(읽기 우세) 시스템.

### Functional(기능) 요구사항

- **단축**: `long_url` 입력 → `short_url` 발급 (예: `https://nav.to/aZ3kT9q`)
- **리다이렉트**: `short_url` 접근 → 원본으로 HTTP redirect
- **커스텀 별칭(Custom Alias)**: 사용자가 `nav.to/myevent` 처럼 직접 지정 가능
- **만료(Expiration)**: TTL(Time To Live, 유효 기간) 설정 가능, 만료 후 410 Gone
- **클릭 통계(Analytics)**: 클릭 수, Referer(유입 경로), 지역, 디바이스 집계

### Non-functional(비기능) 요구사항

- **읽기:쓰기 = 100:1** — read-heavy. 리다이렉트가 절대 다수. 읽기 latency가 제품 체감을 지배.
- **고가용성(High Availability)**: 리다이렉트는 죽으면 안 된다. 링크가 인쇄물·QR에 박혀 영구 사용됨.
- **저지연(Low Latency)**: 리다이렉트 p99 < 50ms 목표.
- **키 예측 불가(Non-predictable)**: 키를 순차 증가로 노출하면 경쟁사·크롤러가 전체 URL을 enumeration(전수 조회).
- **일관성**: 단축은 Read-your-writes(자기가 쓴 건 바로 읽힘) 수준이면 충분. 통계는 최종 일관성(Eventual Consistency) 허용.

> **🎯 면접 포인트 — 첫 5분이 평가를 가른다**
>
> "URL 단축기 만드세요"에 바로 테이블부터 그리면 감점. **읽기:쓰기 비율, 키 길이/문자셋, 커스텀 별칭 여부, 만료·통계 필요성** 을 먼저 물어야 한다. 면접관은 "당신이 스코프를 통제할 수 있는가"를 본다.

## 2. 용량 추정 (Back-of-the-envelope)

### 2-1. 쓰기 QPS

가정: **쓰기(단축 생성) 1억 건/월**.

- 1개월 ≈ 30일 × 86,400초 ≈ `2.6 × 10⁶ 초` (≈ 약 250만 초)
- 평균 쓰기 QPS = 1억 / 2.6×10⁶ ≈ **≈ 40 writes/s**
- 피크 QPS ≈ 평균 × 5 ≈ **≈ 200 writes/s**

### 2-2. 읽기 QPS (100:1)

- 평균 읽기 QPS = 40 × 100 = **≈ 4,000 reads/s**
- 피크 읽기 QPS ≈ 4,000 × 5 ≈ **≈ 20,000 reads/s**

→ 결론: 쓰기는 단일 노드도 감당. **읽기 2만 QPS를 어떻게 받느냐가 설계의 핵심**. 캐시 + 읽기 복제(Read Replica)가 필수.

### 2-3. 5년 누적 URL 수 → 키 길이 산정

- 1억/월 × 12 × 5년 = **60억 ≈ 6 × 10⁹ 개**
- 키 문자셋: `base62` = [a-z A-Z 0-9] = 62종
- 키 길이별 공간: 6자 = 62⁶ ≈ **568억** (≈ 5.7×10¹⁰) — 60억 수용 가능하나 여유 10배뿐 7자 = 62⁷ ≈ **3.5조** (≈ 3.5×10¹²) — 60억의 약 580배 여유 → **7자 채택**

> **💡 외워둘 base62 치트시트**
>
> 62⁶ ≈ 568억, 62⁷ ≈ 3.5조, 62⁸ ≈ 218조. "수십억~수조 규모면 7자"는 거의 모든 면접에서 통하는 기본값. bit.ly·TinyURL도 6~7자대.

### 2-4. 스토리지 추정

레코드 1건당 대략:

- `key` 7B + `long_url` 평균 100B + 메타(created, expire, ownerId, 카운터) ≈ 100B → **레코드 ≈ 약 500B** (인덱스·오버헤드 포함 넉넉히)
- 5년 60억 × 500B = **3 × 10¹² B ≈ 3 TB**

→ 단일 RDBMS 한 대로도 수 TB는 가능하지만, 6×10⁹ 행 + 2만 읽기 QPS 면 **읽기 복제 다수 + 향후 샤딩**을 염두에 둔다.

### 2-5. 캐시 메모리

읽기는 인기 URL에 쏠린다(80/20). 핫 20%만 캐시:

- 하루 읽기 ≈ 4,000 × 86,400 ≈ 3.5억 reads/day, 고유 URL이 그중 약 20% = 약 7천만 핫키
- 핫키 1건 캐시 ≈ (key 7B + url 100B + 오버헤드) ≈ 약 200B → 7천만 × 200B ≈ **14 GB**

→ Redis 한 클러스터(수십 GB)로 충분히 핫셋 수용. **캐시 히트율 90%+ 면 DB 읽기 부하가 1/10로 떨어진다.**

## 3. API / 데이터 모델

### 3-1. API 설계 (REST)

| 메서드 · 경로 | 설명 | 요청 / 응답 |
| --- | --- | --- |
| `POST /api/v1/shorten` | 단축 URL 생성 | req: `{ longUrl, customAlias?, expireAt? }` → res: `{ shortUrl, key }` |
| `GET /{key}` | 리다이렉트 (핵심 트래픽) | **301** 또는 **302** + `Location: long_url` |
| `GET /api/v1/{key}/stats` | 클릭 통계 조회 | res: `{ clicks, byCountry, byReferer, byDevice }` |
| `DELETE /api/v1/{key}` | 링크 삭제 (소유자만) | 인증 필요 (API Key / OAuth) |

> **⚠️ 면접 함정 — 301 vs 302 즉답**
>
> **301(Moved Permanently)** : 브라우저·중간 프록시가 **응답을 영구 캐시** → 이후 클릭이 우리 서버로 안 옴 → **클릭 통계를 못 센다.** 대신 서버 부하·지연은 최소. **302(Found, 임시)** : 매번 우리 서버를 거침 → 통계 수집 가능, 만료·차단 즉시 반영. 대신 트래픽 100% 흡수. → **"통계가 핵심 기능이면 302"** 가 정답 방향. 통계 불필요·성능 최우선이면 301. 이 Trade-off를 말로 풀어야 한다.

### 3-2. 데이터 모델 (erDiagram)

```mermaid
erDiagram
    URL_MAPPING ||--o{ CLICK_EVENT : "발생"
    URL_MAPPING {
        char7 key PK "base62 단축키 (PK + 캐시키)"
        varchar long_url "원본 URL"
        bigint owner_id FK "소유자 (nullable)"
        timestamp created_at "생성 시각"
        timestamp expire_at "만료 시각 (nullable)"
        boolean is_active "활성 여부 (삭제 soft)"
    }
    CLICK_EVENT {
        bigint event_id PK "클릭 이벤트 (append-only)"
        char7 key FK "단축키"
        timestamp clicked_at "클릭 시각"
        varchar referer "유입 경로"
        varchar country "지역 (GeoIP)"
        varchar device "디바이스"
    }
    USER ||--o{ URL_MAPPING : "소유"
    USER {
        bigint owner_id PK
        varchar email
        varchar api_key "인증 키"
    }
```

*데이터 모델 — 리다이렉트 경로는 `URL_MAPPING`만 보면 됨(단일 PK 조회). 통계는 `CLICK_EVENT`에 비동기 적재.*

#### 인덱스 / 스키마 결정

- `key`는 **PK이자 캐시 키**. 리다이렉트는 PK point-lookup 한 번 → 인덱스 추가 불필요(클러스터드 인덱스로 끝).
- 커스텀 별칭은 `key` 컬럼에 그대로 저장(별도 alias 컬럼 두면 조회 분기 발생). `UNIQUE` 제약으로 중복 방지.
- `CLICK_EVENT`는 append-only(추가 전용) → 시계열 파티셔닝(월별) 또는 별도 OLAP(Online Analytical Processing, 분석용) 저장소로 분리.

## 4. High-level 아키텍처

```mermaid
flowchart TB
    User(["👤 클라이언트"])
    LB["⚖️ Load Balancer\n(L7, 지역 분산)"]
    WApp["✍️ Write Service\n단축 생성 API"]
    RApp["🔁 Redirect Service\n리다이렉트 (stateless)"]
    KGS["🔑 KGS\nKey Generation Service\n사전 생성 키 풀"]
    Cache["⚡ Redis Cache\n핫 URL 80/20"]
    DBM[("🗄️ DB Primary\nURL_MAPPING")]
    DBR[("🗄️ Read Replica\n×N")]
    Kafka["📨 Kafka\nclick-events"]
    OLAP[("📊 Analytics Store\nClickHouse/OLAP")]

    User -->|"POST /shorten"| LB
    User -->|"GET /{key}"| LB
    LB --> WApp
    LB --> RApp

    WApp -->|"키 발급 요청"| KGS
    WApp -->|"INSERT"| DBM
    WApp -.->|"write-through"| Cache

    RApp -->|"1.조회"| Cache
    Cache -.->|"miss → 2.조회"| DBR
    RApp -->|"3.302 + click 비동기"| Kafka
    Kafka --> OLAP

    DBM -->|"복제"| DBR

    style WApp fill:#dbeafe,stroke:#3b82f6,color:#1e3a8a
    style RApp fill:#dcfce7,stroke:#22c55e,color:#14532d
    style KGS  fill:#fef3c7,stroke:#f59e0b,color:#78350f
    style Cache fill:#fce7f3,stroke:#ec4899,color:#831843
    style Kafka fill:#ede9fe,stroke:#8b5cf6,color:#3b0764
```

*High-level 아키텍처 — 읽기 경로(초록)와 쓰기 경로(파랑)를 분리. 통계는 Kafka로 비동기 흘려 리다이렉트 latency를 보호.*

### 리다이렉트 요청 흐름 (읽기 — 핵심)

```mermaid
flowchart LR
    A["GET /{key}"] --> B{"Redis\n캐시 히트?"}
    B -->|"Hit 90%"| C["302 Location:\nlong_url 반환"]
    B -->|"Miss 10%"| D[("Read Replica\nSELECT by PK")]
    D --> E{"존재 &\n만료 전?"}
    E -->|"Yes"| F["캐시 채움\n(TTL)"]
    F --> C
    E -->|"만료"| G["410 Gone"]
    E -->|"없음"| H["404 Not Found"]
    C --> I["click 이벤트\nKafka 비동기 발행"]

    style C fill:#dcfce7,stroke:#22c55e
    style G fill:#fff7ed,stroke:#ea580c
    style H fill:#fee2e2,stroke:#ef4444
```

*리다이렉트 흐름 — 캐시 우선, miss 시 Read Replica. click 발행은 응답 후 비동기(latency 0 영향).*

### 키 발급 흐름 (KGS 방식 — sequenceDiagram)

```mermaid
sequenceDiagram
    participant U as 클라이언트
    participant W as Write Service
    participant K as KGS (키 풀)
    participant DB as DB Primary
    participant C as Cache

    U->>W: POST /shorten(longUrl)
    W->>K: 미사용 키 1개 요청
    K->>K: used 테이블에서 키 1개 pop\n(원자적 마킹)
    K-->>W: key = "aZ3kT9q"
    W->>DB: INSERT(key, longUrl, expireAt)
    DB-->>W: OK (UNIQUE 충돌 없음 보장)
    W->>C: write-through (key → longUrl)
    W-->>U: { shortUrl }
    Note over K,DB: KGS는 키를 미리 대량 생성해두므로\n쓰기 경로에서 충돌 검사·재시도가 없다
```

*KGS 키 발급 — 사전 생성된 키 풀에서 pop. 쓰기 경로의 충돌·재시도를 제거해 latency 안정화.*

## 4-B. 키 생성 전략 비교 🔥(Deep-dive)

이 시스템의 진짜 깊이는 "어떻게 짧고·유일하고·예측 불가능한 키를 만드는가"에 있다. 네 가지 전략을 비교한다.

| 전략 | 방식 | 충돌(Collision) | 예측 가능성 | 확장성 / 비용 |
| --- | --- | --- | --- | --- |
| **① 해시 truncate** (MD5/SHA → 앞 7자) | long_url 해시 후 base62 7자 절단 | **높음** — 절단 시 비둘기집 충돌. 충돌 시 salt 추가 후 재해시 루프 필요 | 낮음(URL 의존) — 단 같은 URL은 같은 키(중복 제거엔 장점) | 충돌 처리 비용이 트래픽 증가에 비선형 |
| **② base62(auto-inc id)** | DB auto-increment id를 base62 인코딩 | **없음** — id가 유일하므로 충돌 0 | **매우 높음(위험)** — id 순차 → 키 순차 → enumeration 가능 | 단순·저렴하나 단일 시퀀스가 SPOF·샤딩 난점 |
| **③ KGS(사전 생성)** Key Generation Service | 오프라인에서 랜덤 키 대량 생성 → used/unused 테이블 → 쓰기 시 pop | **없음** — 생성 단계에서 중복 제거 완료 | **낮음(좋음)** — 무작위 키라 예측 불가 | 쓰기 경로 충돌 0, latency 안정. 키 풀 관리·중복 발급 방지 필요 |
| **④ 분산 ID(Snowflake)** | timestamp+machineId+seq → base62 | **없음** — 전역 유일 보장 | 중간 — timestamp 비트로 시간 추론 가능, 키가 길어짐(보통 11자+) | 분산 환경 최강, 단 키 길이 증가 → "짧음" 요구와 상충 |

> **🎯 면접 함정 — 가장 많이 틀리는 3가지**
>
> **1. "auto-increment id를 그냥 base62 인코딩하면 됩니다"** → id가 순차라 키도 순차 → 경쟁사가 `aaaab, aaaac…` 로 전체 URL을 enumeration. **예측 가능성** 을 지적해야 통과. **2. 해시 truncate에서 충돌 처리를 안 함** → "MD5 앞 7자 자르면 끝"은 비둘기집 원리상 반드시 충돌. 재해시·salt 루프를 말해야 함. **3. Snowflake로 "짧게" 한다는 모순** → Snowflake는 64bit라 base62로도 11자 내외. "짧은 URL" 요구와 충돌함을 인지해야 함.

> **💡 실전 권장 — KGS 하이브리드**
>
> 대규모 단축 URL 서비스에서는 **③ KGS**를 검토할 수 있다. 키를 미리 생성해 두므로 쓰기 경로가 단순 pop+INSERT가 되어 latency가 평탄하고, 무작위라 예측도 불가. 커스텀 별칭만 별도 UNIQUE 충돌 검사로 처리한다.

## 5. Deep-dive 🔥(Deep-dive)

### 5-1. 캐싱 — 80/20 인기 URL

- 리다이렉트는 멱법칙(power-law) 분포 — 소수 URL(이벤트·바이럴 링크)이 트래픽 대부분. **LRU(Least Recently Used) 캐시**로 핫셋만 보관.
- 캐시 전략은 **Cache-aside(읽기 시 채움)** + 생성 시 **Write-through** 병행. 새 링크는 만들자마자 캐시에 있어 첫 클릭도 빠름.
- TTL은 짧게(예: 1시간) 잡되, 만료·삭제는 **능동 무효화(invalidation)**로 즉시 반영.

> **⚠️ Cache Stampede (쇄도)**
>
> 바이럴 링크의 캐시 TTL이 만료되는 순간 수천 요청이 동시에 DB로 몰림(Thundering herd). 대응: **TTL 지터(jitter)** , **분산 락 기반 단일 재계산** , 혹은 인기 키는 만료 안 시키는 **핀 고정(pinning)** .

### 5-2. 301 vs 302 — 통계 영향 🔥(Deep-dive)

```mermaid
flowchart TB
    subgraph S301["301 Permanent"]
      A1["첫 클릭"] --> B1["서버 응답"]
      B1 --> C1["브라우저/프록시\n영구 캐시"]
      C1 --> D1["이후 클릭\n서버 안 옴 ❌"]
      D1 --> E1["통계 누락 / 부하 최소"]
    end
    subgraph S302["302 Temporary"]
      A2["모든 클릭"] --> B2["매번 서버 거침"]
      B2 --> C2["통계 정확 ✅"]
      B2 --> D2["만료·차단 즉시 반영 ✅"]
      D2 --> E2["트래픽 100% 흡수"]
    end
    style S301 fill:#fff7ed,stroke:#ea580c
    style S302 fill:#f0fdf4,stroke:#16a34a
```

*301 vs 302 — 통계가 제품 핵심이면 302. 순수 성능·통계 불필요면 301. 이 선택은 비즈니스 요구가 결정.*

### 5-3. 분석 비동기 수집 (Kafka)

- 리다이렉트 응답 경로에서 통계를 **동기 INSERT 하면 안 된다** — 클릭마다 DB 쓰기가 붙어 read latency·DB 부하 폭증.
- 리다이렉트는 즉시 302 반환 후, click 이벤트를 **Kafka에 비동기 발행** → 컨슈머가 배치 집계 → OLAP(ClickHouse 등) 적재.
- 통계는 **최종 일관성** 허용 — "클릭 수가 몇 초 늦게 반영"은 비즈니스상 문제없음.

### 5-4. 충돌 & Hot Key

- **충돌**: 해시 방식이면 INSERT 시 `UNIQUE` 위반 → salt 추가 재시도. KGS면 사전 제거로 충돌 0.
- **Hot Key**: 단일 바이럴 키가 Redis 한 샤드에 집중 → 핫스팟. 대응: **로컬 캐시(앱 인메모리) 추가 레이어**, 또는 키 복제(같은 값 N벌). 리다이렉트는 read-only라 복제가 안전.

> **💡 물류 도메인 연결 — 운송장 단축 링크**
>
> " `nav.to/track/xxx` 형태의 **배송 추적 단축 URL** "도 같은 구조. 단 추적 링크는 **302 필수** (배송 상태가 바뀌므로 매번 최신 페이지로). 풀필먼트 알림 SMS에 들어가는 링크는 hot key + 만료(배송 완료 후 7일) 설계가 그대로 적용된다.

## 6. Trade-off & Alternatives

### 6-1. 키 생성: 해시 vs 카운터 vs KGS

- **해시**: 같은 URL 중복 제거에 유리하나 충돌 처리 부담. 통계·예측불가 모두 보통.
- **카운터(auto-inc base62)**: 구현 최단·충돌 0이나 **예측 가능성**이 치명적 약점. 내부용·비공개 링크면 허용.
- **KGS**: 쓰기 경로 안정·예측불가. 키 풀 운영 복잡도가 비용. **대규모 공개 서비스의 기본값.**

### 6-2. SQL vs NoSQL

| 관점 | RDBMS(MySQL/PostgreSQL) | NoSQL(DynamoDB/Cassandra) |
| --- | --- | --- |
| 접근 패턴 | PK point-lookup 위주 → 잘 맞음 | key-value 단순 조회에 최적 |
| 스케일 | 읽기 복제로 수만 QPS, 그 이상은 샤딩 필요 | 수평 확장 자연스러움(파티션 키 = url key) |
| UNIQUE/트랜잭션 | 커스텀 별칭 UNIQUE·만료 일관성 처리 쉬움 | 조건부 쓰기(conditional put)로 가능하나 까다로움 |
| 결론 | 중규모·강한 일관성·복잡 쿼리 | 초대규모·단순 KV·전역 분산 |

→ **접근 패턴이 단순 KV + 초대규모면 NoSQL**(DynamoDB로 key=PK). 커스텀 별칭·통계 조인·중규모면 RDBMS + 읽기 복제가 운영이 단순. 정답 없음, 규모와 일관성 요구로 결정.

### 6-3. 301 vs 302

요약: **통계·만료·차단이 제품 가치면 302**, **순수 성능·인프라 비용 최소화면 301**. 절대 정답은 비즈니스 요구가 정한다 — 면접에선 "둘 다 말하고 조건을 제시"가 만점.

> **🎯 가상 사례**
>
> 통계·관리 기능이 제품 가치라면 302 계열과 클릭 이벤트 파이프라인을 선택할 수 있고, 순수 리다이렉트 성능이 우선이면 301을 검토할 수 있다. 실제 캐시·클라이언트 동작은 RFC와 사용 환경으로 검증하며 특정 단축 URL 서비스의 내부 구현을 일반화하지 않는다.

```text
id = next_distributed_id()
short_key = base62(id)
store(short_key -> normalized_url)
redirect: validate -> lookup -> emit_click_event -> 302
```

## 검수 경계와 실패 흐름

- 수치와 임계값은 요구사항으로 선언하고 실제 workload·부하 테스트·관측 지표로 검증한다. 제품·기업의 내부 구현을 근거 없이 일반화하지 않는다.
- 쓰기 성공 후 이벤트/읽기 모델 갱신 실패, 응답 유실 후 재시도, 중복·순서 역전·부분 장애를 정상적인 실패 경로로 모델링한다.
- 원장과 캐시·검색·알림·분석 파생 모델의 상태를 구분하고, 멱등 키·버전·재처리 큐·대사 작업으로 수렴시킨다.
- 성능 최적화는 평균이 아니라 p95/p99, 버스트와 복구 중 부하를 함께 본다. fallback을 추가할 때 정확성·보안·개인정보·비용 trade-off를 기록한다.

## 공식·1차 출처

- [https://www.rfc-editor.org/rfc/rfc3986](https://www.rfc-editor.org/rfc/rfc3986)
- [https://www.rfc-editor.org/rfc/rfc9110](https://www.rfc-editor.org/rfc/rfc9110)
- [https://cheatsheetseries.owasp.org/cheatsheets/Unvalidated_Redirects_and_Forwards_Cheat_Sheet.html](https://cheatsheetseries.owasp.org/cheatsheets/Unvalidated_Redirects_and_Forwards_Cheat_Sheet.html)$review_23_system_design_09_case_url_shortener$
WHERE slug = 'system-design-09-case-url-shortener' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_system_design_10_case_delivery_tracking$> **검수 경계** — 이벤트 수·QPS·지연과 보존 기간은 가상 입력이다. 특정 운송 기업의 내부 처리량·토폴로지로 일반화하지 않는다.

## 1. 요구사항 명확화 (Requirements)

> **한 줄 정의** — 기사앱 스캔 이벤트를 수집해 *송장(Waybill) 상태·위치*를 갱신하고, 고객에게 실시간 조회와 상태 변경 푸시를 제공한다. 압도적 read-heavy + 최종 일관성 허용.

### Functional(기능) 요구사항

- **송장번호 조회**: `waybill`로 현재 상태·진행 단계·예상 도착·위치 조회
- **상태 변경 푸시**: 집하·간선 출발·배송 출발(Out for delivery)·배송 완료 시 푸시/SMS 알림
- **기사앱 스캔 이벤트 수집**: 기사가 바코드 스캔 → `TrackingEvent` 발생(집하·허브 도착/출발·배송 완료 등)
- **푸시 구독**: 고객이 특정 송장 알림 구독/해제

### Non-functional(비기능) 요구사항

- **수집 규모**: 가정한 대량 `TrackingEvent`/일. 피크 시간대(오전 출고/저녁 배송) 몰림.
- **read-heavy**: 조회 QPS가 수집 QPS의 10~50배(고객·CS·셀러가 반복 조회).
- **최종 일관성(Eventual Consistency) 허용**: "스캔 후 수 초 내 조회에 반영"이면 충분. 강한 일관성 불필요.
- **순서 보장**: 같은 송장 내 이벤트는 **시간 순서**가 의미 있음(상태 역행 방지).
- **가용성**: 수집 파이프라인이 죽어도 기사앱은 로컬 큐로 버티고 재전송. 데이터 유실 0 목표.
- **오프라인 내성**: 지하·산간 통신 음영에서 스캔 → 재접속 시 일괄 재전송.

> **🎯 면접 포인트 — 왜 범위가 넓은가**
>
> 라스트마일 추적 문제는 고객 조회 화면뿐 아니라 **대량 이벤트 수집 + 순서 보장 + 멱등 + Fan-out 알림 + 읽기 모델 분리(CQRS)**를 함께 묻기 때문에 종합 문제로 쓸 수 있다. 실제 면접의 빈도나 평가 기준은 회사별 공개 자료로 확인한다.

## 2. 용량 추정 (Back-of-the-envelope)

### 2-1. 수집(쓰기) QPS

가정: **일 5천만 TrackingEvent** (송장 1건당 여러 단계 스캔이라는 교육용 입력). 실제 수집량은 운송장 수·스캔 정책·운영 기록으로 재산정한다.

- 1일 = 86,400초 ≈ `10⁵ 초`
- 평균 수집 QPS = 5×10⁷ / 86,400 ≈ **≈ 580 writes/s**
- 피크는 출고·배송 시간대 집중 → 평균 × 5~6 ≈ **≈ 3,000~3,500 writes/s**

### 2-2. 조회(읽기) QPS

- 읽기 = 쓰기 × 10~50배 가정. 보수적으로 ×20 → 평균 ≈ **≈ 11,000 reads/s**
- 피크(배송 몰리는 저녁, 고객 새로고침) ≈ **≈ 50,000~70,000 reads/s**

→ 결론: **조회를 위한 읽기 모델(머티리얼라이즈 뷰) + 캐시**가 핵심. 수집은 이벤트 스토어에 append, 조회는 별도 최적화된 모델로 분리(CQRS, Command Query Responsibility Segregation, 명령/조회 책임 분리).

### 2-3. 스토리지 추정

이벤트 1건 ≈ **300B**(송장번호, 상태코드, 위치 lat/lng, 허브ID, 기사ID, timestamp, 디바이스):

- 일: 5×10⁷ × 300B = 1.5×10¹⁰ B = **≈ 15 GB/day**
- 연: 15GB × 365 ≈ **≈ 5.5 TB/year** (이벤트 스토어, 압축 전)
- 핫 데이터(진행 중 배송, 최근 7~14일)만 빠른 저장소, 그 이후는 콜드 스토리지(S3/Glacier)로 티어링.

> **💡 외워둘 숫자**
>
> "일 5천만 이벤트 → 평균 ~580 QPS, 피크 ~3.5K QPS, 일 15GB, 연 5.5TB." 이 한 줄을 술술 말하면 추정 단계 통과. 핵심은 **이벤트가 append-only라 무한 증가 → 티어링/파티셔닝 필수** 임을 짚는 것.

## 3. API / 데이터 모델

### 3-1. API 설계

| 메서드 · 경로 | 설명 | 요청 / 응답 |
| --- | --- | --- |
| `POST /api/v1/scan-events` | 기사앱 스캔 이벤트 수집 (배치 가능) | req: `{ events: [{ waybill, statusCode, geo, hubId, scannedAt, clientEventId }] }` + `Idempotency-Key` |
| `GET /api/v1/tracking/{waybill}` | 송장 상태·진행 단계 조회 (핵심 트래픽) | res: `{ status, steps[], lastLocation, eta }` |
| `POST /api/v1/tracking/{waybill}/subscribe` | 상태 변경 푸시 구독 | req: `{ channel: push\|sms, token }` |

> **⚠️ 실무 함정 — 수집 API에 Idempotency-Key는 필수**
>
> 기사앱은 **오프라인 후 재전송·네트워크 타임아웃 재시도** 로 같은 스캔을 여러 번 보낸다. `clientEventId` (앱이 생성한 UUID) 또는 `Idempotency-Key(멱등성 키)` 로 중복 스캔을 서버에서 dedup(중복 제거) 해야 함. 안 하면 "배송 완료"가 두 번 찍히고 알림이 두 번 간다.

### 3-2. 데이터 모델 (erDiagram)

```mermaid
erDiagram
    SHIPMENT ||--|| WAYBILL : "1:1 운송장"
    WAYBILL ||--o{ TRACKING_EVENT : "append-only 이벤트"
    SHIPMENT ||--o{ DELIVERY_TASK : "라스트마일 작업"
    WAYBILL {
        varchar waybill_no PK "송장번호 (조회·파티션 키)"
        varchar status "현재 상태 (읽기모델 스냅샷)"
        bigint last_event_seq "마지막 반영 이벤트 순번"
        timestamp updated_at
    }
    TRACKING_EVENT {
        bigint event_id PK "전역 순번 (append-only)"
        varchar waybill_no FK "송장번호"
        varchar client_event_id "기사앱 UUID (멱등 dedup)"
        varchar status_code "스캔 상태코드"
        decimal lat
        decimal lng
        varchar hub_id "허브/캠프 ID"
        bigint driver_id
        timestamp scanned_at "기사앱 실제 스캔 시각"
        timestamp ingested_at "서버 수신 시각"
    }
    SHIPMENT {
        bigint shipment_id PK
        bigint order_id FK "OMS 주문 연결"
        varchar dest_zone "배송 권역"
    }
    DELIVERY_TASK {
        bigint task_id PK
        bigint driver_id
        varchar waybill_no FK
        varchar task_status "배차/진행 상태"
    }
```

*데이터 모델 — `TRACKING_EVENT`는 append-only 이벤트 스토어(진실의 원천), `WAYBILL.status`는 조회용 머티리얼라이즈 뷰(스냅샷). `scanned_at`(실제 스캔)과 `ingested_at`(서버 수신)을 분리해 out-of-order 판정에 사용. Shipment 1:1 Waybill, Waybill 1:N TrackingEvent, `client_event_id`로 중복 스캔 dedup.*

#### 핵심 설계 결정

- `TRACKING_EVENT`는 **append-only**(수정·삭제 없음) → 감사·재처리·이벤트소싱 가능.
- `WAYBILL.status`는 이벤트를 접어 만든 **읽기 모델(read model)**. 조회는 이 한 행만 보면 됨 → 수만 QPS 대응.
- `(waybill_no, client_event_id)` UNIQUE → 멱등 dedup. `last_event_seq`로 out-of-order/중복 반영 방지.

## 4. High-level 아키텍처

```mermaid
flowchart TB
    Driver(["📱 기사앱\n바코드 스캔 / 로컬 큐"])
    Cust(["👤 고객 / CS / 셀러"])
    LB["⚖️ Load Balancer"]
    Ingest["📥 Ingest API\n수집 + 멱등 dedup"]
    Kafka["📨 Kafka\ntopic: tracking-events\n(partition = waybill)"]
    Stream["⚙️ Stream Processor\n상태 머신 갱신 / 순서검증"]
    ES[("🗄️ Event Store\nTRACKING_EVENT\nappend-only")]
    Read[("📖 Read Model\nWAYBILL 스냅샷")]
    CDC["🔄 CDC\nChange Data Capture"]
    Cache["⚡ Redis\n핫 송장 캐시"]
    Search[("🔎 Search\nElasticsearch (옵션)")]
    Notify["🔔 Notification\nFan-out"]
    Push(["📲 Push / SMS"])
    Query["🔁 Query API\n조회 (stateless)"]

    Driver -->|"POST scan-events"| LB
    LB --> Ingest
    Ingest -->|"발행"| Kafka
    Kafka --> Stream
    Stream -->|"append"| ES
    Stream -->|"upsert 상태"| Read
    Stream -->|"상태 변경 시"| Notify
    Notify --> Push
    Read --> CDC
    CDC --> Cache
    CDC --> Search

    Cust -->|"GET tracking"| LB
    LB --> Query
    Query --> Cache
    Cache -.->|"miss"| Read

    style Ingest fill:#dbeafe,stroke:#3b82f6,color:#1e3a8a
    style Kafka  fill:#ede9fe,stroke:#8b5cf6,color:#3b0764
    style Stream fill:#fef3c7,stroke:#f59e0b,color:#78350f
    style Read   fill:#dcfce7,stroke:#22c55e,color:#14532d
    style Notify fill:#fce7f3,stroke:#ec4899,color:#831843
    style Cache  fill:#fce7f3,stroke:#ec4899,color:#831843
```

*전체 아키텍처 — 수집(파랑) → Kafka(보라) → Stream 처리(주황) → 이벤트스토어 + 읽기모델(초록) → CDC로 캐시/검색 갱신 → 알림 Fan-out(핑크). 조회는 캐시 우선.*

### 송장 상태 머신 (stateDiagram)

```mermaid
stateDiagram-v2
    [*] --> CREATED : 운송장 발행
    CREATED --> PICKED_UP : 집하 스캔
    PICKED_UP --> IN_TRANSIT : 간선 출발
    IN_TRANSIT --> IN_TRANSIT : 허브 도착/출발 (복수)
    IN_TRANSIT --> OUT_FOR_DELIVERY : 캠프 도착 / 배차
    OUT_FOR_DELIVERY --> DELIVERED : 수령 완료 (POD)
    OUT_FOR_DELIVERY --> DELIVERY_FAILED : 부재 / 거부
    DELIVERY_FAILED --> OUT_FOR_DELIVERY : 재방문
    DELIVERY_FAILED --> RETURNED : 최종 반송
    DELIVERED --> [*]
    RETURNED --> [*]
    note right of OUT_FOR_DELIVERY
        역행 금지: 이미 DELIVERED인데
        뒤늦게 IN_TRANSIT 이벤트가 와도
        상태를 되돌리지 않는다 (out-of-order 방어)
    end note
```

*송장 상태 전이 — Stream Processor가 이 머신으로 전이를 검증. 허용되지 않는 역행 전이는 무시(이벤트는 보존, 상태만 미반영).*

### 스캔 이벤트 수집 + 멱등 (sequenceDiagram)

```mermaid
sequenceDiagram
    participant D as 기사앱
    participant I as Ingest API
    participant K as Kafka (waybill 파티션)
    participant S as Stream Processor
    participant E as Event Store
    participant R as Read Model
    participant N as Notification

    D->>I: POST scan-events(clientEventId, waybill, DELIVERED)
    I->>I: dedup 체크 (clientEventId 본 적 있나?)
    alt 신규 이벤트
        I->>K: 발행 (key=waybill → 순서 보장)
        I-->>D: 202 Accepted
        K->>S: consume (파티션 순서대로)
        S->>S: 상태 머신 전이 검증\n(seq > last_event_seq?)
        S->>E: append TRACKING_EVENT
        S->>R: upsert WAYBILL.status=DELIVERED
        S->>N: StatusChanged 발행 → 고객 푸시
    else 중복 (재전송)
        I-->>D: 202 (이미 처리됨, no-op)
    end
```

*수집 + 멱등 흐름 — 같은 `waybill`은 같은 Kafka 파티션으로 라우팅돼 순서 보장. `clientEventId`로 중복 스캔을 dedup. Stream 단계에서 한 번 더 seq 검증(at-least-once 컨슈머 대비).*

## 5. Deep-dive 🔥(Deep-dive)

### 5-1. 대량 이벤트 Fan-out & 알림

- 상태 변경 시 **구독한 고객에게 푸시/SMS Fan-out(팬아웃)**. 모든 스캔이 아니라 **의미 있는 상태 전이**(집하/배송출발/완료)만 알림 → 트래픽 절감.
- 알림은 별도 워커가 Kafka `status-changed` 토픽 consume → 푸시 게이트웨이로 비동기 발송. 발송 실패는 retry 큐 + DLQ(Dead Letter Queue, 실패 메시지 큐).
- Rate limiting: 동일 고객에 단시간 중복 알림 억제(coalescing).

### 5-2. Kafka 파티셔닝 — waybill 키 순서 보장 🔥(Deep-dive)

> **🎯 면접 핵심 — 순서는 "파티션 단위로만" 보장된다**
>
> Kafka는 **파티션 내에서만** 순서를 보장한다. 그래서 **partition key = waybill_no** 로 잡아 같은 송장의 모든 이벤트를 한 파티션에 모은다 → 그 송장의 집하→간선→배송 순서가 유지됨. 송장 간 순서는 어차피 무관하므로 전역 순서는 불필요. "Kafka가 알아서 순서 보장한다"고 답하면 감점 — **파티셔닝 키 선택** 을 말해야 한다.

### 5-3. 멱등 소비 (Idempotent Consumer) — 중복 스캔 🔥(Deep-dive)

- Kafka는 기본 **at-least-once(최소 한 번)** — 컨슈머 재시작·리밸런스 시 같은 메시지 재처리 가능. "Exactly-once는 허상"임을 인지하고 **멱등 소비**로 푼다.
- 방어 2겹: ① Ingest 단계 `clientEventId` dedup, ② Stream 단계 `last_event_seq` 비교(이미 반영한 이벤트면 skip).
- 읽기 모델 upsert는 **조건부 UPDATE**(`WHERE last_event_seq < :seq`)로 원자성 + out-of-order 동시 방어.

### 5-4. 기사앱 오프라인 동기화 🔥(Deep-dive)

- 지하·산간 음영에서 스캔 → 앱 **로컬 큐(SQLite 등)에 저장** → 재접속 시 `scannedAt` 원본 시각을 담아 일괄 재전송.
- 서버는 `scanned_at`(실제 발생)과 `ingested_at`(수신)을 분리 저장 → 상태/순서 판정은 **scanned_at 기준**. 늦게 도착해도 시간순으로 올바르게 접힘.
- 이게 **out-of-order(순서 뒤바뀜)**의 주원인. 5-5와 연결.

### 5-5. 상태 머신 역행 방지 (out-of-order) 🔥(Deep-dive)

> **⚠️ 실무 함정 — "DELIVERED 후 IN_TRANSIT이 도착"**
>
> 오프라인 재전송으로 **늦게 도착한 과거 이벤트** 가 현재 상태를 되돌리면 고객이 "배송완료 → 배송중"으로 보이는 사고. 방어: ① 이벤트에 **단조 증가 seq/scanned_at** 부여, ② 읽기 모델은 `seq > last_event_seq` 일 때만 상태 갱신, ③ 상태 머신에서 **허용된 전이만** 반영(이벤트 자체는 스토어에 모두 보존).

### 5-6. CDC로 읽기 모델 → 캐시/검색 갱신

- `WAYBILL` 읽기 모델 변경을 **CDC(Change Data Capture, 변경 데이터 캡처)**(Debezium 등)로 캡처 → Redis 캐시·Elasticsearch 인덱스 갱신.
- 장점: 애플리케이션이 캐시/검색 동기화를 신경 안 써도 됨(이중 쓰기 제거 → 정합성↑). 단점: 파이프라인 추가 운영 비용.

### 5-7. 핫 송장 (Hot Waybill)

- 바이럴 상품·대형 셀러 송장은 조회가 집중 → Redis 핫스팟. 대응: **앱 로컬 캐시(짧은 TTL)** 추가, 핫키 복제.
- 조회는 read-only라 stale(약간 오래됨) 허용 → TTL 수 초로 잡아 DB 보호.

### 5-8. 최종 일관성

스캔 → Kafka → Stream → 읽기 모델 → 캐시까지 수 초의 지연 존재. 고객 입장에선 "스캔 후 몇 초 내 반영"이면 충분하므로 **최종 일관성으로 충분**. 강한 일관성을 요구하면 처리량이 급락 — 도메인 특성상 불필요한 비용.

## 6. Trade-off & Alternatives

### 6-1. 동기 vs 비동기 상태 갱신

- **동기**(수집 API가 즉시 상태 갱신): 구현 단순·조회 즉시 일관. 그러나 수집 피크 시 DB 쓰기 경쟁 → latency·장애 전파.
- **비동기**(Kafka 경유): 수집 API는 발행만 → 빠르고 버퍼링으로 피크 흡수(Back-pressure 대응). 대신 최종 일관성·파이프라인 복잡도. **대규모는 비동기 채택.**

### 6-2. 이벤트소싱 vs 상태 스냅샷

| 관점 | 이벤트 소싱 (append-only 이벤트가 진실) | 상태 스냅샷만 (status 컬럼 UPDATE) |
| --- | --- | --- |
| 이력/감사 | 전 이력 보존 → 재현·디버깅·분쟁 대응 강함 | 현재 상태만 → 이력은 별도 로그 필요 |
| 재처리 | 이벤트 리플레이로 읽기 모델 재구축 가능 | 불가 (덮어써짐) |
| 조회 성능 | 그대로면 매 조회마다 접기 → 느림 → 스냅샷 병행 필요 | 단일 행 조회 → 빠름 |
| 저장 비용 | 높음 (모든 이벤트 누적, 티어링 필요) | 낮음 |
| 결론 | 이력·감사·재처리가 중요한 추적엔 적합 | 단순·저비용이나 추적 도메인엔 정보 손실 |

→ 추적 시스템은 **하이브리드 설계를 검토**할 수 있다: 이벤트 스토어(append-only)를 진실의 원천으로 두고, 빠른 조회를 위해 **스냅샷(읽기 모델)을 함께** 유지(CQRS). 이벤트소싱의 이력 강점과 스냅샷의 조회 속도를 모두 취함.

### 6-3. Push vs Pull 추적

| 관점 | Push (서버 → 고객 실시간 전송) | Pull (고객이 조회 시 갱신) |
| --- | --- | --- |
| 실시간성 | 높음 (상태 변경 즉시 푸시) | 고객이 열 때만 최신 |
| 서버 비용 | 구독 관리·연결·Fan-out 비용 큼 | 저렴 (조회 시 캐시 조회) |
| 적합 | "배송 출발/완료" 같은 핵심 전이 알림 | "내 택배 어디?" 반복 조회 화면 |

→ **둘 다 쓴다**: 핵심 상태 전이는 Push(푸시/SMS), 상세 진행 화면은 Pull(캐시 조회). 모든 스캔을 Push하면 비용 폭발이므로 의미 있는 전이만 선별.

### 6-4. Strong vs Eventual Consistency

추적은 **Eventual로 충분**(수 초 지연 무해). Strong을 고집하면 수집 경로에 동기 합의가 끼어 처리량 급락. 단 **"배송 완료" 같은 결제·정산 트리거가 되는 전이**는 다운스트림에서 멱등하게 한 번만 처리되도록 보장(중복 정산 방지) — 일관성 등급을 이벤트별로 차등 적용하는 게 시니어다운 답변.

> **🎯 가상 도메인 사례 — 풀필먼트·라스트마일**
>
> 자체 배송망, 3PL 위탁, 새벽 배송처럼 운영 모델이 다른 주체의 이벤트가 합류한다고 가정한다. 다수 주체 이벤트일수록 멱등·순서 보장과 오프라인 재전송 정책을 명시하고, 특정 기업의 실제 운영을 전제하지 않는다.

```json
{
  "eventId": "evt-01J...",
  "waybillId": "W-42",
  "sequence": 19,
  "status": "OUT_FOR_DELIVERY",
  "occurredAt": "2026-08-20T05:30:00Z"
}
```

## 검수 경계와 실패 흐름

- 한 송장의 sequence가 낮은 재전송 이벤트, 중복 eventId, 장치 clock 오류를 각각 구분하고 상태 머신의 허용 전이·idempotency key·reconciliation 경로를 둔다.
- Kafka partition 순서는 partition 내부 범위이며, hot waybill이 생기면 key 분할·per-waybill sequencer·후속 version guard 중 trade-off를 선택한다.
- projection/snapshot 갱신이 실패해도 append-only 원본 이벤트와 consumer offset을 보존하고, 재처리 중 고객 알림·정산 side effect가 중복되지 않게 한다.
- 이벤트량·보존·fan-out은 가상 입력이다. ingress·consumer 처리량·lag oldest age·p95/p99와 복구 후 대사를 부하 테스트로 검증한다.

## 공식·1차 출처

- [https://www.gs1.org/standards/epcis](https://www.gs1.org/standards/epcis)
- [https://kafka.apache.org/documentation/#semantics](https://kafka.apache.org/documentation/#semantics)
- [https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/transactional-outbox.html](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/transactional-outbox.html)$review_23_system_design_10_case_delivery_tracking$
WHERE slug = 'system-design-10-case-delivery-tracking' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_system_design_11_case_newsfeed$> **검수 경계** — DAU·팔로워 수·피드 길이·p99는 가상 입력이다. 특정 SNS 기업의 현재 그래프 저장소나 랭킹 구현을 사실로 단정하지 않는다.

## 1. 요구사항 명확화 — 무엇을 피드라 부를지부터 합의

`News Feed(뉴스피드)`는 "내가 팔로우한 사람들의 최근 글을 시간/랭킹 순으로 모아 보여주는 화면"이다. 트위터 타임라인, 인스타 피드, 페이스북 뉴스피드가 모두 같은 문제다. 바로 그림을 그리면 감점 — 먼저 범위를 좁힌다.

### Functional 요구사항

- **피드 조회(read)**: 내가 팔로우한 사람들의 post를 모아 페이지네이션으로 반환. 무한 스크롤.
- **글 작성(write)**: post 생성 시 팔로워들의 피드에 반영.
- **정렬 기준**: 순수 시간역순(reverse-chronological)인가, **랭킹(engagement 기반)** 인가? 이 결정이 파이프라인 복잡도를 좌우.
- **팔로우 그래프**: follow/unfollow. 유저당 팔로잉/팔로워 수의 분포(롱테일 + 셀럽).

### Non-functional 요구사항

| 속성 | 목표 | 이유 |
| --- | --- | --- |
| **Read-heavy** | Read:Write ≈ 100:1 이상 | 피드는 쓰기보다 조회가 압도적. 조회 최적화가 설계의 중심 |
| **Low latency** | 피드 조회 p99 < 200ms | 첫 화면 로딩 체감. 조회 시점에 무거운 연산을 하면 무너짐 |
| **Eventual Consistency(최종 일관성)** | 제품 계약이 허용한 지연 | 내 글이 피드에 늦게 보일 수 있으므로 허용 지연·read-your-writes 경로를 명시 |
| **High availability** | 피드는 죽어도 stale하게라도 뜨게 | 은행이 아니다. 약간 오래된 피드 > 빈 화면 |

> **🎯 면접 포인트 — 가장 먼저 던질 질문**
>
> "정렬이 **시간순인가 랭킹인가**?", "**Read:Write 비율**은?", "셀럽 같은 **팔로워 편중(skew)** 이 있나?", "피드는 **일관성보다 가용성** 우선인가?" — 이 네 개를 먼저 물으면 시니어 신호다. 특히 랭킹 여부는 아키텍처를 통째로 바꾼다. 요구사항 없이 바로 Fan-out 그리면 감점.

## 2. 용량 추정 — 셀럽 문제가 숫자에서 튀어나온다

전제: `DAU(Daily Active Users, 일간 활성 사용자)` **2억 명**, 유저당 평균 팔로잉 **200명**.

### QPS 추정

- 1 day ≈ 10⁵ 초 (86,400s).
- 유저가 하루 평균 **10회 피드 조회** → 조회 = 2억 × 10 = 20억/day → 평균 **약 23,000 QPS**, 피크 5배면 **약 115,000 QPS**.
- 유저가 하루 평균 **0.2개 글 작성** → 쓰기 = 2억 × 0.2 = 4,000만/day → 평균 **약 460 QPS**. → **Read:Write ≈ 50:1**, 조회가 압도적.

### Fan-out(팬아웃) 쓰기 증폭

`Fan-out(팬아웃)`은 글 1개를 팔로워 N명의 피드에 뿌리는 것. 쓰기 460 QPS라도 팔로워 수만큼 증폭된다.

- 평균 팔로워 200명 가정: 460 × 200 = **약 92,000 fan-out writes/sec** — 이미 조회 QPS에 육박.
- **셀럽 1명(팔로워 5,000만)** 이 글 1개 쓰면: 단일 write가 **5,000만 개의 피드 삽입**으로 폭발. 초당 몇 명만 동시에 써도 수억 건. → 순수 push는 여기서 붕괴.

### 피드 캐시 메모리

- 유저당 피드 캐시를 **post ID 800개**만 유지(최근 것만). ID 8B + score 8B ≈ 16B → 유저당 약 13KB.
- 활성 유저 2억 전체를 precompute하면 2억 × 13KB ≈ **2.6TB**. → 전부는 낭비. **활성 유저만** 캐싱(아래 lazy 전략).

> **💡 추정의 결론을 설계로**
>
> "쓰기는 460 QPS로 작지만 fan-out으로 9만/sec까지 증폭되고, 셀럽에선 단발 5,000만으로 폭발 → **순수 push 불가**. 조회는 11만 QPS라 조회 시점 연산은 최소화해야 함 → **순수 pull도 불가**. 결론은 **하이브리드**." 추정이 곧 아키텍처 결정 근거다.

## 3. API / 데이터 모델

### API (REST)

- `GET /v1/feed?cursor={id}&limit=20` → 피드 페이지. **cursor 기반 페이지네이션**(offset은 삽입 시 밀림/중복 발생).
- `POST /v1/posts` `{ text, media_ids }` → 글 작성, fan-out 트리거.
- `POST /v1/follow` `{ target_user_id }` / `DELETE /v1/follow/{id}`.

### 데이터 모델

```sql
-- 원본 post (source of truth) — 샤드 키: author_id
CREATE TABLE posts (
    post_id     BIGINT PRIMARY KEY,   -- Snowflake ID (시간순 정렬 내장)
    author_id   BIGINT NOT NULL,
    content     TEXT,
    created_at  TIMESTAMPTZ NOT NULL
);

-- 팔로우 그래프 — 양방향 조회를 위해 두 인덱스
CREATE TABLE follows (
    follower_id BIGINT NOT NULL,
    followee_id BIGINT NOT NULL,
    PRIMARY KEY (follower_id, followee_id)
);
CREATE INDEX idx_followee ON follows (followee_id);  -- "이 사람의 팔로워 목록" = fan-out 대상
```

> **⚠️ 실무 함정 — post_id에 auto-increment 쓰지 마라**
>
> 피드는 시간역순 정렬이 핵심인데 auto-increment는 **샤드 간 전역 순서**를 못 준다. **Snowflake ID**(상위 비트 = 타임스탬프)를 쓰면 ID 자체가 대략 시간순이라, 피드 캐시(`ZSET`)의 score로 그대로 재활용된다. 트위터가 Snowflake를 만든 이유가 바로 이것.

## 4. High-level 아키텍처

```mermaid
flowchart LR
    U(["✍️ 작성자"]) --> WSVC["Post Service"]
    WSVC --> PDB[("Post DB\n(source of truth)")]
    WSVC --> MQ["📨 Fan-out Queue\n(Kafka)"]
    MQ --> FW["Fan-out Worker"]
    FW -->|"일반 유저: push"| FC[("🗄️ Feed Cache\n(Redis ZSET)")]
    FW -.->|"셀럽: skip (pull)"| FC

    R(["📱 조회자"]) --> FSVC["Feed Service"]
    FSVC -->|"1) push분 읽기"| FC
    FSVC -->|"2) 팔로우한 셀럽\nposts 직접 조회 (pull)"| PDB
    FSVC --> MERGE["merge + 랭킹 정렬"]
    MERGE --> R

    style MQ fill:#fef3c7,stroke:#f59e0b,color:#78350f
    style FC fill:#fce7f3,stroke:#ec4899,color:#831843
    style MERGE fill:#dbeafe,stroke:#3b82f6,color:#1e3a8a
```

*작성 시 fan-out worker가 일반 유저 피드엔 push, 셀럽은 skip. 조회 시 push분(캐시) + 셀럽분(pull)을 merge.*

### 두 가지 극단 — 그리고 하이브리드

| 방식 | 쓰기 시 | 조회 시 | 강점 | 약점 |
| --- | --- | --- | --- | --- |
| **Fan-out on Write (push)** | 팔로워 전원 피드에 미리 삽입 | 내 캐시만 읽으면 끝 (빠름) | **조회 초저지연**, 조회 로직 단순 | 쓰기 증폭 폭발, 셀럽에서 붕괴, 비활성 유저 낭비 |
| **Fan-out on Read (pull)** | 아무것도 안 함 | 팔로잉 전원의 최근 글을 그때 모아 merge | 쓰기 저렴, 저장공간 절약 | **조회 시 무거운 연산**(팔로잉 200개 스캔+정렬) → 지연 폭증 |
| **Hybrid (실무 정답)** | 일반은 push, 셀럽은 skip | 캐시(push분) + 셀럽(pull) merge | 양쪽 장점, 셀럽 폭발 회피 | merge 로직 복잡, 경계 관리 필요 |

> **💡 사례 — 실제로 어떻게 하나**
>
> **공개 패턴을 일반화할 때의 주의** — 공개된 뉴스피드 사례에서 fan-out on write와 hot-key 예외가 소개되지만, 현재 특정 회사의 내부 구현으로 단정하지 않는다. 일반 유저는 push하고 고차수 계정은 pull해 merge하는 하이브리드는 하나의 설계 가설이다.

## 5. Deep-dive 🔥

### 5-1. 셀럽(hot-key) 문제 — 하이브리드 merge

셀럽 글을 push하면 단발 5,000만 write. 그래서 **셀럽은 push 대상에서 제외**하고, 조회 시점에 pull한다.

```mermaid
sequenceDiagram
    participant U as 조회자
    participant F as Feed Service
    participant C as Feed Cache(Redis)
    participant P as Post DB

    U->>F: GET /feed
    F->>C: ZREVRANGE feed:user (push된 일반유저 글)
    C-->>F: post_id 리스트 (최근순)
    F->>P: 내가 팔로우한 셀럽들의 최근 post 조회 (pull)
    P-->>F: 셀럽 최신 글
    F->>F: 두 소스 merge + 랭킹 정렬 + dedup
    F-->>U: 최종 피드 20개
```

*일반 유저 글은 미리 push되어 캐시에 있고, 셀럽 글만 조회 시 pull해서 합친다. 셀럽이 몇 명뿐이라 pull 비용이 작다.*

> **🎯 면접 함정 #1 — 셀럽 경계와 merge 정렬**
>
> "셀럽 = 팔로워 N만 이상"의 **경계값**을 물으면 좋다(보통 수십만~백만). 그리고 merge 후 정렬 기준: 시간순이면 두 소스를 timestamp로 k-way merge, **랭킹이면 두 소스를 한 스코어 함수로 재평가**해야 한다. "그냥 합쳐서 시간순 정렬"이라고만 하면 랭킹 케이스를 놓친 것. 또 유저가 셀럽 경계를 넘는 순간의 과거 글 정합성(이미 push된 것 vs 앞으론 pull)도 지적 포인트.

### 5-2. 피드 캐시 설계 — 낭비 없이 precompute

- **자료구조**: Redis `ZSET`, member=post_id, score=Snowflake(시간). `ZREVRANGE`로 최신순 페이지네이션.
- **리스트 상한**: 유저당 최근 **800개**만 유지(`ZREMRANGEBYRANK`로 초과분 trim). 무한 스크롤 깊은 곳은 DB에서 pull.
- **Lazy precompute**: 2억 전부 미리 만들면 2.6TB 낭비. **최근 활성 유저만** 캐싱하고, 비활성 유저는 캐시 미스 시 재생성 후 TTL 부여.

```redis
# fan-out worker가 일반 팔로워 피드에 삽입 (원자적으로 상한 유지)
ZADD  feed:{follower_id}  {snowflake_score}  {post_id}
ZREMRANGEBYRANK  feed:{follower_id}  0  -801   # 최신 800개만 남김
EXPIRE feed:{follower_id}  604800               # 7일 미접속시 만료 → 메모리 회수
```

> **⚠️ 실무 함정 — cache stampede & 캐시 미스 재생성**
>
> 비활성 유저가 오랜만에 접속해 캐시 미스가 나면, 피드를 팔로잉 전원 스캔으로 재생성해야 한다(pull과 동일). 인기 유저들에 동시 미스가 몰리면 **stampede(쇄도)**. 완화: 재생성에 **단일 flight lock**(`SETNX`)을 걸어 한 요청만 재생성하고 나머지는 대기/stale 반환. "미스나면 다시 만들면 됩니다"는 stampede를 무시한 답.

### 5-3. 랭킹 파이프라인 개요

시간순을 넘어 engagement 랭킹을 넣으면 별도 파이프라인이 붙는다.

```mermaid
flowchart LR
    CAND["후보 생성\n(push캐시 + 셀럽pull)"] --> FEAT["피처 추출\n(작성자 친밀도·최신성·\n좋아요/댓글 예측)"]
    FEAT --> SCORE["스코어링 모델\n(경량 ML or heuristic)"]
    SCORE --> RANK["정렬 + 다양성 규칙\n(한 작성자 연속 노출 억제)"]
    RANK --> OUT(["최종 피드"])

    style SCORE fill:#dbeafe,stroke:#3b82f6,color:#1e3a8a
    style RANK fill:#dcfce7,stroke:#22c55e,color:#14532d
```

*후보 생성 → 피처 → 스코어링 → 재정렬. 무거운 스코어링을 조회 경로에 넣으면 지연이 터지므로, 후보 수를 수백 개로 제한한 뒤 경량 모델을 태운다.*

> **💡 물류 도메인 — "화주 대시보드 배송 이벤트 피드"**
>
> 뉴스피드를 물류로 재해석하면 **화주(shipper) 대시보드의 배송 이벤트 피드**다. 화주가 "팔로우"하는 대상 = 자기 운송장(shipment)들이고, post = 상태 이벤트(집화·간선 상차·허브 도착·배송 출발·완료). 여기서도 **셀럽 = 대형 화주**: 하루 수십만 건을 발송하는 대형 화주 한 명은 이벤트가 폭주한다. 소형 화주는 **push**(이벤트 발생 시 대시보드 피드 캐시에 삽입)로 실시간 체감을 주고, 대형 화주는 **pull + 집계뷰**(조회 시 최근 이벤트를 시계열 DB에서 range 스캔)로 폭발을 막는다. 순서 보장이 중요하므로 이벤트에 **Snowflake ID + per-shipment sequence**를 붙여, 중복/역전을 dedup한다.

## 6. Trade-off 정리 — "정답"은 하이브리드지만 경계가 관건

| 결정 포인트 | 선택 A | 선택 B | 언제 어느 쪽 |
| --- | --- | --- | --- |
| Fan-out 전략 | Push (조회 빠름) | Pull (쓰기 저렴) | 대부분 유저는 Push, 셀럽·고팔로워만 Pull → **하이브리드** |
| 정렬 | 시간역순 (단순·저비용) | 랭킹 (참여도↑·복잡) | MVP·실시간성 우선이면 시간순, 체류시간·광고 최적화면 랭킹 |
| 피드 캐시 범위 | 전 유저 precompute | 활성 유저만 lazy | 저장공간·비용을 우선하면 lazy를 검토, 초저지연 절대우선이면 precompute |
| ID 발급 | auto-increment | Snowflake | 다중 샤드에서 시간 정렬이 필요하면 Snowflake 같은 시간 기반 ID를 검토 |
| 일관성 | Strong (즉시 반영) | Eventual (수초 지연) | 피드는 Eventual로 충분, 결제/잔액이라면 Strong |

> **🎯 마무리 한 줄 (면접 클로징)**
>
> "기본은 **일반 유저 push + 셀럽 pull 하이브리드**로, 조회는 Redis ZSET 피드 캐시(최근 800개, 활성 유저 lazy precompute)에서 초저지연으로 뽑고, 셀럽 글만 조회 시 merge합니다. ID는 **Snowflake**로 시간순 정렬과 dedup을 동시에 잡고, 랭킹은 후보를 수백 개로 좁힌 뒤 경량 스코어링을 태웁니다. 셀럽 경계값과 merge 정렬이 실제 난이도의 핵심입니다." — 하이브리드의 근거와 경계 관리를 한 호흡에 말하면 합격 시그널.

## 검수 경계와 실패 흐름

- 수치와 임계값은 요구사항으로 선언하고 실제 workload·부하 테스트·관측 지표로 검증한다. 제품·기업의 내부 구현을 근거 없이 일반화하지 않는다.
- 쓰기 성공 후 이벤트/읽기 모델 갱신 실패, 응답 유실 후 재시도, 중복·순서 역전·부분 장애를 정상적인 실패 경로로 모델링한다.
- 원장과 캐시·검색·알림·분석 파생 모델의 상태를 구분하고, 멱등 키·버전·재처리 큐·대사 작업으로 수렴시킨다.
- 성능 최적화는 평균이 아니라 p95/p99, 버스트와 복구 중 부하를 함께 본다. fallback을 추가할 때 정확성·보안·개인정보·비용 trade-off를 기록한다.

## 공식·1차 출처

- [https://redis.io/docs/latest/develop/data-types/sorted-sets/](https://redis.io/docs/latest/develop/data-types/sorted-sets/)
- [https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-partition-key-design.html](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-partition-key-design.html)
- [https://kafka.apache.org/documentation/#intro_consumers](https://kafka.apache.org/documentation/#intro_consumers)$review_23_system_design_11_case_newsfeed$
WHERE slug = 'system-design-11-case-newsfeed' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_system_design_12_case_chat$> **검수 경계** — 동시 연결·메시지 QPS·p99와 그룹 크기는 가상 요구사항이다. 특정 채팅 서비스의 내부 구현과 저장소를 일반화하지 않는다.

## 1. 요구사항 명확화 — 채팅은 '전달 보장'이 핵심

`실시간 채팅(Real-time Chat)`은 "메시지를 낮은 지연으로 상대에게 밀어 넣고(push), 잃지 않고 순서대로 저장·표시"하는 시스템이다. 메신저·협업 도구·기사-고객 채널이 공유하는 문제를 추상화하고, 제품별 내부 구현은 공개 자료로 확인하지 않는다. 먼저 범위를 좁힌다.

### Functional 요구사항

- **1:1 채팅 / 그룹 채팅**: 그룹 인원 상한(수십? 수백? 수천의 Discord 서버?)에 따라 설계가 갈린다.
- **메시지 전달**: 실시간 push, **at-least-once 전달 + 클라이언트 dedup**. 순서 보장.
- **상태 표시**: 온라인/오프라인(presence), 타이핑 인디케이터, **읽음(read receipt)**, **안읽음 수**.
- **오프라인 지원**: 수신자가 접속 안 했으면 저장했다가, 재접속 시 sync + 모바일 push 알림.
- **히스토리**: 지난 대화 스크롤(무한 페이지네이션).

### Non-functional 요구사항

| 속성 | 목표 | 이유 |
| --- | --- | --- |
| **Low latency** | 전송 p99 < 200ms (같은 리전) | 실시간 체감의 생명 |
| **Durability(내구성)** | 메시지 유실 0 지향 | "보냈는데 안 왔다"는 채팅앱의 사망 신호 |
| **Ordering(순서)** | 채널 내 순서 보장 | 대화 맥락이 뒤섞이면 안 됨 |
| **High availability** | 게이트웨이 장애 시 재접속·재전송 | 연결 끊김은 상시 발생 → graceful reconnect 필수 |
| **Scale** | 동시 접속(concurrent connections)은 가상 입력으로 선언 | 연결 자체가 자원이므로 FD·메모리·재접속 폭주를 부하 테스트 |

> **🎯 면접 포인트 — 먼저 물을 질문**
>
> "**1:1 위주인가 대형 그룹인가**? 그룹 크기와 fan-out 방식에 따라 설계가 달라진다", "**전달 보장 수준**은?(at-least-once + dedup)", "**멀티 디바이스** 지원?(폰+PC 동시)", "presence·타이핑까지 필요한가?" — 이 질문들이 시니어 신호. 특히 그룹 규모는 아키텍처를 통째로 바꾼다.

## 2. 용량 추정 — 동시 접속이 자원이다

전제: `DAU(Daily Active Users, 일간 활성 사용자)` **1억 명**, 유저당 하루 평균 송신 **40 메시지**.

### 메시지 QPS

- 1 day ≈ 10⁵ 초 (86,400s).
- 총 송신 = 1억 × 40 = 40억/day → 평균 **약 46,000 QPS**, 피크 5배면 **약 230,000 QPS**.
- 그룹 채팅은 1건 송신이 N명에게 fan-out → 실제 **전달(delivery) 이벤트**는 이보다 훨씬 큼(그룹 평균 인원 곱).

### 동시 접속(concurrent connection)

- 동접률 20% 가정: 1억 × 0.2 = **2,000만 동시 WebSocket 연결**.
- 게이트웨이당 유지 연결 수는 메모리·FD·TLS·메시지 패턴을 측정해 가정한다. 예컨대 65만을 가정하면 2,000만 연결은 약 30~40대지만, 이 수치는 용량 테스트 전의 계산값이다. → 연결 상태(누가 어디 붙었나)를 관리하는 것이 핵심 과제.

### 저장 용량

- 메시지 1개 ≈ **300 B**(본문+메타). 40억/day × 300B = **약 1.2 TB/day** → 1년 **약 430 TB**.
- 이 가정의 저장량과 쓰기 패턴은 단일 RDB의 디스크·복구·파티션 한계를 먼저 benchmark한다. 필요하면 **wide-column store**에 채널별 시계열로 저장하는 선택지를 비교한다.

> **💡 추정의 결론을 설계로**
>
> "동접 2,000만 → 게이트웨이 30~40대에 연결이 흩어짐 → **세션 라우팅(누가 어느 서버?)** 이 1급 문제. 저장 430TB/년 → RDB 불가, **채널ID를 파티션 키로 하는 wide-column**. 순서를 서버가 흩어진 채로 지켜야 함 → **per-channel sequence**." 추정이 곧 설계 축이 된다.

## 3. API / 데이터 모델

### 연결 & API

- **WebSocket**: `wss://chat/connect?token=...` → 인증 후 지속 연결. 이 연결로 송수신·presence·타이핑을 멀티플렉싱.
- `send(channel_id, client_msg_id, text)` — `client_msg_id`는 클라이언트 UUID로 **dedup·재전송 안전성** 확보.
- `GET /v1/channels/{id}/messages?before={seq}&limit=50` — 히스토리 페이지네이션.
- `ack(channel_id, last_read_seq)` — 읽음 커서 갱신.

### 데이터 모델 (wide-column)

```sql
-- 메시지: partition key = channel_id, clustering = seq (채널 내 순서 정렬 내장)
-- (Cassandra/HBase 개념을 SQL 유사문법으로 표현)
CREATE TABLE messages (
    channel_id   BIGINT,
    seq          BIGINT,        -- per-channel monotonic sequence
    message_id   BIGINT,        -- Snowflake (전역 유일·시간 힌트)
    sender_id    BIGINT,
    content      TEXT,
    created_at   TIMESTAMPTZ,
    PRIMARY KEY ((channel_id), seq)   -- 채널 단위 파티션, seq 순 정렬 저장
) WITH CLUSTERING ORDER BY (seq DESC);

-- 읽음 커서: 참여자별 '어디까지 읽었나'만 저장 (메시지마다 X)
CREATE TABLE read_cursors (
    channel_id    BIGINT,
    user_id       BIGINT,
    last_read_seq BIGINT,
    PRIMARY KEY ((channel_id), user_id)
);
```

> **⚠️ 실무 함정 — 서버 timestamp로 정렬하지 마라**
>
> 게이트웨이가 30대로 흩어져 있고 각 서버 벽시계(wall clock)는 **clock skew(시계 오차)** 가 있다. timestamp로 정렬하면 늦게 도착한 메시지가 앞에 끼거나 순서가 뒤집힌다. 반드시 **채널별 단조 증가 시퀀스(per-channel monotonic sequence)** 를 발급해 그걸로 정렬·dedup해야 한다. "created_at으로 order by 하면 됩니다"는 즉시 지적당한다.

## 4. High-level 아키텍처

```mermaid
flowchart LR
    A(["📱 유저 A"]) -.WebSocket.-> GW1["Gateway 1\n(연결 유지)"]
    B(["📱 유저 B"]) -.WebSocket.-> GW2["Gateway 2"]

    GW1 --> MSVC["Message Service\n(seq 발급·검증)"]
    MSVC --> STORE[("Wide-column\n(HBase/Cassandra)")]
    MSVC --> ROUTE["Session Registry\n(Redis: user→gateway)"]
    MSVC --> MQ["📨 Delivery Bus\n(Kafka/Pub-Sub)"]

    MQ --> GW2
    GW2 -.push.-> B
    MSVC -.오프라인.-> PUSH["APNs/FCM\n모바일 푸시"]

    style GW1 fill:#dbeafe,stroke:#3b82f6,color:#1e3a8a
    style GW2 fill:#dbeafe,stroke:#3b82f6,color:#1e3a8a
    style ROUTE fill:#fce7f3,stroke:#ec4899,color:#831843
    style MQ fill:#fef3c7,stroke:#f59e0b,color:#78350f
```

*A는 GW1, B는 GW2에 붙어 있다. Message Service가 seq 발급·저장 후, Session Registry로 "B가 GW2에 있음"을 조회해 그 게이트웨이로 delivery. B가 오프라인이면 저장만 하고 모바일 푸시.*

### Long Polling vs SSE vs WebSocket

| 방식 | 방향성 | 지연 | 오버헤드 | 채팅 적합도 |
| --- | --- | --- | --- | --- |
| **Long Polling** | 단방향(요청-대기) | 중간(재연결 gap) | 매 폴링마다 HTTP 헤더·재핸드셰이크 | △ fallback용으론 OK |
| **SSE(Server-Sent Events)** | 서버→클라 단방향 | 낮음 | HTTP 유지, 송신은 별도 요청 필요 | △ 수신 위주면 가능(알림엔 좋음) |
| **WebSocket** | **양방향 full-duplex** | **가장 낮음** | 핸드셰이크 1회 후 프레임만 | ◎ 채팅의 표준 |

> **💡 사례 — 무엇을 쓰나**
>
> 공개된 기술 사례에서는 WebSocket 게이트웨이, 세션 레지스트리, wide-column 저장 같은 조합이 보이지만 제품별 프로토콜·저장소·운영 규모는 다르다. 이 조합은 요구사항을 설명하기 위한 설계 선택지로만 사용한다.

## 5. Deep-dive 🔥

### 5-1. 세션 라우팅 — "B가 지금 어느 서버에?"

게이트웨이가 흩어져 있으니, A의 메시지를 B에게 밀려면 "B가 붙은 게이트웨이"를 알아야 한다. **Session Registry(보통 Redis)** 에 `user_id → gateway_id` 매핑을 유지한다.

```mermaid
sequenceDiagram
    participant A as 유저 A
    participant G1 as Gateway 1
    participant MS as Message Service
    participant REG as Session Registry(Redis)
    participant G2 as Gateway 2
    participant B as 유저 B

    Note over B,G2: B 접속 시 등록: SET session:B = GW2 (TTL + heartbeat 갱신)
    A->>G1: send(channel, msg)
    G1->>MS: 저장 요청
    MS->>MS: per-channel seq 발급 + wide-column 저장
    MS->>REG: GET session:B → "GW2"
    MS->>G2: deliver(msg) via Delivery Bus
    G2-->>B: WebSocket push
    B-->>G2: ack(seq)
```

*B 접속 시 자기 게이트웨이를 레지스트리에 등록(heartbeat로 TTL 갱신). 전송 시 레지스트리를 조회해 정확한 게이트웨이로 라우팅.*

> **🎯 면접 함정 #1 — 레지스트리 정합성과 멀티 디바이스**
>
> ① 게이트웨이가 죽으면 레지스트리의 매핑이 **stale**해진다 → heartbeat 기반 TTL + 재접속 시 재등록으로 self-heal. ② 유저가 **폰+PC 동시 접속**이면 `user_id → {여러 gateway}` 세트가 되어 **전 디바이스로 fan-out**해야 한다. "user당 서버 하나"로 답하면 멀티 디바이스를 놓친 것. ③ 각 게이트웨이가 `Delivery Bus(Kafka/Pub-Sub)`를 구독하고 자기에게 붙은 유저만 골라 push하는 방식(브로드캐스트 구독)이 레지스트리 조회를 줄이는 대안.

### 5-2. 순서 보장 — per-channel sequence, 병목 피하기

채널마다 단조 증가 seq를 발급한다. 문제는 발급 지점이 병목/SPOF가 되지 않게 하는 것.

- **채널 단위 샤딩**: seq 발급을 채널ID로 샤딩. 한 채널은 항상 같은 파티션/워커가 처리 → 그 안에서 순차 증가. 채널 간엔 독립이라 전체는 수평 확장.
- **at-least-once + client dedup**: 네트워크 재전송으로 중복이 올 수 있으니, `client_msg_id`로 서버가 dedup하고, 수신 클라이언트도 seq로 중복 제거.

```mermaid
stateDiagram-v2
    [*] --> Sent: 클라 전송(client_msg_id)
    Sent --> Stored: 서버 seq 발급+저장
    Stored --> Delivered: 수신자 게이트웨이 push
    Delivered --> Read: 수신자 ack(last_read_seq)
    Stored --> Offline: 수신자 미접속
    Offline --> Delivered: 재접속 시 sync(seq gap 재전송)
```

*메시지 라이프사이클. Offline이면 저장만 하고, 재접속 시 마지막 읽은 seq 이후를 gap 채워 재전송한다.*

> **⚠️ 실무 함정 — sequence 발급을 전역 단일 카운터로 두지 마라**
>
> 모든 채널의 seq를 하나의 전역 원자 카운터에서 뽑으면 그게 곧 전 시스템의 SPOF·병목이다(초당 수십만 발급). **채널 단위로 seq 공간을 분리**해야 수평 확장된다. 전역 유일성이 필요한 건 `message_id`(Snowflake)뿐이고, **정렬용 seq는 채널 로컬**이면 충분하다.

### 5-3. 읽음 처리 & 안읽음 수 — fan-out 폭발 관리

- **읽음 커서(read cursor)**: 메시지마다 읽음 플래그를 두지 않는다. 참여자별 `last_read_seq` **하나**만 저장 → "그 seq 이하는 다 읽음". 저장·갱신 비용이 O(참여자).
- **안읽음 수(unread count)**: `채널 최신 seq − 내 last_read_seq`로 즉시 계산. 별도 카운터를 매 메시지 증가시키는 방식보다 정합성이 안전.

| 방식 | 읽음 표현 | 비용 | 대형 그룹 |
| --- | --- | --- | --- |
| **메시지별 읽음 플래그** | 메시지 × 유저 매트릭스 | 폭발적(N×M) | ✗ 수백 명 방에서 붕괴 |
| **read cursor(커서)** | 참여자별 last_read_seq 1개 | O(참여자) | ◎ 표준 방식 |

> **🎯 면접 함정 #2 — 대형 그룹 read receipt fan-out**
>
> 예를 들어 500명 방에서 한 명이 읽을 때마다 read receipt를 **전원에게 실시간 push**하면 500명 × 500명 = 25만 이벤트가 튈 수 있다. 1:1이나 소규모는 실시간 receipt를 제공하고, **대형 그룹은 read receipt를 집계**하거나 주기적 조회로 바꾸는 설계를 검토한다. 특정 제품의 기능 유무를 일반화하지 않는다.

> **💡 물류 도메인 — "기사-고객 실시간 채팅 & 위치 공유"**
>
> 라스트마일에서 **배송기사와 고객 간 채팅**은 정확히 이 시스템이다. 특징: ① 대화가 **주문(order) 단위로 단명**한다 → 채널 = order_id, 배송 완료 후 TTL로 아카이빙. ② 채팅 채널 위에 **실시간 위치 공유(기사 GPS 좌표 스트림)** 를 얹는데, 이건 순서·유실이 덜 민감한 **고빈도 저가치 이벤트**라 채팅 메시지와 다른 QoS로 다뤄야 한다(위치는 최신값만 유지·중간값 drop 허용, 채팅은 durable). ③ 기사·고객 모두 오프라인이 잦으니 **오프라인 저장 + FCM/APNs 푸시**가 핵심. ④ "메시지를 상담사가 봤나"보다 "**기사가 곧 도착**" 같은 시스템 이벤트를 채팅 스트림에 섞어 보내는 하이브리드가 실무에 흔하다. per-channel seq로 채팅·시스템 이벤트·위치를 한 타임라인에 정렬한다.

## 6. Trade-off 정리 — "정답"은 없다

| 결정 포인트 | 선택 A | 선택 B | 언제 어느 쪽 |
| --- | --- | --- | --- |
| 전송 프로토콜 | WebSocket (양방향·저지연) | SSE/Long Polling (단순·방화벽 친화) | 채팅 본류는 WebSocket, 수신 알림·fallback은 SSE/폴링 |
| 순서 보장 | per-channel seq (확장성) | 전역 timestamp (단순) | 다중 게이트웨이면 seq 필수, 단일 노드 데모면 timestamp도 가능 |
| 저장소 | wide-column (쓰기 처리량·시계열) | RDB (트랜잭션·조인) | 대규모 채팅은 wide-column, 소규모·강한 정합성이면 RDB |
| 전달 보장 | at-least-once + dedup (안전) | at-most-once (단순·유실 허용) | 채팅은 유실 불가 → at-least-once, 위치/타이핑은 at-most-once로 경량화 |
| read receipt | 전원 실시간 fan-out | 집계/미제공 | 1:1·소규모는 실시간, 대형 그룹은 집계 또는 생략 |

> **🎯 마무리 한 줄 (면접 클로징)**
>
> "채팅 본류는 **WebSocket 게이트웨이 + Redis 세션 레지스트리(멀티 디바이스 fan-out) + Kafka delivery bus**로 흩어진 서버 간 라우팅을 풀고, 순서는 **채널 단위 샤딩 + per-channel monotonic seq**로 병목 없이 보장합니다. 저장은 channel_id 파티션의 **wide-column**, 읽음은 **read cursor 한 개**로 O(참여자)에 잡고, 오프라인은 저장 후 **재접속 sync + 모바일 푸시**로 메웁니다. 대형 그룹의 read receipt fan-out만 집계로 눌러줍니다." — 라우팅·순서·읽음·오프라인을 한 호흡에 정리하면 합격 시그널.

## 검수 경계와 실패 흐름

- 수치와 임계값은 요구사항으로 선언하고 실제 workload·부하 테스트·관측 지표로 검증한다. 제품·기업의 내부 구현을 근거 없이 일반화하지 않는다.
- 쓰기 성공 후 이벤트/읽기 모델 갱신 실패, 응답 유실 후 재시도, 중복·순서 역전·부분 장애를 정상적인 실패 경로로 모델링한다.
- 원장과 캐시·검색·알림·분석 파생 모델의 상태를 구분하고, 멱등 키·버전·재처리 큐·대사 작업으로 수렴시킨다.
- 성능 최적화는 평균이 아니라 p95/p99, 버스트와 복구 중 부하를 함께 본다. fallback을 추가할 때 정확성·보안·개인정보·비용 trade-off를 기록한다.

## 공식·1차 출처

- [https://www.rfc-editor.org/rfc/rfc6455](https://www.rfc-editor.org/rfc/rfc6455)
- [https://developer.mozilla.org/en-US/docs/Web/API/WebSocket](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket)
- [https://cheatsheetseries.owasp.org/cheatsheets/WebSocket_Security_Cheat_Sheet.html](https://cheatsheetseries.owasp.org/cheatsheets/WebSocket_Security_Cheat_Sheet.html)$review_23_system_design_12_case_chat$
WHERE slug = 'system-design-12-case-chat' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_system_design_13_case_search_autocomplete$> **검수 경계** — QPS·p99·debounce·prefix 수와 메모리 크기는 가상 요구사항이다. 특정 검색 기업의 집계·개인화 내부 구현을 사실로 단정하지 않는다.

## 1. 요구사항 명확화 — read-heavy의 극단

`Search Autocomplete(검색 자동완성)`은 사용자가 입력창에 `t`, `to`, `top` 을 칠 때마다 상위 후보를 즉시 내려주는 기능이다. 검색 실행(엔터)보다 **요청 수가 압도적으로 많은** read-heavy 시스템이라는 점을 먼저 못 박아야 한다.

### Functional 요구사항

- **prefix 매칭**: 입력 문자열을 접두어로 갖는 후보를 반환. `top` → `토스`, `토스뱅크`, `톱니바퀴`...
- **상위 K개**: 보통 K = 5~10. 무한정이 아니라 **인기도(popularity) 순 상위 K**만.
- **정렬 기준**: 검색 빈도(frequency) + 최신성(recency) + (선택) 개인화·지역.
- **범위 밖 합의**: 오타 교정(fuzzy), 다국어/초성 검색, 개인화는 v1 범위 밖으로 명시 후 확장으로 다룸.

### Non-functional 요구사항

| 속성 | 목표 | 이유 |
| --- | --- | --- |
| **Ultra-low latency** | p99 < 100ms (체감상 50~100ms) | 타이핑을 따라와야 함. 느리면 후보가 뒤늦게 떠 UX 붕괴 |
| **High QPS** | debounce·검색어 길이에 따라 검색 QPS의 5~10배가 될 수 있음 | 한 검색당 글자 수만큼 요청 발생 |
| **Availability** | 자동완성 죽어도 검색 본체는 살아야 | 부가 기능 — fail-soft(빈 목록 반환) |
| **Freshness** | 분~시간 단위 신선도 | 실시간 정확성보다 **사전계산된 근사**가 우선 |

> **🎯 면접 포인트 — "쓰기보다 읽기가 100배"를 선언하라**
>
> 자동완성의 정체성은 **극단적 read-heavy + 사전계산**이다. "검색어를 실시간으로 정렬해서 top K를 뽑겠다"고 시작하면 감점 — 매 keystroke마다 정렬하면 지연이 터진다. "쓰기(집계)는 백그라운드에서 미리, 읽기(서빙)는 미리 만든 자료구조 조회만" 이라는 **read/write 분리**를 첫 문장으로 선언하면 시니어 신호다.

## 2. 용량 추정 — keystroke가 QPS를 부풀린다

### QPS 추정

전제: 하루 **검색 1,000만 건(10^7)**, 평균 검색어 길이 **5글자**, 각 글자마다 debounce 후 1요청.

- 1 day ≈ 10^5 초 (86,400s).
- 검색 실행 QPS = 10^7 / 10^5 = **약 100 QPS**.
- 자동완성 요청 = 검색 × 5글자 = 5 × 10^7 → **약 500 QPS 평균**.
- 피크는 평균의 5~10배 → **약 2,500 ~ 5,000 QPS**로 설계.

> 실무 debounce(디바운스, 입력이 멈추면 요청): 20~50ms 대기로 keystroke당 요청을 3~5배 줄인다. 추정에도 debounce 후 유효 요청만 계산해야 과대추정을 피한다.

### 데이터·메모리 추정

- 고유 검색어(용어) 수: **1,000만(10^7)**, 용어 평균 20 B.
- Trie 노드: 대략 용어 수 × 평균 접두어 공유율. 노드당 자식 포인터·top-K 캐시 포함 보수적으로 **용어당 ~200 B** → 10^7 × 200 B = **약 2 GB**.
- 상위 K 사전계산 캐시(prefix → K개 리스트): 자주 쓰는 prefix 수백만 개 × (K개 × 20 B) → **수 GB**.
- 결론: **단일 노드 메모리(수십 GB)에 in-memory Trie**가 들어간다. 다만 QPS·가용성 때문에 **여러 replica로 복제**하고 prefix로 샤딩.

> **💡 추정 → 설계 연결**
>
> "2,500~5,000 QPS, Trie ~2GB → 메모리엔 여유, 병목은 QPS와 지연. 따라서 **읽기 전용 Trie replica를 여러 대**로 수평 확장하고, prefix 상위 K를 **미리 노드에 붙여** 조회를 O(prefix 길이)로 끝낸다. 앞단엔 CDN·Redis 캐시로 대부분을 흡수." — 추정이 곧 아키텍처 결정 근거.

## 3. API / 데이터 모델

### 서빙 API

- `GET /autocomplete?q=top&limit=10&locale=ko` → `["토스","토스뱅크","톱니바퀴", ...]`.
- 응답은 캐시 친화적으로: `Cache-Control: public, max-age=60`, `ETag` 부여 → CDN·브라우저가 흡수.
- fail-soft: 내부 오류 시 `200 []`(빈 목록) 반환 — 검색창을 막지 않는다.

### 데이터 모델

- **집계 저장(원천)**: `term_frequency(term, count, window_end)` — 시계열 집계 테이블/스토어.
- **서빙 자료구조**: Trie 노드에 `top_k`(사전계산된 상위 K 리스트)를 **직접 저장**. prefix 조회 시 정렬 없이 바로 리턴.
- **Redis 서빙(대안)**: `ZSET` per prefix — `ZADD ac:{prefix} {score} {term}`, 조회는 `ZREVRANGE ac:{prefix} 0 K`.

```redis
# prefix "top" 후보를 인기도(score) 내림차순 상위 10개
ZREVRANGE ac:top 0 9 WITHSCORES

# 집계 배치가 prefix별 top-K를 사전계산해 갱신 (score = 빈도 가중치)
ZADD ac:top 98421 "토스" 51200 "토스뱅크" 8800 "톱니바퀴"
EXPIRE ac:top 3600          # 신선도 1시간, 배치가 재적재
```

> **⚠️ 실무 함정 — "매 요청 정렬"과 "prefix ZSET 폭발"**
>
> ① 조회 시점에 전체 후보를 `LIKE 'top%'` 로 긁어 정렬하면 p99가 수백 ms로 터진다 — **반드시 top-K 사전계산**. ② 그렇다고 모든 prefix마다 ZSET을 만들면(`t`, `to`, `top`...) 키가 폭증한다. 짧은 prefix(1~2글자)는 후보가 너무 많아 hot key가 된다. 해법: **인기 prefix만 캐시**하고 나머지는 Trie 조회로 폴백, 짧은 prefix는 CDN에서 강하게 캐시.

## 4. High-level 아키텍처

자동완성은 두 개의 독립된 경로 — **서빙(읽기)**와 **집계 파이프라인(쓰기)** — 로 나뉜다.

```mermaid
flowchart LR
    C(["⌨️ Client (debounce)"]) --> CDN["🌐 CDN / Edge Cache"]
    CDN -->|"miss"| GW["API Gateway"]
    GW --> R[("⚡ Redis\nprefix top-K")]
    GW -->|"cache miss"| TRIE["🌲 Trie 서빙 클러스터\n(prefix 샤딩, read replica)"]
    TRIE --> RESP(["상위 K 후보"])
    R --> RESP

    subgraph PIPE["📊 집계 파이프라인 (백그라운드)"]
      LOG[("검색 로그\n(Kafka)")] --> BATCH["배치 집계\n(Spark, 일/시간)"]
      LOG --> STREAM["스트리밍 집계\n(Flink, 실시간 트렌드)"]
      BATCH --> MERGE["top-K 병합·정렬"]
      STREAM --> MERGE
      MERGE -->|"사전계산 적재"| TRIE
      MERGE -->|"사전계산 적재"| R
    end

    style CDN fill:#dbeafe,stroke:#3b82f6,color:#1e3a8a
    style R fill:#fce7f3,stroke:#ec4899,color:#831843
    style TRIE fill:#dcfce7,stroke:#22c55e,color:#14532d
    style MERGE fill:#fef3c7,stroke:#f59e0b,color:#78350f
```

*읽기 경로는 CDN→Redis→Trie 순으로 얕게 끝나고, 쓰기(집계)는 검색 로그를 배치+스트리밍으로 모아 top-K를 미리 만들어 서빙 계층에 밀어넣는다.*

### 서빙 방식 3종 비교

| 방식 | p99 지연 | 메모리/운영 | 업데이트 비용 | 언제 |
| --- | --- | --- | --- | --- |
| **In-memory Trie + top-K** | **가장 낮음** (~ms, O(prefix)) | 높음(전량 메모리·자체 운영) | 재빌드/증분 갱신 필요 | 초저지연·대규모 트래픽, 대규모 검색 서비스 |
| **DB `LIKE 'prefix%'`** | 높음(인덱스 스캔·정렬) | 낮음(기존 DB 재사용) | 즉시(쓰면 반영) | 소규모·프로토타입, prefix 인덱스로 버팀 |
| **Elasticsearch completion suggester** | 낮음(FST 기반) | 중간(ES 클러스터 운영) | 색인 반영 지연 | 오타·다국어·랭킹 유연성 필요, 운영 편의 |

> **💡 사례 — 어떻게 서빙하나**
>
> 대규모 검색 서비스의 공개 설계 패턴에서는 검색량 로그를 집계해 prefix별 상위 후보를 사전계산하거나 개인화·연관어를 병합한다. 제품별 정책은 다르므로 현재 특정 회사의 구현으로 단정하지 않는다. 소규모 서비스라면 **Elasticsearch completion suggester**(내부적으로 `FST(Finite State Transducer, 유한 상태 변환기)`)를 검토해 Trie 운영 비용을 줄일 수 있다.

## 5. Deep-dive

### 5-1. Trie와 상위 K 사전계산

Trie는 접두어를 공유하는 트리다. 핵심 최적화는 **각 노드에 그 아래 서브트리의 top-K를 미리 붙여두는 것**. 그러면 조회는 "prefix까지 내려가서 노드의 top-K를 그대로 반환" — 정렬 없이 **O(prefix 길이)**.

```mermaid
flowchart TD
    ROOT(("root")) --> T["t"]
    T --> TO["to"]
    TO --> TOP["top<br/>top-K: [토스, 토스뱅크, 톱니]"]
    TO --> TOS["tos"]
    TOS --> TOSS["토스<br/>freq: 98,421"]
    TOP -.->|"조회: 노드 top-K 즉시 반환"| OUT(["상위 K 후보"])

    style TOP fill:#dcfce7,stroke:#22c55e,color:#14532d
    style OUT fill:#dbeafe,stroke:#3b82f6,color:#1e3a8a
```

*각 Trie 노드가 서브트리의 top-K를 캐시 → prefix 조회 시 정렬 비용 0. 집계 배치가 top-K를 주기적으로 재계산해 노드에 밀어넣는다.*

> **🎯 면접 함정 #1 — "조회 때 정렬"의 함정**
>
> 순진한 구현은 prefix 노드 아래 전체 후보를 모아 매 요청마다 정렬한다 → 인기 prefix(`t`)는 후보가 수십만이라 지연 폭발. **정렬은 집계 시점(백그라운드)에 미리**, 조회는 캐시된 top-K를 읽기만. 이 read/write 비대칭을 설명하면 핵심 한 방 통과.

### 5-2. prefix 기반 샤딩과 hot shard

Trie가 메모리를 넘거나 QPS를 한 노드로 못 버티면 샤딩한다. 자연스러운 키는 **prefix 앞 1~2글자**.

```mermaid
sequenceDiagram
    participant C as Client
    participant LB as Router
    participant S1 as Shard [a-h]
    participant S2 as Shard [i-p]
    participant S3 as Shard [q-z]

    C->>LB: q="top"
    LB->>S2: prefix 't' → shard[i-p]
    S2-->>C: [토스, 토스뱅크, ...]
    Note over LB,S2: 인기 prefix가 한 샤드에 몰리면 hot shard
    Note over LB,S3: 완화: 인기 prefix 전용 복제 + 앞단 CDN 캐시
```

| 샤딩 전략 | 장점 | 단점 |
| --- | --- | --- |
| **prefix 글자 기반** | 라우팅 단순·같은 prefix 지역성 | 알파벳/글자 분포 편중 → hot shard |
| **prefix 해시 기반** | 부하 균등 | 같은 prefix 그룹 지역성 상실, 범위 조회 불리 |
| **인기 prefix 전용 복제** | hot key 흡수 | 복제 관리·정합성 부담 |

> **⚠️ 실무 함정 — 짧은 prefix가 hot shard를 만든다**
>
> `t`, `a` 같은 1글자 prefix는 후보가 압도적으로 많고 요청도 몰려 **hot shard/hot key**가 된다. 대응: ① 1~2글자 결과는 **CDN·브라우저에 길게 캐시**(어차피 잘 안 바뀜), ② 인기 prefix 샤드를 **추가 복제**, ③ debounce로 아주 짧은 prefix 요청 자체를 줄이기. "prefix 앞글자로 샤딩하면 끝"이라 답하면 편중을 지적당한다.

### 5-3. 집계 파이프라인 — 배치 + 실시간 트렌드

top-K를 만드는 쓰기 경로다. 정확한 누적 통계(배치)와 급상승 트렌드(스트리밍)를 **병합**하는 lambda-style이 핵심.

- **배치(Batch)**: 검색 로그를 일/시간 단위로 Spark 집계 → 안정적 누적 빈도. 지연 크지만 정확.
- **스트리밍(Streaming)**: Flink/Kafka Streams로 최근 N분 윈도 집계 → 급상승어 즉시 반영.
- **병합·감쇠**: `score = 배치 누적 × 시간감쇠 + 실시간 트렌드 가중`. 오래된 인기어는 `decay(감쇠)`로 서서히 강등.

| 갱신 방식 | 신선도 | 비용 | 위험 |
| --- | --- | --- | --- |
| **배치만 (일 단위)** | 낮음(하루 지연) | 저 | 실시간 이슈어 누락 |
| **스트리밍만** | 높음 | 고(상시 연산) | 노이즈·스팸어 급부상 |
| **배치 + 스트리밍 병합** | 균형 | 중~고 | 병합 로직 복잡·정합성 관리 |

> **⚠️ 실무 함정 — 트렌드 조작·오염**
>
> 실시간 트렌드를 그대로 반영하면 **어뷰징(반복 검색으로 특정어 급상승)**, 부적절어, 오타어가 후보에 오른다. 방어: 유니크 사용자 기준 카운트(반복 필터), 블록리스트, 최소 빈도 임계치, 이상탐지. 실시간 급상승은 어뷰징·부적절어 위험이 있어 운영 정책과 이상탐지를 함께 설계해야 한다. "실시간 빈도 그대로 top-K" 는 운영 리스크를 무시한 답.

### 5-4. 다층 캐싱

read-heavy를 흡수하는 방어선. 자동완성 응답은 개인화만 없다면 매우 캐시 친화적이다.

| 계층 | TTL | 무엇을 흡수 | 주의 |
| --- | --- | --- | --- |
| **브라우저** | 30~60s | 같은 사용자의 재타이핑 | 개인화 붙으면 캐시 불가 |
| **CDN/Edge** | 60s~수분 | 인기 prefix 전역 트래픽 | prefix가 키 → 카디널리티 관리 |
| **Redis** | 분 단위 | Trie 앞단 공용 캐시 | stampede(쇄도) 방지 필요 |
| **Trie 노드 top-K** | 집계 주기 | 최종 서빙 자료구조 | 증분 갱신 정합성 |

> **💡 물류 도메인 — "주소·상품명 자동완성"**
>
> 풀필먼트/라스트마일에서 **송장 입력 시 주소 자동완성**, **셀러 상품 등록 시 상품명 자동완성**이 같은 구조다. • 주소는 **도로명 접두어 Trie**로, 배송량 많은 지역(강남·판교)이 hot prefix → CDN 캐시 + 지역 샤드 복제. • 상품명은 **검색·주문 빈도로 top-K 사전계산**하되, 신상품·품절은 스트리밍으로 빠르게 반영(품절 상품을 계속 추천하면 오배차·오주문). freshness가 물류에선 곧 정확성이라, 배치 주기를 짧게 가져가고 품절 이벤트는 실시간 무효화(invalidation)한다.

## 6. Trade-off 정리 — "정답"은 없다

| 결정 포인트 | 선택 A | 선택 B | 언제 어느 쪽 |
| --- | --- | --- | --- |
| 서빙 자료구조 | In-memory Trie (초저지연) | Elasticsearch suggester (운영 편의) | 초대형·초저지연이면 Trie, 오타·다국어·소규모면 ES |
| top-K | 사전계산 (조회 빠름) | 실시간 정렬 (항상 최신) | 거의 항상 사전계산, 극소규모만 실시간 |
| 집계 | 배치 (정확·저비용) | 스트리밍 병합 (신선) | 트렌드 중요하면 병합, 안정 도메인이면 배치 |
| 샤딩 | prefix 글자 (지역성) | 해시 (부하 균등) | 범위·지역성이면 글자, 균등 우선이면 해시 |
| 캐시 신선도 | 긴 TTL (부하↓) | 짧은 TTL + 무효화 (신선) | 안 바뀌는 prefix는 길게, 품절/트렌드는 짧게+이벤트 무효화 |

> **🎯 마무리 한 줄 (면접 클로징)**
>
> "읽기와 쓰기를 분리해 **집계 파이프라인이 prefix별 top-K를 미리 만들고**, 서빙은 **in-memory Trie 노드의 top-K를 O(prefix)로 조회**합니다. 앞단은 CDN·Redis 다층 캐시로 read-heavy를 흡수하고, prefix 글자로 샤딩하되 hot prefix는 복제·엣지 캐시로 방어합니다. 트렌드는 **배치 + 스트리밍 병합**에 어뷰징 필터를 얹어 신선도와 안정성을 함께 잡습니다." — read/write 분리와 다층 방어를 한 호흡에 정리하면 합격 시그널.

```text
for query in aggregated_queries:
  for prefix in prefixes(query.text):
    topK[prefix].offer(query.text, query.score)
serve(prefix) = cache.get(prefix) ?: trie.node(prefix).topK
```

## 검수 경계와 실패 흐름

- 수치와 임계값은 요구사항으로 선언하고 실제 workload·부하 테스트·관측 지표로 검증한다. 제품·기업의 내부 구현을 근거 없이 일반화하지 않는다.
- 쓰기 성공 후 이벤트/읽기 모델 갱신 실패, 응답 유실 후 재시도, 중복·순서 역전·부분 장애를 정상적인 실패 경로로 모델링한다.
- 원장과 캐시·검색·알림·분석 파생 모델의 상태를 구분하고, 멱등 키·버전·재처리 큐·대사 작업으로 수렴시킨다.
- 성능 최적화는 평균이 아니라 p95/p99, 버스트와 복구 중 부하를 함께 본다. fallback을 추가할 때 정확성·보안·개인정보·비용 trade-off를 기록한다.

## 공식·1차 출처

- [https://lucene.apache.org/core/](https://lucene.apache.org/core/)
- [https://redis.io/docs/latest/develop/data-types/sorted-sets/](https://redis.io/docs/latest/develop/data-types/sorted-sets/)$review_23_system_design_13_case_search_autocomplete$
WHERE slug = 'system-design-13-case-search-autocomplete' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_system_design_14_multi_region$> **검수 경계** — RTT·RTO·RPO와 제품별 수치는 리전·구성·계약에 따라 달라진다. 클라우드 문서가 보장하는 범위와 설계 가설을 분리한다.

## 1. 왜 멀티리전인가 — 세 가지 동인

`Multi-Region(멀티리전)` 아키텍처는 시스템을 지리적으로 떨어진 여러 데이터센터 리전에 배치하는 것이다. 단일 리전으로 충분한데 굳이 복잡도를 떠안는 이유는 셋뿐이다.

- **지연(Latency)**: 사용자와 가까운 리전에서 응답. 서울 사용자가 미국 리전에 붙으면 왕복만 150~200ms. 글로벌 서비스는 사용자를 가까운 리전으로 붙여 체감 지연을 낮춘다.
- **가용성(Availability)**: 한 리전 전체 장애에도 다른 리전이 트래픽을 받아 서비스 지속하도록 설계할 수 있다. Single-region은 리전이 장애 도메인이 된다.
- **규제·데이터 주권(Data Sovereignty)**: `GDPR(General Data Protection Regulation, 유럽 개인정보보호법)`, 중국 데이터 현지화 등 — 특정 국가 사용자 데이터를 그 지역에 저장해야 하는 법적 요구.

> **🎯 면접 포인트 — "왜"를 못 대면 오버엔지니어링**
>
> 멀티리전은 비용·복잡도·일관성 난이도가 급증한다. "글로벌하니까 멀티리전"은 감점. 위 셋 중 **어떤 동인이 지배적인가**를 먼저 규정해야 아키텍처가 갈린다. 규제 때문이면 geo-partitioning이, 가용성 때문이면 failover 설계가, 지연 때문이면 read replica 배치가 중심이 된다.

### 물리적 제약 — 빛의 속도는 못 이긴다

> 아래 RTT는 지역·네트워크 경로에 따라 달라지는 설명용 범위다. 실제 동기/비동기 선택은 측정된 p95/p99와 quorum 설정으로 검증한다.

| 구간 | RTT(왕복) | 함의 |
| --- | --- | --- |
| DC 내부 | ~0.5ms | 동기 복제 가능 |
| 같은 대륙 리전 간 (서울↔도쿄) | ~30~40ms | 동기 복제 부담되지만 가능 |
| 대륙 간 (서울↔버지니아) | ~150~180ms | 동기 복제하면 매 쓰기가 150ms+ → 사실상 불가 |
| 유럽↔아시아 | ~120~150ms | 동일 |

> **⚠️ 실무 함정 — "전 리전 동기 복제로 강한 일관성"**
>
> 리전 간 RTT가 수십~수백 ms인 환경에서 모든 쓰기를 전 리전에 **동기 복제**하면 커밋 지연이 네트워크 왕복에 묶인다. 처리량과 장애 영향은 배치·프로토콜·워크로드에 따라 달라진다. 따라서 한 가지 흔한 기준은 **리전 내부는 동기, 리전 간은 비동기** 복제이지만, 지연·RPO/RTO·일관성 계약에 따라 달라진다. 비동기의 대가가 곧 다음 섹션의 replication lag과 충돌이다. "전부 strong consistency"는 물리를 무시한 답.

## 2. 아키텍처 패턴 — Active-Passive vs Active-Active

```mermaid
flowchart TB
    subgraph AP["Active-Passive (Warm Standby)"]
      direction LR
      U1(["🌏 전 세계 사용자"]) --> P1["Region A (Active)\n읽기+쓰기"]
      P1 -->|"비동기 복제"| S1["Region B (Passive)\n대기·읽기만"]
      P1 -.->|"장애 시 승격"| S1
    end

    subgraph AA["Active-Active"]
      direction LR
      U2A(["아시아 사용자"]) --> A2["Region A\n읽기+쓰기"]
      U2B(["미주 사용자"]) --> B2["Region B\n읽기+쓰기"]
      A2 <-->|"양방향 비동기 복제\n+ 충돌 해결"| B2
    end

    style P1 fill:#dcfce7,stroke:#22c55e,color:#14532d
    style S1 fill:#e5e7eb,stroke:#9ca3af,color:#374151
    style A2 fill:#dcfce7,stroke:#22c55e,color:#14532d
    style B2 fill:#dcfce7,stroke:#22c55e,color:#14532d
```

*Active-Passive는 한 리전만 쓰기를 받고 다른 리전은 대기(장애 시 승격). Active-Active는 여러 리전이 동시에 쓰기를 받아 충돌 해결이 필수.*

| 패턴 | 쓰기 | 장점 | 단점 | RTO/RPO |
| --- | --- | --- | --- | --- |
| **Active-Passive (Warm Standby)** | 단일 리전 | 충돌 없음·단순, 일관성 관리 쉬움 | Passive 리소스 유휴·페일오버 시간 필요 | RTO 분~수십분, RPO ≈ lag |
| **Active-Active** | 다중 리전 | 낮은 지연·리소스 활용·리전 장애에 강함 | **충돌 해결 필수**·복잡도 급증 | RTO 초~분, RPO ≈ lag |
| **Pilot Light** | 단일 리전 | 최소 비용 대기 | 페일오버 시 스케일업 시간 김 | RTO 수십분~시간 |

> **💡 가상 사례 — Active-Active 검증**
>
> 여러 리전에 Active-Active를 배치하면 가까운 리전으로 라우팅할 수 있지만, 장애 시 트래픽 전환·데이터 충돌·복구 시간을 실제 설정으로 검증해야 한다. 정기적인 chaos/DR 훈련으로 페일오버를 검증하고, 특정 회사의 리전 수나 RTO를 일반화하지 않는다.

## 3. 리전 간 복제와 충돌 해결

비동기 복제는 **replication lag(복제 지연)**을 만든다. Region A에 쓴 데이터가 Region B에 도달하기 전, B가 같은 레코드를 수정하면 **충돌(conflict)**이 발생한다.

```mermaid
sequenceDiagram
    participant UA as 사용자(아시아)
    participant A as Region A
    participant B as Region B
    participant UB as 사용자(미주)

    UA->>A: 재고 = 10 → 9 (주문)
    UB->>B: 재고 = 10 → 9 (동시 주문)
    Note over A,B: 아직 서로 복제 전 — 둘 다 로컬 10 기준
    A-->>B: 비동기 복제: A는 9
    B-->>A: 비동기 복제: B도 9
    Note over A,B: ❌ 충돌 — 실제로 2개 팔렸는데 재고는 9 (1개만 차감됨)
    Note over A,B: 진짜 정답은 8. LWW로 덮으면 재고·매출 손실
```

*Active-Active에서 동시 쓰기 충돌 — 재고 같은 수치는 LWW로 덮으면 데이터가 소실된다.*

### 충돌 해결 전략 3종

| 전략 | 방식 | 장점 | 위험 |
| --- | --- | --- | --- |
| **LWW (Last-Write-Wins)** | 타임스탬프 큰 쓰기 채택 | 단순·자동 | **조용한 데이터 손실**, 시계 오차(clock skew)에 취약 |
| **CRDT (Conflict-free Replicated Data Type)** | 수학적으로 병합 보장(카운터·집합) | 손실 없이 자동 수렴 | 표현 가능한 자료형 제한·메모리 오버헤드 |
| **단일 writer 리전 (home region)** | 레코드마다 쓰기 담당 리전 고정 | 충돌 원천 차단 | 원격 사용자 쓰기 지연·home 리전 장애 시 재지정 |

> **⚠️ 실무 함정 — LWW의 조용한 손실**
>
> LWW는 "타임스탬프 큰 값이 이긴다"이지만, 위 재고 예시처럼 **두 쓰기가 모두 유효한 차감**일 때 하나를 버리면 재고·매출이 소실된다. 게다가 서버 시계가 어긋나면(clock skew) 나중 쓰기가 더 작은 타임스탬프를 달아 **먼저 쓴 값이 이기는** 역전도 생긴다. 카운터성 데이터는 **CRDT(예: PN-Counter)**나 **단일 writer**로 가야 한다. "충돌은 LWW로 처리"만 답하면 시니어 기준 미달.

## 4. 데이터 파티셔닝 — home region과 geo-partitioning

충돌을 원천 차단하는 상위 전략은 **각 데이터에 "고향 리전"을 부여**하는 것이다.

- **User home region**: 사용자 A의 데이터는 A가 속한 리전이 쓰기를 소유. 다른 리전은 읽기 복제본만. → 사용자별 충돌 없음.
- **Geo-partitioning**: 데이터를 지역 기준으로 분할 저장. 유럽 사용자 데이터는 유럽 리전에만(GDPR 충족). CockroachDB·Spanner가 row 단위 `locality`를 지정.

```mermaid
stateDiagram-v2
    [*] --> AsiaHome: 아시아 사용자 가입
    AsiaHome --> AsiaWrite: 쓰기는 아시아 리전
    AsiaWrite --> UsRead: 미주에서 읽기(복제본)
    UsRead --> AsiaWrite: 쓰기는 다시 home으로 라우팅
    AsiaWrite --> Failover: home 리전 장애
    Failover --> Reassign: 임시 home 재지정(승격)
    Reassign --> AsiaWrite: 복구 후 원복
```

*User home region — 쓰기는 항상 home 리전으로, 원격 리전은 읽기 복제본. 장애 시에만 home을 재지정.*

> **💡 가상 사례 — 글로벌 커머스의 지역 분리**
>
> 지역별 데이터·재고를 분리하고 리전 간에는 카탈로그처럼 최종 일관성으로 충분한 데이터를 비동기 복제한다고 가정할 수 있다. 재고·결제처럼 강한 일관성이 필요한 데이터의 쓰기 리전을 어디에 둘지는 규제·계약·복구 목표로 정하며 특정 회사의 운영 방식으로 단정하지 않는다.

## 5. 페일오버 — RTO/RPO와 라우팅

리전 장애 시 트래픽을 다른 리전으로 넘기는 것이 페일오버다. 두 지표로 목표를 정량화한다.

- **RTO(Recovery Time Objective, 복구 목표 시간)**: 장애 후 서비스 재개까지 허용 시간. (예: 5분)
- **RPO(Recovery Point Objective, 복구 목표 지점)**: 허용 가능한 데이터 손실 범위. 비동기 복제면 **RPO ≈ replication lag**.

```mermaid
flowchart LR
    U(["🌏 사용자"]) --> DNS["GSLB / DNS\n(Route53 health check)"]
    DNS -->|"정상"| RA["Region A (primary)"]
    DNS -.->|"health 실패 시\nTTL 후 전환"| RB["Region B (promote)"]
    RA -->|"비동기 복제 (lag = RPO)"| RB

    style RA fill:#dcfce7,stroke:#22c55e,color:#14532d
    style RB fill:#fef3c7,stroke:#f59e0b,color:#78350f
    style DNS fill:#dbeafe,stroke:#3b82f6,color:#1e3a8a
```

*GSLB/DNS health check가 리전 장애를 감지하고 트래픽을 승격 리전으로 전환. 전환 지연에 DNS TTL이 더해진다.*

### 글로벌 트랜잭션·복제 기술 비교

| 기술 | 일관성 | 복제 | 페일오버 특성 | 대가 |
| --- | --- | --- | --- | --- |
| **Google Spanner** | 외부 일관성(strong) | Paxos quorum + **TrueTime** | 동기 quorum 가정에서 RPO ≈ 0 | 쓰기 지연↑·GPS/원자시계 인프라 |
| **DynamoDB Global Tables (MREC)** | 기본 eventual·동시 쓰기 LWW | 멀티 리전 Active-Active 비동기 | RPO는 복제 지연·장애 시점에 의존 | 충돌 시 LWW 손실 가능 |
| **DynamoDB Global Tables (MRSC)** | 다중 리전 strong, 정확히 3개 리전 구성 | 다중 리전 동기 일관성 모델 | 가용성·지연·구성 제약을 현재 문서로 확인 | MREC와 보장·비용이 다름 |
| **Aurora Global Database** | 리전 내 strong, 리전 간 async | 스토리지 레벨 비동기 | RPO/RTO는 엔진·리전·복구 구성과 테스트 결과에 의존 | 승격 시간·읽기 전용 secondary |

> **⚠️ 실무 함정 — DNS 페일오버의 split-brain과 TTL**
>
> ① **DNS TTL**: 클라이언트·중간 리졸버가 이전 IP를 TTL 동안 캐시 → TTL이 300초면 전환에 최대 5분 지연(RTO 악화). 그래서 짧은 TTL + health check를 쓰지만 너무 짧으면 DNS 부하. ② **Split-brain(분단 뇌)**: 네트워크 분단으로 두 리전이 서로 상대가 죽은 줄 알고 **둘 다 primary로 승격**하면 양쪽에 쓰기가 갈려 데이터가 갈라진다. 방어: 외부 합의(quorum/witness), fencing token, 자동 승격에 사람 확인 게이트. "health check 실패하면 자동 승격"만 답하면 split-brain을 지적당한다.

> **🎯 면접 포인트 — RPO는 비동기 복제에서 0이 될 수 없다**
>
> 비동기 복제는 원리상 "primary에 커밋됐지만 아직 secondary에 안 넘어간 데이터"가 존재한다. primary가 그 순간 죽으면 그 데이터는 **소실**된다 — RPO > 0은 필연. RPO를 0으로 만들려면 동기 복제(Spanner식 quorum)가 필요하고, 그 대가는 쓰기 지연이다. 이 **RPO-지연 트레이드오프**를 명확히 말하는 게 시니어 시그널.

## 6. 심화 함정 — 물류 도메인 재해석

> **💡 물류 도메인 — "글로벌 풀필먼트 재고의 리전 간 정합성"**
>
> 글로벌 이커머스는 한국·미국·유럽 `FC(Fulfillment Center, 풀필먼트 센터)`의 재고를 각 리전 DB로 관리한다. 여기서 멀티리전 일관성이 곧 돈이다. • **재고 차감은 절대 LWW 금지** — 위 재고 예시처럼 동시 주문이 조용히 소실되면 **oversell(초과 판매)**이나 재고 유령이 생긴다. FC별 재고는 **단일 writer 리전(home = 그 FC의 리전)**에 가두고 강한 일관성으로 차감한다. • 리전 간에는 **"판매 가능 수량(ATP, Available To Promise)" 요약만 최종 일관성**으로 복제 — 다른 리전 고객에게 "재고 있음"을 보여주되, 실제 차감(확정)은 home 리전 트랜잭션으로. • 리전 장애로 페일오버할 때 lag만큼의 **미복제 주문**은 RPO 손실 후보 → **Outbox + 멱등(idempotent) 재처리**로 복구 시 재적용, 또는 결제 확정 전까지 재고를 **soft-reserve**만 걸어 손실 시 자동 해제. 물류에선 RPO 1건이 실제 배송사고이므로, 재고·주문 확정 경로만 동기 quorum(비용 감수), 조회·추천은 비동기로 나누는 **경로별 일관성 차등**이 정답에 가깝다.

```mermaid
flowchart LR
    subgraph KR["🇰🇷 Region KR (home for KR FC)"]
      KRDB[("재고 DB\nstrong")]
    end
    subgraph US["🇺🇸 Region US (home for US FC)"]
      USDB[("재고 DB\nstrong")]
    end
    KRDB -.->|"ATP 요약만\n최종 일관성 복제"| USDB
    USDB -.->|"ATP 요약만\n최종 일관성 복제"| KRDB
    ORD(["글로벌 주문"]) -->|"차감은 home 리전 트랜잭션"| KRDB
    ORD --> USDB

    style KRDB fill:#dcfce7,stroke:#22c55e,color:#14532d
    style USDB fill:#dcfce7,stroke:#22c55e,color:#14532d
```

*FC 재고 차감은 home 리전 strong consistency로, 리전 간에는 판매 가능 수량(ATP) 요약만 최종 일관성으로 복제.*

```sql
-- home 리전 내부: 재고 차감은 조건부 UPDATE로 원자적·oversell 방지
UPDATE inventory
   SET available = available - :qty,
       version   = version + 1
 WHERE fc_id = :fcId
   AND sku    = :sku
   AND available >= :qty;   -- 0행이면 재고 부족 → 주문 거절 (조용한 음수 금지)

-- 페일오버 복구 시 Outbox 이벤트를 멱등키로 재적용 (중복 차감 방지)
INSERT INTO applied_events (event_id) VALUES (:eventId)
ON CONFLICT (event_id) DO NOTHING;   -- 이미 적용됐으면 skip
```

### 확인 질문 3개

1. 리전 간 RTT 150ms 환경에서 결제 트랜잭션에 strong consistency가 필요하다면, 지연을 감수하고 동기 quorum(Spanner식)을 쓸지 vs 단일 리전에 가둘지 어떻게 결정하겠는가?
2. Active-Active에서 "좋아요 수 카운터"와 "계좌 잔액"은 충돌 해결 전략이 달라야 한다. 각각 무엇을 쓰고 왜 그런가? (힌트: CRDT vs 단일 writer)
3. DNS TTL 300초 + 비동기 복제 lag 2초인 시스템의 실질 RTO와 RPO는 각각 얼마인가? 이를 각각 절반으로 줄이려면 무엇을 바꿔야 하고, 그 대가는?

> **🎯 마무리 한 줄 (면접 클로징)**
>
> "멀티리전은 지연·가용성·규제 중 지배 동인을 먼저 정하고, **리전 내부는 동기·리전 간은 비동기**를 기본으로 합니다. 충돌은 데이터 성격별로 갈라 — 카운터는 CRDT, 잔액·재고는 **단일 writer home region + strong consistency**로 가두고, 조회성은 최종 일관성으로 복제합니다. 페일오버는 **RTO/RPO를 정량 목표로** 잡고 split-brain을 fencing/quorum으로 막으며, 무엇보다 평소에 리전 장애를 훈련합니다." — 경로별 일관성 차등과 RTO/RPO 정량화를 한 호흡에 말하면 시니어 합격 시그널.

## 검수 경계와 실패 흐름

- RPO는 제품 표의 고정값이 아니라 replication mode·lag·장애 시점을 포함한 계약이다. sync quorum과 async replica를 같은 행에서 섞지 않는다.
- Active-Active 충돌은 LWW·CRDT·home-region single writer 중 데이터 불변식에 맞게 선택하고, 재고·잔액의 차감 손실을 merge 정책으로 숨기지 않는다.
- DNS TTL·resolver cache·기존 connection이 RTO에 더해지고, 양쪽 리전이 writer가 되는 split-brain은 fencing/quorum으로 차단한다.
- 장애 전환 뒤 미복제 주문·예약을 outbox·멱등 재처리·대사로 수렴시키며, 복구 훈련에서 RTO/RPO·p95/p99를 실제 측정한다.

## 공식·1차 출처

- [https://cloud.google.com/spanner/docs/true-time-external-consistency](https://cloud.google.com/spanner/docs/true-time-external-consistency)
- [https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/V2globaltables_HowItWorks.html](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/V2globaltables_HowItWorks.html)
- [https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database.html](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database.html)
- [https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-failover.html](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-failover.html)$review_23_system_design_14_multi_region$
WHERE slug = 'system-design-14-multi-region' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_system_design_15_interview_framework$> **검수 경계** — 45분·시간 배분·QPS와 면접 평가 축은 학습용 프레임이다. 특정 회사 면접의 공통 채점 기준으로 단정하지 않는다.

## 0. 이 카드의 목적 — 문제 20개보다 프레임워크 1개

시스템 디자인 면접에서는 지식뿐 아니라 제한된 시간 안에 범위를 좁히고 근거를 제시하는 능력도 평가될 수 있다. Kafka도 알고 Redis도 아는데, 45분 뒤 화이트보드에는 정당화 없는 박스만 잔뜩 그려져 있다. 면접관이 보는 것은 정답 아키텍처가 아니라 **모호한 문제를 구조화하는 능력·trade-off를 언어화하는 능력·압박에 무너지지 않는 태도**다.

> **🎯 면접 포인트 — 면접관의 채점 기준**
>
> 여러 시스템 디자인 면접에서 **요구사항 파악 / 용량 추정 / 아키텍처 합리성 / Deep-dive 깊이 / Trade-off 설명 / 커뮤니케이션**을 평가할 수 있지만, 회사별 루브릭·시간·질문은 다르다. 이 카드는 45분을 가정한 교육용 진행 프레임이다.

## 1. 45분 타임라인 — 시간을 지배하라

```mermaid
flowchart LR
    S(["면접 시작"]) --> R["1. 요구사항 명확화<br/>5~10분"]
    R --> E["2. 용량 추정<br/>5분"]
    E --> A["3. API / 데이터 모델<br/>5분"]
    A --> H["4. High-level 아키텍처<br/>10분"]
    H --> D["5. Deep-dive<br/>15분"]
    D --> C["6. 마무리 · Trade-off<br/>5분"]
    C --> F(["종료"])

    style R fill:#dbeafe,stroke:#3b82f6,color:#1e3a8a
    style E fill:#e0e7ff,stroke:#6366f1,color:#312e81
    style A fill:#ede9fe,stroke:#8b5cf6,color:#4c1d95
    style H fill:#fef3c7,stroke:#f59e0b,color:#78350f
    style D fill:#fee2e2,stroke:#ef4444,color:#7f1d1d
    style C fill:#dcfce7,stroke:#22c55e,color:#14532d
```

*45분 배분. Deep-dive(15분)가 변별력의 핵심 구간이다. 앞단계를 질질 끌면 Deep-dive를 못 가고 "박스만 그리다 끝난" 인상을 남긴다.*

| 단계 | 시간 | 이 단계에서 면접관이 확인하는 것 | 흔한 실패 |
| --- | --- | --- | --- |
| 요구사항 명확화 | 5~10분 | scope를 좁히는가, 무엇을 안 만들지 정하는가 | 질문 없이 바로 그림 |
| 용량 추정 | 5분 | 숫자를 만들고 그 숫자로 결정하는가 | 계산 없이 "많이 옵니다" |
| API / 데이터 모델 | 5분 | 핵심 엔티티·접근 패턴을 잡는가 | 필드 나열에 시간 낭비 |
| High-level | 10분 | 컴포넌트 간 데이터 흐름이 말이 되는가 | 정당화 없는 기술 나열 |
| Deep-dive | 15분 | 병목·일관성·장애를 끝까지 파는가 | 얕게 훑고 다음으로 도망 |
| 마무리 | 5분 | trade-off를 스스로 요약하는가 | 시간 초과로 도달 못 함 |

> **💡 팁 — 시간 배분을 입으로 선언하라**
>
> 시작할 때 "요구사항 5분, 추정 5분 잡고 아키텍처와 deep-dive에 시간을 많이 쓰겠습니다"라고 말하면 그 자체로 **시간 관리 능력**을 보여주는 신호다. 면접관은 "이 사람은 45분을 스스로 운영하는구나"라고 첫인상을 잡는다.

## 2. 단계별 진행법 + 압박 후속 질문 대응

면접관의 후속 질문은 랜덤이 아니다. 각 단계마다 **"네가 지금 한 결정을 정말 이해하고 했냐"**를 찌르는 정형화된 압박이 있다. 미리 알면 방어할 수 있다.

### 2-1. 요구사항 명확화 (5~10분)

무엇을 만들고 무엇을 **안** 만들지부터 합의한다. Functional(기능)과 Non-functional(비기능: 가용성·일관성·지연·처리량·저장량)을 나눠 묻는다.

> **⚠️ 실무 함정 — "일단 그리기" 유혹**
>
> 문제를 듣자마자 손이 화이트보드로 가는 것이 가장 흔한 탈락 신호다. "URL 단축기 설계하세요"에 바로 hash 함수를 그리는 순간, 면접관은 "custom alias 지원 여부? 만료? 분석 기능?"을 묻고 지원자는 이미 그린 그림을 지운다. **5분의 질문이 40분의 방향을 정한다.**

압박 후속과 대응:

- 면접관: "이 시스템의 **핵심 유스케이스 하나만** 꼽으면?" → 모범: scope를 좁혀 "쓰기보다 읽기가 100:1인 조회 중심 시스템"처럼 성격을 한 문장으로 규정. 이 규정이 뒤의 캐시·복제 결정을 정당화한다.
- 면접관: "가용성과 일관성 중 뭐가 더 중요한가요?" → 모범: 도메인으로 답한다. "송금은 강한 일관성(Strong Consistency), 배송 위치 표시는 최종 일관성(Eventual Consistency, 최종 일관성)으로 지연 몇 초를 허용" — CAP(Consistency, Availability, Partition tolerance) 이론을 도메인에 접지.

### 2-2. 용량 추정 (5분)

DAU(Daily Active Users, 일간 활성 사용자) → QPS(Queries Per Second, 초당 쿼리 수) → 저장량 → 대역폭. 반드시 **계산 과정을 입으로** 말한다.

```text
전제: DAU 1억, 사용자당 하루 평균 조회 10회
1 day ≈ 10^5 초 (정확히 86,400s)

평균 QPS = (1억 × 10) / 10^5 = 10^9 / 10^5 = 10,000 QPS
피크 QPS = 평균 × 5~10배 ≈ 50,000 ~ 100,000 QPS

저장량(가정: 레코드당 300B, 하루 10억 write)
= 10^9 × 300B = 3 × 10^11 B ≈ 300 GB/day → 1년 ≈ 100 TB
```

> **🎯 면접 포인트 — 추정은 설계의 근거가 되어야 한다**
>
> 숫자를 계산만 하고 버리면 의미 없다. "피크 10만 QPS → 단일 DB로 불가 → 읽기 복제 + 캐시로 읽기를 흡수, 쓰기는 샤딩"처럼 **추정 → 아키텍처 결정으로 즉시 연결**해야 한다. 면접관이 "그 숫자로 무엇을 결정했나요?"라고 물었을 때 답이 없으면 계산은 장식이었던 것.

압박 후속: 면접관 "**트래픽이 10배가 되면** 어디가 먼저 터지나요?" → 모범 4단 구성: ① 병목 지목("단일 write DB") ② 문제에서 정한 QPS와 benchmark를 근거로 한계 초과를 계산 ③ 완화책("샤딩 키를 user_id로, 논리 샤드 N개") ④ **새 trade-off**("대신 cross-shard 조인 불가, 분산 트랜잭션 필요 → Saga로 회피"). "오토스케일 하면 됩니다"는 ②③④가 통째로 빠져 감점이다.

### 2-3. API / 데이터 모델 (5분)

REST vs gRPC를 접근 패턴으로 정하고, 핵심 엔티티와 **주요 인덱스**를 잡는다. 필드를 전부 나열하지 말고 접근 패턴(어떤 쿼리가 뜨거운가)에 집중한다.

### 2-4. High-level 아키텍처 (10분)

LB(Load Balancer) → App → Cache → DB에 Queue·CDN·Search를 필요한 만큼 배치. **각 박스를 그릴 때마다 "왜 여기 있는지" 한 문장**을 붙인다.

```mermaid
flowchart LR
    C(["Client"]) --> LB["Load Balancer"]
    LB --> APP["App 서버<br/>(Stateless)"]
    APP --> CACHE[("Redis<br/>Cache-aside")]
    APP --> DB[("Primary DB<br/>+ Read Replica")]
    APP --> MQ["Message Queue<br/>(비동기 처리)"]
    MQ --> WORKER["Worker"]
    WORKER --> DB

    style LB fill:#dbeafe,stroke:#3b82f6,color:#1e3a8a
    style CACHE fill:#fce7f3,stroke:#ec4899,color:#831843
    style DB fill:#dcfce7,stroke:#22c55e,color:#14532d
    style MQ fill:#fef3c7,stroke:#f59e0b,color:#78350f
```

*High-level 기본형. 각 컴포넌트마다 존재 이유를 말로 정당화해야 "기술 나열"에서 벗어난다.*

압박 후속: 면접관 "**왜 Kafka인가요? SQS는 안 되나요?**" → 모범: 요구사항으로 가른다. "**재생(replay)·다중 컨슈머·순서 보장·높은 처리량**이 필요하면 Kafka(로그 기반, 파티션 순서). 단순 작업 큐이고 운영 부담을 줄이고 싶으면 SQS(완전관리형). 지금은 이벤트를 여러 소비자가 각자 처리하고 재생이 필요하므로 Kafka." — "Kafka가 좋으니까요"는 즉시 반격당한다.

### 2-5. Deep-dive (15분) — 변별력의 심장

면접관이 한 컴포넌트를 콕 집어 "여기를 더 파봅시다"라고 한다. 병목(Hotspot)·일관성·장애 전파(Cascading failure)·데이터 파이프라인 중 하나로 깊이 들어간다.

```mermaid
flowchart TD
    Q(["면접관의 압박 질문"]) --> T{"질문 유형?"}
    T -->|"확장성"| SC["병목 지목 → 샤딩/복제<br/>→ 새 trade-off 언급"]
    T -->|"장애"| FL["SPOF 인정 → 다중화<br/>→ circuit breaker / fail-open"]
    T -->|"일관성"| CO["Strong vs Eventual 선택<br/>→ 도메인 근거로 정당화"]
    T -->|"캐시 죽으면?"| CA["thundering herd 인정<br/>→ TTL 지터 / 요청 병합"]
    T -->|"모르는 영역"| HN["가정 명시 → 아는 원리로 추론<br/>→ '검증하려면 X를 재보겠다'"]

    SC --> G(["시니어 신호"])
    FL --> G
    CO --> G
    CA --> G
    HN --> G

    style Q fill:#fee2e2,stroke:#ef4444,color:#7f1d1d
    style G fill:#dcfce7,stroke:#22c55e,color:#14532d
    style HN fill:#e0e7ff,stroke:#6366f1,color:#312e81
```

*압박 질문 분기 대응. 핵심은 "모르는 영역"조차 가정을 명시하고 원리로 추론하는 것 — 침묵이나 얼버무림만 피하면 된다.*

압박 후속: 면접관 "**그 캐시가 죽으면** 어떻게 되나요?" → 모범: ① 즉시 문제 인정("모든 읽기가 DB로 몰리는 **thundering herd(쇄도)**, DB가 2차로 죽는 cascading failure") ② 완화("TTL(Time To Live)에 지터를 줘 동시 만료 분산, 동일 키 요청은 **request coalescing**으로 1건만 DB로, cache warming") ③ 근거("현재 캐시 히트율 95% 가정 시 miss가 5%→100%면 DB 부하 20배"). 숫자로 규모를 잡으면 시니어 신호.

> **⚠️ 실무 함정 — Deep-dive에서 도망치기**
>
> 면접관이 깊이 파려 하는데 "그 부분은 이렇게 하면 되고요, 다음으로 넘어가서..."로 **주제를 바꾸는 것**이 미들과 시니어를 가르는 결정적 순간이다. 면접관은 일부러 한 곳을 깊이 판다. 여기서 "더 파고들 수 있다"를 보여주지 못하면 지식의 깊이가 없다고 판단한다. **한 주제를 3~4겹까지 파는 연습**을 해야 한다.

### 2-6. 마무리 (5분)

스스로 trade-off를 요약한다. "기본 설계는 A, 대안은 B(이럴 땐 B가 낫다), 남은 리스크는 C" 3문장이면 충분하다. 관측성(Observability: Metric·Log·Trace)과 비용을 한 줄씩 얹으면 완성도가 올라간다.

## 3. 흔한 탈락 패턴 — 자기 진단 체크리스트

| 탈락 패턴 | 무엇이 문제인가 | 어떻게 고치나 |
| --- | --- | --- |
| **요구사항 생략** | 5분 질문 없이 바로 그림 → scope 폭주 | 반드시 Functional/Non-functional 나눠 5분 확보 |
| **정당화 없는 기술 나열** | "Kafka, Redis, Cassandra 씁니다" 나열만 | 박스마다 "왜"를 한 문장씩 |
| **숫자 없는 주장** | "트래픽 많으니 확장해야죠" | DAU→QPS→저장량 계산을 입으로 |
| **면접관 힌트 무시** | 힌트를 흘려듣고 하던 것 계속 | 힌트는 "이쪽을 보라"는 신호 — 즉시 방향 전환 |
| **Deep-dive 회피** | 파려 하면 주제 변경 | 한 주제 3~4겹 파는 연습 |
| **시간 관리 실패** | 앞에서 20분 써 Deep-dive 못 감 | 타임박스 선언 + 스스로 컷 |

> **💡 팁 — 면접관 힌트는 감점이 아니라 구조 신호**
>
> "혹시 이 부분에서 데이터가 급증하면요?" 같은 질문은 비난이 아니라 **"여길 파면 점수를 준다"는 안내**다. 힌트가 나오면 감점당한 게 아니라 오히려 기회다. 힌트를 무시하고 원래 하려던 말을 계속하는 것이야말로 커뮤니케이션 감점. 힌트가 나오면 "좋은 지적입니다, 그 시나리오를 보면..."으로 즉시 올라타라.

## 4. 레벨별 평가 루브릭 — 같은 문제, 다른 깊이

같은 "배송 추적 시스템"을 줘도 레벨에 따라 발화가 갈린다. 자신이 지금 어느 칸에 있는지 진단하라.

| 단계 | 주니어 | 미들 | 시니어 |
| --- | --- | --- | --- |
| 요구사항 | 바로 그림부터 | 기능 요구는 물음 | 비기능(가용성·일관성 목표)을 숫자로 고정 |
| 추정 | 생략 | 대략 계산 | 추정을 아키텍처 결정 근거로 직결 |
| 아키텍처 | 단일 서버 | LB+DB+Cache 표준형 | 각 선택의 trade-off를 스스로 언급 |
| Deep-dive | 얕게 훑음 | 한 겹 파고 멈춤 | 병목→완화→새 trade-off까지 3~4겹 |
| 장애 | 고려 안 함 | SPOF 지목 | cascading·retry storm·fail-open 정책까지 |
| 커뮤니케이션 | 침묵/독백 | 설명은 함 | 면접관과 협업하듯 가정을 합의하며 진행 |

> **🎯 면접 포인트 — 시니어의 결정적 차이는 "trade-off의 자발성"**
>
> 미들은 면접관이 물어야 trade-off를 답한다. 시니어는 **묻기 전에 스스로** "이 선택의 단점은 X인데, 대안 Y는 이럴 때 낫습니다"를 말한다. 회사별 합격선은 공개 루브릭으로 확정할 수 없으므로, 정답 암기보다 **자기 결정의 반대편 trade-off를 스스로 설명하는 능력**을 연습한다.

## 5. 모의 면접 시나리오 — "배송 추적 시스템을 설계하세요"

물류 도메인으로 45분이 실제로 어떻게 흐르는지 문답으로 본다.

```mermaid
sequenceDiagram
    participant I as 면접관
    participant C as 지원자

    I->>C: "배송 추적(Delivery Tracking) 시스템을 설계하세요"
    C->>I: "범위 확인 — 실시간 위치 표시가 핵심인가요, 상태 변경 이력이 핵심인가요?"
    I->>C: "둘 다지만 사용자가 보는 건 현재 위치 + 상태 타임라인"
    C->>I: "쓰기:읽기 비율은요? 기사 위치는 몇 초마다 갱신?"
    I->>C: "기사 100만 명, 10초마다 위치 전송, 고객 조회는 그보다 잦음"

    Note over C: 용량 추정
    C->>I: "위치 write = 100만/10s = 10만 QPS. 조회는 그 수배 → 읽기 중심"
    C->>I: "위치는 최종 일관성 허용(몇 초 지연 OK), 배송완료 같은 상태는 강한 일관성"

    Note over C: High-level
    C->>I: "기사 위치는 시계열(time-series) 성격 → 최신 위치는 Redis, 이력은 Cassandra"
    C->>I: "상태 전이는 이벤트로 Kafka에 싣고, 고객 푸시는 컨슈머가 fan-out"

    I->>C: "트래픽 10배, 위치 write 100만 QPS면 어디가 터지나요?"
    C->>I: "위치 저장소. driver_id로 샤딩, 최신 위치는 Redis라 write가 곧 덮어쓰기 → 저장량은 일정"
    C->>I: "대신 이력 Cassandra는 hot partition 위험 → 파티션 키에 시간 버킷 추가"

    I->>C: "고객 푸시를 보내는 Kafka 컨슈머가 죽으면요?"
    C->>I: "consumer group이 리밸런싱, offset부터 재개 → 재처리는 idempotent consumer로 중복 제거"
    C->>I: "정리하면: 최신위치 Redis + 이력 Cassandra + 상태 Kafka, 위치는 eventual·완료는 strong 일관성"

    I->>C: "좋습니다. 관측성은요?"
    C->>I: "위치 지연을 p99로 추적, 분산 추적(Distributed tracing)으로 전송→표시 경로 계측"
```

*문답 흐름. 지원자가 그림보다 **질문·숫자·trade-off**를 먼저 던지는 리듬에 주목. 면접관의 압박마다 "지목→근거→완화→새 trade-off" 4단으로 응수한다.*

> **💡 팁 — 이 카드로 연습하는 법**
>
> `/interview <주제>`로 코치를 면접관 삼아 45분 타이머를 걸고 위 리듬을 재현하라. 끝나면 6축(요구사항·추정·아키텍처·Deep-dive·Trade-off·커뮤니케이션)을 각 5점으로 자가 채점하고, 4번 루브릭에서 자신이 어느 칸이었는지 표시하라. 관련 케이스는 `system-design-08~10`(Rate Limiter·URL Shortener·배송 추적)으로 이어서 손에 익힌다.

## 검수 경계와 실패 흐름

- 45분의 순서는 요구사항·추정·설계·deep-dive·failure mode·trade-off를 모두 관찰하기 위한 교육용 프레임이며 회사별 루브릭으로 일반화하지 않는다.
- 지원자가 평균 QPS나 단일 SLA 숫자를 먼저 단정하면 측정 창·분모·peak factor·공통 장애 도메인을 되묻고, 가정이 바뀔 때 설계를 갱신하는지 본다.
- 압박 질문은 retry storm·cache miss 폭주·partial failure·out-of-order event처럼 앞선 가정을 깨는 방식으로 만들고, 지원자가 fallback의 정확성·보안·비용까지 설명하게 한다.
- 마지막에는 선택한 SLO와 error budget, 남은 unknown, 검증할 부하 테스트와 장애 훈련을 명시하게 하여 말솜씨와 운영 가능한 설계를 구분한다.

## 공식·1차 출처

- [https://sre.google/sre-book/service-level-objectives/](https://sre.google/sre-book/service-level-objectives/)
- [https://sre.google/sre-book/handling-overload/](https://sre.google/sre-book/handling-overload/)
- [https://aws.amazon.com/architecture/well-architected/](https://aws.amazon.com/architecture/well-architected/)$review_23_system_design_15_interview_framework$
WHERE slug = 'system-design-15-interview-framework' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_system_design_16_lsm_vs_btree$> **검수 경계** — 쓰기량·조회 비율·증폭 수치는 가상 워크로드다. 엔진 구현·압축·SSD·compaction 정책에 따라 벤치마크 결과가 달라진다.

## 1. 저장 엔진 선택은 증폭 비용 선택이다

`B+Tree`는 정렬된 페이지를 제자리 갱신하고, `LSM-Tree(Log-Structured Merge-Tree, 로그 구조 병합 트리)`는 쓰기를 메모리와 순차 파일에 모은 뒤 백그라운드에서 합친다. “LSM은 쓰기가 빠르고 B+Tree는 읽기가 빠르다”는 출발점일 뿐이다. 운영에서는 사용자 I/O 한 번이 내부적으로 몇 번의 I/O와 몇 바이트의 저장 공간을 만드는지 봐야 한다.

| 비용 | 의미 | LSM-Tree | B+Tree |
|---|---|---|---|
| Read Amplification | 한 번 읽기 위해 확인하는 구조 수 | 여러 SSTable·레벨을 확인할 수 있음 | 보통 루트→리프 페이지 경로 |
| Write Amplification | 논리 쓰기 1바이트당 실제 쓰기 바이트 | WAL·Flush·반복 Compaction | WAL·데이터 페이지·페이지 분할 |
| Space Amplification | 최신 논리 데이터보다 더 쓰는 공간 | 중복 버전·삭제 Tombstone이 병합 전까지 존재 | 페이지 여유 공간·오래된 버전 |

```mermaid
flowchart LR
    subgraph LSM["LSM-Tree 쓰기·읽기 경로"]
        W[Write] --> WAL[WAL]
        W --> MEM[MemTable]
        MEM -->|Flush| L0[L0 SSTables]
        L0 -->|Compaction| LN[L1..Ln SSTables]
        R[Read] --> MEM
        R --> BF[Bloom Filter]
        BF --> L0
        BF --> LN
    end
    subgraph BT["B+Tree 경로"]
        BW[Write] --> BWAL[WAL]
        BW --> ROOT[Root]
        ROOT --> LEAF[Leaf Page]
        LEAF -->|가득 참| SPLIT[Page Split]
        BR[Read] --> ROOT
    end
```

## 2. LSM-Tree의 실제 경로

쓰기는 먼저 WAL(Write-Ahead Log, 선행 기록 로그)에 남고 정렬된 MemTable에 들어간다. MemTable이 차면 불변 구조로 전환한 뒤 SSTable(Sorted String Table)로 순차 Flush한다. 읽기는 MemTable과 여러 SSTable 후보를 확인하므로 Bloom Filter와 블록 인덱스가 불필요한 디스크 접근을 줄인다.

Compaction은 중복 버전과 Tombstone을 제거하지만 데이터를 다시 읽고 쓴다. Leveled Compaction은 읽기·공간 증폭을 낮추는 대신 쓰기 증폭이 커지기 쉽고, Tiered/Universal Compaction은 쓰기를 덜 합치는 대신 읽기·공간 비용과 I/O 변동성이 커진다.

```text
관측해야 할 최소 지표
- flush bytes/sec, compaction read/write bytes/sec
- L0 file count와 compaction pending bytes
- block-cache hit ratio, Bloom useful/false-positive 비율
- foreground write stall 시간, read p95/p99 latency
```

> **실무 함정** — 평균 쓰기 처리량이 충분해도 Compaction이 밀리면 L0 파일이 쌓여 쓰기 Stall과 읽기 p99가 함께 튄다. 부하 시험은 유입 구간뿐 아니라 Compaction이 정상 상태로 수렴하는 시간까지 지속해야 한다.

## 3. 언제 무엇을 선택하는가

- Append 중심 이벤트·시계열·대규모 KV 적재처럼 쓰기량이 크고 범위별 데이터 수명이 분명하면 LSM-Tree가 유리하다.
- 짧은 포인트 조회, 강한 범위 스캔 예측성, 빈번한 제자리 갱신이 중요하면 B+Tree가 단순한 선택일 수 있다.
- 엔진 이름보다 키 분포, 캐시 크기, 압축 전략, SSD IOPS, 읽기/쓰기 비율을 같은 데이터로 측정한다.

> **면접 포인트** — “쓰기 많으니 LSM”에서 멈추지 말고, Compaction 예산을 별도 I/O로 확보하고 쓰기 Stall·Tombstone·복구 시간까지 운영 설계에 포함해야 시니어 답변이 된다.

## 참고

- [RocksDB Compaction](https://github.com/facebook/rocksdb/wiki/Compaction)
- [RocksDB Universal Compaction](https://github.com/facebook/rocksdb/wiki/Universal-Compaction)

## 검수 경계와 실패 흐름

- L0 file 수·pending compaction bytes·compaction debt가 증가하면 read p99와 write stall이 함께 악화되는지 관측하고, compaction이 ingest를 따라잡지 못할 때 rate limit·retention·storage tier를 조정한다.
- Bloom filter false positive는 추가 block/SSTable read를 만들 뿐 false negative로 정답을 놓치는 경로가 아니다. bits-per-key와 메모리·I/O 비용을 함께 benchmark한다.
- tombstone이 compaction 전까지 남아 오래된 값이 읽히는 것처럼 보이지 않는지, snapshot/WAL recovery 뒤 삭제 불변식이 유지되는지 검증한다.
- B+Tree page split과 LSM flush/compaction의 write amplification을 SSD write budget·GC·복제 I/O와 함께 측정하고, 평균이 아닌 p95/p99와 stall time으로 선택을 재검증한다.

## 공식·1차 출처

- [https://github.com/facebook/rocksdb/wiki/Compaction](https://github.com/facebook/rocksdb/wiki/Compaction)
- [https://github.com/facebook/rocksdb/wiki/RocksDB-Bloom-Filter](https://github.com/facebook/rocksdb/wiki/RocksDB-Bloom-Filter)
- [https://www.postgresql.org/docs/current/indexes.html](https://www.postgresql.org/docs/current/indexes.html)$review_23_system_design_16_lsm_vs_btree$
WHERE slug = 'system-design-16-lsm-vs-btree' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_system_design_19_cdn_origin_shield$> **검수 경계** — Origin Shield·TTL·purge·캐시 키의 효과는 CDN 제품과 트래픽 분포에 따라 달라진다.

## 1. 캐시를 계층으로 본다

엣지 노드는 사용자와 가깝지만 모든 미스를 원본으로 보내면 인기 객체 만료 순간에 원본이 무너진다. 여러 엣지의 미스를 중간 Shield가 합치면 원본 요청 수를 줄일 수 있다.

```mermaid
flowchart LR
    U[사용자] --> E1[Edge POP]
    E1 --> S[Origin Shield]
    S --> O[Origin]
    E2[다른 Edge POP] --> S
```

| 결정 | 이점 | 위험 |
|---|---|---|
| 긴 TTL | 높은 적중률 | 오래된 응답 |
| Shield | 원본 보호·요청 병합 | 중앙 병목·지역 간 지연 |
| 버전 URL | 즉시 안전한 교체 | URL 생성 규칙 필요 |
| Purge | 같은 URL을 빠르게 갱신 | 전파 지연·운영 복잡성 |

```text
cache_key = scheme + host + path + normalized_query + selected_headers
freshness  = max_age - current_age
```

> **실무 함정** — 사용자 쿠키 전체를 키에 넣으면 객체가 사용자별로 쪼개져 CDN이 사실상 우회된다. 응답을 바꾸는 최소 차원만 명시한다.

## 2. 실패와 관측

미스율만 보지 말고 Shield 적중률, 원본 요청률, Purge 전파 시간, 오래된 응답 제공량을 함께 본다. 원본 장애 때 `stale-if-error`를 허용할 데이터와 절대 허용하지 않을 데이터를 분류한다.

> **면접 포인트** — CDN 도입으로 끝내지 말고 캐시 키, 일관성 요구, Hot Key와 원본 보호까지 요청 경로 전체를 설명한다.

## 검수 경계와 실패 흐름

- 수치와 임계값은 요구사항으로 선언하고 실제 workload·부하 테스트·관측 지표로 검증한다. 제품·기업의 내부 구현을 근거 없이 일반화하지 않는다.
- 쓰기 성공 후 이벤트/읽기 모델 갱신 실패, 응답 유실 후 재시도, 중복·순서 역전·부분 장애를 정상적인 실패 경로로 모델링한다.
- 원장과 캐시·검색·알림·분석 파생 모델의 상태를 구분하고, 멱등 키·버전·재처리 큐·대사 작업으로 수렴시킨다.
- 성능 최적화는 평균이 아니라 p95/p99, 버스트와 복구 중 부하를 함께 본다. fallback을 추가할 때 정확성·보안·개인정보·비용 trade-off를 기록한다.

## 공식·1차 출처

- [https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/origin-shield.html](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/origin-shield.html)
- [https://developers.cloudflare.com/cache/concepts/cache-behavior/](https://developers.cloudflare.com/cache/concepts/cache-behavior/)
- [https://www.rfc-editor.org/rfc/rfc9111](https://www.rfc-editor.org/rfc/rfc9111)$review_23_system_design_19_cdn_origin_shield$
WHERE slug = 'system-design-19-cdn-origin-shield' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_system_design_20_social_graph_design$> **검수 경계** — 팔로워 수·공통 연결 수·캐시 크기는 가상 입력이다. 특정 소셜 서비스의 현재 그래프 저장소나 추천 알고리즘을 사실로 단정하지 않는다.

## 1. 관계의 의미부터 고정한다

팔로우는 방향 간선 하나지만 친구는 수락 상태를 가진 대칭 관계다. 쓰기 API는 요청 ID나 관계의 자연 키로 재시도를 멱등하게 처리하고 차단 관계가 모든 조회보다 우선하도록 한다.

```mermaid
flowchart LR
    A[User A] -->|follows| B[User B]
    A <-->|accepted friendship| C[User C]
    B --> G[(그래프 저장소)]
    C --> G
    G --> R[추천·공통 연결]
```

| 조회 | 기본 구조 | 확장 전략 |
|---|---|---|
| 내가 팔로우 | `from_user` 인접 목록 | 커서 페이지네이션 |
| 나를 팔로우 | `to_user` 역방향 인덱스 | 샤드·캐시 |
| 공통 연결 | 정렬된 두 집합 교집합 | 작은 집합 우선·비동기 후보 |
| 추천 | 2-hop 후보+점수 | 배치 계산·온라인 필터 |

```sql
INSERT INTO follows(from_user_id, to_user_id, created_at)
VALUES (:from, :to, now())
ON CONFLICT (from_user_id, to_user_id) DO NOTHING;
```

> **설계 판단** — 일반 사용자는 사용자 ID 기준 샤딩이 단순하지만 유명 계정의 역방향 목록은 한 파티션에 집중된다. 고차수 노드는 별도 버킷으로 분산한다.

## 2. 일관성과 개인정보

관계 생성 직후 읽기는 주 저장소에서 확인하고 추천·카운트는 최종 일관성을 허용할 수 있다. 비공개 계정, 차단, 탈퇴 삭제는 파생 캐시와 추천 인덱스에도 전파해야 한다.

> **면접 포인트** — 그래프 DB 이름보다 핵심 조회 패턴, 차수 분포, 방향 인덱스, 개인정보 삭제 경로를 먼저 제시한다.

## 검수 경계와 실패 흐름

- 수치와 임계값은 요구사항으로 선언하고 실제 workload·부하 테스트·관측 지표로 검증한다. 제품·기업의 내부 구현을 근거 없이 일반화하지 않는다.
- 쓰기 성공 후 이벤트/읽기 모델 갱신 실패, 응답 유실 후 재시도, 중복·순서 역전·부분 장애를 정상적인 실패 경로로 모델링한다.
- 원장과 캐시·검색·알림·분석 파생 모델의 상태를 구분하고, 멱등 키·버전·재처리 큐·대사 작업으로 수렴시킨다.
- 성능 최적화는 평균이 아니라 p95/p99, 버스트와 복구 중 부하를 함께 본다. fallback을 추가할 때 정확성·보안·개인정보·비용 trade-off를 기록한다.

## 공식·1차 출처

- [https://docs.aws.amazon.com/neptune/latest/userguide/PropertyGraph.html](https://docs.aws.amazon.com/neptune/latest/userguide/PropertyGraph.html)
- [https://redis.io/docs/latest/develop/data-types/sets/](https://redis.io/docs/latest/develop/data-types/sets/)
- [https://tinkerpop.apache.org/docs/current/reference/](https://tinkerpop.apache.org/docs/current/reference/)$review_23_system_design_20_social_graph_design$
WHERE slug = 'system-design-20-social-graph-design' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_system_design_22_session_management_design$> **검수 경계** — 동시 세션 수와 토큰 TTL은 보안 요구사항과 사용자 경험에 따른 가상 입력이다. JWT나 Redis가 즉시 로그아웃을 자동 보장하지 않는다.

## 1. 두 종류의 상태를 구분한다

Access Token은 요청 검증 비용을 낮추고 짧게 유지한다. Refresh Token 계열은 서버에 해시와 세대 정보를 저장해 회전과 폐기를 통제한다. 비밀번호 변경이나 계정 차단은 사용자 세션 버전을 올려 전체 기기를 무효화할 수 있다.

```mermaid
sequenceDiagram
    participant C as Client
    participant A as Auth
    participant S as Session Store
    C->>A: refresh token R1
    A->>S: consume hash(R1)
    S-->>A: valid family, generation 1
    A->>S: revoke R1, store R2
    A-->>C: access token + R2
```

| 선택 | 장점 | 비용 |
|---|---|---|
| 서버 세션 | 즉시 폐기·정책 변경 | 저장소 조회와 가용성 |
| 서명 Access Token | 분산 검증 | 만료 전 폐기 어려움 |
| Refresh 회전 | 탈취 재사용 감지 | 가족 상태·경쟁 처리 |
| 사용자 세션 버전 | 전체 로그아웃 단순화 | 검증 시 버전 확인 필요 |

```text
session_key = hash(refresh_token)
partition   = hash(user_id)
ttl         = min(device_policy, absolute_session_lifetime)
```

> **보안 경계** — 원본 Refresh Token을 로그나 DB에 평문으로 남기지 않는다. 재사용이 감지되면 같은 Token Family 전체를 폐기한다.

## 2. 확장과 장애

세션 저장소는 사용자 또는 Token ID로 샤딩하고 TTL 삭제 폭주를 분산한다. 저장소 장애 때 인증을 전부 허용하는 Fail-open은 보안 사고가 되므로 기능별 정책을 명시한다.

> **면접 포인트** — 토큰 형식 선택보다 강제 로그아웃 시간, 탈취 모델, 키 회전, 저장소 장애 정책을 요구사항으로 수치화한다.

## 검수 경계와 실패 흐름

- 수치와 임계값은 요구사항으로 선언하고 실제 workload·부하 테스트·관측 지표로 검증한다. 제품·기업의 내부 구현을 근거 없이 일반화하지 않는다.
- 쓰기 성공 후 이벤트/읽기 모델 갱신 실패, 응답 유실 후 재시도, 중복·순서 역전·부분 장애를 정상적인 실패 경로로 모델링한다.
- 원장과 캐시·검색·알림·분석 파생 모델의 상태를 구분하고, 멱등 키·버전·재처리 큐·대사 작업으로 수렴시킨다.
- 성능 최적화는 평균이 아니라 p95/p99, 버스트와 복구 중 부하를 함께 본다. fallback을 추가할 때 정확성·보안·개인정보·비용 trade-off를 기록한다.

## 공식·1차 출처

- [https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html)
- [https://www.rfc-editor.org/rfc/rfc8725](https://www.rfc-editor.org/rfc/rfc8725)
- [https://www.rfc-editor.org/rfc/rfc9700](https://www.rfc-editor.org/rfc/rfc9700)$review_23_system_design_22_session_management_design$
WHERE slug = 'system-design-22-session-management-design' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_system_design_23_unique_id_design$> **검수 경계** — ID 비트 구성·생성량·시계 정밀도·수명은 요구사항으로 계산한다. UUID·Snowflake·구간 할당 중 하나가 모든 용도에 최적이라는 일반화는 피한다.

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

## 검수 경계와 실패 흐름

- clock rollback이 감지되면 대기·논리 epoch 증가·생성기 중단 중 정책을 선택하고, rollback window와 가용성 손실을 지표화한다.
- sequence가 소진되거나 epoch가 rollover하면 충돌을 재시도만으로 숨기지 말고 생성 실패·수명·마이그레이션 경로를 명시한다.
- node ID lease·registry가 분할되면 fencing token과 최종 저장소 UNIQUE 제약으로 중복을 차단하고, duplicate key·순서 역전·생성 지연을 알람으로 남긴다.
- 외부 공개 ID의 예측 가능성·내부 B-Tree locality·정렬성은 서로 다른 요구사항이다. 생성량·bit 배치·DB insert benchmark를 함께 검증한다.

## 공식·1차 출처

- [https://www.rfc-editor.org/rfc/rfc9562](https://www.rfc-editor.org/rfc/rfc9562)
- [https://github.com/twitter-archive/snowflake](https://github.com/twitter-archive/snowflake)
- [https://www.postgresql.org/docs/current/datatype-uuid.html](https://www.postgresql.org/docs/current/datatype-uuid.html)$review_23_system_design_23_unique_id_design$
WHERE slug = 'system-design-23-unique-id-design' AND source = 'MANUAL';

UPDATE cards
SET content_md = $review_23_system_design_24_storage_index_interview$> **검수 경계** — 이벤트 수·보존 기간·객체 크기·조회 패턴은 면접용 가정이다. 저장소의 편안한 한계를 제품 불문 상수로 말하지 않는다.

## 1. 저장소 이름보다 질의표가 먼저다

면접에서는 평균과 최대 쓰기량, 객체 크기, 보존 기간, 허용 유실량을 가정으로 선언한다. 각 API가 사용하는 키, 정렬, 범위, 일관성을 표로 만들면 필요한 인덱스가 드러난다.

```mermaid
flowchart TD
    R[요구사항·SLO] --> Q[질의 패턴]
    Q --> K[기본 키·정렬 키]
    K --> P[파티션·복제]
    P --> F[실패·재샤딩]
```

| 질문 | 확인할 결정 | 경고 신호 |
|---|---|---|
| 무엇으로 찾나 | Partition Key | 단조 증가 키 한 파티션 |
| 어떤 순서인가 | Sort Key·Index | 모든 필드 인덱싱 |
| 얼마나 오래 두나 | TTL·Archive | 삭제 폭주 |
| 얼마나 정확해야 하나 | 복제·일관성 | 요구 없는 강한 일관성 |

```text
daily_bytes = peak_events_per_second * average_event_bytes * 86_400
replicated_capacity = daily_bytes * retention_days * replication_factor
```

> **면접 전략** — 계산값은 정답이 아니라 설계 규모를 고르는 근거다. 압축, 인덱스, 복제 오버헤드가 빠졌음을 명시하고 여유 계수를 둔다.

## 2. 깊이 질문에 대비한다

Hot Key는 버킷을 추가하되 읽을 때 합치는 비용을 설명한다. 보조 인덱스는 쓰기 증폭과 지연을 만들며, 재샤딩 중에는 이중 쓰기보다 변경 로그 기반 복제를 선호할 수 있다.

> **면접 포인트** — 정상 경로 뒤에 노드 장애, 복제 지연, 파티션 이동, 데이터 복구와 검증 순서를 붙이면 설계가 완성된다.

## 검수 경계와 실패 흐름

- 수치와 임계값은 요구사항으로 선언하고 실제 workload·부하 테스트·관측 지표로 검증한다. 제품·기업의 내부 구현을 근거 없이 일반화하지 않는다.
- 쓰기 성공 후 이벤트/읽기 모델 갱신 실패, 응답 유실 후 재시도, 중복·순서 역전·부분 장애를 정상적인 실패 경로로 모델링한다.
- 원장과 캐시·검색·알림·분석 파생 모델의 상태를 구분하고, 멱등 키·버전·재처리 큐·대사 작업으로 수렴시킨다.
- 성능 최적화는 평균이 아니라 p95/p99, 버스트와 복구 중 부하를 함께 본다. fallback을 추가할 때 정확성·보안·개인정보·비용 trade-off를 기록한다.

## 공식·1차 출처

- [https://www.postgresql.org/docs/current/indexes.html](https://www.postgresql.org/docs/current/indexes.html)
- [https://www.postgresql.org/docs/current/ddl-partitioning.html](https://www.postgresql.org/docs/current/ddl-partitioning.html)
- [https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-partition-key-design.html](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-partition-key-design.html)$review_23_system_design_24_storage_index_interview$
WHERE slug = 'system-design-24-storage-index-interview' AND source = 'MANUAL';
