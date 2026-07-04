"use client";

import { useEffect, useRef } from "react";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";

/** 마크다운 본문 렌더 + ```mermaid 코드블록을 다이어그램으로 렌더 */
export default function CardBody({ md }: { md: string }) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    let active = true;
    (async () => {
      const nodes = ref.current?.querySelectorAll<HTMLElement>(
        "[data-mermaid]:not([data-rendered])"
      );
      if (!nodes || nodes.length === 0) return;
      const mermaid = (await import("mermaid")).default;
      if (!active) return;
      mermaid.initialize({
        startOnLoad: false,
        securityLevel: "loose",
        theme: "neutral",
      });
      for (let i = 0; i < nodes.length; i++) {
        const el = nodes[i];
        const code = el.getAttribute("data-mermaid") ?? "";
        try {
          const { svg } = await mermaid.render(`mmd-${Date.now()}-${i}`, code);
          if (!active) return;
          el.innerHTML = svg;
          el.setAttribute("data-rendered", "1");
        } catch {
          el.textContent = code; // 렌더 실패 시 원문 표시
          el.setAttribute("data-rendered", "1");
        }
      }
    })();
    return () => {
      active = false;
    };
  }, [md]);

  return (
    <div className="content" ref={ref}>
      <ReactMarkdown
        remarkPlugins={[remarkGfm]}
        components={{
          code({ className, children, ...props }) {
            const match = /language-(\w+)/.exec(className ?? "");
            if (match?.[1] === "mermaid") {
              return (
                <div
                  className="mermaid-box"
                  data-mermaid={String(children).replace(/\n$/, "")}
                />
              );
            }
            return (
              <code className={className} {...props}>
                {children}
              </code>
            );
          },
        }}
      >
        {md}
      </ReactMarkdown>
    </div>
  );
}
