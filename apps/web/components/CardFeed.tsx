"use client";

import { useState } from "react";
import Link from "next/link";
import {
  CardSummary,
  FeedResponse,
  TopicArea,
  getFeed,
  AREA_LABELS,
} from "@/lib/api";

const MODE_LABELS: Record<string, string> = {
  CONCEPT: "개념",
  DESIGN: "설계",
  INTERVIEW: "면접",
  REVIEW: "리뷰",
};

export default function CardFeed({
  initial,
  area,
}: {
  initial: FeedResponse;
  area?: TopicArea;
}) {
  const [items, setItems] = useState<CardSummary[]>(initial.items);
  const [cursor, setCursor] = useState<string | null>(initial.nextCursor);
  const [loading, setLoading] = useState(false);

  async function loadMore() {
    if (!cursor || loading) return;
    setLoading(true);
    try {
      const res = await getFeed({ area, cursor, limit: 20 });
      setItems((prev) => [...prev, ...res.items]);
      setCursor(res.nextCursor);
    } finally {
      setLoading(false);
    }
  }

  if (items.length === 0) {
    return (
      <p className="empty">
        아직 학습 카드가 없습니다.
        <br />
        생성 배치가 돌면 여기에 쌓입니다.
      </p>
    );
  }

  return (
    <>
      <div className="feed">
        {items.map((c) => (
          <Link key={c.id} href={`/cards/${c.id}`} className="card">
            <div className="meta">
              <span className="badge">{AREA_LABELS[c.area]}</span>
              <span className="badge mode">{MODE_LABELS[c.mode] ?? c.mode}</span>
              <span className="diff">난이도 {c.difficulty}/5</span>
            </div>
            <h2>{c.title}</h2>
            {c.summary && <p className="summary">{c.summary}</p>}
            {c.tags.length > 0 && (
              <div className="tags">
                {c.tags.slice(0, 4).map((t) => (
                  <span key={t} className="tag">
                    #{t}
                  </span>
                ))}
              </div>
            )}
          </Link>
        ))}
      </div>
      {cursor && (
        <button className="loadmore" onClick={loadMore} disabled={loading}>
          {loading ? "불러오는 중…" : "더 보기"}
        </button>
      )}
    </>
  );
}
