---
area: AI
mode: CONCEPT
coach: ai-coach
title: "Hybrid Retrieval과 Reranking — 검색 Recall과 Precision 높이기"
slug: ai-06-hybrid-retrieval-reranking
topicKey: ai-470
difficulty: 4
summary: "Keyword와 Vector 후보를 합치고 Reranker로 재정렬해 고유명사·의미·비용 요구를 함께 만족시킨다."
tags:
  - "Hybrid Search"
  - "Reranking"
  - "RRF"
questions:
  - "고유 상품 코드 검색에서 Dense Retrieval만 사용할 때 어떤 문제가 생기나요?"
  - "Reranker에 전달할 후보 수를 늘리면 품질과 지연이 어떻게 변하나요?"
  - "RRF와 점수 정규화 방식의 장단점을 비교해보세요."
---
## 1. 후보 생성과 정밀 정렬을 분리한다

Sparse Retrieval은 정확한 단어에 강하고 Dense Retrieval은 의미가 비슷한 표현에 강하다. 두 결과를 RRF(Reciprocal Rank Fusion, 역순위 결합) 등으로 합친 뒤 Cross-Encoder나 작은 LLM Reranker가 상위 후보를 정밀 평가한다.

```mermaid
flowchart LR
    Q[Query] --> K[Keyword Top 50]
    Q --> V[Vector Top 50]
    K --> F[Rank Fusion]
    V --> F
    F --> R[Reranker Top 10]
    R --> C[Context Builder]
```

| 단계 | 최적화 목표 | 비용 특성 |
|---|---|---|
| Candidate Retrieval | Recall | 빠르고 넓게 검색 |
| Fusion | 서로 다른 점수 결합 | 저렴한 순위 계산 |
| Reranking | Precision | 후보 수에 비례한 추론 비용 |
| Context Build | 다양성·Token 예산 | 중복 제거 필요 |

```python
rrf_score = sum(1 / (60 + rank) for rank in source_ranks)
```

> **실무 함정** — 최종 답변 점수만 보면 검색 개선 효과를 알 수 없다. Retriever Recall과 Reranker nDCG를 별도 측정한다.

## 2. Query 유형별 경로를 선택한다

상품 코드·오류 코드는 Keyword 비중을 높이고, 자연어 정책 질문은 Vector 비중을 높일 수 있다. 다만 동적 Routing 자체도 평가 세트와 실패 시 기본 경로가 필요하다.

> **면접 포인트** — Top-k를 고정 상수로 암기하지 말고 후보 수, Context Token, p95 지연, Recall 목표로 실험한다.
