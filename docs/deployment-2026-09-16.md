# 2026-09-16 저장소 선택 콘텐츠 배포

- 소스: `066354c`, main 커밋·푸시 완료.
- API Cloud Build: `19d1a44e-c83d-4a14-a766-25284409e0c6`, SUCCESS.
- Cloud Run: `jobstudy-api-00016-mkr`, 운영 트래픽 100%.
- Web: `dpl_J54DsSzKRYcyFBVsJ2decsm1RHsM`, READY, [운영 사이트](https://jobstudy-eta.vercel.app).
- 원격 CI: `34995564269`, 성공.

RDBMS/NoSQL 부분 정정 카드를 심층 검수로 전환했다. 구성별 일관성·NoSQL 트랜잭션·DynamoDB Query 페이지 처리·Shard의 조회 비용·가상 물류 선택을 보강했다. 기존 질문과 카드 ID를 유지하며 V13으로 본문만 갱신했다.

Node 검사 13개, 콘텐츠 계약, Web 빌드, diff 검사 통과. 페이지 함수는 본문에서 직접 추출해 빈 중간 페이지 후 결과·커서 전달·빈 마지막 페이지를 검증했다. Gradle 소켓이 샌드박스에서 차단되어 권한 적용 후 재실행했다.

운영 DB 읽기 전용 검증으로 V13 성공·최신 본문 35개 일치·MANUAL 카드 및 질문 레코드 보존을 확인했다. 운영 상세 HTML에서 새 본문과 질문 해설을 확인했다. 실제 DynamoDB/Cassandra/MongoDB 장애·부하 시험과 모바일 상호작용 검증은 수행하지 않았다.

누적 심층 34개·부분 정정 1개, 고유 변경 본문 35개, 해설 40개/120문항. 남은 94개는 구조 점검 상태이며 전체 심층 검수 완료가 아니다.

## DB 면접 후속 배포

- 소스: `5f50952`, main 커밋·푸시 완료.
- API Cloud Build: `8c740ffa-de76-459d-9ea8-a626d548ca4a`, SUCCESS.
- Cloud Run: `jobstudy-api-00017-zqh`, 운영 트래픽 100%.
- Web: `dpl_4L3QXWvuz1zpQS7yNiKpCjwr8Ukd`, inspect에서 Ready와 운영 별칭 연결 확인.
- 원격 CI: `34997502279`, 성공.

Node 검사 14개·콘텐츠 계약·Web 빌드 통과. 임시 PostgreSQL 18.4에서 기존 RR Snapshot/동일 행 변경 거절 및 Write Skew 재현 2개 통과. PostgreSQL 17·MySQL 8.4 실행으로 계산하지 않는다. 실제 락 대기 후 실패의 타이밍까지 새로 재현한 검사는 아니다.

운영 DB에서 V14 성공·최신 본문 35개 일치·MANUAL 카드와 질문 레코드 보존을 확인했다. API health는 UP이다. Vercel 배포 CLI는 fetch failed로 종료됐지만 같은 배포를 inspect해 Ready·운영 별칭을 확인했으므로 재배포하지 않았다. 운영 상세 HTML 조회는 CLI·시간 제한 직접 요청 모두 응답 없이 지연/시간 초과되어 본문·해설 HTML 확인은 미완료다. 장기 대기한 조회 프로세스는 종료했다. 웹 응답은 후속 재확인 대상이다.

누적 심층 35개·부분 정정 0개, 해설 41개/123문항. 남은 94개는 구조 점검 상태다.
