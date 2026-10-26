import http from 'node:http';
import { timingSafeEqual } from 'node:crypto';
import { appendFile, mkdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ask, OpenAIModel } from './assistant.mjs';
import { MarketData } from './market.mjs';
import { symbol, validateHoldings } from './finance.mjs';
import { DailyBudget, validateDeployment } from './security.mjs';

export function validateRequest(raw) {
  const holdings = validateHoldings(raw.holdings);
  if (!Array.isArray(raw.watchlist) || raw.watchlist.length > 50) throw new Error('Invalid watchlist');
  const watchlist = [...new Set(raw.watchlist.map(symbol))];
  if (new Set([...holdings.map(h => h.ticker), ...watchlist]).size > 50) throw new Error('At most fifty distinct symbols');
  if (!Array.isArray(raw.messages) || !raw.messages.length || raw.messages.length > 20) throw new Error('Invalid conversation');
  let count = 0;
  const messages = raw.messages.map(m => {
    if (!['user', 'assistant'].includes(m.role) || typeof m.content !== 'string' || !m.content.trim() || m.content.length > 4000) throw new Error('Invalid message');
    count += m.content.length;
    return { role: m.role, content: m.content };
  });
  if (messages.at(-1).role !== 'user' || count > 20_000) throw new Error('Invalid conversation');
  return { holdings, watchlist, messages };
}
async function body(request) {
  let size = 0, chunks = [];
  for await (const chunk of request) {
    size += chunk.length;
    if (size > 65_536) throw new Error('Request too large');
    chunks.push(chunk);
  }
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
}
function authorized(request, token) {
  if (!token) return true; // Allowed only on loopback; listen() enforces this.
  const given = Buffer.from(request.headers.authorization ?? '');
  const expected = Buffer.from(`Bearer ${token}`);
  return given.length === expected.length && timingSafeEqual(given, expected);
}
export function createServer({ market = new MarketData(), model = new OpenAIModel(), token = process.env.PERCH_API_TOKEN,
  analyticsPath = process.env.PERCH_ANALYTICS_PATH ?? './data/events.jsonl',
  budget = new DailyBudget({ limit: Number(process.env.PERCH_DAILY_ANSWER_LIMIT ?? 50),
    path: process.env.NODE_ENV === 'production' ? process.env.PERCH_BUDGET_PATH ?? './data/budget.json' : undefined }) } = {}) {
  const requests = new Map(), issuedAnswers = new Map();
  let active = 0;
  async function record(event) {
    await mkdir(dirname(analyticsPath), { recursive: true });
    await appendFile(analyticsPath, JSON.stringify({ at: new Date().toISOString(), ...event }) + '\n', { mode: 0o600 });
  }
  const json = (response, status, value) => {
    response.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
    response.end(JSON.stringify(value));
  };
  return http.createServer({ requestTimeout: 20_000, headersTimeout: 10_000 }, async (request, response) => {
    const url = new URL(request.url, 'http://localhost');
    if (url.pathname === '/health' && request.method === 'GET') return json(response, 200, { status: 'ok' });
    if (!authorized(request, token)) return json(response, 401, { error: 'Authentication required' });
    // A single demo token shares its limit across IPs and reverse proxies.
    const address = token ? 'authenticated-demo' : request.socket.remoteAddress ?? 'unknown';
    const now = Date.now();
    // Bound the map and expire idle buckets. No IP addresses are persisted.
    for (const [key, bucket] of requests) if (now - bucket.start > 60_000) requests.delete(key);
    if (requests.size > 10_000) return json(response, 503, { error: 'Busy, please try again' });
    const bucket = requests.get(address) ?? { start: now, count: 0 };
    bucket.count++; requests.set(address, bucket);
    if (bucket.count > 30) { response.setHeader('Retry-After', '60'); return json(response, 429, { error: 'Please wait before trying again' }); }
    if (active >= 8) return json(response, 503, { error: 'Busy, please try again' });
    active++;
    try {
      if (request.method === 'GET' && url.pathname === '/v1/status') return json(response, 200, {
        status: 'ok', marketConfigured: Boolean(market.apiKey?.trim()), aiConfigured: Boolean(model?.apiKey?.trim())
      });
      if (request.method === 'GET' && url.pathname === '/v1/quotes') {
        const symbols = (url.searchParams.get('symbols') ?? '').split(',').filter(Boolean);
        return json(response, 200, await market.quotes(symbols));
      }
      if (request.method === 'POST' && ['/v1/ask', '/v1/insights'].includes(url.pathname)) {
        const input = validateRequest(await body(request));
        let allowed;
        try { allowed = await budget.reserve(); }
        catch { return json(response, 503, { error: 'Request budget is temporarily unavailable' }); }
        if (!allowed) { response.setHeader('Retry-After', '3600'); return json(response, 429, { error: 'Demo answer budget reached; please try another day' }); }
        const abort = new AbortController();
        const timer = setTimeout(() => abort.abort(), 90_000);
        response.on('close', () => { if (!response.writableEnded) abort.abort(); });
        const stream = url.pathname === '/v1/ask';
        if (stream) response.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache, no-transform',
          Connection: 'keep-alive', 'X-Accel-Buffering': 'no', 'X-Content-Type-Options': 'nosniff' });
        const heartbeat = stream ? setInterval(() => { if (!response.destroyed) response.write(': keepalive\n\n'); }, 10_000) : null;
        try {
          const result = await ask({ ...input, market, model, signal: abort.signal,
            onEvent: stream ? event => { if (!response.destroyed) response.write(`data: ${JSON.stringify(event)}\n\n`); } : undefined });
          for (const [id, entry] of issuedAnswers) if (now - entry.at > 86_400_000) issuedAnswers.delete(id);
          if (issuedAnswers.size >= 2000) issuedAnswers.delete(issuedAnswers.keys().next().value);
          issuedAnswers.set(result.id, { at: now, rated: false });
          // No prompts, messages, positions, quote values, tokens, or identifiers are logged.
          await record({ type: 'answer', mode: result.mode, latencyMs: result.latencyMs,
            coverage: result.coverage, freshness: result.freshness, toolCalls: result.toolCalls, metrics: result.metrics }).catch(() => {});
          if (stream) response.end(); else json(response, 200, result);
        } finally { clearTimeout(timer); if (heartbeat) clearInterval(heartbeat); }
        return;
      }
      if (request.method === 'POST' && url.pathname === '/v1/feedback') {
        const raw = await body(request);
        const entry = issuedAnswers.get(raw.answerID);
        if (!entry || entry.rated || !['helpful', 'unhelpful'].includes(raw.rating)) return json(response, 400, { error: 'Invalid feedback' });
        entry.rated = true;
        try { await record({ type: 'feedback', rating: raw.rating }); }
        catch (error) { entry.rated = false; throw error; }
        return json(response, 200, { saved: true });
      }
      json(response, 404, { error: 'Not found' });
    } catch {
      if (response.headersSent) {
        if (!response.destroyed) response.end(`data: ${JSON.stringify({ type: 'error', message: 'The response was interrupted. Please retry.' })}\n\n`);
      } else json(response, 400, { error: 'Invalid request or data unavailable' });
    } finally { active--; }
  });
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const host = process.env.HOST ?? '127.0.0.1';
  validateDeployment({ host, production: process.env.NODE_ENV === 'production', token: process.env.PERCH_API_TOKEN,
    openAIKey: process.env.OPENAI_API_KEY, finnhubKey: process.env.FINNHUB_API_KEY });
  const server = createServer();
  server.listen(Number(process.env.PORT ?? 8787), host, () => process.stdout.write('Perch API listening\n'));
  for (const name of ['SIGTERM', 'SIGINT']) process.on(name, () => {
    server.close(() => process.exit(0));
    setTimeout(() => { server.closeAllConnections(); process.exit(0); }, 10_000).unref();
  });
}
