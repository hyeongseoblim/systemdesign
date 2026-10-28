"use client";
import { useCallback, useEffect, useRef, useState } from "react";
import { readStorage, writeStorage } from "@/lib/study";
import { parseReadingPosition, readingOffset, readingPositionKey, type ReadingPosition } from "@/lib/reading";

const OFFSET = 96;
function anchors() {
  return [...document.querySelectorAll<HTMLElement>("#reading, .content h2[id], #questions, #deep-questions, #complete")].filter(el => el.getClientRects().length > 0);
}
function sectionRange(el: HTMLElement) {
  const sections = anchors();
  const next = sections[sections.indexOf(el) + 1];
  return Math.max(0, (next ? next.getBoundingClientRect().top + window.scrollY : document.documentElement.scrollHeight) - (el.getBoundingClientRect().top + window.scrollY));
}
export default function ReadingProgress({ cardId }: { cardId: string }) {
  const resumeFrames = useRef<number[]>([]);
  const barRef = useRef<HTMLDivElement>(null);
  const [resume, setResume] = useState<{ position: ReadingPosition; title: string } | null>(null);
  const legacyKey = `jobStudy::position::${cardId}`;
  const key = readingPositionKey(cardId);
  useEffect(() => {
    const saved = parseReadingPosition(readStorage(key));
    const sectionId = saved?.sectionId ?? readStorage(legacyKey);
    const target = sectionId ? document.getElementById(sectionId) : null;
    if (target && sectionId) setResume({
      position: saved ?? { sectionId, offset: 0, fraction: 0, viewportWidth: window.innerWidth },
      title: sectionId === "reading" ? "본문" : sectionId === "questions" || sectionId === "deep-questions" ? "질문 답하기" : sectionId === "complete" ? "학습 마무리" : (target.textContent ?? "본문").slice(0, 65),
    });
    let raf = 0;
    let timer: ReturnType<typeof setTimeout> | undefined;
    function save() {
      const current = anchors().filter(el => el.getBoundingClientRect().top <= OFFSET + 1).at(-1);
      if (!current) return;
      const range = sectionRange(current);
      const offset = Math.max(0, OFFSET - current.getBoundingClientRect().top);
      writeStorage(legacyKey, current.id, false);
      writeStorage(key, JSON.stringify({ sectionId: current.id, offset, fraction: range ? Math.min(1, offset / range) : 0, viewportWidth: document.documentElement.clientWidth }), false);
    }
    function update() {
      const max = document.documentElement.scrollHeight - window.innerHeight;
      const progress = max > 0 ? Math.min(100, Math.max(0, window.scrollY / max * 100)) : 0;
      if (barRef.current) {
        barRef.current.style.setProperty("--reading-progress", `${progress}%`);
        barRef.current.setAttribute("aria-valuenow", String(Math.round(progress)));
      }
    }
    function onScroll() { cancelAnimationFrame(raf); raf = requestAnimationFrame(update); clearTimeout(timer); timer = setTimeout(save, 180); }
    function onClick(event: MouseEvent) { if ((event.target as Element)?.closest?.("a")) save(); }
    function onVisibility() { if (document.visibilityState === "hidden") save(); }
    const observer = new ResizeObserver(update); observer.observe(document.body);
    update();
    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", update);
    window.addEventListener("pagehide", save);
    document.addEventListener("visibilitychange", onVisibility);
    document.addEventListener("click", onClick, true);
    return () => {
      observer.disconnect(); resumeFrames.current.forEach(cancelAnimationFrame); cancelAnimationFrame(raf); clearTimeout(timer);
      window.removeEventListener("scroll", onScroll); window.removeEventListener("resize", update); window.removeEventListener("pagehide", save);
      document.removeEventListener("visibilitychange", onVisibility); document.removeEventListener("click", onClick, true);
    };
  }, [cardId, key, legacyKey]);
  const continueReading = useCallback(() => {
    if (!resume) return;
    const target = document.getElementById(resume.position.sectionId);
    if (!target) { setResume(null); return; }
    let parent = target.parentElement;
    while (parent) { if (parent instanceof HTMLDetailsElement) parent.open = true; parent = parent.parentElement; }
    const position = resume.position;
    setResume(null);
    resumeFrames.current.forEach(cancelAnimationFrame);
    resumeFrames.current = [requestAnimationFrame(() => { resumeFrames.current.push(requestAnimationFrame(() => {
      if (!target.isConnected) return;
      window.scrollTo({ top: Math.max(0, target.getBoundingClientRect().top + window.scrollY + readingOffset(position, sectionRange(target), document.documentElement.clientWidth) - OFFSET), behavior: "instant" });
      target.tabIndex = -1; target.focus({ preventScroll: true });
    })); })];
  }, [resume]);
  useEffect(() => { if (resume && window.location.hash === "#resume") continueReading(); }, [resume, continueReading]);
  return <>
    <div className="progressbar" role="progressbar" aria-label="이 페이지 읽기 진행" aria-valuemin={0} aria-valuemax={100} aria-valuenow={0} ref={barRef}><span /></div>
    {resume && <aside className="reading-resume"><div><span>지난번 읽던 곳</span><p>{resume.title}</p></div><button type="button" onClick={continueReading}>이어서 읽기 ↓</button></aside>}
  </>;
}
