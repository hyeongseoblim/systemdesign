-- jobStudy 학습 플랫폼 초기 스키마

CREATE TABLE cards (
    id              UUID         PRIMARY KEY,
    area            VARCHAR(40)  NOT NULL,
    coach           VARCHAR(60),
    mode            VARCHAR(20)  NOT NULL,
    title           VARCHAR(300) NOT NULL,
    slug            VARCHAR(300) NOT NULL UNIQUE,
    summary         TEXT,
    content_md      TEXT         NOT NULL,
    difficulty      SMALLINT     NOT NULL DEFAULT 1,
    status          VARCHAR(20)  NOT NULL DEFAULT 'DRAFT',
    quality_score   SMALLINT,
    source          VARCHAR(20)  NOT NULL DEFAULT 'AI_GENERATED',
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    published_at    TIMESTAMPTZ
);

-- 피드 조회 최적화: status 필터 + (published_at, id) keyset 정렬
CREATE INDEX idx_cards_feed ON cards (status, published_at DESC, id DESC);
CREATE INDEX idx_cards_area ON cards (area, published_at DESC);

CREATE TABLE card_tags (
    card_id UUID        NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
    tag     VARCHAR(50) NOT NULL,
    PRIMARY KEY (card_id, tag)
);

CREATE TABLE card_questions (
    id            UUID     PRIMARY KEY,
    card_id       UUID     NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
    question      TEXT     NOT NULL,
    display_order SMALLINT NOT NULL DEFAULT 0
);
CREATE INDEX idx_card_questions_card ON card_questions (card_id);

-- 무엇을 언제 생성할지 관리 (품질 게이트 1: 중복 방지)
CREATE TABLE curriculum_topics (
    id                UUID         PRIMARY KEY,
    area              VARCHAR(40)  NOT NULL,
    title             VARCHAR(300) NOT NULL,
    mode              VARCHAR(20)  NOT NULL DEFAULT 'CONCEPT',
    display_order     INT          NOT NULL DEFAULT 0,
    generated         BOOLEAN      NOT NULL DEFAULT FALSE,
    generated_card_id UUID         REFERENCES cards(id),
    planned_date      DATE,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_curriculum_pending ON curriculum_topics (area, generated, display_order);

-- 학습 진행: 질문별 답변, 북마크
CREATE TABLE interactions (
    id             UUID        PRIMARY KEY,
    card_id        UUID        NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
    question_id    UUID        REFERENCES card_questions(id) ON DELETE CASCADE,
    answer         TEXT,
    bookmarked     BOOLEAN     NOT NULL DEFAULT FALSE,
    last_viewed_at TIMESTAMPTZ,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_interactions_card ON interactions (card_id);
