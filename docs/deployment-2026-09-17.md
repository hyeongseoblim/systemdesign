# 2026-09-17 I/O 다중화 검수 배포

- 소스: `3beca3b`, main 커밋·푸시 완료.
- API Cloud Build: `a67be613-88ad-48b7-9d96-b42a471067fd`, SUCCESS.
- Cloud Run: `jobstudy-api-00018-w8p`, 운영 트래픽 100%.
- Web: `dpl_hzmuBuwH154pqfVufm4SDZHCvQhz`, READY, 운영 별칭 반영.
- 원격 CI: `35167271276`, 성공.

Node 검사 15개·콘텐츠 계약·Web 빌드 통과. 본문 C 함수를 추출한 검사에서 EINTR/부분 읽기/EAGAIN/EWOULDBLOCK/EOF/오류 분기를 반환값 주입으로 확인했다. CI에도 같은 검사를 추가했다. 실제 Linux epoll 이벤트나 부하를 재현한 검사는 아니다.

운영 DB에서 V15 성공·최신 본문 36개 일치·MANUAL 카드 및 질문 레코드 보존을 확인했다. I/O 상세 HTML에서 새 함수와 새 질문 해설을 확인했다.

## 웹 응답 재확인 범위

기본 주소 조회는 시간 초과가 재발했다. 운영 호스트명과 TLS 검증을 유지하면서 다른 Vercel 배포 주소에서 확인한 Edge IP `216.198.79.3`으로 연결한 요청은 성공했다. 이 경로로 V14 DB 면접의 새 본문·해설과 V15 I/O 카드의 본문·해설을 확인했다. 콘텐츠 HTML 확인은 완료했으나 기본 접속 경로 시간 초과의 원인이나 모든 사용자 환경의 정상 접속까지 증명한 것은 아니다. DNS/네트워크 설정은 변경하지 않았다.

누적 심층 36개, 구조 점검 93개, 해설 42개/126문항. 전체 심층 검수는 아직 진행 중이다.

## 가상 메모리·Socket 내부 검수 배포

- 소스: `9ec11fa`, main 커밋·푸시 완료.
- 원격 CI: `35172147158`, API·Web 성공.
- API Cloud Build: `52d19a74-904c-4d05-a036-ac965acfe582`, SUCCESS.
- Cloud Run: `jobstudy-api-00019-7f4`, 운영 트래픽 100%, 서비스 `maxScale=1`.
- Web: `dpl_Cth984rM76nYfqhUZSaRc5bi7h2n`, production READY, `jobstudy-eta.vercel.app` 별칭 반영.

로컬에서 API 테스트 31개가 통과했고 Docker가 필요한 커리큘럼 마이그레이션 테스트 1개는 건너뛰었다. Node 학습·본문 회귀 검사 17개, 콘텐츠 계약 129개, Web production build, Python HLC 3개와 C I/O 분기 검사가 통과했다. 가상 메모리의 임시 파일 mmap 예제와 Socket의 Loopback Half-close 예제도 실행했다. 실제 Linux COW 부하·접속 폭주·TLS·망 장애 시험은 범위에 포함하지 않았다.

운영 Neon에서 V16 `review virtual memory`와 V17 `review socket internals`의 성공을 확인했다. MANUAL/PUBLISHED 카드 129개, MANUAL 커리큘럼 70개, PENDING 314개가 유지됐다. API 상세 응답에서 두 카드의 새 본문과 기존 질문 ID·문구를 확인했다.

운영 웹 상세 HTML에서 가상 메모리와 Socket 본문, 두 카드의 질문별 해설 6개를 확인했다. API health는 `UP`이고 `https://jobstudy-eta.vercel.app` origin의 CORS preflight는 200과 올바른 `access-control-allow-origin`을 반환했다.

누적 심층 38개, 구조 점검 91개, 해설 44개/132문항. 전체 심층 검수는 계속 진행한다.
