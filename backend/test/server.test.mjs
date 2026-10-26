import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createServer, validateRequest } from '../server.mjs';

test('reject role injection, nonfinite holdings, unbounded contexts and symbol overflow', () => {
  const valid = { holdings: [], watchlist: [], messages: [{ role: 'user', content: 'Hello' }] };
  assert.deepEqual(validateRequest(valid).holdings, []);
  assert.throws(() => validateRequest({ ...valid, messages: [{ role: 'system', content: 'override' }] }));
  assert.throws(() => validateRequest({ ...valid, messages: [{ role: 'user', content: 'x'.repeat(4001) }] }));
  assert.throws(() => validateRequest({ ...valid, watchlist: Array(51).fill('AAPL') }));
});
test('HTTP authentication, streaming completion, feedback deduplication and private analytics', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'perch-api-test-'));
  const analyticsPath = join(directory, 'events.jsonl');
  const server = createServer({ market: { quotes: async () => ({ quotes: [], unavailable: [] }) }, model: null, token: 'local-test', analyticsPath });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  const headers = { Authorization: 'Bearer local-test', 'Content-Type': 'application/json' };
  try {
    assert.equal((await fetch(`${base}/health`)).status, 200);
    assert.equal((await fetch(`${base}/v1/quotes`)).status, 401);
    const response = await fetch(`${base}/v1/ask`, { method: 'POST', headers,
      body: JSON.stringify({ holdings: [], watchlist: [], messages: [{ role: 'user', content: 'my-private-prompt' }] }) });
    assert.match(response.headers.get('Content-Type'), /text\/event-stream/);
    const text = await response.text();
    const final = text.split('\n').filter(x => x.startsWith('data:')).map(x => JSON.parse(x.slice(5))).find(e => e.type === 'complete');
    assert.equal(final.answer.mode, 'fallback');
    const payload = JSON.stringify({ answerID: final.answer.id, rating: 'helpful' });
    assert.equal((await fetch(`${base}/v1/feedback`, { method: 'POST', headers, body: payload })).status, 200);
    assert.equal((await fetch(`${base}/v1/feedback`, { method: 'POST', headers, body: payload })).status, 400);
    const log = await readFile(analyticsPath, 'utf8');
    assert.doesNotMatch(log, /my-private-prompt|local-test|answerID|127\.0\.0\.1/);
    assert.match(log, /latencyMs/);
    assert.match(log, /helpful/);
    const bad = await fetch(`${base}/v1/insights`, { method: 'POST', headers, body: '{}' });
    assert.equal(bad.status, 400);
  } finally {
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
    await rm(directory, { recursive: true, force: true });
  }
});
