"use client";

import { useEffect, useState } from "react";
import { readKey, doneKey } from "@/lib/api";
import { Mastery, MASTERY_LABELS, masteryKey, readStudy, writeStorage } from "@/lib/study";

export default function LearnActions({ cardId, step = 3, compact = false }: { cardId: string; step?: number; compact?: boolean }) {
  const [done, setDone] = useState(false);
  const [mastery, setMastery] = useState<Mastery>();
  const [error, setError] = useState(false);
  useEffect(() => {
    function refresh() {
      const record = readStudy(cardId);
      setDone(!!record.done);
      setMastery(record.mastery);
    }
    refresh();
    window.addEventListener("study-change", refresh);
    window.addEventListener("storage", refresh);
    setError(!writeStorage(readKey(cardId), new Date().toISOString()));
    return () => {
      window.removeEventListener("study-change", refresh);
      window.removeEventListener("storage", refresh);
    };
  }, [cardId]);
  function rate(value: Mastery) {
    if (!writeStorage(masteryKey(cardId), value)) { setError(true); return; }
    setMastery(value); setError(false);
  }
  function toggle() {
    if (!writeStorage(doneKey(cardId), done ? null : new Date().toISOString())) { setError(true); return; }
    setDone(!done); setError(false);
  }
  if (compact) return <div className="starter-record" aria-label="학습 기록">
    <div className="starter-record-buttons">
      <button className={`chip ${done ? "on" : ""}`} onClick={toggle} aria-pressed={done}>{done ? "✓ 학습 완료 · 표시 해제" : "학습 완료로 표시"}</button>
      <button className={`chip ${mastery === "review" || mastery === "hint" ? "on" : ""}`} onClick={() => rate(mastery === "review" || mastery === "hint" ? "confident" : "review")} aria-pressed={mastery === "review" || mastery === "hint"}>{mastery === "review" || mastery === "hint" ? "✓ 복습에 저장됨 · 해제" : "복습에 저장"}</button>
    </div>
    <p className="hint" aria-live="polite">{done ? "완료를 기록했어요. 홈에서 다음 학습을 확인할 수 있어요." : "답을 비교한 뒤 완료를 표시하면 홈의 다음 학습에 반영됩니다."}</p>
    {error && <p role="alert">학습 기록을 저장하지 못했어요. 브라우저의 저장소 설정을 확인해 주세요.</p>}
  </div>;
  return (
    <section id="complete" className={`learn-actions ${done ? "is-done" : ""}`}>
      <div className="learn-actions-copy"><span>STEP {step}</span><div>
        <h2>본문 없이 설명할 수 있나요?</h2>
        <p>이해도를 선택하면 복습 목록에 반영됩니다. 학습 완료와 별도로 기록해요.</p>
      </div></div>
      <div className="mastery-options" role="group" aria-label="이해도 자기 평가">
        {(Object.keys(MASTERY_LABELS) as Mastery[]).map((value) => (
          <button key={value} className={`chip ${mastery === value ? "on" : ""}`} aria-pressed={mastery === value} onClick={() => rate(value)}>{MASTERY_LABELS[value]}</button>
        ))}
      </div>
      <p className="hint" aria-live="polite">{mastery === "confident" ? "복습 필요 목록에서 제외됩니다." : mastery ? "홈의 ‘복습 필요’에서 다시 볼 수 있어요." : "선택한 이해도는 이 브라우저에 저장됩니다."}</p>
      <button className={`done-btn ${done ? "on" : ""}`} onClick={toggle} aria-pressed={done}>{done ? "✓ 학습 완료됨" : "학습 완료로 표시"}</button>
      {done && <p className="undo-hint">다시 누르면 완료 표시가 해제됩니다. 이해도 기록은 유지됩니다.</p>}
      {error && <p role="alert">이 브라우저에 기록을 저장하지 못했어요. 저장소 사용 설정을 확인해 주세요.</p>}
    </section>
  );
}
