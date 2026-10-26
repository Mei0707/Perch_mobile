// Opt-in live smoke: real backend HTTP/SSE + real providers, synthetic holdings only.
import { writeFile } from 'node:fs/promises';
import { sseEvents } from './assistant.mjs';
const base = new URL(process.env.PERCH_VERIFY_BASE_URL ?? 'http://127.0.0.1:8787');
if (base.protocol !== 'https:' && !(base.protocol === 'http:' && ['127.0.0.1', 'localhost', '[::1]'].includes(base.hostname))) throw new Error('Use HTTPS or loopback');
if (!process.env.PERCH_API_TOKEN?.trim()) throw new Error('Configure PERCH_API_TOKEN in the local ignored .env');
const headers = { Authorization: `Bearer ${process.env.PERCH_API_TOKEN}`, 'Content-Type': 'application/json' };
const unauthorized = await fetch(new URL('/v1/status', base));
if (unauthorized.status !== 401) throw new Error('Backend did not require authentication');
const response = await fetch(new URL('/v1/ask', base), { method: 'POST', headers, signal: AbortSignal.timeout(100_000),
  body: JSON.stringify({ holdings: [{ ticker: 'NVDA', shares: 35, averageCost: 8 }, { ticker: 'AAPL', shares: 65, averageCost: 8 }],
    watchlist: ['AAPL', 'NVDA'], messages: [{ role: 'user', content: 'What happens if I reduce NVDA by 20%?' }] }) });
if (!response.ok) throw new Error(`Backend returned HTTP ${response.status}`);
let answer, draftReceived = false;
for await (const event of sseEvents(response.body)) {
  if (event.type === 'draft' && event.text) draftReceived = true;
  if (event.type === 'error') throw new Error('Backend stream failed');
  if (event.type === 'complete') answer = event.answer;
}
if (!answer) throw new Error('Stream ended without completion');
const passed = answer.mode === 'llm' && answer.coverage === 'complete' && draftReceived
  && answer.sources.length === 2 && answer.sources.every(s => s.source === 'Finnhub')
  && answer.metrics.toolResults.some(t => t.name === 'simulateTrade' && t.origin === 'model' && t.success);
const report = { generatedAt: new Date().toISOString(), baseURL: base.origin, passed, syntheticPositions: true,
  authenticated: true, mode: answer.mode, coverage: answer.coverage, draftReceived, latencyMs: answer.latencyMs,
  firstDraftMs: answer.metrics.firstDraftMs, sources: answer.sources, failure: answer.metrics.fallbackReason,
  explanation: answer.explanation, limitations: answer.limitations };
await writeFile(new URL('./eval-results-http.json', import.meta.url), JSON.stringify(report, null, 2));
console.log(JSON.stringify({ ...report, explanation: undefined, limitations: undefined }, null, 2));
if (!passed) process.exitCode = 1;
