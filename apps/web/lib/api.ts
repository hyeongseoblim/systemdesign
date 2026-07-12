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

export const MODE_LABELS: Record<LearningMode, string> = {
  CONCEPT: "개념",
  DESIGN: "설계",
  INTERVIEW: "면접",
  REVIEW: "리뷰",
};

/** 읽음/완료 상태 — localStorage 키 (기기 로컬 학습 기록) */
export const readKey = (id: string) => `jobStudy::read::${id}`;
export const doneKey = (id: string) => `jobStudy::done::${id}`;

/** 요약 등 플레인 텍스트 자리에서 마크다운 문법 제거 */
export function stripMd(s: string): string {
  return s
    .replace(/\*\*([^*]+)\*\*/g, "$1")
    .replace(/\*([^*]+)\*/g, "$1")
    .replace(/`([^`]+)`/g, "$1")
    .replace(/\[([^\]]+)\]\([^)]*\)/g, "$1");
}

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
