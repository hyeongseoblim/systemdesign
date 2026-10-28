"use client";

import { useEffect, useId, useState } from "react";
import { readStorage, writeStorage } from "@/lib/study";

/** Save on every change so leaving the page never depends on a debounce timer. */
export default function RecallInput({ storageKey, label, onStoredChange }: {
  storageKey: string;
  label: string;
  onStoredChange?: (value: string, success: boolean) => void;
}) {
  const id = useId();
  const [value, setValue] = useState("");
  const [status, setStatus] = useState<"empty" | "saved" | "error">("empty");
  useEffect(() => {
    const stored = readStorage(storageKey) ?? "";
    setValue(stored); setStatus(stored ? "saved" : "empty");
  }, [storageKey]);
  return <div className="recall-input">
    <label htmlFor={id}>내 답변 <span>한두 문장으로 적어도 좋아요.</span></label>
    <textarea id={id} aria-label={label} value={value} placeholder="기억나는 핵심을 내 말로 적어 보세요."
      onChange={event => {
        const next = event.target.value;
        setValue(next);
        const success = writeStorage(storageKey, next);
        setStatus(success ? "saved" : "error");
        onStoredChange?.(next, success);
      }} />
    <p className={`recall-save ${status === "error" ? "has-error" : ""}`} role={status === "error" ? "alert" : undefined}>
      {status === "error" ? "답변을 저장하지 못했어요. 나가기 전에 답변을 복사해 주세요." : status === "saved" ? "✓ 이 브라우저에 저장됨" : "입력한 답변은 이 브라우저에 자동 저장돼요."}
    </p>
  </div>;
}
