"use client";

import { useEffect, useState } from "react";
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
      {questions.map((q, i) => (
        <AnswerCard key={q.id} cardId={cardId} qid={q.id} index={i} question={q.question} />
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

  useEffect(() => {
    setValue(localStorage.getItem(storageKey) ?? "");
  }, [storageKey]);

  function onChange(e: React.ChangeEvent<HTMLTextAreaElement>) {
    setValue(e.target.value);
    localStorage.setItem(storageKey, e.target.value);
  }

  return (
    <div className="qcard">
      <div className="qn">Q{index + 1}</div>
      <p>{question}</p>
      <textarea
        value={value}
        onChange={onChange}
        placeholder="답변을 입력하세요… (자동 저장)"
      />
    </div>
  );
}
