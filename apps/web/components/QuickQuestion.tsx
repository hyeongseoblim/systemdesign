"use client";

import { useEffect, useState } from "react";
import { readStorage, writeStorage } from "@/lib/study";

export default function QuickQuestion({ cardId, question, check }: { cardId: string; question: string; check: string }) {
  const key = `jobStudy::quick::${cardId}`;
  const [answer, setAnswer] = useState("");
  const [error, setError] = useState(false);

  useEffect(() => { setAnswer(readStorage(key) ?? ""); }, [key]);

  return <section id="questions" className="quick-question">
    <div className="study-section-head"><span>STEP 2</span><div><h2>한 가지만 떠올려 보기</h2><p>길게 쓰지 않아도 괜찮아요. 말로 답해도 됩니다.</p></div></div>
    <label htmlFor={`quick-${cardId}`}>{question}</label>
    <textarea id={`quick-${cardId}`} value={answer} onChange={(event) => {
      setAnswer(event.target.value);
      setError(!writeStorage(key, event.target.value));
    }} placeholder="내 생각을 한두 문장으로 적어 보세요 (선택)" />
    <details className="answer-guide"><summary>생각해 볼 기준 보기</summary><p>{check}</p></details>
    {error && <p role="alert">답을 저장하지 못했어요. 화면을 나가기 전에 복사해 주세요.</p>}
  </section>;
}
