import {
  getFeed,
  AREA_LABELS,
  MODE_LABELS,
  DIFFICULTY_LABELS,
  TopicArea,
  LearningMode,
  DifficultyLevel,
} from "@/lib/api";
import CardFeed from "@/components/CardFeed";
import ActiveTabScroller from "@/components/ActiveTabScroller";
import Link from "next/link";

const AREAS = Object.keys(AREA_LABELS) as TopicArea[];
const MODES = Object.keys(MODE_LABELS) as LearningMode[];
// 현재 큐레이션 카드가 존재하는 난이도만 노출한다. API 자체는 1~5를 모두 지원한다.
const DIFFICULTIES = [3, 4, 5] as DifficultyLevel[];

function feedHref(area?: TopicArea, mode?: LearningMode, difficulty?: DifficultyLevel) {
  const q = new URLSearchParams();
  if (area) q.set("area", area);
  if (mode) q.set("mode", mode);
  if (difficulty) q.set("difficulty", String(difficulty));
  const s = q.toString();
  return s ? `/?${s}` : "/";
}

export default async function Home({
  searchParams,
}: {
  searchParams: Promise<{ area?: string; mode?: string; difficulty?: string }>;
}) {
  const { area, mode, difficulty } = await searchParams;
  const activeArea = AREAS.includes(area as TopicArea)
    ? (area as TopicArea)
    : undefined;
  const activeMode = MODES.includes(mode as LearningMode)
    ? (mode as LearningMode)
    : undefined;
  const parsedDifficulty = Number(difficulty);
  const activeDifficulty = DIFFICULTIES.includes(parsedDifficulty as DifficultyLevel)
    ? (parsedDifficulty as DifficultyLevel)
    : undefined;
  const shuffleSeed = Math.floor(Math.random() * 2_147_483_647);

  let initial;
  let error: string | null = null;
  try {
    initial = await getFeed({
      area: activeArea,
      mode: activeMode,
      difficulty: activeDifficulty,
      shuffleSeed,
      limit: 20,
    });
  } catch (e) {
    error = e instanceof Error ? e.message : "불러오기 실패";
    initial = { items: [], nextCursor: null };
  }

  return (
    <>
      <header className="topbar home-topbar">
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
            </div>
            <nav className="tabs" aria-label="카테고리 필터">
              <Link
                className={`tab t-all ${!activeArea ? "active" : ""}`}
                href={feedHref(undefined, activeMode, activeDifficulty)}
                aria-current={!activeArea ? "page" : undefined}
              >
                전체
              </Link>
              {AREAS.map((a) => (
                <Link
                  key={a}
                  className={`tab a-${a} ${activeArea === a ? "active" : ""}`}
                  href={feedHref(a, activeMode, activeDifficulty)}
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
            </div>
            <nav className="tabs sub" aria-label="학습 모드 필터">
              <Link
                className={`tab ${!activeMode ? "active" : ""}`}
                href={feedHref(activeArea, undefined, activeDifficulty)}
                aria-current={!activeMode ? "page" : undefined}
              >
                모든 모드
              </Link>
              {MODES.map((m) => (
                <Link
                  key={m}
                  className={`tab ${activeMode === m ? "active" : ""}`}
                  href={feedHref(activeArea, m, activeDifficulty)}
                  aria-current={activeMode === m ? "page" : undefined}
                >
                  {MODE_LABELS[m]}
                </Link>
              ))}
            </nav>
          </div>
          <div className="filter-group difficulty-filter">
            <div className="filter-heading">
              <span>난이도</span>
            </div>
            <nav className="tabs sub" aria-label="난이도 필터">
              <Link
                className={`tab ${!activeDifficulty ? "active" : ""}`}
                href={feedHref(activeArea, activeMode, undefined)}
                aria-current={!activeDifficulty ? "page" : undefined}
              >
                전체 난이도
              </Link>
              {DIFFICULTIES.map((level) => (
                <Link
                  key={level}
                  className={`tab ${activeDifficulty === level ? "active" : ""}`}
                  href={feedHref(activeArea, activeMode, level)}
                  aria-current={activeDifficulty === level ? "page" : undefined}
                >
                  {DIFFICULTY_LABELS[level]}
                </Link>
              ))}
            </nav>
          </div>
        </div>
        <ActiveTabScroller
          filterKey={`${activeArea ?? "ALL"}:${activeMode ?? "ALL"}:${activeDifficulty ?? "ALL"}`}
        />
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
          key={`${activeArea ?? "ALL"}:${activeMode ?? "ALL"}:${activeDifficulty ?? "ALL"}`}
          initial={initial}
          area={activeArea}
          mode={activeMode}
          difficulty={activeDifficulty}
          shuffleSeed={shuffleSeed}
        />
      )}
    </>
  );
}
