import Link from "next/link";
import { TopicArea } from "@/lib/api";

/**
 * 카드 상세에서 그 주제로 바로 면접을 연다.
 * 읽은 직후가 가장 기억이 선명한 시점이라, 여기서 "대답하는 학습"으로 넘어가게 한다.
 */
export default function StartInterviewFromCard({
  cardId,
  area,
  title,
  difficulty,
  step = 4,
}: {
  cardId: string;
  area: TopicArea;
  title: string;
  difficulty: number;
  step?: number;
}) {
  void cardId;
  const query = new URLSearchParams({
    area,
    topic: title,
    difficulty: String(difficulty),
  });

  return (
    <section className="card-interview">
      <div className="card-interview-copy">
        <span>OPTIONAL · STEP {step}</span>
        <div>
          <h2>말로 설명하며 실전 점검</h2>
          <p>읽은 직후 카드를 덮고 답하면 기억에 더 오래 남습니다.</p>
        </div>
      </div>
      <Link className="ghost-btn wide" href={`/interview?${query.toString()}`}>
        이 주제로 무료 면접 연습 ↗
      </Link>
    </section>
  );
}
