import Link from "next/link";
import {
  listInterviews,
  AREA_LABELS,
  STATUS_LABELS,
  InterviewSummary,
} from "@/lib/api";
import InterviewStarter from "@/components/InterviewStarter";
import DifficultyDots from "@/components/DifficultyDots";

export default async function InterviewHome() {
  let past: InterviewSummary[] = [];
  let error: string | null = null;
  try {
    past = await listInterviews(10);
  } catch (e) {
    error = e instanceof Error ? e.message : "불러오기 실패";
  }

  return (
    <>
      <header className="topbar">
        <div className="brand">
          <h1>면접 시뮬레이션</h1>
          <p>답하고, 압박받고, 피드백 받기</p>
        </div>
      </header>

      <Link href="/" className="back">
        ← 카드 피드로
      </Link>

      <InterviewStarter />

      <h2 className="section-title">지난 면접</h2>
      {error ? (
        <p className="empty">
          <span className="glyph">📡</span>
          API에 연결할 수 없습니다.
        </p>
      ) : past.length === 0 ? (
        <p className="empty">
          <span className="glyph">🎙️</span>
          아직 진행한 면접이 없습니다.
        </p>
      ) : (
        <div className="feed">
          {past.map((s) => (
            <Link
              key={s.id}
              href={`/interview/${s.id}`}
              className={`card a-${s.area}`}
            >
              <div className="meta">
                <span className="badge">{AREA_LABELS[s.area]}</span>
                <span className={`badge status s-${s.status}`}>
                  {STATUS_LABELS[s.status]}
                </span>
                <DifficultyDots level={s.difficulty} />
              </div>
              <h2>{s.topic}</h2>
              <p className="summary">
                {s.turnCount}턴 ·{" "}
                {new Date(s.startedAt).toLocaleDateString("ko-KR", {
                  month: "long",
                  day: "numeric",
                })}
              </p>
            </Link>
          ))}
        </div>
      )}
    </>
  );
}
