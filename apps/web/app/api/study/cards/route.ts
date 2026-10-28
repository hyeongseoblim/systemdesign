import { proxyCardRead } from "@/lib/cardProxy";
export const dynamic = "force-dynamic";
export function GET(request: Request) {
  const input = new URL(request.url).searchParams;
  const query = new URLSearchParams();
  for (const key of ["area", "mode", "difficulty", "shuffleSeed", "cursor", "limit"]) {
    const value = input.get(key); if (value !== null) query.set(key, value);
  }
  return proxyCardRead(`?${query}`);
}
