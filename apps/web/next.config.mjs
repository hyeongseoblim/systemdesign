import path from "node:path";
import { fileURLToPath } from "node:url";

const appDir = path.dirname(fileURLToPath(import.meta.url));

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // The repository has a root lockfile as well as apps/web/package-lock.json.
  // Pin tracing to the repository that owns this Next.js app instead of relying
  // on Next.js' lockfile-based workspace-root inference.
  outputFileTracingRoot: path.join(appDir, "..", ".."),
};

export default nextConfig;
