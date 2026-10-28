"use client";
import Link from "next/link";
import { useEffect, useState } from "react";

/** Keep the next learning action within reach as the reader moves down the page. */
export default function LearningDock({ backHref, hasQuestions = true }: { backHref: string; hasQuestions?: boolean }) {
  const [phase, setPhase] = useState<"reading" | "questions" | "complete" | "deep-reading" | "deep-questions">("reading");
  useEffect(() => {
    let frame = 0;
    function update() {
      const complete = document.getElementById("complete");
      const questions = document.getElementById("questions");
      const threshold = window.innerHeight * .5;
      const deep = document.querySelector<HTMLElement>(".starter-deep-dive[open]");
      if (deep && deep.getBoundingClientRect().top < threshold) {
        const questions = document.getElementById("deep-questions");
        setPhase(questions && questions.getBoundingClientRect().top < threshold ? "deep-questions" : "deep-reading");
        return;
      }
      setPhase(complete && complete.getBoundingClientRect().top < threshold ? "complete" : questions && questions.getBoundingClientRect().top < threshold ? "questions" : "reading");
    }
    function onScroll() { cancelAnimationFrame(frame); frame = requestAnimationFrame(update); }
    const observer = new ResizeObserver(onScroll); observer.observe(document.body);
    onScroll(); window.addEventListener("scroll", onScroll, { passive: true }); window.addEventListener("resize", onScroll);
    return () => { observer.disconnect(); cancelAnimationFrame(frame); window.removeEventListener("scroll", onScroll); window.removeEventListener("resize", onScroll); };
  }, []);
  return <nav className="reading-dock" aria-label="학습 이동">
    <Link href={backHref}>← 목록</Link>
    {phase === "complete" ? <Link className="dock-primary" href="/">다음 학습 고르기 →</Link> : <a className="dock-primary" href={phase === "deep-reading" ? "#deep-questions" : phase === "reading" && hasQuestions ? "#questions" : "#complete"}>{(phase === "reading" && hasQuestions) || phase === "deep-reading" ? "기억에서 꺼내보기 →" : "이해도 기록하기 →"}</a>}
  </nav>;
}
