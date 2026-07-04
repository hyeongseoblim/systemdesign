import { getCard, AREA_LABELS } from "@/lib/api";
import CardBody from "@/components/CardBody";
import QuestionAnswers from "@/components/QuestionAnswers";
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

  return (
    <article className="detail">
      <Link href="/" className="back">
        ← 피드로
      </Link>
      <div className="meta">
        <span className="badge">{AREA_LABELS[card.area]}</span>
        {card.coach && <span className="badge mode">{card.coach}</span>}
        <span className="diff">난이도 {card.difficulty}/5</span>
      </div>
      <h1>{card.title}</h1>
      <CardBody md={card.contentMd} />
      <QuestionAnswers cardId={card.id} questions={card.questions} />
    </article>
  );
}
