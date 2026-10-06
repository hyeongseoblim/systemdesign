import type { CardSummary } from "./api";
import { STARTER_LESSONS, nextStarter } from "./starterPath";
import { needsReview, type StudyRecord } from "./study";

export function randomRecommendation(cards: CardSummary[], records: Record<string, StudyRecord>, previousId?: string, random = Math.random): CardSummary | undefined {
  const fresh = cards.filter(card => !records[card.id]?.read && !records[card.id]?.done && !records[card.id]?.mastery);
  const unfinished = cards.filter(card => !records[card.id]?.done);
  const pool = fresh.length ? fresh : unfinished.length ? unfinished : cards;
  const alternatives = pool.filter(card => card.id !== previousId);
  const candidates = alternatives.length ? alternatives : pool;
  return candidates.length ? candidates[Math.floor(random() * candidates.length)] : undefined;
}

export function homeLearning(cards: CardSummary[], records: Record<string, StudyRecord>) {
  const starterSlugs = new Set(STARTER_LESSONS.map((lesson) => lesson.slug));
  const starterCards = cards.filter((card) => starterSlugs.has(card.slug));
  const starterDone = starterCards.filter((card) => records[card.id]?.done).length;
  // 목록이 누락되어도 초기 학습 완료로 오인하지 않는다.
  const starterComplete = starterDone === STARTER_LESSONS.length;
  const started = cards.some((card) => {
    const record = records[card.id];
    return !!(record?.read || record?.done || record?.mastery);
  });
  const reading = cards.filter((card) => records[card.id]?.read && !records[card.id]?.done)
    .sort((a, b) => (records[b.id]?.read ?? "").localeCompare(records[a.id]?.read ?? ""))[0];
  const review = cards.filter((card) => needsReview(records[card.id] ?? {}));
  const fresh = cards.filter((card) => !starterSlugs.has(card.slug) && !records[card.id]?.read && !records[card.id]?.done && !records[card.id]?.mastery);
  const starter = nextStarter(cards, records);
  const exploring = cards.some((card) => !starterSlugs.has(card.slug) && !!(records[card.id]?.read || records[card.id]?.done || records[card.id]?.mastery));
  // 진행 중인 학습을 우선한다. 초기 학습 이후에는 복습과 일반 카드로 이어진다.
  const primary = reading ?? (!starterComplete && !started ? starter?.card : undefined) ?? review[0] ?? (!starterComplete && !exploring ? starter?.card : undefined) ?? fresh[0];
  const action = reading ? "continue" : primary && needsReview(records[primary.id] ?? {}) ? "review" : primary && starterSlugs.has(primary.slug) ? "starter" : "explore";
  const recommendations: CardSummary[] = [];
  for (const card of fresh) {
    if (card.id === primary?.id || recommendations.some((item) => item.area === card.area)) continue;
    recommendations.push(card);
    if (recommendations.length === 3) break;
  }
  return { starterDone, starterComplete, started, starter, primary, action, review, recommendations,
    completeCount: cards.filter((card) => records[card.id]?.done).length };
}
