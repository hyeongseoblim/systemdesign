"use client";

import { useState } from "react";
import Link from "next/link";
import { AREA_LABELS, MODE_LABELS, stripMd, type CardSummary, type TopicArea } from "@/lib/api";
import { homeLearning, randomRecommendation } from "@/lib/home";
import { STARTER_LESSONS } from "@/lib/starterPath";
import type { StudyRecord } from "@/lib/study";

function Icon({ type }: { type: "learn" | "review" | "explore" | "interview" }) {
  const paths = {
    learn: "M4 4h6c1 0 2 1 2 2 0-1 1-2 2-2h6v15h-6c-1 0-2 1-2 2 0-1-1-2-2-2H4V4Zm8 2v15",
    review: "M3 10a9 9 0 1 1 2 8M3 4v6h6m3-3v5l3 2",
    explore: "M3 3h7v7H3V3Zm11 0h7v7h-7V3ZM3 14h7v7H3v-7Zm11 0h7v7h-7v-7Z",
    interview: "M21 11a9 9 0 0 1-9 9H3l2-5a9 9 0 1 1 16-4ZM8 10h8m-8 4h5",
  };
  return <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={paths[type]} /></svg>;
}

const TOPIC_HINTS: Record<TopicArea, string> = {
  SYSTEM_DESIGN: "분산 시스템 · 확장성 · 일관성",
  LOGISTICS: "주문 · 재고 · 배송 · 풀필먼트",
  BACKEND_DEV: "API · 동시성 · 테스트",
  BACKEND_ARCHITECTURE: "MSA · 이벤트 · 서비스 경계",
  DATABASE: "인덱스 · 트랜잭션 · 저장소",
  INFRA: "컨테이너 · Kubernetes · 운영",
  CS: "네트워크 · 메모리 · 운영체제",
  AI: "LLM · RAG · 평가 · 에이전트",
};

export default function HomeDashboard({ cards, records, ready, loading, error, cardHref, rememberPosition }: {
  cards: CardSummary[]; records: Record<string, StudyRecord>; ready: boolean; loading: boolean; error: boolean;
  cardHref: (id: string) => string; rememberPosition: () => void;
}) {
  const state = homeLearning(cards, records);
  const [randomId, setRandomId] = useState<string>();
  const randomCard = cards.find(card => card.id === randomId);
  const settled = ready && !loading && !error;
  const primaryTitle = state.action === "continue" ? "이어서 학습" : state.action === "review" ? "지금 복습할 한 장" : state.action === "starter" ? "첫 학습 시작하기" : "다음 학습";
  function lessonCard(card: CardSummary, label?: string) {
    const record = records[card.id] ?? {};
    const review = record.mastery === "review" || record.mastery === "hint";
    const starterLesson = label ? STARTER_LESSONS.find(lesson => lesson.slug === card.slug) : undefined;
    const summary = starterLesson?.takeaway ?? (card.summary ? stripMd(card.summary) : "");
    return <Link key={card.id} href={cardHref(card.id)} onClick={rememberPosition} className={`home-lesson-card a-${card.area}`}>
      <div className="home-lesson-top"><span>{AREA_LABELS[card.area]}</span><span className={`home-lesson-state ${record.done ? "completed" : ""}`}>{review ? "복습 필요" : record.done ? "✓ 완료" : record.read ? "학습 중" : label ?? MODE_LABELS[card.mode]}</span></div>
      <h3>{starterLesson?.label ?? card.title}</h3>
      {summary && summary !== card.title && <p>{summary}</p>}
      <div className="home-lesson-bottom"><span>{review || record.done ? "다시 학습하기" : record.read ? "이어서 학습하기" : "학습 시작하기"}</span><span aria-hidden="true">↗</span></div>
    </Link>;
  }
  const starters = STARTER_LESSONS.map((lesson, i) => {
    const card = cards.find((item) => item.slug === lesson.slug);
    return card ? lessonCard(card, `시작 ${i + 1}`) : null;
  });
  return <div className="home-dashboard">
    <header className="home-heading"><div><span className="eyebrow">MY LEARNING</span><h2>오늘의 학습</h2></div>
      <form action="/" className="home-search" role="search"><input type="hidden" name="view" value="explore" /><label htmlFor="home-search" className="sr-only">배우고 싶은 주제 찾기</label><input id="home-search" name="q" type="search" placeholder="배우고 싶은 주제 검색" /><button type="submit" aria-label="검색">→</button></form>
    </header>
    <nav className="home-metrics" aria-label="학습 현황"><Link href="/?view=explore&study=complete">완료 <strong>{settled ? state.completeCount : "—"}</strong></Link><Link href="/?view=review">복습 <strong>{settled ? state.review.length : "—"}</strong></Link><Link href="/?view=explore">전체 카드 <strong>{settled ? cards.length : "—"}</strong></Link></nav>
    <section className="home-topics" aria-label="주제별 카테고리"><div className="home-section-title"><h2>주제별로 골라보기</h2><Link href="/?view=explore">전체 보기 →</Link></div><div className="home-area-grid">{(Object.keys(AREA_LABELS) as TopicArea[]).map(area => <Link key={area} className={`home-area a-${area}`} href={`/?view=explore&area=${area}`}><div className="home-area-title"><span className="home-area-dot" aria-hidden="true" /><strong>{AREA_LABELS[area]}</strong><span aria-hidden="true">↗</span></div><p>{TOPIC_HINTS[area]}</p><span className="home-area-count">{settled ? `${cards.filter(card => card.area === area).length}개 카드` : "카드 탐색"}</span></Link>)}</div></section>
    <nav className="home-action-grid" aria-label="학습 선택" aria-busy={!settled}>
      <Link className="home-action-card primary" href={settled && state.primary ? cardHref(state.primary.id) : "/?view=explore"} onClick={rememberPosition}>
        <div className="home-action-top"><span className="home-action-icon"><Icon type="learn" /></span><span className="home-action-badge">{settled ? "추천" : "준비 중"}</span></div>
        <h3>{settled ? primaryTitle : error ? "목록 다시 확인" : "학습 불러오는 중"}</h3>
        <p>{settled && state.primary ? state.primary.title : error ? "전체 카드에서 다시 시도해 주세요." : settled ? "관심 있는 주제를 골라보세요." : "학습 기록을 확인하고 있어요."}</p>
        <span className="home-action-footer">{settled && state.primary ? "이 카드 열기" : "전체 카드 보기"}<span aria-hidden="true">→</span></span>
      </Link>
      <Link className="home-action-card" href="/?view=review"><div className="home-action-top"><span className="home-action-icon review"><Icon type="review" /></span><span className="home-action-count">{settled ? `${state.review.length}개` : "—"}</span></div><h3>복습하기</h3><p>{settled && state.review.length ? "다시 보고 싶은 카드를 떠올려 보세요." : "학습 중 저장한 카드를 다시 확인해요."}</p><span className="home-action-footer">복습 목록<span aria-hidden="true">→</span></span></Link>
      <Link className="home-action-card" href="/?view=explore"><div className="home-action-top"><span className="home-action-icon explore"><Icon type="explore" /></span><span className="home-action-count">{settled ? `${cards.length}개` : "전체"}</span></div><h3>전체 카드 탐색</h3><p>분야와 난이도로 원하는 학습을 찾아보세요.</p><span className="home-action-footer">카드 둘러보기<span aria-hidden="true">→</span></span></Link>
      <Link className="home-action-card" href="/interview"><div className="home-action-top"><span className="home-action-icon interview"><Icon type="interview" /></span></div><h3>면접 연습</h3><p>배운 내용을 말로 설명하며 확인해 보세요.</p><span className="home-action-footer">연습 시작하기<span aria-hidden="true">→</span></span></Link>
    </nav>
    {settled && <>
      <section className="home-random" aria-label="랜덤 학습 추천">
        <div className="home-section-title"><h2>무엇을 배울지 고민이라면</h2><button className="chip" onClick={() => setRandomId(randomRecommendation(cards, records, randomId)?.id)} disabled={!cards.length}>{randomCard ? "다시 추천" : "랜덤으로 한 장 추천"}</button></div>
        <p className="hint">미학습 카드부터 골라드려요. 모두 학습했다면 다시 볼 카드를 추천합니다.</p>
        <div aria-live="polite" aria-atomic="true">{randomCard ? <div className="home-random-result">{lessonCard(randomCard)}</div> : <p className="home-random-placeholder">추천을 누르면 학습 카드 한 장이 여기에 나타납니다.</p>}</div>
      </section>
      {!state.started && <section aria-label="초기 학습 안내"><div className="home-section-title"><h2>처음이라면, 이 5장부터</h2><span>전체 {cards.length}개 중 선택 학습</span></div><div className="home-lesson-grid">{starters}</div></section>}
      {state.review.length > 0 && <section><div className="home-section-title"><h2>다시 볼 카드</h2><Link href="/?view=review">모두 보기 →</Link></div><div className="home-lesson-grid">{state.review.slice(0, 3).map(card => lessonCard(card))}</div></section>}
    </>}
    {settled && state.started && <details className="home-starter-archive"><summary>초기 5장 {state.starterComplete ? "다시 보기" : "이어보기"}<span>{state.starterDone}/{STARTER_LESSONS.length} 완료</span></summary><div className="home-lesson-grid">{starters}</div></details>}
    <p className="home-storage-note">학습 기록은 이 브라우저에 저장됩니다.</p>
  </div>;
}
