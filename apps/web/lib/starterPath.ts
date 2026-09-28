import type { CardSummary } from "./api";
import type { StudyRecord } from "./study";

export interface StarterLesson {
  slug: string;
  label: string;
  takeaway: string;
  example: string;
  question: string;
  check: string;
}

// 기존 심화 카드의 순서만 안내한다. 카드·질문 ID나 본문은 바꾸지 않는다.
export const STARTER_LESSONS: StarterLesson[] = [
  {
    slug: "backend-01-api-design",
    label: "API 설계",
    takeaway: "API는 화면의 버튼보다 '주문'처럼 다루는 대상을 중심으로 주소와 동작을 정하면 이해하기 쉽습니다.",
    example: "주문 목록은 GET /orders, 새 주문은 POST /orders처럼 표현합니다. 같은 주문을 실수로 두 번 만들지 않게 하는 규칙은 별도로 필요합니다.",
    question: "주문 상세를 조회하는 주소와 HTTP 메서드를 어떻게 정할까요?",
    check: "GET /orders/{id}처럼 주문 ID로 대상을 지정하고, 조회에는 GET을 쓰면 됩니다.",
  },
  {
    slug: "database-01-index-explain",
    label: "인덱스 읽기",
    takeaway: "인덱스는 책의 찾아보기처럼 조건에 맞는 행을 빨리 찾도록 돕습니다. 모든 쿼리가 빨라지는 것은 아닙니다.",
    example: "주문 번호로 한 건을 자주 찾는다면 orders(order_no) 인덱스가 도움이 됩니다. 대신 주문을 추가할 때 인덱스도 갱신해야 합니다.",
    question: "주문 번호 검색이 느리다면 가장 먼저 무엇을 확인하고 싶나요?",
    check: "실행계획에서 실제로 어떤 경로로 읽는지 확인하고, 주문 번호 인덱스 유무와 데이터 분포를 살펴보세요.",
  },
  {
    slug: "backend-05-testing",
    label: "테스트 선택",
    takeaway: "테스트는 '무엇이 깨지면 곤란한가'에서 시작합니다. 작은 규칙과 실제 연동은 검증 방법이 다릅니다.",
    example: "할인율 계산은 빠른 단위 테스트로, DB 제약을 포함한 주문 저장은 실제 DB에 가까운 통합 테스트로 확인합니다.",
    question: "할인 금액 계산과 DB 저장 중, DB 없이 먼저 시험할 수 있는 것은 무엇인가요?",
    check: "할인 금액 계산입니다. DB 저장은 쿼리·제약·트랜잭션 동작도 확인해야 합니다.",
  },
  {
    slug: "cs-03-network",
    label: "웹 요청 이해",
    takeaway: "웹 요청은 주소를 찾고, 서버와 연결한 뒤, 요청과 응답을 주고받는 여러 단계를 거칩니다.",
    example: "페이지가 늦게 뜰 때 DNS 조회가 느린지, 서버 연결이 느린지, 응답 생성이 느린지 나누어 보면 원인을 좁힐 수 있습니다.",
    question: "서버 응답 시간이 짧아도 화면이 느릴 수 있는 이유 한 가지를 떠올려 보세요.",
    check: "DNS 조회, 연결·TLS 설정, 리소스 다운로드, 브라우저 렌더링 등이 추가 시간을 쓸 수 있습니다.",
  },
  {
    slug: "system-design-01-fundamentals",
    label: "시스템 설계",
    takeaway: "시스템 설계는 기술 이름보다 '얼마나 빨라야 하고, 얼마나 자주 멈춰도 되는가'를 먼저 정하는 일입니다.",
    example: "결제는 중복 처리 방지가 중요하고, 배송 조회는 잠깐 늦게 갱신되어도 되는 경우가 있습니다. 둘을 같은 기준으로 설계할 필요는 없습니다.",
    question: "결제 결과와 배송 위치 중, 더 엄격하게 최신 값을 확인해야 할 정보는 무엇일까요?",
    check: "보통 결제 결과입니다. 돈이 중복 이동하거나 상태가 어긋나면 영향이 크기 때문입니다. 실제 요구사항은 서비스별로 확인해야 합니다.",
  },
];

export function starterLesson(slug: string): StarterLesson | undefined {
  return STARTER_LESSONS.find((lesson) => lesson.slug === slug);
}

export function nextStarter(cards: CardSummary[], records: Record<string, StudyRecord>): { card: CardSummary; position: number } | undefined {
  for (const [index, lesson] of STARTER_LESSONS.entries()) {
    const card = cards.find((item) => item.slug === lesson.slug);
    if (card && !records[card.id]?.done) return { card, position: index + 1 };
  }
  return undefined;
}
