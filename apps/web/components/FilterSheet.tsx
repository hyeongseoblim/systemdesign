"use client";

import { useRef } from "react";
import { Button } from "@astryxdesign/core/Button";
import { useSearchParams } from "next/navigation";

export default function FilterSheet({ children }: { children: React.ReactNode }) {
  const dialog = useRef<HTMLDialogElement>(null);
  const params = useSearchParams();
  const count = ["area", "mode", "difficulty"].filter(key => params.has(key)).length;
  return <div className="filter-launcher">
    <span>나에게 맞는 학습 찾기</span>
    <Button className="app-control" label={count > 0 ? `필터 · ${count}` : "필터"} onClick={() => dialog.current?.showModal()} aria-haspopup="dialog" />
    <dialog ref={dialog} className="filter-sheet" aria-labelledby="filter-title" onClick={event => { if (event.target === dialog.current) dialog.current.close(); }}>
      <div className="filter-sheet-content">
        <div className="sheet-heading"><h2 id="filter-title">학습 필터</h2><Button className="app-control" label="닫기" onClick={() => dialog.current?.close()} /></div>
        {children}
        <Button className="app-control" label="결과 보기" variant="primary" width="100%" onClick={() => dialog.current?.close()} />
      </div>
    </dialog>
  </div>;
}
