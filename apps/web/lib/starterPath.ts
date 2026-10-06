import type { CardSummary } from "./api";
import type { StudyRecord } from "./study";

export interface StarterLesson {
  slug: string;
  label: string;
  takeaway: string;
  explanation: string;
  example: string;
  question: string;
  answer: string;
  answerExplanation: string;
}

// 기존 심화 카드의 순서만 안내한다. 카드·질문 ID나 본문은 바꾸지 않는다.
export const STARTER_LESSONS: StarterLesson[] = [
  {
    slug: "backend-01-api-design",
    label: "API 설계",
    takeaway: "API는 화면의 버튼보다 '주문'처럼 다루는 대상을 중심으로 주소와 동작을 정하면 이해하기 쉽습니다.",
    explanation: "주소는 어떤 대상을 다루는지, HTTP 메서드는 어떤 일을 하는지 나타냅니다. 조회는 GET, 생성은 POST로 구분합니다. 목록은 대상의 모음을 가리키고, 한 건을 지정하려면 주소에 그 대상의 ID를 붙입니다.",
    example: "주문 목록 조회는 GET /orders, 새 주문 생성은 POST /orders로 표현합니다. 상품 목록 조회는 GET /products, 특정 상품 조회는 GET /products/42처럼 ID를 붙여 구분합니다.",
    question: "주문 상세를 조회하는 주소와 HTTP 메서드를 어떻게 정할까요?",
    answer: "GET /orders/{orderId}",
    answerExplanation: "GET은 주문을 변경하지 않고 조회하는 동작입니다. /orders는 주문 모음이고, {orderId}는 그중 한 주문을 지정합니다. 예를 들어 주문 ID가 123이면 GET /orders/123입니다. 변수 이름보다 조회 메서드와 특정 주문을 식별하는 구조가 중요합니다.",
  },
  {
    slug: "database-01-index-explain",
    label: "인덱스 읽기",
    takeaway: "인덱스는 책의 찾아보기처럼 조건에 맞는 행을 빨리 찾도록 돕습니다. 모든 쿼리가 빨라지는 것은 아닙니다.",
    explanation: "인덱스가 없으면 많은 행을 하나씩 확인할 수 있습니다. 인덱스가 있어도 조건에 맞는 행이 너무 많으면 전체를 읽는 편이 나을 수 있어요. EXPLAIN으로 DB가 선택한 읽기 경로를 확인하고, 실행 시간은 실제 측정으로 비교합니다.",
    example: "주문 번호로 한 건을 자주 찾는다면 orders(order_no) 인덱스가 도움이 됩니다. 대신 주문을 추가할 때 인덱스도 갱신해야 합니다.",
    question: "주문 번호 검색이 느리다면 가장 먼저 무엇을 확인하고 싶나요?",
    answer: "EXPLAIN으로 읽기 경로를 확인하고, 주문 번호 인덱스와 조건에 맞는 데이터의 양을 살펴봅니다.",
    answerExplanation: "검색이 느리다는 이유만으로 인덱스를 추가하기보다 DB가 실제로 어떤 경로를 선택했는지 먼저 확인해야 합니다. 주문 번호를 한 건 찾는 경우와 많은 행을 찾는 경우는 적절한 읽기 경로가 다를 수 있습니다.",
  },
  {
    slug: "backend-05-testing",
    label: "테스트 선택",
    takeaway: "테스트는 '무엇이 깨지면 곤란한가'에서 시작합니다. 작은 규칙과 실제 연동은 검증 방법이 다릅니다.",
    explanation: "입력만으로 결과가 정해지는 계산은 DB나 네트워크 없이 검증할 수 있습니다. 반면 저장이 제대로 되는지는 실제 쿼리, 제약 조건, 트랜잭션까지 함께 동작시켜 봐야 알 수 있어요.",
    example: "할인율 계산은 빠른 단위 테스트로, DB 제약을 포함한 주문 저장은 실제 DB에 가까운 통합 테스트로 확인합니다.",
    question: "할인 금액 계산과 DB 저장 중, DB 없이 먼저 시험할 수 있는 것은 무엇인가요?",
    answer: "할인 금액 계산을 DB 없이 먼저 시험할 수 있습니다.",
    answerExplanation: "가격과 할인율을 입력해서 예상 금액과 비교하면 계산 규칙을 검증할 수 있습니다. DB 저장은 실제 DB의 쿼리와 제약 조건에 영향을 받으므로 계산 테스트만으로 저장 동작까지 확인할 수는 없습니다.",
  },
  {
    slug: "cs-03-network",
    label: "웹 요청 이해",
    takeaway: "웹 요청은 주소를 찾고, 서버와 연결한 뒤, 요청과 응답을 주고받는 여러 단계를 거칩니다.",
    explanation: "브라우저는 DNS로 서버 주소를 찾고 연결을 준비한 뒤 요청을 보냅니다. HTTPS라면 TLS 설정도 필요합니다. 응답을 받아도 이미지와 스크립트를 내려받고 화면을 그리는 시간이 더해집니다.",
    example: "페이지가 늦게 뜰 때 DNS 조회가 느린지, 서버 연결이 느린지, 응답 생성이 느린지 나누어 보면 원인을 좁힐 수 있습니다.",
    question: "서버 응답 시간이 짧아도 화면이 느릴 수 있는 이유 한 가지를 떠올려 보세요.",
    answer: "이미지나 스크립트를 내려받거나 브라우저가 화면을 그리는 데 시간이 걸릴 수 있습니다.",
    answerExplanation: "서버 응답 시간은 페이지가 보이기까지 걸린 전체 시간의 일부입니다. DNS 조회나 연결·TLS 설정이 느린 경우도 가능합니다. 내가 떠올린 원인이 서버의 응답 생성 외 단계에 해당하는지 확인해 보세요.",
  },
  {
    slug: "system-design-01-fundamentals",
    label: "시스템 설계",
    takeaway: "시스템 설계는 기술 이름보다 '얼마나 빨라야 하고, 얼마나 자주 멈춰도 되는가'를 먼저 정하는 일입니다.",
    explanation: "속도뿐 아니라 데이터가 얼마나 최신이어야 하는지, 장애 때 어떤 기능을 유지해야 하는지도 정해야 합니다. 돈이나 재고처럼 틀리면 피해가 큰 정보와 잠시 늦어도 괜찮은 정보를 구분하면 설계 기준을 세울 수 있어요.",
    example: "결제는 중복 처리 방지가 중요하고, 배송 조회는 잠깐 늦게 갱신되어도 되는 경우가 있습니다. 둘을 같은 기준으로 설계할 필요는 없습니다.",
    question: "결제 결과와 배송 위치 중, 더 엄격하게 최신 값을 확인해야 할 정보는 무엇일까요?",
    answer: "보통 결제 결과에 더 엄격한 최신성 기준이 필요합니다.",
    answerExplanation: "오래된 결제 상태로 판단하면 중복 결제나 잘못된 후속 처리가 발생할 수 있습니다. 배송 위치는 잠시 늦게 표시되어도 허용되는 경우가 있지만, 배차나 안전 판단에 쓰인다면 더 엄격한 기준이 필요합니다. 정보가 사용되는 목적에 따라 결정합니다.",
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
