import { proxyCardRead } from "@/lib/cardProxy";
export const dynamic = "force-dynamic";
export async function GET(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) return Response.json({ detail: "올바른 카드 ID가 필요합니다." }, { status: 400 });
  return proxyCardRead(`/${id}`);
}
