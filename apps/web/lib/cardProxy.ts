import { API_BASE } from "./api";

/** Public card reads only. Never forward admin tokens or arbitrary upstream URLs. */
export async function proxyCardRead(suffix: string, cacheCatalog = false) {
  try {
    const upstream = await fetch(`${API_BASE}/api/v1/cards${suffix}`, { ...(cacheCatalog ? { cache: "force-cache" as const, next: { revalidate: 60 } } : { cache: "no-store" as const }), signal: AbortSignal.timeout(25_000) });
    return Response.json(await upstream.json(), { status: upstream.status, headers: { "Cache-Control": "no-store" } });
  } catch {
    return Response.json({ detail: "카드 연결이 지연되고 있어요. 잠시 후 다시 시도해 주세요." }, { status: 503, headers: { "Cache-Control": "no-store" } });
  }
}
