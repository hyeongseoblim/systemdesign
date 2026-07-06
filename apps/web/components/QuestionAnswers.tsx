"use client";

import { useEffect, useRef, useState } from "react";
import { QuestionItem, getInteractions, saveAnswer } from "@/lib/api";

/**
 * 질문별 답변 — 서버(interactions API) 동기화가 원본, localStorage는 오프라인 폴백.
 * 로드: 서버 값 우선, 없으면 로컬 값 복원. 입력: 로컬 즉시 저장 + 1.5s 디바운스로 서버 저장.
 */
export default function QuestionAnswers({
  cardId,
  questions,
}: {
  cardId: string;
  questions: QuestionItem[];
}) {
  const [serverAnswers, setServerAnswers] = useState<Record<string, string>>();

  useEffect(() => {
    let active = true;
    getInteractions(cardId)
      .then((res) => {
        if (!active) return;
        const map: Record<string, string> = {};
        res.answers.forEach((a) => {
          if (a.answer) map[a.questionId] = a.answer;
        });
        setServerAnswers(map);
      })
      .catch(() => {
        if (active) setServerAnswers({}); // 오프라인 — 로컬 폴백으로 진행
      });
    return () => {
      active = false;
    };
  }, [cardId]);

  if (questions.length === 0) return null;
  return (
    <div className="qsection">
      <h3>이해도 확인</h3>
      {questions.map((q, i) => (
        <AnswerCard
          key={q.id}
          cardId={cardId}
          qid={q.id}
          index={i}
          question={q.question}
          serverValue={serverAnswers?.[q.id]}
          loaded={serverAnswers !== undefined}
        />
      ))}
    </div>
  );
}

type SyncState = "idle" | "typing" | "saving" | "saved" | "offline";

const SYNC_LABEL: Record<SyncState, string> = {
  idle: "",
  typing: "● 입력 중",
  saving: "⟳ 동기화 중",
  saved: "✓ 동기화됨",
  offline: "⚠ 오프라인 (로컬 저장됨)",
};

function AnswerCard({
  cardId,
  qid,
  index,
  question,
  serverValue,
  loaded,
}: {
  cardId: string;
  qid: string;
  index: number;
  question: string;
  serverValue?: string;
  loaded: boolean;
}) {
  const storageKey = `jobStudy::ans::${cardId}::${qid}`;
  const [value, setValue] = useState("");
  const [sync, setSync] = useState<SyncState>("idle");
  const timer = useRef<ReturnType<typeof setTimeout>>(undefined);
  const initialized = useRef(false);

  // 서버 로드 완료 시 1회 초기화: 서버 값 우선, 없으면 로컬
  useEffect(() => {
    if (!loaded || initialized.current) return;
    initialized.current = true;
    const local = localStorage.getItem(storageKey) ?? "";
    setValue(serverValue ?? local);
  }, [loaded, serverValue, storageKey]);

  function onChange(e: React.ChangeEvent<HTMLTextAreaElement>) {
    const v = e.target.value;
    setValue(v);
    localStorage.setItem(storageKey, v);
    setSync("typing");
    clearTimeout(timer.current);
    timer.current = setTimeout(() => {
      setSync("saving");
      saveAnswer(cardId, qid, v)
        .then(() => setSync("saved"))
        .catch(() => setSync("offline"));
    }, 1500);
  }

  return (
    <div className="qcard">
      <div className="qn">
        Q{index + 1}
        <span style={{ float: "right", fontWeight: 500 }}>{SYNC_LABEL[sync]}</span>
      </div>
      <p>{question}</p>
      <textarea
        value={value}
        onChange={onChange}
        placeholder="답변을 입력하세요… (자동 저장·동기화)"
      />
    </div>
  );
}
