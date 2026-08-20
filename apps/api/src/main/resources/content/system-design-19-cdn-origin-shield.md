---
area: SYSTEM_DESIGN
mode: CONCEPT
coach: system-design-coach
title: "CDN 내부 — 엣지 계층·Origin Shield·무효화 전파"
slug: system-design-19-cdn-origin-shield
topicKey: system-design-112
difficulty: 4
summary: "다단 캐시와 Origin Shield가 원본 부하를 줄이는 원리, 캐시 키와 무효화가 정확성에 미치는 영향을 설명한다."
tags:
  - "CDN"
  - "Caching"
  - "Origin Shield"
  - "Invalidation"
questions:
  - "Origin Shield가 캐시 미스 폭주를 어떻게 줄이며 새로운 병목이 되지 않게 하려면 무엇을 관측해야 하나요?"
  - "URL 외 헤더와 쿠키를 캐시 키에 포함할 때 적중률과 정확성 사이의 Trade-off를 설명해보세요."
  - "TTL, 버전 URL, Purge 중 상품 가격처럼 빠르게 바뀌는 데이터에 적합한 전략을 설계해보세요."
---
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
