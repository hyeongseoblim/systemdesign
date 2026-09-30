import path from "node:path";
import { fileURLToPath } from "node:url";

const appDir = path.dirname(fileURLToPath(import.meta.url));

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // The repository has a root lockfile as well as apps/web/package-lock.json.
  // Pin tracing to this repository locally. Vercel deploys apps/web as its own
  // root, so its default tracing root must remain in effect there.
  ...(process.env.VERCEL ? {} : { outputFileTracingRoot: path.join(appDir, "..", "..") }),
};

export default nextConfig;
