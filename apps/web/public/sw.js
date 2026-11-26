const PREFIX = "study-with-job-";
const PAGES = PREFIX + "pages-v3";
const ASSETS = PREFIX + "assets-v3";
const OFFLINE = "/offline.html";
const PAGE_LIMIT = 20;
const ASSET_LIMIT = 120;

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(PAGES).then((cache) => cache.add(OFFLINE)));
});

self.addEventListener("activate", (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter((key) => key.startsWith(PREFIX) && key !== PAGES && key !== ASSETS)
      .map((key) => caches.delete(key)));
    await self.clients.claim();
  })());
});

async function store(cache, key, response, limit, preserve) {
  await cache.put(key, response);
  const keys = (await cache.keys()).filter((request) => request.url !== preserve);
  await Promise.all(keys.slice(0, Math.max(0, keys.length - limit)).map((request) => cache.delete(request)));
}

async function readPage(request, isCard) {
  const cache = await caches.open(PAGES);
  let response;
  try {
    response = await fetch(request);
  } catch {
    if (isCard) {
      const path = new URL(request.url).pathname;
      const saved = await cache.match(request) || await cache.match(path);
      if (saved) return saved;
    }
    return await cache.match(OFFLINE) || Response.error();
  }
  if (isCard && response.ok && response.headers.get("content-type")?.includes("text/html")) {
    try {
      await store(cache, request, response.clone(), PAGE_LIMIT, new URL(OFFLINE, self.location.origin).href);
    } catch {
      // Storage can be unavailable or full. Keep the online response usable.
    }
  }
  return response;
}

async function readAsset(request) {
  const cache = await caches.open(ASSETS);
  const cached = await cache.match(request);
  if (cached) return cached;
  const response = await fetch(request);
  if (response.ok) {
    try {
      await store(cache, request, response.clone(), ASSET_LIMIT);
    } catch {
      // Storage can be unavailable or full.
    }
  }
  return response;
}

self.addEventListener("fetch", (event) => {
  const { request } = event;
  const url = new URL(request.url);
  if (request.method !== "GET" || url.origin !== self.location.origin) return;
  if (request.mode === "navigate") {
    const isCard = /^\/cards\/[0-9a-f-]{36}$/i.test(url.pathname);
    event.respondWith(readPage(request, isCard));
  } else if (url.pathname.startsWith("/_next/static/") || url.pathname.startsWith("/diagrams/")) {
    event.respondWith(readAsset(request));
  }
});
