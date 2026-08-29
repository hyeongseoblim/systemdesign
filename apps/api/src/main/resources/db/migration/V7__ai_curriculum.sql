-- 생성형 AI와 LLM 애플리케이션 개발을 백엔드 학습 커리큘럼의 독립 영역으로 추가한다.
INSERT INTO curriculum_topics (
    id, area, title, mode, display_order, generated, planned_date,
    topic_key, resolution_status
)
VALUES
  (gen_random_uuid(), 'AI', 'Transformer와 LLM 작동 원리', 'CONCEPT', 465, false, NULL, 'ai-465', 'PENDING'),
  (gen_random_uuid(), 'AI', 'Tokenization과 Context Window 설계', 'CONCEPT', 466, false, NULL, 'ai-466', 'PENDING'),
  (gen_random_uuid(), 'AI', 'Prompt 설계와 Structured Output', 'CONCEPT', 467, false, NULL, 'ai-467', 'PENDING'),
  (gen_random_uuid(), 'AI', 'Embedding과 Vector Search', 'CONCEPT', 468, false, NULL, 'ai-468', 'PENDING'),
  (gen_random_uuid(), 'AI', '프로덕션 RAG 파이프라인 설계', 'DESIGN', 469, false, NULL, 'ai-469', 'PENDING'),
  (gen_random_uuid(), 'AI', 'Hybrid Retrieval과 Reranking', 'CONCEPT', 470, false, NULL, 'ai-470', 'PENDING'),
  (gen_random_uuid(), 'AI', 'Tool Calling과 Model Context Protocol', 'CONCEPT', 471, false, NULL, 'ai-471', 'PENDING'),
  (gen_random_uuid(), 'AI', '신뢰 가능한 Agent Workflow 설계', 'DESIGN', 472, false, NULL, 'ai-472', 'PENDING'),
  (gen_random_uuid(), 'AI', 'LLM 평가·관측성·회귀 테스트', 'CONCEPT', 473, false, NULL, 'ai-473', 'PENDING'),
  (gen_random_uuid(), 'AI', 'Prompt Injection과 AI 보안 리뷰', 'REVIEW', 474, false, NULL, 'ai-474', 'PENDING'),
  (gen_random_uuid(), 'AI', 'LLM 추론 서빙과 비용·지연 최적화', 'DESIGN', 475, false, NULL, 'ai-475', 'PENDING'),
  (gen_random_uuid(), 'AI', 'Fine-tuning·LoRA·Quantization', 'CONCEPT', 476, false, NULL, 'ai-476', 'PENDING'),
  (gen_random_uuid(), 'AI', 'Multimodal AI 파이프라인 설계', 'DESIGN', 477, false, NULL, 'ai-477', 'PENDING'),
  (gen_random_uuid(), 'AI', '프로덕션 LLM 시스템 설계 면접', 'INTERVIEW', 478, false, NULL, 'ai-478', 'PENDING'),
  (gen_random_uuid(), 'AI', 'LLM 연동 코드 리뷰 체크리스트', 'REVIEW', 479, false, NULL, 'ai-479', 'PENDING');
