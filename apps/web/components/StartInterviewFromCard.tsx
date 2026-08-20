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
}: {
  cardId: string;
  area: TopicArea;
  title: string;
  difficulty: number;
}) {
  void cardId;
  const query = new URLSearchParams({
    area,
    topic: title,
    difficulty: String(difficulty),
  });

  return (
    <div className="card-interview">
      <Link className="ghost-btn wide" href={`/interview?${query.toString()}`}>
        이 주제로 ChatGPT 면접 보기 ↗
      </Link>
      <p className="hint">
        읽은 직후가 가장 잘 기억날 때입니다. 카드를 덮고 답해 보세요.
      </p>
    </div>
  );
}
