export function sectionId(title: string): string {
  return `section-${title.trim().replace(/[*`]/g, "").replace(/[^\p{L}\p{N}]+/gu, "-").replace(/^-|-$/g, "")}`;
}
export function headings(md: string): { title: string; id: string }[] {
  let fence = false;
  return md.split("\n").flatMap((line) => {
    if (/^\s*(```|~~~)/.test(line)) { fence = !fence; return []; }
    if (fence || !/^## /.test(line) || /이해도 확인/.test(line)) return [];
    const title = line.slice(3).replace(/[*`]/g, "").trim();
    return [{ title, id: sectionId(title) }];
  });
}

export interface ReadingPosition {
  sectionId: string;
  offset: number;
  fraction: number;
  viewportWidth: number;
}
export const readingPositionKey = (id: string) => `jobStudy::position-offset::${id}`;
export function parseReadingPosition(raw: string | null): ReadingPosition | null {
  try {
    const value = JSON.parse(raw ?? "null");
    if (!value || typeof value.sectionId !== "string" || !value.sectionId ||
      !Number.isFinite(value.offset) || value.offset < 0 ||
      !Number.isFinite(value.fraction) || value.fraction < 0 || value.fraction > 1 ||
      !Number.isFinite(value.viewportWidth) || value.viewportWidth <= 0) return null;
    return value;
  } catch { return null; }
}
export function readingOffset(position: ReadingPosition, range: number, width: number): number {
  const offset = Math.abs(width - position.viewportWidth) < 24 ? position.offset : position.fraction * range;
  return Math.min(Math.max(0, range), Math.max(0, offset));
}
