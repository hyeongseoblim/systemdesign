import type { Metadata, Viewport } from "next";
import "./globals.css";
import { Suspense } from "react";
import AppNavigation from "@/components/AppNavigation";
import ServiceWorkerRegister from "@/components/ServiceWorkerRegister";

export const metadata: Metadata = {
  title: "STUDY WITH JOB — 커리어를 만드는 기술 학습",
  description: "매일 쌓이는 백엔드/시스템 디자인 학습 카드",
  manifest: "/manifest.webmanifest",
  appleWebApp: { capable: true, statusBarStyle: "default", title: "STUDY WITH JOB" },
};

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: dark)", color: "#1b1e1b" },
    { media: "(prefers-color-scheme: light)", color: "#f5f5f1" },
  ],
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="ko">
      <body>
        <a className="skip-to-content" href="#main-content">본문으로 바로가기</a>
        <main id="main-content" className="app" tabIndex={-1}>{children}</main>
        <Suspense fallback={null}><AppNavigation /></Suspense>
        <ServiceWorkerRegister />
      </body>
    </html>
  );
}
