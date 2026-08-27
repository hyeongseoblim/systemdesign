"use client";

import { useEffect, useState } from "react";
import { readKey, doneKey } from "@/lib/api";

/** 상세 진입 시 읽음 기록 + 학습 완료 토글 (기기 로컬) */
export default function LearnActions({ cardId, step = 3 }: { cardId: string; step?: number }) {
  const [done, setDone] = useState(false);

  useEffect(() => {
    localStorage.setItem(readKey(cardId), new Date().toISOString());
    setDone(!!localStorage.getItem(doneKey(cardId)));
  }, [cardId]);

  function toggle() {
    const next = !done;
    setDone(next);
    if (next) localStorage.setItem(doneKey(cardId), new Date().toISOString());
    else localStorage.removeItem(doneKey(cardId));
  }

  return (
    <section className={`learn-actions ${done ? "is-done" : ""}`}>
      <div className="learn-actions-copy">
        <span>STEP {step}</span>
        <div>
          <h2>{done ? "오늘 학습을 완료했어요" : "학습을 마무리할까요?"}</h2>
          <p>{done ? "피드에서 복습할 카드로 표시됩니다." : "읽기와 답변을 마쳤다면 완료로 기록하세요."}</p>
        </div>
      </div>
      <button
        className={`done-btn ${done ? "on" : ""}`}
        onClick={toggle}
        aria-pressed={done}
      >
        {done ? "✓ 학습 완료됨" : "학습 완료로 표시"}
      </button>
      {done && <p className="undo-hint">다시 누르면 완료 표시가 해제됩니다.</p>}
    </section>
  );
}
