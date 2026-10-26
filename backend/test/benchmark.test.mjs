import test from 'node:test';
import assert from 'node:assert/strict';
import { gradeAnswer, percentile, summarize } from '../benchmark.mjs';
import { ask, OpenAIModel } from '../assistant.mjs';

const holdings = [{ ticker: 'AAPL', shares: 10, averageCost: 8 }];
const quotes = [{ ticker: 'AAPL', price: 10, previousClose: 12, source: 'Finnhub', asOf: new Date().toISOString() }];
const market = { quotes: async () => ({ quotes, unavailable: [] }), quote: async () => quotes[0] };
const raw = { title: 'Movement', explanationTemplate: 'Daily contribution is {{portfolio.day}}.', factIDs: ['portfolio.day'], limitations: [] };

test('benchmark distinguishes real model calls, automatic reads, first draft, and failed tools', async () => {
  let round = 0;
  const model = { model: 'fixture-adapter', plan: async () => round++ === 0 ? [
    { type: 'function_call', call_id: 'unknown', name: 'executeTrade', arguments: '{}' },
    { type: 'function_call', call_id: 'allocation', name: 'calculateAllocation', arguments: '{}' }
  ] : [], explain: async (_, __, onDraft) => { onDraft('Daily contribution is -$20.00.'); return raw; } };
  const answer = await ask({ holdings, messages: [{ role: 'user', content: 'Explain my daily movement' }], market, model });
  assert.equal(answer.metrics.modelRequests, 2);
  assert.equal(answer.metrics.toolResults.filter(t => t.origin === 'automatic').length, 1);
  const modelTools = answer.metrics.toolResults.filter(t => t.origin === 'model');
  assert.equal(modelTools.length, 2);
  assert.equal(modelTools.filter(t => t.success).length, 1);
  assert.ok(answer.metrics.firstDraftMs >= 0);
  const report = summarize([{ ...answer, passed: true }]);
  assert.equal(report.modelToolSuccessRate, 0.5);
  assert.equal(report.llmAnswers, 1);
});
test('offline fallback is never reported as successful LLM performance', async () => {
  const answer = await ask({ holdings, messages: [{ role: 'user', content: 'Explain movement' }], market, model: null });
  const report = summarize([{ ...answer, passed: true }]);
  assert.equal(report.llmP95Ms, null);
  assert.equal(report.firstDraftP95Ms, null);
  assert.equal(report.modelToolSuccessRate, null);
  assert.equal(report.modelRequests, 0);
  assert.equal(answer.metrics.fallbackReason, 'not_configured');
  assert.equal(gradeAnswer(answer, {}, true).passed, false);
});
test('live scenario grade requires a successful model tool, not a matching fallback number', () => {
  const answer = { mode: 'llm', factIDs: ['scenario.after'], explanation: '28.00%', metrics: { toolResults: [{ name: 'simulateTrade', success: true, origin: 'fallback' }] } };
  assert.equal(gradeAnswer(answer, { requiredTool: 'simulateTrade', contains: '28.00%' }, true).passed, false);
});
test('provider authentication failure is measurable without leaking response bodies', async () => {
  const model = new OpenAIModel({ apiKey: 'private-secret', fetcher: async () => new Response('sensitive-provider-error', { status: 401 }) });
  const answer = await ask({ holdings, messages: [{ role: 'user', content: 'Explain movement' }], market, model });
  assert.equal(answer.metrics.fallbackReason, 'authentication');
  assert.doesNotMatch(JSON.stringify(answer), /private-secret|sensitive-provider-error/);
});
test('percentiles reject missing/nonfinite samples and use the nearest-rank definition', () => {
  assert.equal(percentile([1, 2, 3, null, NaN, Infinity], 0.95), 3);
  assert.equal(percentile([], 0.95), null);
});

test('known unused declarations are canonicalized while every unknown reference is rejected', async () => {
  const { validateAnswer } = await import('../assistant.mjs');
  const { factsFor, portfolio } = await import('../finance.mjs');
  const facts = factsFor(portfolio(holdings, quotes));
  const answer = validateAnswer({ ...raw, factIDs: ['portfolio.day', 'portfolio.value'] }, facts);
  assert.deepEqual(answer.factIDs, ['portfolio.day']);
  assert.throws(() => validateAnswer({ ...raw, explanationTemplate: 'Value {{invented.fact}}.' }, facts));
});

test('generation schema permits only known numeric placeholders, including sector IDs', async () => {
  const { answerSchemaFor } = await import('../assistant.mjs');
  const schema = answerSchemaFor([{ id: 'portfolio.value' }, { id: 'sector.0' }]);
  const pattern = new RegExp(schema.properties.explanationTemplate.pattern);
  assert.equal(pattern.test('Value {{portfolio.value}}, sector {{sector.0}}.'), true);
  assert.equal(pattern.test('Invented {{portfolioXvalue}}.'), false);
  assert.equal(pattern.test('A return of 99%.'), false);
  assert.deepEqual(schema.properties.title.enum, ['Portfolio explanation']);
  assert.equal(answerSchemaFor([]).properties.factIDs.maxItems, 0);
});

test('ordinary qualitative prose is allowed while spelled-out financial quantities are rejected', async () => {
  const { validateAnswer } = await import('../assistant.mjs');
  const { factsFor, portfolio } = await import('../finance.mjs');
  const facts = factsFor(portfolio(holdings, quotes));
  assert.doesNotThrow(() => validateAnswer({ ...raw, explanationTemplate: 'A move in one holding can affect portfolio movement: {{portfolio.day}}.' }, facts));
  assert.throws(() => validateAnswer({ ...raw, explanationTemplate: 'Your gain was twenty dollars.' }, facts));
  assert.throws(() => validateAnswer({ ...raw, explanationTemplate: 'Sell twenty shares.' }, facts));
});

test('generation rejects Unicode number evasions and requires an incomplete-coverage preface', async () => {
  const { answerSchemaFor, validateAnswer } = await import('../assistant.mjs');
  const schema = answerSchemaFor([{ id: 'portfolio.value' }]);
  assert.equal(new RegExp(schema.properties.explanationTemplate.pattern).test('Guaranteed return ⁹⁹⁹.'), false);
  assert.throws(() => validateAnswer({ ...raw, explanationTemplate: 'Guaranteed return ⁹⁹⁹.' }, [{ id: 'portfolio.day', display: '$0.00' }]));
  const incomplete = new RegExp(answerSchemaFor([{ id: 'AAPL.value' }]).properties.explanationTemplate.pattern);
  assert.throws(() => validateAnswer({ ...raw, explanationTemplate: 'Your portfolio dropped today.', factIDs: [] }, [{ id: 'AAPL.value', display: '$1.00' }]));
  assert.equal(incomplete.test('Portfolio totals and overall movement are unavailable because quotes are missing. AAPL value is {{AAPL.value}}.'), true);
});

test('quote tool cannot add zero-price facts even if an adapter violates the quote contract', async () => {
  const invalidMarket = { quotes: async () => ({ quotes, unavailable: [] }), quote: async () => ({ ...quotes[0], price: 0 }) };
  const model = { plan: async () => [{ type: 'function_call', name: 'getStockQuote', call_id: 'invalid', arguments: '{"ticker":"AAPL"}' }],
    explain: async (input, facts) => { assert.equal(facts.some(f => f.id === 'AAPL.quote'), false); return raw; } };
  const answer = await ask({ holdings, messages: [{ role: 'user', content: 'Quote AAPL' }], market: invalidMarket, model });
  assert.equal(answer.metrics.toolResults.find(t => t.name === 'getStockQuote').success, false);
});

test('scenario explanation sees after-sale sector facts instead of stale current risk facts', async () => {
  const twoHoldings = [{ ticker: 'NVDA', shares: 35, averageCost: 8 }, { ticker: 'AAPL', shares: 65, averageCost: 8 }];
  const twoQuotes = ['NVDA', 'AAPL'].map(ticker => ({ ticker, price: 10, previousClose: 10, sector: 'Technology', source: 'Finnhub', asOf: new Date().toISOString() }));
  const model = { plan: async () => [{ type: 'function_call', name: 'simulateTrade', call_id: 'sale', arguments: '{"ticker":"NVDA","reductionPercent":20}' }],
    explain: async (_, facts) => {
      assert.equal(facts.some(f => f.id === 'sector.0'), false);
      assert.equal(facts.find(f => f.id === 'scenario.sectorAfter').display, '93.00%');
      return { title: 'Sale scenario', explanationTemplate: 'Sector exposure after sale is {{scenario.sectorAfter}}.', factIDs: ['scenario.sectorAfter'], limitations: [] };
    } };
  const result = await ask({ holdings: twoHoldings, messages: [{ role: 'user', content: 'Reduce NVDA by twenty percent' }], market: { quotes: async () => ({ quotes: twoQuotes }) }, model });
  assert.equal(result.mode, 'llm');
});
