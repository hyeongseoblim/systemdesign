"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import {
  CardSummary,
  FeedResponse,
  TopicArea,
  LearningMode,
  getFeed,
  AREA_LABELS,
  MODE_LABELS,
  readKey,
  stripMd,
} from "@/lib/api";
import DifficultyDots from "@/components/DifficultyDots";

function SkeletonCard() {
  return (
    <div className="skel" aria-hidden>
      <div className="line w40" />
      <div className="line w80" />
      <div className="line w60" />
    </div>
  );
}

export default function CardFeed({
  initial,
  area,
  mode,
}: {
  initial: FeedResponse;
  area?: TopicArea;
  mode?: LearningMode;
}) {
  const [items, setItems] = useState<CardSummary[]>(initial.items);
  const [cursor, setCursor] = useState<string | null>(initial.nextCursor);
  const [loading, setLoading] = useState(false);
  const [readSet, setReadSet] = useState<Set<string>>(new Set());
  const sentinelRef = useRef<HTMLDivElement>(null);

  // 기기 로컬 읽음 기록 (hydration 이후 반영)
  useEffect(() => {
    const read = new Set<string>();
    for (const c of items) {
      if (localStorage.getItem(readKey(c.id))) read.add(c.id);
    }
    setReadSet(read);
  }, [items]);

  async function loadMore() {
    if (!cursor || loading) return;
    setLoading(true);
    try {
      const res = await getFeed({ area, mode, cursor, limit: 20 });
      setItems((prev) => [...prev, ...res.items]);
      setCursor(res.nextCursor);
    } finally {
      setLoading(false);
    }
  }

  // 무한 스크롤 — 센티널이 보이면 다음 페이지
  useEffect(() => {
    const el = sentinelRef.current;
    if (!el || !cursor) return;
    const io = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting) loadMore();
      },
      { rootMargin: "400px 0px" }
    );
    io.observe(el);
    return () => io.disconnect();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [cursor, loading]);

  if (items.length === 0) {
    return (
      <p className="empty">
        <span className="glyph">🗂️</span>
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
          const isRead = readSet.has(c.id);
          return (
            <Link
              key={c.id}
              href={`/cards/${c.id}`}
              className={`card a-${c.area} ${isRead ? "is-read" : ""}`}
            >
              <div className="meta">
                <span className="badge">{AREA_LABELS[c.area]}</span>
                <span className="badge mode">{MODE_LABELS[c.mode] ?? c.mode}</span>
                {isRead && <span className="read-check">✓ 읽음</span>}
                <DifficultyDots level={c.difficulty} />
              </div>
              <h2>{c.title}</h2>
              {c.summary && stripMd(c.summary) !== c.title && (
                <p className="summary">{stripMd(c.summary)}</p>
              )}
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
          );
        })}
        {loading && (
          <>
            <SkeletonCard />
            <SkeletonCard />
          </>
        )}
      </div>
      {cursor && (
        <>
          <div ref={sentinelRef} className="sentinel" aria-hidden />
          <button className="loadmore" onClick={loadMore} disabled={loading}>
            {loading ? "불러오는 중…" : "더 보기"}
          </button>
        </>
      )}
    </>
  );
}
