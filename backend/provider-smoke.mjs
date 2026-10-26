import { writeFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import { ask, OpenAIModel } from './assistant.mjs';
import { MarketData } from './market.mjs';
import { elapsed, failureCode } from './diagnostics.mjs';

export async function verifyProviders({ market = new MarketData(), model = new OpenAIModel(),
  quoteConfigured = Boolean(process.env.FINNHUB_API_KEY?.trim()), llmConfigured = Boolean(process.env.OPENAI_API_KEY?.trim()) } = {}) {
  const result = { generatedAt: new Date().toISOString(), finnhub: { status: 'blocked', reason: 'not_configured' },
    openai: { status: 'blocked', reason: 'not_configured' }, passed: false };
  let quote;
  if (quoteConfigured) {
    const began = performance.now();
    try {
      quote = await market.quote('AAPL');
      result.finnhub = { status: 'passed', ticker: quote.ticker, asOf: quote.asOf, freshness: quote.freshness,
        source: quote.source, latencyMs: elapsed(began) };
    } catch (error) { result.finnhub = { status: 'failed', reason: failureCode(error), latencyMs: elapsed(began) }; }
  }
  if (llmConfigured) {
    // Only synthetic positions are sent. If market validation failed, use an explicitly
    // identified fixture to isolate real LLM connectivity from market connectivity.
    const chosen = quote ?? { ticker: 'AAPL', price: 10, previousClose: 12, sector: 'Technology', source: 'Finnhub',
      freshness: 'fresh', asOf: new Date().toISOString() };
    const selectedMarket = { quotes: async () => ({ quotes: [chosen], unavailable: [] }), quote: async () => chosen };
    try {
      const answer = await ask({ holdings: [{ ticker: 'AAPL', shares: 2.5, averageCost: 8 }], watchlist: ['AAPL'],
        messages: [{ role: 'user', content: 'Explain my current portfolio value and daily price contribution. Reference portfolio.value and portfolio.day.' }],
        market: selectedMarket, model });
      const passed = answer.mode === 'llm' && ['portfolio.value', 'portfolio.day'].every(id => answer.factIDs.includes(id));
      result.openai = { status: passed ? 'passed' : 'failed', reason: passed ? null : answer.metrics?.fallbackReason ?? 'missing_expected_facts',
        marketData: quote ? 'live-provider-quote' : 'fixture', model: model.model ?? null, latencyMs: answer.latencyMs,
        firstDraftMs: answer.metrics?.firstDraftMs, modelRequests: answer.metrics?.modelRequests };
    } catch (error) { result.openai = { status: 'failed', reason: failureCode(error) }; }
  }
  result.passed = result.finnhub.status === 'passed' && result.openai.status === 'passed';
  return result;
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const result = await verifyProviders();
  await writeFile(new URL('./eval-results-providers.json', import.meta.url), JSON.stringify(result, null, 2));
  console.log(JSON.stringify(result, null, 2));
  if (!result.passed) process.exitCode = [result.finnhub, result.openai].some(r => r.status === 'failed') ? 1 : 2;
}
