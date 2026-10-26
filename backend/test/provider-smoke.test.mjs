import test from 'node:test';
import assert from 'node:assert/strict';
import { verifyProviders } from '../provider-smoke.mjs';
import { MarketData } from '../market.mjs';

test('live smoke reports missing keys as blocked and makes no requests', async () => {
  let calls = 0;
  const result = await verifyProviders({ quoteConfigured: false, llmConfigured: false,
    market: { quote: async () => { calls++; } }, model: { plan: async () => { calls++; } } });
  assert.equal(result.passed, false);
  assert.equal(result.finnhub.status, 'blocked');
  assert.equal(result.openai.status, 'blocked');
  assert.equal(calls, 0);
});
test('fallback output never passes a live provider smoke test', async () => {
  const result = await verifyProviders({ quoteConfigured: false, llmConfigured: true,
    model: { plan: async () => { throw new Error('provider offline'); } } });
  assert.equal(result.openai.status, 'failed');
  assert.equal(result.openai.marketData, 'fixture');
  assert.equal(result.passed, false);
});
test('Finnhub authentication errors are classified without exposing payloads', async () => {
  const market = new MarketData({ apiKey: 'secret', fetcher: async () => new Response('private provider detail', { status: 401 }) });
  const result = await verifyProviders({ market, quoteConfigured: true, llmConfigured: false });
  assert.equal(result.finnhub.reason, 'authentication');
  assert.doesNotMatch(JSON.stringify(result), /private provider detail|secret/);
});
test('market provider request budget bounds distinct-symbol fan-out', async () => {
  let calls = 0;
  const market = new MarketData({ apiKey: 'test', perMinuteLimit: 1, fetcher: async () => {
    calls++;
    return new Response(JSON.stringify({ c: 10, pc: 9, t: Math.floor(Date.now() / 1000) }));
  } });
  const batch = await market.quotes(['AAPL', 'NVDA']);
  assert.equal(calls, 1);
  assert.equal(batch.quotes.length, 1);
  assert.deepEqual(batch.unavailable, ['NVDA']);
});
