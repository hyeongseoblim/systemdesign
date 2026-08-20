import Link from "next/link";
import { TopicArea, AREA_LABELS } from "@/lib/api";
import InterviewStarter from "@/components/InterviewStarter";

const AREAS = Object.keys(AREA_LABELS) as TopicArea[];

export default async function InterviewHome({
  searchParams,
}: {
  searchParams: Promise<{ area?: string; topic?: string; difficulty?: string }>;
}) {
  const params = await searchParams;
  const initialArea = AREAS.includes(params.area as TopicArea)
    ? (params.area as TopicArea)
    : "SYSTEM_DESIGN";
  const parsedDifficulty = Number(params.difficulty);
  const initialDifficulty = Number.isInteger(parsedDifficulty) && parsedDifficulty >= 1 && parsedDifficulty <= 5
    ? parsedDifficulty
    : 4;

  return (
    <>
      <header className="topbar">
        <div className="brand">
          <h1>면접 시뮬레이션</h1>
          <p>ChatGPT 웹으로 무료 연습</p>
        </div>
      </header>

      <Link href="/" className="back">
        ← 카드 피드로
      </Link>

      <div className="cost-note">
        <strong>별도 API 키나 결제가 필요하지 않습니다.</strong>
        <p>면접 대화와 기록은 사용자의 ChatGPT 계정에서 관리됩니다.</p>
      </div>

      <InterviewStarter
        initialArea={initialArea}
        initialTopic={params.topic ?? ""}
        initialDifficulty={initialDifficulty}
      />
    </>
  );
}
