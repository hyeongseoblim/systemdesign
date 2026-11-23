"use client";

import { useEffect, useState } from "react";
import { Button } from "@astryxdesign/core/Button";

interface InstallPrompt extends Event {
  prompt: () => Promise<{ outcome: "accepted" | "dismissed" }>;
}

export default function InstallApp() {
  const [prompt, setPrompt] = useState<InstallPrompt>();
  const [installed, setInstalled] = useState(false);

  useEffect(() => {
    function capture(event: Event) {
      event.preventDefault();
      setPrompt(event as InstallPrompt);
    }
    function finish() {
      setInstalled(true);
      setPrompt(undefined);
    }
    window.addEventListener("beforeinstallprompt", capture);
    window.addEventListener("appinstalled", finish);
    return () => {
      window.removeEventListener("beforeinstallprompt", capture);
      window.removeEventListener("appinstalled", finish);
    };
  }, []);

  if (installed) return null;

  return (
    <details className="app-install">
      <summary>홈 화면에 앱 추가</summary>
      {prompt ? (
        <Button className="app-control" label="STUDY WITH JOB 설치" variant="primary" clickAction={async () => {
          setPrompt(undefined);
          try {
            const result = await prompt.prompt();
            if (result.outcome === "accepted") setInstalled(true);
          } catch {
            // Installation can still be triggered from the browser menu.
          }
        }} />
      ) : (
        <p>iPhone에서는 Safari의 공유 메뉴에서 ‘홈 화면에 추가’를 선택하세요. Chrome에서는 브라우저 메뉴에서 ‘앱 설치’ 또는 ‘홈 화면에 추가’를 선택하세요.</p>
      )}
    </details>
  );
}
