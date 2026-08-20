-- 대화형 면접 세션. 카드(정적 콘텐츠)와 달리 멀티턴 대화 기록을 보관한다.
-- Anthropic Messages API는 stateless라 매 턴 전체 히스토리를 재전송해야 하므로,
-- turn_order 순서로 복원 가능한 형태로 저장한다.

CREATE TABLE interview_sessions (
    id                UUID         PRIMARY KEY,
    area              VARCHAR(40)  NOT NULL,
    topic             VARCHAR(300) NOT NULL,
    difficulty        SMALLINT     NOT NULL DEFAULT 3,
    coach             VARCHAR(60),
    status            VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',  -- ACTIVE / COMPLETED / ABANDONED
    -- 카드 상세에서 바로 면접을 연 경우의 출처 (선택)
    card_id           UUID         REFERENCES cards(id) ON DELETE SET NULL,
    -- 종료 시 생성되는 3축 피드백(좋은 점/개선점/빅테크 기준 평가) 마크다운
    feedback_md       TEXT,
    -- 예산 추적. cache_read는 캐시 히트분(정가의 약 1/10)이라 분리 집계한다.
    input_tokens      INT          NOT NULL DEFAULT 0,
    output_tokens     INT          NOT NULL DEFAULT 0,
    cache_read_tokens INT          NOT NULL DEFAULT 0,
    started_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    ended_at          TIMESTAMPTZ
);
CREATE INDEX idx_interview_sessions_started ON interview_sessions (started_at DESC);
CREATE INDEX idx_interview_sessions_status ON interview_sessions (status, started_at DESC);

CREATE TABLE interview_turns (
    id         UUID        PRIMARY KEY,
    session_id UUID        NOT NULL REFERENCES interview_sessions(id) ON DELETE CASCADE,
    role       VARCHAR(20) NOT NULL,   -- INTERVIEWER / CANDIDATE
    content    TEXT        NOT NULL,
    turn_order SMALLINT    NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_interview_turns_session ON interview_turns (session_id, turn_order);
