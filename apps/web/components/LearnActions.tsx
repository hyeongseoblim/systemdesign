"use client";

import { useEffect, useState } from "react";
import { readKey, doneKey } from "@/lib/api";

/** 상세 진입 시 읽음 기록 + 학습 완료 토글 (기기 로컬) */
export default function LearnActions({ cardId }: { cardId: string }) {
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
    <div className="learn-actions">
      <button className={`done-btn ${done ? "on" : ""}`} onClick={toggle}>
        {done ? "✓ 학습 완료 — 잘하고 있어요" : "이 카드 학습 완료로 표시"}
      </button>
    </div>
  );
}
