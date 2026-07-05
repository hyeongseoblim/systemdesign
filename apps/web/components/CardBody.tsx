"use client";

import { useEffect, useRef } from "react";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";

/** hast 노드에서 텍스트만 추출 (callout 종류 분류용) */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function nodeText(node: any): string {
  if (!node) return "";
  if (node.type === "text") return node.value ?? "";
  if (Array.isArray(node.children)) return node.children.map(nodeText).join("");
  return "";
}

function calloutType(text: string): "info" | "warn" | "tip" | "note" {
  if (/함정|주의|안티패턴|피하|경고/.test(text)) return "warn";
  if (/팁|💡|권장|추천|요령/.test(text)) return "tip";
  if (/면접|포인트|핵심|중요/.test(text)) return "info";
  return "note";
}

/** 마크다운 본문 렌더 + ```mermaid 다이어그램 + callout/코드블록 커스텀 */
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
        theme: "base",
        themeVariables: {
          background: "#0a1017",
          primaryColor: "#111a28",
          primaryBorderColor: "#22d3ee",
          primaryTextColor: "#e6edf5",
          secondaryColor: "#12202b",
          tertiaryColor: "#1a1224",
          lineColor: "#3a4a5c",
          fontFamily: "JetBrains Mono, monospace",
          fontSize: "12px",
        },
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
          el.textContent = code;
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
          // fenced code 의 <pre> 래퍼 제거 (커스텀 .codeblock 이 대체)
          pre: ({ children }) => <>{children}</>,
          code({ className, children, ...props }) {
            const raw = String(children).replace(/\n$/, "");
            const lang = /language-(\w+)/.exec(className ?? "")?.[1];
            if (lang === "mermaid") {
              return <div className="mermaid-box" data-mermaid={raw} />;
            }
            const isBlock = Boolean(lang) || raw.includes("\n");
            if (isBlock) {
              return (
                <div className="codeblock">
                  <div className="cb-head">
                    <span className="dot" style={{ background: "#fb7185" }} />
                    <span className="dot" style={{ background: "#fbbf24" }} />
                    <span className="dot" style={{ background: "#34d399" }} />
                    {lang && <span className="cb-lang">{lang}</span>}
                  </div>
                  <pre>
                    <code className={className}>{raw}</code>
                  </pre>
                </div>
              );
            }
            return (
              <code className={className} {...props}>
                {children}
              </code>
            );
          },
          blockquote({ node, children }) {
            const type = calloutType(nodeText(node));
            return (
              <div className={`callout ${type}`}>
                <div className="c-body">{children}</div>
              </div>
            );
          },
        }}
      >
        {md}
      </ReactMarkdown>
    </div>
  );
}
