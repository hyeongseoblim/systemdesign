"use client";

import { useEffect, useRef, useState } from "react";
import { QuestionItem } from "@/lib/api";

/** 질문별 답변 — localStorage 자동 저장 (Phase 4에서 interactions API로 승격 예정) */
export default function QuestionAnswers({
  cardId,
  questions,
}: {
  cardId: string;
  questions: QuestionItem[];
}) {
  if (questions.length === 0) return null;
  return (
    <div className="qsection">
      <h3>이해도 확인</h3>
      <p className="qhint">답변은 이 기기에 자동 저장됩니다. 말로 설명하듯 써보세요.</p>
      {questions.map((q, i) => (
        <AnswerCard
          key={q.id}
          cardId={cardId}
          qid={q.id}
          index={i}
          question={q.question}
        />
      ))}
    </div>
  );
}

function AnswerCard({
  cardId,
  qid,
  index,
  question,
}: {
  cardId: string;
  qid: string;
  index: number;
  question: string;
}) {
  const storageKey = `jobStudy::ans::${cardId}::${qid}`;
  const [value, setValue] = useState("");
  const [saved, setSaved] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    setValue(localStorage.getItem(storageKey) ?? "");
  }, [storageKey]);

  function onChange(e: React.ChangeEvent<HTMLTextAreaElement>) {
    setValue(e.target.value);
    localStorage.setItem(storageKey, e.target.value);
    setSaved(true);
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => setSaved(false), 1200);
  }

  return (
    <div className="qcard">
      <div className="qhead">
        <span className="qn">Q{index + 1}</span>
        <span className={`saved ${saved ? "show" : ""}`}>✓ 저장됨</span>
      </div>
      <p className="qtext">{question}</p>
      <textarea
        value={value}
        onChange={onChange}
        placeholder="답변을 입력하세요…"
      />
    </div>
  );
}
