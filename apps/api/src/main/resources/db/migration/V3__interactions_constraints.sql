-- interactions upsert 무결성:
--   답변 행 = (card_id, question_id) 당 1개
--   북마크 행 = question_id IS NULL 로 카드당 1개
CREATE UNIQUE INDEX uq_interactions_card_question
    ON interactions (card_id, question_id) WHERE question_id IS NOT NULL;
CREATE UNIQUE INDEX uq_interactions_card_bookmark
    ON interactions (card_id) WHERE question_id IS NULL;
