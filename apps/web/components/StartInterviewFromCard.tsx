"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { startInterview, TopicArea } from "@/lib/api";

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
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function start() {
    if (busy) return;
    setBusy(true);
    setError(null);
    try {
      const session = await startInterview({
        area,
        topic: title,
        difficulty,
        cardId,
      });
      router.push(`/interview/${session.id}`);
    } catch (e) {
      setError(e instanceof Error ? e.message : "면접을 시작하지 못했습니다");
      setBusy(false);
    }
  }

  return (
    <div className="card-interview">
      <button className="ghost-btn wide" onClick={start} disabled={busy}>
        {busy ? "면접관을 부르는 중…" : "🎙️ 이 주제로 면접 보기"}
      </button>
      {error && <p className="form-error">{error}</p>}
      <p className="hint">
        읽은 직후가 가장 잘 기억날 때입니다. 카드를 덮고 답해 보세요.
      </p>
    </div>
  );
}
