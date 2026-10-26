import test from 'node:test';
import assert from 'node:assert/strict';
import { MarketData } from '../market.mjs';
const now = Date.now();
const raw = { c: 10, pc: 12, o: 11, h: 12, l: 9, t: Math.floor(now / 1000) };
const response = body => new Response(JSON.stringify(body));

test('uses server credential, coalesces quotes and expires cache', async () => {
  let clock = now, count = 0;
  const market = new MarketData({ apiKey: 'server-only', now: () => clock, fetcher: async (url, options) => {
    count++;
    assert.equal(url.searchParams.get('symbol'), 'NVDA');
    assert.equal(url.searchParams.has('token'), false);
    assert.equal(options.headers['X-Finnhub-Token'], 'server-only');
    return response(raw);
  } });
  await Promise.all([market.quote('NVDA'), market.quote('NVDA')]);
  assert.equal(count, 1);
  await market.quote('NVDA'); assert.equal(count, 1);
  clock += 61000;
  await market.quote('NVDA'); assert.equal(count, 2);
});
test('provider failures return stale cache with original timestamp, never fabricated prices', async () => {
  let clock = now, fail = false;
  const market = new MarketData({ apiKey: 'test', now: () => clock, fetcher: async () => {
    if (fail) throw new Error('offline');
    return response(raw);
  } });
  const first = await market.quote('NVDA');
  fail = true; clock += 61000;
  const cached = await market.quote('NVDA');
  assert.equal(cached.price, first.price);
  assert.equal(cached.asOf, first.asOf);
  assert.equal(cached.freshness, 'stale');
  const missing = await market.quotes(['AAPL']);
  assert.deepEqual(missing.unavailable, ['AAPL']);
  assert.deepEqual(missing.quotes, []);
});
test('zero and invalid provider payloads are unavailable', async () => {
  for (const value of [{}, { ...raw, c: 0 }, { ...raw, t: 0 }, { ...raw, pc: -1 }, { ...raw, t: Infinity }]) {
    const market = new MarketData({ apiKey: 'test', fetcher: async () => response(value) });
    const result = await market.quotes(['NVDA']);
    assert.deepEqual(result.unavailable, ['NVDA']);
  }
});
test('missing provider configuration has no demo quote fallback', async () => {
  const result = await new MarketData({ apiKey: '' }).quotes(['AAPL']);
  assert.deepEqual(result, { quotes: [], unavailable: ['AAPL'] });
});
