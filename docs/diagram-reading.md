# 본문 다이어그램의 세로 이미지 읽기

## 표시 방식

- Markdown·운영 DB·카드/질문 ID는 유지하고 웹 본문 표시를 바꾼다. DB migration이나 API 배포는 필요 없다.
- `apps/web/public/diagrams/`에는 도표 원문 SHA-256을 파일명으로 사용하는 SVG 273개가 있다. `apps/web/content/diagrams.json`이 정규화한 원문과 이미지·크기·확대 구간을 연결한다.
- Mermaid 266개, ASCII 도표 4개와 화살표 설명 흐름 3개를 이미지로 제공한다. 가로 흐름도와 명시적 하위 방향 LR/RL을 TB로 배치한다.
- 시퀀스 64개는 Mermaid parser의 참여자·메시지·메모·조건·반복·병렬 구간 데이터를 이용해 폭 300px의 세로 단계 SVG로 그린다. 메시지의 발신/수신과 제어 구간을 유지하며 내부 entity placeholder를 원래 문자로 복원한다.
- 넓은 도표는 전체 이미지를 보여주고, 별도 화면에서 전체 SVG를 열어 기기의 확대 기능으로 살펴볼 수 있다. 잘린 확대 조각을 반복하지 않는다.
- 일반 코드 블록은 코드로 유지한다. 도표 원문은 각 이미지의 '다이어그램 텍스트 설명'에서 확인할 수 있다. 이미지 배경과 글자색을 함께 고정해 앱 라이트/다크 테마 양쪽에서 대비를 유지한다.
- 아직 이미지로 생성되지 않은 신규 Mermaid에는 클라이언트 SVG 이미지 fallback이 있다. 본문 갱신 시에는 생성기를 실행해 정적 이미지를 추가해야 CI의 전체 콘텐츠 검사를 통과한다.

## 재생성

```bash
cd apps/web
npm ci
npm run generate:diagrams
npm run test:diagrams
npm run test:study
npm run build
```

생성기는 macOS의 설치된 Google Chrome을 사용한다. 다른 경로는 `CHROME_PATH`로 지정한다. Linux에서는 Playwright Chromium을 설치(`npx playwright install chromium`)한 뒤 실행한다. 생성기는 로컬 정적 파일만 읽으며 운영 DB나 API에 쓰지 않는다.

시퀀스 문장 속 세미콜론과 빈 edge label 등 기존 Mermaid parser 오류는 렌더링 입력에서 보정한다. 학습 원문과 배포된 migration 파일은 수정하지 않는다. 생성 SVG에는 외부 폰트·HTML foreignObject·스크립트가 없다.

## 검증

```bash
# 빌드한 웹을 별도 터미널에서 실행
npm run start -- --port 3400
# 웹·API 주소 생략 시 localhost:3400 및 기존 운영 API 사용
npm run test:diagrams:browser
```

- 정적 검사: 모든 원문 이미지 연결·파일 hash·SVG·시퀀스 폭과 문자 복원·확대 구간의 전체 커버리지.
- 브라우저 검사: 273개 이미지 모두 decode, 대표 카드 5종 × 320/390/768/1280px에서 도표 overflow·이미지 누락·넓은 도표의 전체 이미지 링크 검사, 다크 테마와 텍스트 설명 확인.
- 브라우저 검사 결과와 스크린샷 기본 저장 위치: `/tmp/jobstudy-diagram-check`. 다른 위치는 `DIAGRAM_ARTIFACTS`로 지정한다.
- 2026-10-27 운영 129개 카드 본문의 Mermaid 266개와 정적 이미지 원문 연결을 대조했으며 누락 0개였다.
- 실기기·지하철 네트워크 사용성은 별도 검증 대상이다.
