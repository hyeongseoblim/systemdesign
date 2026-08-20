import { redirect } from "next/navigation";

export default async function InterviewSessionPage({
  params: _params,
}: {
  params: Promise<{ id: string }>;
}) {
  await _params;
  redirect("/interview");
}
