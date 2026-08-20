"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { AREA_LABELS, startInterview, TopicArea } from "@/lib/api";

const AREAS = Object.keys(AREA_LABELS) as TopicArea[];

/** 모바일에서 주제를 직접 타이핑하는 부담을 줄이는 예시 */
const SUGGESTIONS: Record<TopicArea, string[]> = {
  SYSTEM_DESIGN: [
    "결제·정산 시스템 설계",
    "알림 시스템 설계 — 다채널 팬아웃",
    "근접 검색 — Geohash 기반 주변 기사 찾기",
  ],
  LOGISTICS: [
    "전국 실시간 재고 가용성(ATP) 설계",
    "배송 약속(Delivery Promise) 계산 시스템",
    "반품·역물류 상태 합류 처리",
  ],
  BACKEND_DEV: [
    "재고 차감 동시성 — 오버셀 방지",
    "재시도와 멱등성(Idempotency) 설계",
    "대용량 배치의 트랜잭션 경계",
  ],
  BACKEND_ARCHITECTURE: [
    "주문-결제-배송 Saga 보상 트랜잭션",
    "Outbox 패턴과 exactly-once 전달",
    "모놀리스에서 서비스 분리 기준",
  ],
  DATABASE: [
    "슬로우 쿼리 진단과 인덱스 설계",
    "샤딩 키 선택과 리샤딩 전략",
    "격리수준과 팬텀 리드 실무 사례",
  ],
  INFRA: [
    "무중단 배포 중 장애 롤백 시나리오",
    "오토스케일이 못 따라가는 트래픽 스파이크",
    "관측성 — 장애 원인을 5분 안에 좁히기",
  ],
  CS: [
    "TCP 연결이 느려지는 원인 추적",
    "HTTPS 핸드셰이크와 성능 최적화",
    "데드락 탐지와 회피",
  ],
};

const DIFFICULTIES = [
  { level: 1, label: "입문" },
  { level: 2, label: "기초" },
  { level: 3, label: "중급" },
  { level: 4, label: "시니어" },
  { level: 5, label: "스태프" },
];

export default function InterviewStarter() {
  const router = useRouter();
  const [area, setArea] = useState<TopicArea>("SYSTEM_DESIGN");
  const [topic, setTopic] = useState("");
  const [difficulty, setDifficulty] = useState(4);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function start() {
    const trimmed = topic.trim();
    if (!trimmed || busy) return;
    setBusy(true);
    setError(null);
    try {
      const session = await startInterview({ area, topic: trimmed, difficulty });
      router.push(`/interview/${session.id}`);
    } catch (e) {
      setError(e instanceof Error ? e.message : "면접을 시작하지 못했습니다");
      setBusy(false);
    }
  }

  return (
    <section className={`starter a-${area}`}>
      <label className="field-label">영역</label>
      <div className="chips">
        {AREAS.map((a) => (
          <button
            key={a}
            type="button"
            className={`chip a-${a} ${area === a ? "on" : ""}`}
            onClick={() => setArea(a)}
          >
            {AREA_LABELS[a]}
          </button>
        ))}
      </div>

      <label className="field-label" htmlFor="topic">
        주제
      </label>
      <textarea
        id="topic"
        className="topic-input"
        rows={2}
        placeholder="예: 쿠팡 로켓배송 라스트마일 배차 시스템 설계"
        value={topic}
        onChange={(e) => setTopic(e.target.value)}
      />
      <div className="chips suggestions">
        {SUGGESTIONS[area].map((s) => (
          <button
            key={s}
            type="button"
            className="chip ghost"
            onClick={() => setTopic(s)}
          >
            {s}
          </button>
        ))}
      </div>

      <label className="field-label">난이도</label>
      <div className="chips">
        {DIFFICULTIES.map((d) => (
          <button
            key={d.level}
            type="button"
            className={`chip ${difficulty === d.level ? "on" : ""}`}
            onClick={() => setDifficulty(d.level)}
          >
            {d.level} · {d.label}
          </button>
        ))}
      </div>

      {error && <p className="form-error">{error}</p>}

      <button
        className="primary-btn"
        onClick={start}
        disabled={busy || !topic.trim()}
      >
        {busy ? "면접관을 부르는 중…" : "면접 시작"}
      </button>
      <p className="hint">
        면접관은 답을 먼저 주지 않습니다. 막히면 힌트를 요청하세요.
      </p>
    </section>
  );
}
