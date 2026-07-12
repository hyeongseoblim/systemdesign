import { getFeed, AREA_LABELS, MODE_LABELS, TopicArea, LearningMode } from "@/lib/api";
import CardFeed from "@/components/CardFeed";
import ActiveTabScroller from "@/components/ActiveTabScroller";
import Link from "next/link";

const AREAS = Object.keys(AREA_LABELS) as TopicArea[];
const MODES = Object.keys(MODE_LABELS) as LearningMode[];

function feedHref(area?: TopicArea, mode?: LearningMode) {
  const q = new URLSearchParams();
  if (area) q.set("area", area);
  if (mode) q.set("mode", mode);
  const s = q.toString();
  return s ? `/?${s}` : "/";
}

export default async function Home({
  searchParams,
}: {
  searchParams: Promise<{ area?: string; mode?: string }>;
}) {
  const { area, mode } = await searchParams;
  const activeArea = AREAS.includes(area as TopicArea)
    ? (area as TopicArea)
    : undefined;
  const activeMode = MODES.includes(mode as LearningMode)
    ? (mode as LearningMode)
    : undefined;

  let initial;
  let error: string | null = null;
  try {
    initial = await getFeed({ area: activeArea, mode: activeMode, limit: 20 });
  } catch (e) {
    error = e instanceof Error ? e.message : "불러오기 실패";
    initial = { items: [], nextCursor: null };
  }

  return (
    <>
      <header className="topbar">
        <div className="brand">
          <h1>jobStudy</h1>
          <p>백엔드 · 시스템 디자인 학습 카드</p>
        </div>
        <nav className="tabs">
          <Link
            className={`tab t-all ${!activeArea ? "active" : ""}`}
            href={feedHref(undefined, activeMode)}
          >
            전체
          </Link>
          {AREAS.map((a) => (
            <Link
              key={a}
              className={`tab a-${a} ${activeArea === a ? "active" : ""}`}
              href={feedHref(a, activeMode)}
            >
              {AREA_LABELS[a]}
            </Link>
          ))}
        </nav>
        <nav className="tabs sub">
          <Link
            className={`tab ${!activeMode ? "active" : ""}`}
            href={feedHref(activeArea, undefined)}
          >
            모든 모드
          </Link>
          {MODES.map((m) => (
            <Link
              key={m}
              className={`tab ${activeMode === m ? "active" : ""}`}
              href={feedHref(activeArea, m)}
            >
              {MODE_LABELS[m]}
            </Link>
          ))}
        </nav>
        <ActiveTabScroller />
      </header>

      {error ? (
        <p className="empty">
          <span className="glyph">📡</span>
          API에 연결할 수 없습니다.
          <br />
          백엔드가 실행 중인지 확인하세요.
        </p>
      ) : (
        <CardFeed initial={initial} area={activeArea} mode={activeMode} />
      )}
    </>
  );
}
