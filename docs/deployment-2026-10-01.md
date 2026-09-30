# 2026-10-01 콘텐츠 검수 릴리스

## 범위와 결과

- `2508d5d`에서 V21~V23 마이그레이션으로 기존 MANUAL 카드 88개의 본문을 갱신하고, 전체 129개 카드·387개 질문의 웹 답변 기준을 연결했다. 기존 카드 slug와 질문 문구는 유지했다.
- `e2a66af`에서 Vercel 빌드 환경의 파일 추적 루트를 기본값으로 돌려 배포를 완료했다. 로컬 저장소에서만 명시한 추적 루트를 사용한다.
- 두 커밋의 [CI](https://github.com/hyeongseoblim/systemdesign/actions/runs/36739095519), [후속 CI](https://github.com/hyeongseoblim/systemdesign/actions/runs/36740524447)는 API·웹 모두 통과했다. 로컬 웹 학습 테스트 22/22, 웹·API 빌드, Python 콘텐츠 예제·I/O 검사도 통과했다.

## 운영 배포

- [Cloud Build](https://console.cloud.google.com/cloud-build/builds/8086dc6c-0a3c-409e-9d34-59e12bd67e8c?project=55363157288)에서 `2508d5d` API 이미지를 빌드해 Cloud Run `jobstudy-api-00021-j7x`에 100% 트래픽을 전환했다. Flyway 로그에서 V20 → V21 → V22 → V23 순서와 3개 마이그레이션 성공을 확인했다.
- [Vercel 배포](https://vercel.com/hsne/jobstudy/9DRmKUDgupqHdcD2fJgmUPZdWDHb)는 Ready이며 [운영 웹](https://jobstudy-eta.vercel.app)에 별칭이 연결됐다. 처음 시도는 명시한 추적 루트 때문에 배포 파일 경로가 중복되어 실패했고, `e2a66af`에서 수정해 재배포했다.
- Cloud Run 서비스 전체 `maxScale=1`, `GEN_ENABLED=false`, `INTERVIEW_ENABLED=false`를 배포 후 재확인했다. 비밀값·IAM·결제 설정은 변경하지 않았다.

## 운영 검증

- [API health](https://jobstudy-api-u3uso2qdpa-du.a.run.app/api/v1/health)는 `UP`. 운영 웹 Origin의 카드 API preflight는 HTTP 200과 허용 Origin을 반환했다.
- 카드 피드의 129개 slug가 로컬 129개와 일치했다. V21~V23 대상 88개 상세 API의 본문은 각각 Markdown 원본과 일치하고, 세 질문과 MANUAL 출처를 유지했다.
- 운영 웹 홈과 AI·물류·백엔드 카드 상세가 HTTP 200으로 렌더링됐다. 390×844 헤드리스 Chrome에서 홈 → 첫 카드 → 질문 입력·기준 보기 → 복습 예약 → 복습 목록 1개 표시 → 카드 재진입 후 답변 복원을 확인했다. 테스트는 별도 브라우저 프로필에서 수행했다.
- 실제 휴대전화와 이동 중 통신 상태의 체감 점검은 남아 있다.

API 롤백 시 이전 Cloud Run 리비전으로 트래픽을 되돌릴 수 있다. V21~V23은 운영 DB 본문을 갱신했으므로, 이전 본문까지 되돌리려면 별도 보정 마이그레이션이 필요하다.
