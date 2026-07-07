// 2개월치 커리큘럼(V4) SQL 생성기 — 영역별 주제를 인터리빙해 매일 다양한 영역이 섞이게 함
// 사용: node tools/gen-curriculum.mjs > apps/api/src/main/resources/db/migration/V4__curriculum_2months.sql
// (V2 시드 12개의 display_order 1~3 뒤에 오도록 100부터 시작)

const AREAS = {
  SYSTEM_DESIGN: [
    ["채팅 시스템 설계 — WebSocket·메시지 순서·읽음 확인", "DESIGN"],
    ["알림 시스템 설계 — 푸시·재시도·중복 제거", "DESIGN"],
    ["검색 자동완성 설계 — Trie·랭킹·트래픽 급증", "DESIGN"],
    ["분산 Key-Value Store 설계 — 복제·일관성 해싱·충돌 해결", "DESIGN"],
    ["분산 ID 생성기 — Snowflake·UUID v7 비교", "CONCEPT"],
    ["웹 크롤러 설계 — 정중함·중복 URL·분산 큐", "DESIGN"],
    ["동영상 스트리밍 설계 — 인코딩 파이프라인·적응형 스트리밍", "DESIGN"],
    ["클라우드 파일 스토리지 설계 — 청크·동기화·중복 제거", "DESIGN"],
    ["근접 검색 — Geohash vs QuadTree vs S2", "CONCEPT"],
    ["Uber 배차 매칭 시스템 설계", "DESIGN"],
    ["티켓 예매 시스템 — 대기열·좌석 락·부정 방지", "DESIGN"],
    ["광고 클릭 집계 시스템 — 스트림 집계·지연 데이터", "DESIGN"],
    ["실시간 게임 리더보드 — Sorted Set·샤딩", "DESIGN"],
    ["분산 메시지 큐 내부 — Kafka 파티션·오프셋·ISR", "CONCEPT"],
    ["캐시 장애 3종 — Stampede·Penetration·Avalanche", "CONCEPT"],
    ["CDC 파이프라인 — Debezium·스냅샷·순서 보장", "CONCEPT"],
    ["분산 트랜잭션 총정리 — 2PC vs Saga vs TCC", "CONCEPT"],
    ["CAP·PACELC 실전 적용 — 시스템별 분류", "CONCEPT"],
    ["멱등성 있는 결제 시스템 설계", "DESIGN"],
    ["장애 격리 패턴 — Circuit Breaker·Bulkhead·Backpressure", "CONCEPT"],
    ["핫 파티션(Hot Partition) 문제와 해결", "CONCEPT"],
    ["검색 엔진 기초 — 역색인·BM25·랭킹", "CONCEPT"],
    ["실시간 협업 편집 — OT vs CRDT", "CONCEPT"],
    ["웹훅 전달 시스템 설계 — 서명·재시도·DLQ", "DESIGN"],
    ["대용량 처리 아키텍처 — Lambda vs Kappa", "CONCEPT"],
    ["멀티 리전 아키텍처 — Active-Active·데이터 주권", "CONCEPT"],
    ["모니터링·알림 시스템 설계", "DESIGN"],
  ],
  LOGISTICS: [
    ["WMS 입고 프로세스 — ASN·검수·적치 전략", "CONCEPT"],
    ["피킹 최적화 심화 — Batch·Zone·Wave·Cluster", "CONCEPT"],
    ["재고 실사와 Cycle Counting", "CONCEPT"],
    ["주문 할당(Allocation) 전략 — 창고 선택·분할출고", "CONCEPT"],
    ["Cut-off와 새벽배송 SLA 설계", "CONCEPT"],
    ["라스트마일 배차 — VRP 기초와 휴리스틱", "CONCEPT"],
    ["운송장 라이프사이클과 상태머신 설계", "CONCEPT"],
    ["물류 네트워크 설계 — 허브앤스포크 vs P2P", "CONCEPT"],
    ["반품(역물류) 프로세스와 시스템 설계", "CONCEPT"],
    ["멀티채널 재고 정합성 — 오픈마켓 연동", "CONCEPT"],
    ["풀필먼트 자동화 — AGV·GTP·소터", "CONCEPT"],
    ["OMS-WMS-TMS 인터페이스 — 이벤트 계약 설계", "CONCEPT"],
    ["배송비·운임 계산 엔진 설계", "CONCEPT"],
    ["쿠팡 로켓배송 아키텍처 분석", "CONCEPT"],
    ["컬리 샛별배송 — 시간제약 물류 설계", "CONCEPT"],
    ["아마존 FBA와 3PL 모델 비교", "CONCEPT"],
    ["ETA 예측 시스템 — 피처·모델·서빙", "CONCEPT"],
    ["물류 KPI 데이터 모델 — OTD·재고회전율", "CONCEPT"],
  ],
  BACKEND_ARCHITECTURE: [
    ["Idempotency 설계 총정리 — 키·저장소·소비자 멱등성", "CONCEPT"],
    ["Event Sourcing 기초와 도입 판단", "CONCEPT"],
    ["CQRS 실전 — 읽기 모델 동기화 전략", "CONCEPT"],
    ["DDD Aggregate 설계 규칙", "CONCEPT"],
    ["Bounded Context 나누기 — 이커머스 실습", "CONCEPT"],
    ["헥사고날 아키텍처 — Ports & Adapters", "CONCEPT"],
    ["Modular Monolith 구조화 전략", "CONCEPT"],
    ["MSA 분리 시점과 Strangler Fig 패턴", "CONCEPT"],
    ["API Gateway와 BFF 패턴", "CONCEPT"],
    ["서비스 간 통신 — 동기 vs 비동기 선택 기준", "CONCEPT"],
    ["분산 추적과 컨텍스트 전파", "CONCEPT"],
    ["이벤트 스키마 진화 — Avro·Schema Registry·호환성", "CONCEPT"],
    ["DLQ와 재처리 설계", "CONCEPT"],
    ["Saga 보상 트랜잭션 실패 처리 심화", "CONCEPT"],
    ["API 버저닝과 하위호환 마이그레이션", "CONCEPT"],
    ["멀티테넌시 아키텍처 — 격리 수준 비교", "CONCEPT"],
  ],
  BACKEND_DEV: [
    ["@Transactional 동작 원리와 함정 8가지", "CONCEPT"],
    ["JPA N+1 문제와 해결 전략", "CONCEPT"],
    ["낙관적 락 재시도 구현 — Spring Retry", "CONCEPT"],
    ["Kafka Consumer 멱등 처리 구현", "CONCEPT"],
    ["Outbox 릴레이 구현 — Polling vs Debezium", "CONCEPT"],
    ["Spring 비동기 — @Async·CompletableFuture·Virtual Thread", "CONCEPT"],
    ["Java/Kotlin 동시성 도구 지도 — Executor부터 코루틴까지", "CONCEPT"],
    ["HikariCP 커넥션 풀 튜닝", "CONCEPT"],
    ["Spring Cache + Redis 실전 — TTL·무효화", "CONCEPT"],
    ["Testcontainers 통합 테스트 전략", "CONCEPT"],
    ["예외 설계와 에러 응답 표준화 (RFC 7807)", "CONCEPT"],
    ["페이지네이션 구현 — Offset vs Cursor(keyset)", "CONCEPT"],
    ["파일 업로드 설계 — Presigned URL", "CONCEPT"],
    ["Spring Batch 기초 — 청크·재시작", "CONCEPT"],
    ["웹훅 수신 처리 — 서명 검증·재시도 방어", "CONCEPT"],
    ["API 성능 측정과 프로파일링 루틴", "CONCEPT"],
  ],
  DATABASE: [
    ["복합 인덱스 설계와 커버링 인덱스", "CONCEPT"],
    ["MVCC 내부 — MySQL vs PostgreSQL", "CONCEPT"],
    ["격리수준과 이상현상 — 실습 시나리오", "CONCEPT"],
    ["락 심화 — Gap Lock·Next-key Lock·데드락 분석", "CONCEPT"],
    ["파티셔닝 전략 — Range·List·Hash", "CONCEPT"],
    ["샤딩 실전 — 키 선택과 리샤딩", "CONCEPT"],
    ["복제 지연(Replication Lag) 대응 패턴", "CONCEPT"],
    ["무중단 스키마 변경 — Online DDL·gh-ost", "CONCEPT"],
    ["슬로우 쿼리 진단 루틴", "CONCEPT"],
    ["Redis 자료구조 활용 — 랭킹·큐·카운터", "CONCEPT"],
    ["Redis 캐시 무효화와 Stampede 방지", "CONCEPT"],
    ["B+Tree vs LSM Tree — RocksDB 관점", "CONCEPT"],
    ["DynamoDB Single Table Design", "CONCEPT"],
    ["시계열 데이터 저장 전략", "CONCEPT"],
    ["백업·복구와 PITR", "CONCEPT"],
  ],
  INFRA: [
    ["Docker 이미지 최적화 — 멀티스테이지·레이어 캐시", "CONCEPT"],
    ["K8s 리소스 관리 — requests/limits·QoS·OOMKilled", "CONCEPT"],
    ["K8s 배포 전략 실전 — Canary·Argo Rollouts", "CONCEPT"],
    ["Terraform 기초 — 상태 관리·모듈화", "CONCEPT"],
    ["GitHub Actions CI/CD 패턴", "CONCEPT"],
    ["리버스 프록시와 TLS 종료 — Nginx·Caddy", "CONCEPT"],
    ["메트릭 설계 실전 — RED·USE·SLO 대시보드", "CONCEPT"],
    ["로그 파이프라인 — Loki·ELK 비교", "CONCEPT"],
    ["AWS 오토스케일링과 용량 계획", "CONCEPT"],
    ["장애 대응 프로세스 — 온콜·포스트모템", "CONCEPT"],
    ["클라우드 비용 최적화 — FinOps 기초", "CONCEPT"],
    ["시크릿 관리 — Vault·Secrets Manager", "CONCEPT"],
  ],
  CS: [
    ["HTTP/2·HTTP/3와 성능", "CONCEPT"],
    ["TLS 핸드셰이크와 mTLS", "CONCEPT"],
    ["JVM GC 알고리즘 — G1·ZGC", "CONCEPT"],
    ["OS 스케줄링과 컨텍스트 스위치 비용", "CONCEPT"],
    ["I/O 모델 — epoll·io_uring·이벤트 루프", "CONCEPT"],
    ["개발자를 위한 해시·암호화 기초", "CONCEPT"],
    ["확률적 자료구조 — Bloom Filter·HyperLogLog", "CONCEPT"],
    ["DNS와 서비스 디스커버리", "CONCEPT"],
  ],
};

// 가중 라운드로빈 인터리빙: 남은 개수가 많은 영역부터 하나씩
const queues = Object.entries(AREAS).map(([area, list]) => ({ area, list: [...list] }));
const rows = [];
while (queues.some((q) => q.list.length > 0)) {
  queues.sort((a, b) => b.list.length - a.list.length);
  for (const q of queues) {
    const item = q.list.shift();
    if (item) rows.push({ area: q.area, title: item[0], mode: item[1] });
  }
}

const esc = (s) => s.replace(/'/g, "''");
let sql = `-- 2개월치 학습 커리큘럼 (${rows.length}개, 영역 인터리빙)
-- display_order 100부터 시작 — V2 시드(1~3)가 먼저 소진된 뒤 이어짐
INSERT INTO curriculum_topics (id, area, title, mode, display_order, generated)
VALUES
`;
sql += rows
  .map((r, i) => `  (gen_random_uuid(), '${r.area}', '${esc(r.title)}', '${r.mode}', ${100 + i}, false)`)
  .join(",\n");
sql += ";\n";

process.stdout.write(sql);
console.error(`영역별: ${Object.entries(AREAS).map(([a, l]) => `${a}=${l.length}`).join(", ")} / 합계 ${rows.length}`);
