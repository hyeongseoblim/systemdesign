-- 수동·AI 카드가 같은 커리큘럼 주제를 중복 해결하지 않도록 안정적인 키와 상태를 추가한다.
-- generated/generated_card_id는 기존 배포와의 호환을 위해 유지하고 애플리케이션에서 함께 갱신한다.

ALTER TABLE curriculum_topics
    ADD COLUMN topic_key VARCHAR(160),
    ADD COLUMN resolution_status VARCHAR(24) NOT NULL DEFAULT 'PENDING',
    ADD COLUMN resolved_card_id UUID REFERENCES cards(id) ON DELETE SET NULL,
    ADD COLUMN supersedes_topic_key VARCHAR(160);

-- 제목 정규화는 표현 변경에 취약하다. 마이그레이션 시점의 영역·순서를 고정 키로 사용하고
-- 이후 display_order가 바뀌어도 topic_key는 변경하지 않는다.
UPDATE curriculum_topics
SET topic_key = lower(replace(area, '_', '-')) || '-' || lpad(display_order::text, 3, '0');

-- V6 이전에 생성된 AI 카드의 처리 상태를 보존한다.
UPDATE curriculum_topics
SET resolution_status = CASE WHEN generated THEN 'AI_DRAFT' ELSE 'PENDING' END,
    resolved_card_id = generated_card_id;

UPDATE curriculum_topics topic
SET resolution_status = 'AI_PUBLISHED'
FROM cards card
WHERE topic.generated = true
  AND topic.generated_card_id = card.id
  AND card.status = 'PUBLISHED';

ALTER TABLE curriculum_topics
    ALTER COLUMN topic_key SET NOT NULL,
    ADD CONSTRAINT uq_curriculum_topic_key UNIQUE (topic_key),
    ADD CONSTRAINT ck_curriculum_resolution_status CHECK (
        resolution_status IN ('PENDING', 'MANUAL', 'AI_DRAFT', 'AI_PUBLISHED', 'SKIPPED')
    ),
    ADD CONSTRAINT fk_curriculum_supersedes_topic
        FOREIGN KEY (supersedes_topic_key) REFERENCES curriculum_topics(topic_key) ON DELETE SET NULL;

CREATE INDEX idx_curriculum_resolution_pending
    ON curriculum_topics (resolution_status, display_order, id);
