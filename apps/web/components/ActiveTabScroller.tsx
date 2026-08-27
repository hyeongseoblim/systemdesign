"use client";

import { useEffect } from "react";

/** 활성 필터 칩이 가로 스크롤 밖에 있으면 화면 안으로 끌어온다 */
export default function ActiveTabScroller({ filterKey }: { filterKey: string }) {
  useEffect(() => {
    document.querySelectorAll<HTMLElement>(".tabs .tab.active").forEach((el) => {
      const container = el.parentElement;
      if (!container) return;

      const containerRect = container.getBoundingClientRect();
      const itemRect = el.getBoundingClientRect();
      const centeredLeft =
        container.scrollLeft +
        itemRect.left -
        containerRect.left -
        (container.clientWidth - itemRect.width) / 2;

      // scrollIntoView는 가로 칩 이동과 함께 문서의 세로 스크롤도 바꿀 수 있다.
      container.scrollTo({ left: Math.max(0, centeredLeft), behavior: "smooth" });
    });
  }, [filterKey]);
  return null;
}
