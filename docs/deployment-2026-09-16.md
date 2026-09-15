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
