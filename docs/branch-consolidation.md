# 작업 브랜치 통합

다음 미병합 브랜치의 커밋 이력을 모두 main에 병합했다.

- claude/gracious-heisenberg-53c2ab
- claude/learning-data-status-cb3xhv
- claude/migrate-local-project-qEKvq
- claude/study-content-sections
- codex/complete-deployment-control
- docs/design-brief
- feat/web-design-signal

## 충돌 해결 기준

- 최신 홈 대시보드, 검색·복습·목차·질문별 답변 기준, 라이트/다크 테마와 접근성을 유지했다. Signal 공용 아이콘과 디자인 메타데이터를 현재 8개 영역에 맞춰 통합했다.
- 기존 Cloud Run의 자원·비용 한도, Secret Manager 기반 설정, 최신 Claude 클라이언트를 유지했다. 과거 카드 생성 워크플로는 `GENERATION_ENABLED=true` 변수로 명시적으로 활성화해야 실행된다.
- 구형 interactions API와 게시·보관 관리 API, LLM 호출 밖에서 DB 트랜잭션을 여는 개선을 합쳤다. 공유 답변 조회와 쓰기는 관리자 인증을 요구한다. 일반 웹의 최신 기기 내 답변 저장 흐름은 유지한다. 브라우저에 관리자 토큰을 주입하거나 공유 답변을 모든 사용자에게 동기화하지 않는다.
- 운영 적용된 V1~V23 파일을 바꾸지 않았다. 구형 브랜치의 V3 interaction 인덱스는 V24로 추가하고, 충돌하는 구형 V4 커리큘럼은 tools의 참고 SQL로 보존했다. 현재 연간 커리큘럼을 중복 적재하지 않는다.
- 과거 정적 학습 HTML 54개와 코치 피드백, 콘텐츠 인덱스·위젯 의존성·변환 도구를 소스로 보존했다. 이 파일들은 Next.js 배포 루트인 apps/web과 별개이며 Cloudflare Worker를 새로 배포하지 않는다. 가져오기 도구는 현재 관리자 인증 규칙을 따른다.

## 검증

- API 전체 빌드·테스트. 신규 DB와 기존 V23 DB에서 V24 업그레이드를 확인한다.
- 웹 학습 회귀 테스트, 프로덕션 빌드 및 콘텐츠 예제·I/O 검사.
- 구형 JS/도구 구문 검사, 정적 콘텐츠 인덱스의 54개 원본 파일 존재 여부 검사.
- 카드 가져오기 도구는 로컬 mock 서버에서 인증 헤더·요청 데이터·중복 건너뛰기를 검증했다. 운영 DB에는 가져오지 않았다.

브랜치 삭제 전 복구용 전체 Git bundle을 `/workspace/branch-backups/systemdesign-before-consolidation.bundle`에 저장·검증했다. main 반영과 CI가 성공한 뒤 main의 조상임을 확인한 브랜치만 삭제한다.
