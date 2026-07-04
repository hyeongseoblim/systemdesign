-- AI 생성 파이프라인: 생성 로그(예산 추적) + 커리큘럼 시드

CREATE TABLE generation_logs (
    id            UUID         PRIMARY KEY,
    area          VARCHAR(40),
    topic_id      UUID,
    card_id       UUID         REFERENCES cards(id) ON DELETE SET NULL,
    input_tokens  INT          NOT NULL DEFAULT 0,
    output_tokens INT          NOT NULL DEFAULT 0,
    quality_score SMALLINT,
    outcome       VARCHAR(20)  NOT NULL,   -- PUBLISHED / DRAFT / FAILED
    error         TEXT,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_generation_logs_created ON generation_logs (created_at);

-- 커리큘럼 시드 — 품질 게이트 1(중복 방지)의 출발점.
-- generated=false 인 주제만 매일 배치가 골라서 생성한다.
INSERT INTO curriculum_topics (id, area, title, mode, display_order, generated, planned_date)
VALUES
  (gen_random_uuid(), 'SYSTEM_DESIGN', 'Rate Limiter 설계', 'DESIGN', 1, false, NULL),
  (gen_random_uuid(), 'SYSTEM_DESIGN', 'Consistent Hashing 심화', 'CONCEPT', 2, false, NULL),
  (gen_random_uuid(), 'SYSTEM_DESIGN', '뉴스피드 Fan-out 전략', 'CONCEPT', 3, false, NULL),
  (gen_random_uuid(), 'LOGISTICS', '재고 정합성 — Reserve/Commit/Ship', 'CONCEPT', 1, false, NULL),
  (gen_random_uuid(), 'LOGISTICS', '라스트마일 TrackingEvent Fan-out', 'DESIGN', 2, false, NULL),
  (gen_random_uuid(), 'BACKEND_ARCHITECTURE', 'Outbox 패턴 구현', 'CONCEPT', 1, false, NULL),
  (gen_random_uuid(), 'BACKEND_ARCHITECTURE', '주문-결제-배송 Saga', 'INTERVIEW', 2, false, NULL),
  (gen_random_uuid(), 'BACKEND_DEV', '재고 차감 동시성 4가지', 'CONCEPT', 1, false, NULL),
  (gen_random_uuid(), 'DATABASE', 'MySQL 인덱스 실행계획 읽기', 'CONCEPT', 1, false, NULL),
  (gen_random_uuid(), 'DATABASE', 'Redis 분산 락 (Redlock)', 'CONCEPT', 2, false, NULL),
  (gen_random_uuid(), 'INFRA', 'Kubernetes HPA 오토스케일', 'CONCEPT', 1, false, NULL),
  (gen_random_uuid(), 'CS', 'TCP Congestion Control', 'CONCEPT', 1, false, NULL);
