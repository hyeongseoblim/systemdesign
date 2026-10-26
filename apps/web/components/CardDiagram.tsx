"use client";

import { useEffect, useId, useRef, useState } from "react";
import images from "@/content/diagrams.json";

type DiagramImage = { src: string; width: number; height: number; panels: { offset: number; width: number; height: number }[] };
const diagrams = images as Record<string, DiagramImage>;
export const diagramSource = (source: string) => source.trim().replace(/\r\n/g, "\n");
export const hasDiagramImage = (source: string) => !!diagrams[diagramSource(source)];

/** Images stay in the reading column; wide diagrams also have overlapping detail views. */
export default function CardDiagram({ source }: { source: string }) {
  const code = diagramSource(source);
  const image = diagrams[code];
  const [generated, setGenerated] = useState<DiagramImage>();
  const [failed, setFailed] = useState(false);
  const [width, setWidth] = useState(0);
  const ref = useRef<HTMLElement>(null);
  const id = useId().replace(/:/g, "");
  useEffect(() => {
    if (!ref.current) return;
    const observer = new ResizeObserver(([entry]) => setWidth(entry.contentRect.width));
    observer.observe(ref.current);
    return () => observer.disconnect();
  }, []);
  useEffect(() => {
    if (image) return;
    let active = true;
    setGenerated(undefined); setFailed(false);
    (async () => {
      try {
        const mermaid = (await import("mermaid")).default;
        mermaid.initialize({ startOnLoad: false, securityLevel: "strict", theme: "neutral", htmlLabels: false, flowchart: { htmlLabels: false, useMaxWidth: false } });
        const vertical = code.replace(/^(\s*(?:flowchart|graph))\s+(?:LR|RL)\b/m, "$1 TB");
        const { svg } = await mermaid.render(`fallback-${id}`, vertical);
        const container = document.createElement("div"); container.innerHTML = svg;
        const el = container.querySelector("svg");
        if (!el) throw new Error("Missing diagram image");
        const [, , w, h] = el.getAttribute("viewBox")!.split(/[ ,]+/).map(Number);
        const panels: DiagramImage["panels"] = [];
        if (w > 320) {
          const count = Math.ceil((w - 300) / 150) + 1;
          for (let i = 0; i < count; i++) {
            panels.push({ offset: (w - 300) * i / (count - 1), width: 300, height: h });
          }
        }
        // Native SVG images cannot execute scripts or change the host document.
        const src = `data:image/svg+xml;charset=utf-8,${encodeURIComponent(new XMLSerializer().serializeToString(el))}`;
        if (active) setGenerated({ src, width: w, height: h, panels });
      } catch { if (active) setFailed(true); }
    })();
    return () => { active = false; };
  }, [code, id, image]);
  const diagram = image ?? generated;
  const showDetails = diagram && width > 0 && diagram.width > width * 1.25 && diagram.panels.length > 0;
  return <figure className="diagram-image" ref={ref} aria-label="설명 다이어그램">
    {diagram ? <>
      <img className="diagram-overview" src={diagram.src} width={diagram.width} height={diagram.height} alt="설명 다이어그램 전체 보기" loading="lazy" decoding="async" />
      {showDetails && <div className="diagram-details">
        <p className="diagram-help">확대해서 읽기 · 왼쪽부터 순서대로 아래에 이어집니다.</p>
        {diagram.panels.map((panel, index) => <div className="diagram-panel" key={index}>
          <span className="diagram-panel-label">{index + 1} / {diagram.panels.length}</span>
          <div className="diagram-panel-viewport" style={{ aspectRatio: `${panel.width} / ${panel.height}` }}>
            <img src={diagram.src} width={diagram.width} height={diagram.height} style={{ width: `${diagram.width / panel.width * 100}%`, left: `${-panel.offset / panel.width * 100}%` }} alt={`다이어그램 확대 ${index + 1}/${diagram.panels.length}`} loading="lazy" decoding="async" />
          </div>
        </div>)}
      </div>}
      <details className="diagram-description"><summary>다이어그램 텍스트 설명</summary><pre>{code}</pre></details>
    </> : failed ? <><figcaption>다이어그램을 표시하지 못했어요. 텍스트 설명으로 확인해 주세요.</figcaption><pre>{code}</pre></> : <p role="status">다이어그램 이미지를 준비하고 있어요.</p>}
  </figure>;
}
