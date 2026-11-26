"use client";

import { useState } from "react";
import { Button } from "@astryxdesign/core/Button";

export default function SaveOfflineCard({ cardId }: { cardId: string }) {
  const [status, setStatus] = useState<"idle" | "saved" | "error" | "unavailable">("idle");

  async function saveCard() {
    if (!navigator.serviceWorker?.controller || !window.caches) {
      setStatus("unavailable");
      return;
    }

    try {
      const path = `/cards/${encodeURIComponent(cardId)}`;
      const response = await fetch(path, {
        headers: { Accept: "text/html" },
        signal: AbortSignal.timeout(15000),
      });
      if (!response.ok || !response.headers.get("content-type")?.includes("text/html")) {
        throw new Error("Card document unavailable");
      }

      const html = new DOMParser().parseFromString(await response.clone().text(), "text/html");
      const assets = new Set<string>();
      for (const element of html.querySelectorAll("script[src], link[rel=stylesheet][href], img[src]")) {
        const src = element.getAttribute("src") ?? element.getAttribute("href");
        if (!src) continue;
        const url = new URL(src, location.origin);
        if (url.origin === location.origin &&
            (url.pathname.startsWith("/_next/static/") || url.pathname.startsWith("/diagrams/"))) {
          assets.add(url.href);
        }
      }

      const assetCache = await caches.open("study-with-job-assets-v3");
      await Promise.all([...assets].map(async url => {
        const asset = await fetch(url, { signal: AbortSignal.timeout(15000) });
        if (!asset.ok || !await assetCache.match(url)) throw new Error("Card asset unavailable");
      }));

      const pages = await caches.open("study-with-job-pages-v3");
      // Move the saved card to the end of the same history used by the service worker.
      await pages.delete(path);
      await pages.put(path, response);
      const cards = (await pages.keys()).filter(key => new URL(key.url).pathname.startsWith("/cards/"));
      await Promise.all(cards.slice(0, Math.max(0, cards.length - 20)).map(key => pages.delete(key)));
      setStatus("saved");
    } catch {
      setStatus("error");
    }
  }

  return (
    <div className="offline-card-action">
      <Button className="app-control" label="오프라인에 저장" clickAction={saveCard} />
      <span role="status">
        {status === "saved" && "저장했어요. 연결이 끊겨도 오프라인 홈에서 열 수 있어요."}
        {status === "error" && "저장하지 못했어요. 연결을 확인하고 다시 시도해 주세요."}
        {status === "unavailable" && "앱이 준비되는 중이에요. 잠시 뒤 다시 시도해 주세요."}
      </span>
    </div>
  );
}
