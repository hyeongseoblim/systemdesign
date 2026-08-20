"use client";

import { useEffect, useRef, useState } from "react";
import CardBody from "@/components/CardBody";
import { InterviewDetail, sendAnswer, finishInterview } from "@/lib/api";

export default function InterviewChat({
  initial,
}: {
  initial: InterviewDetail;
}) {
  const [session, setSession] = useState(initial);
  const [draft, setDraft] = useState("");
  const [busy, setBusy] = useState<null | "answer" | "finish">(null);
  const [error, setError] = useState<string | null>(null);
  const bottomRef = useRef<HTMLDivElement>(null);

  const active = session.status === "ACTIVE";

  // 새 턴이 붙거나 로딩 상태가 바뀌면 항상 마지막이 보이도록
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth", block: "end" });
  }, [session.turns.length, busy, session.feedbackMd]);

  async function submit() {
    const answer = draft.trim();
    if (!answer || busy) return;
    setBusy("answer");
    setError(null);
    try {
      const next = await sendAnswer(session.id, answer);
      setSession(next);
      setDraft("");
    } catch (e) {
      setError(e instanceof Error ? e.message : "답변을 전송하지 못했습니다");
    } finally {
      setBusy(null);
    }
  }

  async function finish() {
    if (busy) return;
    setBusy("finish");
    setError(null);
    try {
      setSession(await finishInterview(session.id));
    } catch (e) {
      setError(e instanceof Error ? e.message : "피드백을 생성하지 못했습니다");
    } finally {
      setBusy(null);
    }
  }

  // Cmd/Ctrl+Enter 전송 — 답변이 길어 줄바꿈을 자주 쓰기 때문에 Enter는 개행 유지
  function onKeyDown(e: React.KeyboardEvent<HTMLTextAreaElement>) {
    if ((e.metaKey || e.ctrlKey) && e.key === "Enter") {
      e.preventDefault();
      submit();
    }
  }

  return (
    <div className="chat">
      {session.turns.map((t) => (
        <div key={t.id} className={`turn ${t.role.toLowerCase()}`}>
          <span className="who">
            {t.role === "INTERVIEWER" ? "면접관" : "나"}
          </span>
          <div className="bubble">{t.content}</div>
        </div>
      ))}

      {busy === "answer" && (
        <div className="turn interviewer">
          <span className="who">면접관</span>
          <div className="bubble thinking">
            <i />
            <i />
            <i />
          </div>
        </div>
      )}

      {session.feedbackMd && (
        <section className="feedback">
          <h2>면접 피드백</h2>
          <CardBody md={session.feedbackMd} />
          <p className="usage">
            입력 {session.usage.inputTokens.toLocaleString()} · 출력{" "}
            {session.usage.outputTokens.toLocaleString()} · 캐시 재사용{" "}
            {session.usage.cacheReadTokens.toLocaleString()} 토큰
          </p>
        </section>
      )}

      {busy === "finish" && (
        <p className="hint center">면접 전체를 평가하는 중입니다…</p>
      )}

      {error && <p className="form-error">{error}</p>}

      {active && (
        <div className="composer">
          <textarea
            rows={4}
            placeholder="답변을 입력하세요. 막히면 '힌트 주세요'라고 해도 됩니다."
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            onKeyDown={onKeyDown}
            disabled={busy !== null}
          />
          <div className="composer-actions">
            <button
              className="ghost-btn"
              onClick={finish}
              disabled={busy !== null}
            >
              면접 종료 · 피드백 받기
            </button>
            <button
              className="primary-btn"
              onClick={submit}
              disabled={busy !== null || !draft.trim()}
            >
              {busy === "answer" ? "전송 중…" : "답변 전송"}
            </button>
          </div>
          <p className="hint">⌘/Ctrl + Enter 로도 전송됩니다.</p>
        </div>
      )}

      <div ref={bottomRef} />
    </div>
  );
}
