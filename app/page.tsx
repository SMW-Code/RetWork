import { redirect } from "next/navigation";

// b470 — / → /index.html 리다이렉트 시 쿼리스트링(?ref= 등)을 보존.
//   기존 redirect("/index.html") 은 쿼리를 버려서 추천 링크(?ref=CODE)가 유실됐음.
export default async function Home({
  searchParams,
}: {
  searchParams: Promise<{ [key: string]: string | string[] | undefined }>;
}) {
  const sp = await searchParams;
  const qs = new URLSearchParams();
  for (const k in sp) {
    const v = sp[k];
    if (typeof v === "string") qs.set(k, v);
    else if (Array.isArray(v) && v.length) qs.set(k, v[0]);
  }
  const s = qs.toString();
  redirect("/index.html" + (s ? "?" + s : ""));
}
