/** 난이도 1~5 도트 시각화 — 서버/클라이언트 공용 */
export default function DifficultyDots({ level }: { level: number }) {
  return (
    <span className="diff" aria-label={`난이도 ${level}/5`}>
      <span className="diff-label">난이도 {level}</span>
      <span className="diff-dots" aria-hidden="true">
        {[1, 2, 3, 4, 5].map((n) => (
          <i key={n} className={n <= level ? "on" : ""} />
        ))}
      </span>
    </span>
  );
}
