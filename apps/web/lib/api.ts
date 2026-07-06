// 백엔드 API 클라이언트 + 타입 (apps/api DTO와 1:1 매칭)

export type TopicArea =
  | "SYSTEM_DESIGN"
  | "LOGISTICS"
  | "BACKEND_DEV"
  | "BACKEND_ARCHITECTURE"
  | "DATABASE"
  | "INFRA"
  | "CS";

export type LearningMode = "CONCEPT" | "DESIGN" | "INTERVIEW" | "REVIEW";

export interface CardSummary {
  id: string;
  area: TopicArea;
  mode: LearningMode;
  title: string;
  slug: string;
  summary: string | null;
  coach: string | null;
  difficulty: number;
  tags: string[];
  publishedAt: string | null;
}

export interface QuestionItem {
  id: string;
  question: string;
  displayOrder: number;
}

export interface CardDetail extends CardSummary {
  contentMd: string;
  status: string;
  qualityScore: number | null;
  source: string;
  questions: QuestionItem[];
  createdAt: string;
}

export interface FeedResponse {
  items: CardSummary[];
  nextCursor: string | null;
}

export const API_BASE =
  process.env.NEXT_PUBLIC_API_BASE ?? "http://localhost:8080";

export const AREA_LABELS: Record<TopicArea, string> = {
  SYSTEM_DESIGN: "시스템 디자인",
  LOGISTICS: "물류",
  BACKEND_DEV: "백엔드 개발",
  BACKEND_ARCHITECTURE: "아키텍처",
  DATABASE: "데이터베이스",
  INFRA: "인프라",
  CS: "CS 기초",
};

export async function getFeed(params: {
  area?: TopicArea;
  mode?: LearningMode;
  cursor?: string | null;
  limit?: number;
}): Promise<FeedResponse> {
  const q = new URLSearchParams();
  if (params.area) q.set("area", params.area);
  if (params.mode) q.set("mode", params.mode);
  if (params.cursor) q.set("cursor", params.cursor);
  q.set("limit", String(params.limit ?? 20));

  const res = await fetch(`${API_BASE}/api/v1/cards?${q.toString()}`, {
    cache: "no-store",
  });
  if (!res.ok) throw new Error(`feed failed: ${res.status}`);
  return res.json();
}

export async function getCard(id: string): Promise<CardDetail> {
  const res = await fetch(`${API_BASE}/api/v1/cards/${id}`, {
    cache: "no-store",
  });
  if (!res.ok) throw new Error(`card failed: ${res.status}`);
  return res.json();
}

// ── interactions (답변/북마크 — 기기 간 동기화) ──

export interface AnswerItem {
  questionId: string;
  answer: string | null;
  updatedAt: string;
}

export interface Interactions {
  bookmarked: boolean;
  answers: AnswerItem[];
}

export async function getInteractions(cardId: string): Promise<Interactions> {
  const res = await fetch(`${API_BASE}/api/v1/cards/${cardId}/interactions`, {
    cache: "no-store",
  });
  if (!res.ok) throw new Error(`interactions failed: ${res.status}`);
  return res.json();
}

export async function saveAnswer(
  cardId: string,
  questionId: string,
  answer: string
): Promise<AnswerItem> {
  const res = await fetch(
    `${API_BASE}/api/v1/cards/${cardId}/answers/${questionId}`,
    {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ answer }),
    }
  );
  if (!res.ok) throw new Error(`saveAnswer failed: ${res.status}`);
  return res.json();
}

export async function toggleBookmark(
  cardId: string
): Promise<{ bookmarked: boolean }> {
  const res = await fetch(`${API_BASE}/api/v1/cards/${cardId}/bookmark`, {
    method: "POST",
  });
  if (!res.ok) throw new Error(`bookmark failed: ${res.status}`);
  return res.json();
}
