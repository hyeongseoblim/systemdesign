# ADR-0001: Oracle 대체 무료 티어 클라우드 구성

**Status:** Accepted

**Date:** 2026-08-17
**Deciders:** project owner

## Context

Oracle Cloud Free Tier 인스턴스를 생성할 수 없다. 개인 학습용 서비스이므로 월 고정비 0원,
Spring Boot/Kotlin과 PostgreSQL 호환, 한국에서 사용할 수 있는 공개 HTTPS 엔드포인트가 필요하다.
유휴 시간의 콜드스타트는 허용한다.

## Decision

- 웹: Vercel Hobby의 Next.js 배포
- API: Google Cloud Run, 서울 리전, request-based billing, min 0 / max 1
- DB: Neon Free PostgreSQL, pooled connection과 scale-to-zero 사용
- 이미지: Artifact Registry, 빌드: Cloud Build 무료 한도 사용
- 비밀값: Secret Manager 무료 한도 내 5개 이하 유지

API와 DB가 모두 유휴 시 scale-to-zero 되므로 상시 VM 비용이 없다. Flyway 충돌과 비용 폭주를
줄이기 위해 Cloud Run 최대 인스턴스를 1로 제한한다.

## Options Considered

| 선택지 | 고정비 0원 | 콜드스타트 | 운영 복잡도 | 판단 |
|---|---:|---:|---:|---|
| GCP e2-micro + VM 내 PostgreSQL | 아니오 | 없음 | 높음 | 외부 IPv4 과금 때문에 제외 |
| Cloud Run + Neon Free | 가능 | API/DB 모두 있음 | 낮음 | 채택 |
| Render Free + 외부 DB | 가능 | 있음 | 낮음 | 무료 정책과 DB 수명 제약 때문에 차선 |
| Supabase Free + Cloud Run | 가능 | 있음 | 낮음 | 7일 저활동 프로젝트 pause 때문에 차선 |

## Consequences

- 첫 요청은 Cloud Run과 Neon이 동시에 깨어나 수 초 걸릴 수 있다.
- Spring 내부 `@Scheduled` 작업은 인스턴스가 0일 때 보장되지 않으므로 비활성화한다.
- 개인 프로젝트 수준의 트래픽에서는 무료 한도 내 운영 가능하지만 무료 한도는 지출 상한이 아니다.
- Cloud Run 최대 인스턴스 1은 비용과 Flyway 경쟁을 막는 대신 동시 처리량을 제한한다.
- Neon 0.5GB 저장공간과 월 compute 한도를 모니터링해야 한다.

## Action Items

- [x] Cloud Run 배포 스크립트와 환경변수 예시 추가
- [x] API/DB/웹 배포 순서 문서화
- [ ] Neon 프로젝트와 GCP 결제 연결 프로젝트 생성
- [ ] 실제 비밀값으로 최초 배포
- [ ] Vercel에 Cloud Run URL 설정
- [ ] GCP 예산 알림 또는 사용 가능한 경우 Cloud Run spend cap 설정
