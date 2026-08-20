import Link from "next/link";
import { notFound } from "next/navigation";
import { getInterview, AREA_LABELS, STATUS_LABELS } from "@/lib/api";
import InterviewChat from "@/components/InterviewChat";
import DifficultyDots from "@/components/DifficultyDots";

export default async function InterviewSessionPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;

  let session;
  try {
    session = await getInterview(id);
  } catch {
    notFound();
  }

  return (
    <article className={`detail a-${session.area}`}>
      <Link href="/interview" className="back">
        ← 면접 목록으로
      </Link>
      <div className="meta">
        <span className="badge">{AREA_LABELS[session.area]}</span>
        <span className={`badge status s-${session.status}`}>
          {STATUS_LABELS[session.status]}
        </span>
        <DifficultyDots level={session.difficulty} />
      </div>
      <h1>{session.topic}</h1>
      <div className="byline">
        {session.coach && <span className="coach">{session.coach}</span>}
        <span className="dot" />
        <span>
          {new Date(session.startedAt).toLocaleDateString("ko-KR", {
            year: "numeric",
            month: "long",
            day: "numeric",
          })}
        </span>
      </div>

      <InterviewChat initial={session} />
    </article>
  );
}
