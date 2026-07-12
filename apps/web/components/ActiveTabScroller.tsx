"use client";

import { useEffect } from "react";

/** 활성 필터 칩이 가로 스크롤 밖에 있으면 화면 안으로 끌어온다 */
export default function ActiveTabScroller() {
  useEffect(() => {
    document.querySelectorAll<HTMLElement>(".tabs .tab.active").forEach((el) => {
      el.scrollIntoView({ inline: "center", block: "nearest" });
    });
  }, []);
  return null;
}
