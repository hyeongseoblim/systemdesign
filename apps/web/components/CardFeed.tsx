"use client";

import { useState, type CSSProperties } from "react";
import Link from "next/link";
import { CardSummary, FeedResponse, TopicArea, getFeed } from "@/lib/api";
import {
  AREA_META,
  AreaIcon,
  MODE_META,
  ModeIcon,
  difficultyMeta,
  tint,
} from "@/lib/design";

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
        {items.map((c) => {
          const a = AREA_META[c.area];
          const diff = difficultyMeta(c.difficulty);
          const cardVars = {
            "--area": a.color,
            "--area-tint": tint(a.color),
          } as CSSProperties;
          return (
            <Link key={c.id} href={`/cards/${c.id}`} className="card" style={cardVars}>
              <div className="meta">
                <span className="badge area">
                  <AreaIcon area={c.area} size={12} />
                  {a.label}
                </span>
                <span className="badge mode">
                  <ModeIcon mode={c.mode} size={11} />
                  {MODE_META[c.mode].ko}
                </span>
                <span
                  className="badge diff"
                  style={{ background: diff.color, color: diff.ink }}
                >
                  {diff.label}
                </span>
              </div>
              <h2>{c.title}</h2>
              {c.summary && <p className="summary">{c.summary}</p>}
              {c.tags.length > 0 && (
                <div className="tags">
                  {c.tags.slice(0, 3).map((t) => (
                    <span key={t} className="tag">
                      {t}
                    </span>
                  ))}
                </div>
              )}
            </Link>
          );
        })}
      </div>
      {cursor && (
        <button className="loadmore" onClick={loadMore} disabled={loading}>
          {loading ? "불러오는 중…" : "더 보기"}
        </button>
      )}
    </>
  );
}
