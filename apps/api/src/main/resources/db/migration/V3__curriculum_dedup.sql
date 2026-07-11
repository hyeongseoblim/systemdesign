-- 커리큘럼 주제 중복 정리.
-- V2 시드 이후 수동 큐레이션 카드(content/*.md)가 같은 주제를 이미 다루게 된
-- 항목을 AI 생성 대상에서 제외한다. 이미 생성된(generated=true) 항목은 건드리지 않는다.
--
-- 제거 사유(대응 수동 카드):
--   Rate Limiter 설계              → system-design-08-case-rate-limiter
--   뉴스피드 Fan-out 전략           → system-design-11-case-newsfeed
--   라스트마일 TrackingEvent Fan-out → system-design-10-case-delivery-tracking
--   Outbox 패턴 구현               → backend-architecture-06-outbox-idempotency
--   주문-결제-배송 Saga (INTERVIEW) → backend-architecture-07-interview-saga
--   재고 차감 동시성 4가지          → database-07-inventory-concurrency, backend-07-interview-concurrency
--   MySQL 인덱스 실행계획 읽기      → database-01-index-explain, database-08-interview-index-lock
--
-- 잔여 주제(생성 파이프라인 대상): Consistent Hashing 심화, 재고 정합성 Reserve/Commit/Ship,
-- Redis 분산 락 (Redlock), Kubernetes HPA 오토스케일, TCP Congestion Control
DELETE FROM curriculum_topics
WHERE generated = false
  AND title IN (
    'Rate Limiter 설계',
    '뉴스피드 Fan-out 전략',
    '라스트마일 TrackingEvent Fan-out',
    'Outbox 패턴 구현',
    '주문-결제-배송 Saga',
    '재고 차감 동시성 4가지',
    'MySQL 인덱스 실행계획 읽기'
  );
