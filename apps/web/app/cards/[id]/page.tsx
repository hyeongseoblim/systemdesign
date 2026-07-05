import { getCard } from "@/lib/api";
import CardBody from "@/components/CardBody";
import QuestionAnswers from "@/components/QuestionAnswers";
import Link from "next/link";
import { notFound } from "next/navigation";
import type { CSSProperties } from "react";
import {
  AREA_META,
  AreaIcon,
  MODE_META,
  ModeIcon,
  difficultyMeta,
  tint,
  BackIcon,
} from "@/lib/design";

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

  const a = AREA_META[card.area];
  const diff = difficultyMeta(card.difficulty);
  const readingMin = Math.max(2, Math.round(card.contentMd.length / 450));
  const areaVars = { "--area": a.color, "--area-tint": tint(a.color) } as CSSProperties;

  return (
    <article className="detail" style={areaVars}>
      <div className="detail-top">
        <Link href="/" className="icon-btn" aria-label="피드로">
          <BackIcon />
        </Link>
        <span className="back-label">피드로</span>
      </div>

      <div className="meta">
        <span className="badge area">
          <AreaIcon area={card.area} size={13} />
          {a.label}
        </span>
        <span className="badge mode">
          <ModeIcon mode={card.mode} size={12} />
          {MODE_META[card.mode].ko}
        </span>
        <span className="badge diff" style={{ background: diff.color, color: diff.ink }}>
          {diff.label}
        </span>
      </div>

      <h1>{card.title}</h1>
      <div className="byline">
        <span className="avatar" />
        {card.coach ? `${card.coach} · ` : ""}예상 {readingMin}분
      </div>

      <CardBody md={card.contentMd} />
      <QuestionAnswers cardId={card.id} questions={card.questions} />
    </article>
  );
}
