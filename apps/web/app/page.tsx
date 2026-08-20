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
          <Link href="/" className="brand-home" aria-label="STUDY WITH JOB 홈">
            <span className="brand-mark" aria-hidden="true">S</span>
            <span className="brand-copy">
              <h1>STUDY WITH JOB</h1>
              <p>커리어를 만드는 기술 학습</p>
            </span>
          </Link>
          <Link href="/interview" className="brand-action">
            <span aria-hidden="true">●</span>
            AI 면접
          </Link>
        </div>
        <div className="filter-panel" aria-label="학습 카드 필터">
          <div className="filter-group">
            <div className="filter-heading">
              <span>카테고리</span>
              <strong>{activeArea ? AREA_LABELS[activeArea] : "전체"}</strong>
            </div>
            <nav className="tabs" aria-label="카테고리 필터">
              <Link
                className={`tab t-all ${!activeArea ? "active" : ""}`}
                href={feedHref(undefined, activeMode)}
                aria-current={!activeArea ? "page" : undefined}
              >
                전체
              </Link>
              {AREAS.map((a) => (
                <Link
                  key={a}
                  className={`tab a-${a} ${activeArea === a ? "active" : ""}`}
                  href={feedHref(a, activeMode)}
                  aria-current={activeArea === a ? "page" : undefined}
                >
                  {AREA_LABELS[a]}
                </Link>
              ))}
            </nav>
          </div>
          <div className="filter-group mode-filter">
            <div className="filter-heading">
              <span>학습 모드</span>
              <strong>{activeMode ? MODE_LABELS[activeMode] : "모든 모드"}</strong>
            </div>
            <nav className="tabs sub" aria-label="학습 모드 필터">
              <Link
                className={`tab ${!activeMode ? "active" : ""}`}
                href={feedHref(activeArea, undefined)}
                aria-current={!activeMode ? "page" : undefined}
              >
                모든 모드
              </Link>
              {MODES.map((m) => (
                <Link
                  key={m}
                  className={`tab ${activeMode === m ? "active" : ""}`}
                  href={feedHref(activeArea, m)}
                  aria-current={activeMode === m ? "page" : undefined}
                >
                  {MODE_LABELS[m]}
                </Link>
              ))}
            </nav>
          </div>
        </div>
        <ActiveTabScroller filterKey={`${activeArea ?? "ALL"}:${activeMode ?? "ALL"}`} />
      </header>

      {error ? (
        <p className="empty">
          <span className="glyph">📡</span>
          API에 연결할 수 없습니다.
          <br />
          백엔드가 실행 중인지 확인하세요.
        </p>
      ) : (
        <CardFeed
          key={`${activeArea ?? "ALL"}:${activeMode ?? "ALL"}`}
          initial={initial}
          area={activeArea}
          mode={activeMode}
        />
      )}
    </>
  );
}
