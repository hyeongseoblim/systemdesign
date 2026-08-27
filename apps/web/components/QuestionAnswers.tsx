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
  const [answered, setAnswered] = useState<Set<string>>(new Set());

  useEffect(() => {
    const stored = new Set<string>();
    for (const question of questions) {
      const key = `jobStudy::ans::${cardId}::${question.id}`;
      if ((localStorage.getItem(key) ?? "").trim()) stored.add(question.id);
    }
    setAnswered(stored);
  }, [cardId, questions]);

  function updateAnswered(qid: string, hasAnswer: boolean) {
    setAnswered((current) => {
      const next = new Set(current);
      if (hasAnswer) next.add(qid);
      else next.delete(qid);
      return next;
    });
  }

  if (questions.length === 0) return null;
  return (
    <div className="qsection">
      <div className="qsection-head">
        <span>STEP 2</span>
        <div>
          <h2>기억에서 꺼내보기</h2>
          <p className="qhint">본문을 보지 않고, 동료에게 설명하듯 답해보세요.</p>
        </div>
        <strong>{answered.size}/{questions.length} 작성</strong>
      </div>
      {questions.map((q, i) => (
        <AnswerCard
          key={q.id}
          cardId={cardId}
          qid={q.id}
          index={i}
          question={q.question}
          onAnsweredChange={updateAnswered}
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
  onAnsweredChange,
}: {
  cardId: string;
  qid: string;
  index: number;
  question: string;
  onAnsweredChange: (qid: string, hasAnswer: boolean) => void;
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
    onAnsweredChange(qid, !!e.target.value.trim());
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
        placeholder="내 언어로 핵심을 설명해 보세요…"
        aria-label={`Q${index + 1} 답변`}
      />
      <div className="answer-foot">
        <span>이 기기에 자동 저장</span>
        <span>{value.trim().length}자</span>
      </div>
    </div>
  );
}
