// Signal 디자인 시스템 — 영역/모드/난이도 메타 + 라인 아이콘.
// 색·아이콘 path 는 디자인 브리프(jobStudy Directions · 1a Signal)에서 포팅.
import type { ReactNode } from "react";
import type { TopicArea, LearningMode } from "./api";

/* ── 아이콘 래퍼 (24 그리드, currentColor 스트로크) ── */
function Svg({ size = 16, children }: { size?: number; children: ReactNode }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.8}
      strokeLinecap="round"
      strokeLinejoin="round"
      style={{ display: "block", flex: "none" }}
      aria-hidden
    >
      {children}
    </svg>
  );
}

/* ── 7 영역: 색 + 라인 아이콘 ── */
export const AREA_META: Record<TopicArea, { label: string; color: string }> = {
  SYSTEM_DESIGN: { label: "시스템 디자인", color: "#38BDF8" },
  INFRA: { label: "인프라", color: "#2DD4BF" },
  BACKEND_ARCHITECTURE: { label: "아키텍처", color: "#34D399" },
  CS: { label: "CS 기초", color: "#A3E635" },
  LOGISTICS: { label: "물류", color: "#FBBF24" },
  DATABASE: { label: "데이터베이스", color: "#FB7185" },
  BACKEND_DEV: { label: "백엔드 개발", color: "#A78BFA" },
};

/** 배지 배경용 틴트 (색 + 13% 알파) */
export const tint = (hex: string) => `${hex}22`;

export function AreaIcon({ area, size = 16 }: { area: TopicArea; size?: number }) {
  switch (area) {
    case "SYSTEM_DESIGN":
      return (
        <Svg size={size}>
          <circle cx="6" cy="6" r="2.3" />
          <circle cx="18" cy="6" r="2.3" />
          <circle cx="12" cy="18" r="2.3" />
          <line x1="8" y1="6" x2="16" y2="6" />
          <line x1="7.4" y1="7.7" x2="10.9" y2="16.1" />
          <line x1="16.6" y1="7.7" x2="13.1" y2="16.1" />
        </Svg>
      );
    case "INFRA":
      return (
        <Svg size={size}>
          <path d="M7.4 18a3.9 3.9 0 01-.4-7.78 5 5 0 019.5-1.05A3.75 3.75 0 1117 18z" />
        </Svg>
      );
    case "BACKEND_ARCHITECTURE":
      return (
        <Svg size={size}>
          <path d="M12 3l8 4-8 4-8-4z" />
          <path d="M4 12l8 4 8-4" />
          <path d="M4 16.5l8 4 8-4" />
        </Svg>
      );
    case "CS":
      return (
        <Svg size={size}>
          <path d="M5 5a2 2 0 012-2h12v15H7a2 2 0 00-2 2z" />
          <path d="M5 20a2 2 0 012-2h12" />
          <line x1="9" y1="7.5" x2="15" y2="7.5" />
          <line x1="9" y1="10.5" x2="13" y2="10.5" />
        </Svg>
      );
    case "LOGISTICS":
      return (
        <Svg size={size}>
          <rect x="2" y="7" width="11" height="8" rx="1.2" />
          <path d="M13 9.5h4l3 3v2.5h-7z" />
          <circle cx="6.5" cy="17" r="1.7" />
          <circle cx="16.5" cy="17" r="1.7" />
        </Svg>
      );
    case "DATABASE":
      return (
        <Svg size={size}>
          <path d="M4 6c0-1.66 3.58-3 8-3s8 1.34 8 3-3.58 3-8 3-8-1.34-8-3z" />
          <path d="M4 6v6c0 1.66 3.58 3 8 3s8-1.34 8-3V6" />
          <path d="M4 12v6c0 1.66 3.58 3 8 3s8-1.34 8-3v-6" />
        </Svg>
      );
    case "BACKEND_DEV":
      return (
        <Svg size={size}>
          <rect x="3" y="4" width="18" height="16" rx="2" />
          <path d="M7.5 9l3 3-3 3" />
          <line x1="13" y1="15" x2="17" y2="15" />
        </Svg>
      );
  }
}

/* ── 4 모드: 한/영 라벨 + 아이콘 ── */
export const MODE_META: Record<LearningMode, { ko: string; en: string }> = {
  CONCEPT: { ko: "개념", en: "CONCEPT" },
  DESIGN: { ko: "설계", en: "DESIGN" },
  INTERVIEW: { ko: "면접", en: "INTERVIEW" },
  REVIEW: { ko: "리뷰", en: "REVIEW" },
};

export function ModeIcon({ mode, size = 13 }: { mode: LearningMode; size?: number }) {
  switch (mode) {
    case "CONCEPT":
      return (
        <Svg size={size}>
          <path d="M12 3a6 6 0 00-3.7 10.7c.5.4.7 1 .7 1.6v.2h6v-.2c0-.6.2-1.2.7-1.6A6 6 0 0012 3z" />
          <line x1="9.5" y1="18" x2="14.5" y2="18" />
          <line x1="10.5" y1="20.5" x2="13.5" y2="20.5" />
        </Svg>
      );
    case "DESIGN":
      return (
        <Svg size={size}>
          <circle cx="12" cy="12" r="8.5" />
          <path d="M15 9l-1.7 4.3L9 15l1.7-4.3z" />
        </Svg>
      );
    case "INTERVIEW":
      return (
        <Svg size={size}>
          <path d="M4.5 5.5h15v10H9l-4.5 3.4z" />
        </Svg>
      );
    case "REVIEW":
      return (
        <Svg size={size}>
          <path d="M4.8 12a7.2 7.2 0 0112-5.4M18.5 4.6v3.6H15" />
          <path d="M19.2 12a7.2 7.2 0 01-12 5.4M5.5 19.4V15.8H9" />
        </Svg>
      );
  }
}

/* ── 난이도(1~5) → 3 라벨 ── */
export function difficultyMeta(n: number): { label: string; color: string; ink: string } {
  if (n <= 2) return { label: "초급", color: "#34D399", ink: "#0B1B14" };
  if (n === 3) return { label: "중급", color: "#FBBF24", ink: "#231803" };
  return { label: "고급", color: "#FB7185", ink: "#2A0D12" };
}

/* ── 공용 아이콘 ── */
export const BackIcon = ({ size = 18 }: { size?: number }) => (
  <Svg size={size}>
    <path d="M15 5l-7 7 7 7" />
  </Svg>
);
export const BookmarkIcon = ({ size = 16 }: { size?: number }) => (
  <Svg size={size}>
    <path d="M6 4h12v16l-6-4-6 4z" />
  </Svg>
);
export const StarIcon = ({ size = 12 }: { size?: number }) => (
  <Svg size={size}>
    <path d="M12 4l2.3 4.9 5.2.7-3.8 3.6 1 5.1L12 16.4 7.3 18.3l1-5.1-3.8-3.6 5.2-.7z" />
  </Svg>
);
export const WarnIcon = ({ size = 12 }: { size?: number }) => (
  <Svg size={size}>
    <path d="M12 4l9 15H3z" />
    <line x1="12" y1="10" x2="12" y2="14" />
    <line x1="12" y1="16.5" x2="12" y2="16.6" />
  </Svg>
);
export const TipIcon = ({ size = 12 }: { size?: number }) => (
  <Svg size={size}>
    <path d="M20 6L9 17l-5-5" />
  </Svg>
);
export const QIcon = ({ size = 14 }: { size?: number }) => (
  <Svg size={size}>
    <path d="M9 9a3 3 0 114 2.8c-.8.4-1 .8-1 1.7" />
    <line x1="12" y1="16.5" x2="12" y2="16.6" />
  </Svg>
);
