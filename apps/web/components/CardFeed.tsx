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
  MODE_GUIDES,
  readKey,
  doneKey,
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
  const [doneSet, setDoneSet] = useState<Set<string>>(new Set());
  const sentinelRef = useRef<HTMLDivElement>(null);

  // 필터 내비게이션에서 서버 데이터가 바뀌면 이전 필터의 클라이언트 상태를 폐기한다.
  useEffect(() => {
    setItems(initial.items);
    setCursor(initial.nextCursor);
    setLoading(false);
  }, [initial, area, mode]);

  // 기기 로컬 읽음 기록 (hydration 이후 반영)
  useEffect(() => {
    const read = new Set<string>();
    const done = new Set<string>();
    for (const c of items) {
      if (localStorage.getItem(readKey(c.id))) read.add(c.id);
      if (localStorage.getItem(doneKey(c.id))) done.add(c.id);
    }
    setReadSet(read);
    setDoneSet(done);
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
      <div className="empty">
        <span className="glyph">🗂️</span>
        <strong>조건에 맞는 학습 카드가 없습니다.</strong>
        <p>다른 카테고리나 학습 모드를 선택해 보세요.</p>
        {(area || mode) && <Link href="/" className="reset-filter">필터 초기화</Link>}
      </div>
    );
  }

  const completedCount = items.filter((item) => doneSet.has(item.id)).length;
  const readingCount = items.filter(
    (item) => readSet.has(item.id) && !doneSet.has(item.id)
  ).length;
  const newCount = Math.max(0, items.length - completedCount - readingCount);
  const filterParams = new URLSearchParams();
  if (area) filterParams.set("area", area);
  if (mode) filterParams.set("mode", mode);
  const filterQuery = filterParams.toString();
  const filterSuffix = filterQuery ? `?${filterQuery}` : "";

  return (
    <>
      <div className="feed-toolbar">
        <div className="feed-context">
          <span>학습 카드</span>
          <strong>
            {area ? AREA_LABELS[area] : "전체 카테고리"}
            <i aria-hidden="true">·</i>
            {mode ? MODE_LABELS[mode] : "모든 모드"}
          </strong>
        </div>
        <div className="feed-tools">
          <span className="result-count"><strong>{items.length}</strong>개</span>
          {(area || mode) && <Link href="/" className="reset-filter">필터 초기화</Link>}
        </div>
      </div>
      <div className="study-overview" aria-label="현재 목록 학습 현황">
        <span><i className="state-dot new" />새 학습 <strong>{newCount}</strong></span>
        <span><i className="state-dot reading" />학습 중 <strong>{readingCount}</strong></span>
        <span><i className="state-dot complete" />완료 <strong>{completedCount}</strong></span>
      </div>
      <div className="feed">
        {items.map((c) => {
          const isRead = readSet.has(c.id);
          const isDone = doneSet.has(c.id);
          const studyState = isDone ? "complete" : isRead ? "reading" : "new";
          return (
            <Link
              key={c.id}
              href={`/cards/${c.id}${filterSuffix}`}
              className={`card a-${c.area} state-${studyState}`}
            >
              <div className="meta">
                <span className="badge">{AREA_LABELS[c.area]}</span>
                <span className="badge mode">{MODE_LABELS[c.mode] ?? c.mode}</span>
                <span className={`study-state ${studyState}`}>
                  {isDone ? "✓ 완료" : isRead ? "● 학습 중" : "새 학습"}
                </span>
                <DifficultyDots level={c.difficulty} />
              </div>
              <h2>{c.title}</h2>
              {c.summary && stripMd(c.summary) !== c.title && (
                <p className="summary">{stripMd(c.summary)}</p>
              )}
              <p className="learning-cue">
                <span>학습 초점</span>
                {MODE_GUIDES[c.mode]}
              </p>
              {c.tags.length > 0 && (
                <div className="tags">
                  {c.tags.slice(0, 4).map((t) => (
                    <span key={t} className="tag">
                      #{t}
                    </span>
                  ))}
                </div>
              )}
              <div className="card-cta" aria-hidden="true">
                <span>{isDone ? "다시 복습하기" : isRead ? "이어서 학습하기" : "학습 시작하기"}</span>
                <b>→</b>
              </div>
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
