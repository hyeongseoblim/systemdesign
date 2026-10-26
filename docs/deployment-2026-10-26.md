# 2026-10-26 클라우드 통합 main 운영 배포

## 배포 대상과 결과

- 배포 커밋: `5f7e5b79d709b57233e99c1a22b9c032e991dd84`. 기능 소스는 통합 main `52667f7`이며, 이 커밋은 현황 문서와 V24 사전 검사 결과를 추가했다.
- [CI 성공](https://github.com/hyeongseoblim/systemdesign/actions/runs/40290398940): API build/test, 웹 학습·콘텐츠 회귀 검사, 웹 build.
- [API 배포 성공](https://github.com/hyeongseoblim/systemdesign/actions/runs/40290407370): OIDC 인증, 이미지 빌드·push, 기존 Cloud Run 업데이트, health·카드 검사.
- API revision: `jobstudy-api-00024-f97`, Ready, 트래픽 100%.
- API image: `asia-northeast3-docker.pkg.dev/jobstudy-14798/jobstudy/jobstudy-api@sha256:dff825ec358bdee895bea9ae1005416f9c6cfdf89791bfe24f1c755e5bf5bbc2`.
- API 주소: https://jobstudy-api-u3uso2qdpa-du.a.run.app
- 웹 production: `dpl_4QYSb8H6sBqmeRbtUR6sJ5cLS19i`, READY, Git SHA `5f7e5b79d709b57233e99c1a22b9c032e991dd84`.
- 웹 운영 alias: https://jobstudy-eta.vercel.app
- 이 기록의 후속 문서 커밋은 API 기능 소스와 DB migration을 변경하지 않는다. API를 문서 커밋 때문에 다시 빌드하지 않는다. 웹 Git 배포가 후속 문서 커밋을 따라가면 해당 배포의 READY·SHA를 별도로 확인한다.

## DB 사전·사후 검사

- 운영 DB 조회는 read-only 세션으로 수행했다. 비밀번호·관리자 토큰을 로그나 파일에 기록하지 않았다.
- 사전: Flyway V23 성공, interactions 0행, 답변·북마크 중복 그룹 각각 0, 게시 카드 129개.
- 로컬: PostgreSQL 16 Testcontainers에서 신규 DB와 V23→V24 테스트 2/2 성공, skipped=0.
- 사후: 최신 Flyway V24 success=true, `uq_interactions_card_question`·`uq_interactions_card_bookmark` 2개 인덱스 존재.
- 카드 129개·질문 387개 유지. 배포 전후 정렬된 전체 ID 집합의 MD5가 각각 일치했다.
- card IDs: `cb979f1908d73c25e4440c37e59c1e24`, question IDs: `8f1d5401371d008c9caea7a686b563f9`.

## 운영 검증

- health: UP.
- 공개 카드 피드: 페이지네이션으로 129개 조회, ID 중복 없음. 카드 상세 본문·질문 3개 확인.
- 익명 interactions 조회, 북마크 쓰기, 관리자 초안 조회: 모두 401.
- 관리자 토큰을 사용한 interactions 읽기: 200. 운영 데이터에 답변이나 북마크를 쓰지 않았다.
- 웹 Origin의 카드 API OPTIONS: 200 및 `Access-Control-Allow-Origin: https://jobstudy-eta.vercel.app`.
- 웹 홈: HTTP 200 및 HTML 확인.
- 배포 전후 환경변수·시크릿 참조·컨테이너 자원 한도·런타임 서비스 계정 동일. 서비스 maxScale=1 유지. GEN_ENABLED=false, INTERVIEW_ENABLED=false 유지.
- 새 리비전 기동 후 경고 이상 로그 조회에서 항목이 없었다. 이 확인은 장시간 모니터링을 대체하지 않는다.
- 이번 배포에서 브라우저 학습 상호작용·실기기·지하철 네트워크는 재검증하지 않았다. 실기기 점검은 TASKS.md에 남겨뒀다.

## 롤백

- 이전 리비전: `jobstudy-api-00023-xqb`.
- health 또는 게시 카드 조회 실패 시 이전 리비전으로 트래픽 전환. 이번 검증은 통과해 롤백하지 않았다.
- V24는 추가 인덱스이며 이전 API와 호환된다. 이미지 롤백이 Flyway 이력을 되돌리지는 않는다.
