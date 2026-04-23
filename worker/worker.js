// Cloudflare Worker — jobStudy Q&A sync to GitHub
//
// Environment variables (set in Cloudflare dashboard):
//   GITHUB_TOKEN  (secret)  — GitHub PAT with contents:write on the repo
//   STUDY_KEY     (secret)  — shared secret sent from browser as X-Study-Key
//   GITHUB_OWNER           — e.g. "hyeongseoblim"
//   GITHUB_REPO            — e.g. "SystemDesign"
//   GITHUB_BRANCH          — e.g. "claude/migrate-local-project-qEKvq"

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const origin = request.headers.get('Origin') || '';
    const allowed = [
      `https://${env.GITHUB_OWNER}.github.io`,
      'http://localhost',
      'http://127.0.0.1',
      'file://',
    ];
    const isAllowed = allowed.some(o => origin.startsWith(o));
    const cors = {
      'Access-Control-Allow-Origin': isAllowed ? origin : allowed[0],
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, X-Study-Key',
      'Access-Control-Max-Age': '86400',
      'Vary': 'Origin',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: cors });
    }

    if (request.headers.get('X-Study-Key') !== env.STUDY_KEY) {
      return json({ error: 'unauthorized' }, 401, cors);
    }

    try {
      if (url.pathname === '/load' && request.method === 'GET') {
        return await handleLoad(url, env, cors);
      }
      if (url.pathname === '/save' && request.method === 'POST') {
        return await handleSave(request, env, cors);
      }
      return json({ error: 'not found' }, 404, cors);
    } catch (e) {
      return json({ error: e.message }, 500, cors);
    }
  },
};

async function handleLoad(url, env, cors) {
  const path = url.searchParams.get('path');
  if (!path || !isSafePath(path)) return json({ error: 'invalid path' }, 400, cors);
  const file = `answers/${path}.json`;
  const result = await ghGet(env, file);
  if (result.status === 404) {
    return json({ answers: {}, updatedAt: null }, 200, cors);
  }
  return json(result.data, 200, cors);
}

async function handleSave(request, env, cors) {
  const body = await request.json();
  if (!body.path || !isSafePath(body.path)) return json({ error: 'invalid path' }, 400, cors);
  if (!body.answers || typeof body.answers !== 'object') return json({ error: 'invalid answers' }, 400, cors);

  const file = `answers/${body.path}.json`;
  const existing = await ghGet(env, file);
  const payload = JSON.stringify(
    { answers: body.answers, updatedAt: new Date().toISOString() },
    null,
    2
  );
  await ghPut(env, file, payload, existing.sha);
  return json({ ok: true, updatedAt: new Date().toISOString() }, 200, cors);
}

function isSafePath(p) {
  return /^[a-zA-Z0-9_\-\/]+$/.test(p) && !p.includes('..');
}

async function ghGet(env, path) {
  const r = await fetch(
    `https://api.github.com/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}/contents/${path}?ref=${env.GITHUB_BRANCH}`,
    {
      headers: {
        'Authorization': `Bearer ${env.GITHUB_TOKEN}`,
        'User-Agent': 'jobStudy-worker',
        'Accept': 'application/vnd.github+json',
      },
    }
  );
  if (r.status === 404) return { status: 404 };
  if (!r.ok) throw new Error(`GitHub GET ${r.status}: ${await r.text()}`);
  const j = await r.json();
  const content = atob(j.content.replace(/\n/g, ''));
  return { status: 200, sha: j.sha, data: JSON.parse(content) };
}

async function ghPut(env, path, content, sha) {
  const body = {
    message: `chore(answers): update ${path}`,
    content: btoa(unescape(encodeURIComponent(content))),
    branch: env.GITHUB_BRANCH,
  };
  if (sha) body.sha = sha;
  const r = await fetch(
    `https://api.github.com/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}/contents/${path}`,
    {
      method: 'PUT',
      headers: {
        'Authorization': `Bearer ${env.GITHUB_TOKEN}`,
        'User-Agent': 'jobStudy-worker',
        'Accept': 'application/vnd.github+json',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    }
  );
  if (!r.ok) throw new Error(`GitHub PUT ${r.status}: ${await r.text()}`);
}

function json(data, status, cors) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}
