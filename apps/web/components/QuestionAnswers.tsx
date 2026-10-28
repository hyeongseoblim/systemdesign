"use client";

import { useEffect, useState } from "react";
import ReactMarkdown from "react-markdown";
import remarkCjkFriendly from "remark-cjk-friendly";
import { QuestionItem } from "@/lib/api";
import { parseChecklist, readStorage, writeStorage } from "@/lib/study";
import RecallInput from "./RecallInput";

export interface AnswerGuide {
  reviewedAt: string;
  scope: string;
  sources: { label: string; url: string }[];
  questions: { question: string; points: string[]; pitfall: string; followUp: string }[];
}

export default function QuestionAnswers({ cardId, questions, guide, id = "questions", step = 2 }: {
  cardId: string; questions: QuestionItem[]; guide?: AnswerGuide; id?: string; step?: number;
}) {
  const [answered, setAnswered] = useState<Set<string>>(new Set());
  const [active, setActive] = useState(0);
  const [ready, setReady] = useState(false);
  const selectionKey = `jobStudy::question::${cardId}::${id}`;
  useEffect(() => {
    const stored = new Set(questions.filter(q => (readStorage(`jobStudy::ans::${cardId}::${q.id}`) ?? "").trim()).map(q => q.id));
    setAnswered(stored);
    const savedIndex = questions.findIndex(q => q.id === readStorage(selectionKey));
    const next = questions.findIndex(q => !stored.has(q.id));
    setActive(savedIndex >= 0 ? savedIndex : Math.max(0, next)); setReady(true);
  }, [cardId, questions, selectionKey]);
  function select(index: number) {
    setActive(index); writeStorage(selectionKey, questions[index].id, false);
    requestAnimationFrame(() => {
      const section = document.getElementById(id);
      section?.scrollIntoView({ block: "start", behavior: "instant" });
      section?.querySelector<HTMLElement>(".recall-number")?.focus({ preventScroll: true });
    });
  }
  if (!questions.length) return null;
  const current = questions[active] ?? questions[0];
  return <section id={id} className="qsection recall-session" aria-label="기억에서 꺼내보기">
    <div className="qsection-head"><span>STEP {step}</span><div><h2>기억에서 꺼내보기</h2><p className="qhint">한 번에 한 질문씩, 내 말로 설명해 보세요.</p></div></div>
    <div className="recall-progress"><span>{ready ? answered.size : "—"}/{questions.length} 답변 작성</span><span>작성한 답변은 이어서 고칠 수 있어요.</span></div>
    <nav className="recall-tabs" aria-label="질문 선택">{questions.map((q, i) => <button key={q.id} type="button" disabled={!ready} aria-pressed={active === i} onClick={() => select(i)}>
      <span>{answered.has(q.id) ? "✓ " : ""}질문 {i + 1}</span><small>{answered.has(q.id) ? "작성함" : "떠올리기"}</small>
    </button>)}</nav>
    {ready && <AnswerCard key={current.id} cardId={cardId} question={current} index={active} total={questions.length}
      guide={guide?.questions.find(item => item.question === current.question)}
      onStoredChange={(value, success) => {
        if (!success) return;
        setAnswered(previous => { const next = new Set(previous); if (value.trim()) next.add(current.id); else next.delete(current.id); return next; });
      }} />}
    <nav className="recall-navigation" aria-label="질문 이동">
      <button className="chip" type="button" disabled={active === 0 || !ready} onClick={() => select(active - 1)}>← 이전 질문</button>
      {active < questions.length - 1 ? <button className="recall-next" type="button" disabled={!ready} onClick={() => select(active + 1)}>다음 질문 →</button>
        : <a className="recall-next" href="#complete">이해도 기록하고 마치기 →</a>}
    </nav>
    <p className="recall-reassurance">막히는 질문은 점검 기준을 참고하거나 다음으로 넘어가도 괜찮아요.</p>
    {guide && <details className="guide-sources"><summary>더 확인할 자료</summary><p>점검 기준 검수: {guide.reviewedAt} · {guide.scope}</p><ul>{guide.sources.map(source => <li key={source.url}><a href={source.url} target="_blank" rel="noopener noreferrer">{source.label} ↗</a></li>)}</ul></details>}
  </section>;
}

function AnswerCard({ cardId, question, index, total, guide, onStoredChange }: {
  cardId: string; question: QuestionItem; index: number; total: number; guide?: AnswerGuide["questions"][number]; onStoredChange: (value: string, success: boolean) => void;
}) {
  const checksKey = `jobStudy::checks::${cardId}::${question.id}`;
  const [checked, setChecked] = useState<string[]>([]);
  const [error, setError] = useState(false);
  useEffect(() => { setChecked(parseChecklist(readStorage(checksKey), guide?.points ?? [])); }, [checksKey, guide]);
  return <div className="qcard recall-card">
    <p className="recall-number" tabIndex={-1}>질문 {index + 1} <span>/ {total}</span></p>
    <div className="qtext"><ReactMarkdown remarkPlugins={[remarkCjkFriendly]}>{question.question}</ReactMarkdown></div>
    <RecallInput storageKey={`jobStudy::ans::${cardId}::${question.id}`} label={`Q${index + 1} 답변`} onStoredChange={onStoredChange} />
    {guide && <details className="answer-guide"><summary>내 답과 점검 기준 비교하기</summary>
      <p>내 답에서 설명한 항목을 체크해 보세요. 체크는 이 브라우저에 저장돼요.</p>
      <div className="guide-checklist">{guide.points.map(point => <label key={point}><input type="checkbox" checked={checked.includes(point)} onChange={event => {
        const next = event.target.checked ? [...checked, point] : checked.filter(value => value !== point);
        setChecked(next); setError(!writeStorage(checksKey, JSON.stringify(next), false));
      }} /><span>{point}</span></label>)}</div>
      {error && <p role="alert">점검 항목을 저장하지 못했어요. 답변 저장 상태도 확인해 주세요.</p>}
      <p><strong>놓치기 쉬운 점</strong> {guide.pitfall}</p><p><strong>한 번 더 생각하기</strong> {guide.followUp}</p>
    </details>}
  </div>;
}
