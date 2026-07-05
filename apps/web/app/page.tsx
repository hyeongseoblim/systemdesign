import { getFeed, AREA_LABELS, TopicArea } from "@/lib/api";
import CardFeed from "@/components/CardFeed";
import Link from "next/link";

const AREAS = Object.keys(AREA_LABELS) as TopicArea[];

export default async function Home({
  searchParams,
}: {
  searchParams: Promise<{ area?: string }>;
}) {
  const { area } = await searchParams;
  const activeArea = AREAS.includes(area as TopicArea)
    ? (area as TopicArea)
    : undefined;

  let initial;
  let error: string | null = null;
  try {
    initial = await getFeed({ area: activeArea, limit: 20 });
  } catch (e) {
    error = e instanceof Error ? e.message : "불러오기 실패";
    initial = { items: [], nextCursor: null };
  }

  return (
    <>
      <header className="topbar">
        <div className="row">
          <h1>오늘의 카드</h1>
          {initial.items.length > 0 && (
            <span className="count">{initial.items.length}장</span>
          )}
        </div>
        <p>매일 쌓이는 백엔드 · 시스템 디자인 학습 카드</p>
        <nav className="tabs">
          <Link className={`tab ${!activeArea ? "active" : ""}`} href="/">
            전체
          </Link>
          {AREAS.map((a) => (
            <Link
              key={a}
              className={`tab ${activeArea === a ? "active" : ""}`}
              href={`/?area=${a}`}
            >
              {AREA_LABELS[a]}
            </Link>
          ))}
        </nav>
      </header>

      {error ? (
        <p className="empty">
          API에 연결할 수 없습니다.
          <br />
          백엔드가 실행 중인지 확인하세요.
        </p>
      ) : (
        <CardFeed initial={initial} area={activeArea} />
      )}
    </>
  );
}
