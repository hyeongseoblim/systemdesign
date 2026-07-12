import { getCard, AREA_LABELS, MODE_LABELS, stripMd } from "@/lib/api";
import CardBody from "@/components/CardBody";
import QuestionAnswers from "@/components/QuestionAnswers";
import DifficultyDots from "@/components/DifficultyDots";
import ReadingProgress from "@/components/ReadingProgress";
import LearnActions from "@/components/LearnActions";
import Link from "next/link";
import { notFound } from "next/navigation";

export default async function CardPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;

  let card;
  try {
    card = await getCard(id);
  } catch {
    notFound();
  }

  const published = card.publishedAt
    ? new Date(card.publishedAt).toLocaleDateString("ko-KR", {
        year: "numeric",
        month: "long",
        day: "numeric",
      })
    : null;
  const isAI = card.source === "AI_GENERATED";

  return (
    <article className={`detail a-${card.area}`}>
      <ReadingProgress />
      <Link href="/" className="back">
        ← 피드로
      </Link>
      <div className="meta">
        <span className="badge">{AREA_LABELS[card.area]}</span>
        <span className="badge mode">{MODE_LABELS[card.mode] ?? card.mode}</span>
        <DifficultyDots level={card.difficulty} />
      </div>
      <h1>{card.title}</h1>
      {card.summary && stripMd(card.summary) !== card.title && (
        <p className="lede">{stripMd(card.summary)}</p>
      )}
      <div className="byline">
        {card.coach && <span className="coach">{card.coach}</span>}
        <span className="dot" />
        <span>{isAI ? "🤖 AI 생성" : "✍️ 직접 큐레이션"}</span>
        {isAI && card.qualityScore != null && (
          <>
            <span className="dot" />
            <span>품질 {card.qualityScore}점</span>
          </>
        )}
        {published && (
          <>
            <span className="dot" />
            <span>{published}</span>
          </>
        )}
      </div>
      <CardBody md={card.contentMd} />
      <QuestionAnswers cardId={card.id} questions={card.questions} />
      <LearnActions cardId={card.id} />
    </article>
  );
}
