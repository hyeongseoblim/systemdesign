"use client";

import { useEffect, useRef, useState } from "react";
import { QuestionItem } from "@/lib/api";
import { QIcon } from "@/lib/design";

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
      <div className="qsection-head">
        <span className="q-ic">
          <QIcon size={14} />
        </span>
        <h3>이해도 체크</h3>
        <span className="prog">{questions.length}문항</span>
      </div>
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
  const [saved, setSaved] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    setValue(localStorage.getItem(storageKey) ?? "");
  }, [storageKey]);

  function onChange(e: React.ChangeEvent<HTMLTextAreaElement>) {
    const v = e.target.value;
    setValue(v);
    localStorage.setItem(storageKey, v);
    if (timer.current) clearTimeout(timer.current);
    setSaved(false);
    timer.current = setTimeout(() => setSaved(true), 500);
  }

  return (
    <div className="qcard">
      <div className="qn">Q{index + 1}</div>
      <p>{question}</p>
      <textarea
        value={value}
        onChange={onChange}
        placeholder="여기에 답을 적어보세요… (자동 저장)"
      />
      <div className={`saved ${saved && value ? "show" : ""}`}>저장됨 ✓</div>
    </div>
  );
}
