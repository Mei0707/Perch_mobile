import { FRESH_MS, symbol, validQuote } from './finance.mjs';
import { ProviderError } from './diagnostics.mjs';
const metadata = {
  AAPL: ['Apple Inc.', 'Technology'], MSFT: ['Microsoft Corp.', 'Technology'], NVDA: ['NVIDIA Corp.', 'Technology'],
  AMZN: ['Amazon.com Inc.', 'Consumer'], GOOGL: ['Alphabet Inc.', 'Communication'], TSLA: ['Tesla Inc.', 'Consumer'],
  META: ['Meta Platforms Inc.', 'Communication'], AMD: ['Advanced Micro Devices', 'Technology'],
  JPM: ['JPMorgan Chase & Co.', 'Financials'], UNH: ['UnitedHealth Group', 'Healthcare'],
  NFLX: ['Netflix Inc.', 'Communication'], COST: ['Costco Wholesale Corp.', 'Consumer']
};
export class MarketData {
  constructor({ apiKey = process.env.FINNHUB_API_KEY, fetcher = fetch, now = Date.now, perMinuteLimit = 50 } = {}) {
    this.apiKey = apiKey; this.fetcher = fetcher; this.now = now;
    this.perMinuteLimit = perMinuteLimit; this.window = { start: now(), count: 0 };
    this.cache = new Map(); this.inflight = new Map(); this.lastFailure = new Map();
  }
  async quote(rawTicker) {
    const ticker = symbol(rawTicker);
    const cached = this.cache.get(ticker);
    if (cached && this.now() - cached.fetchedAt < 60_000) return this.withFreshness(cached.quote);
    if (!this.apiKey) throw new ProviderError('finnhub', 'not_configured');
    if (this.lastFailure.get(ticker) > this.now() - 30_000) {
      if (cached && this.now() - Date.parse(cached.quote.asOf) < 7 * 86_400_000) return { ...this.withFreshness(cached.quote), freshness: 'stale' };
      throw new ProviderError('finnhub', 'backoff');
    }
    if (this.inflight.has(ticker)) return this.inflight.get(ticker);
    const pending = this.fetchQuote(ticker, cached).finally(() => this.inflight.delete(ticker));
    this.inflight.set(ticker, pending);
    return pending;
  }
  withFreshness(quote) {
    return { ...quote, freshness: this.now() - Date.parse(quote.asOf) > FRESH_MS ? 'stale' : 'fresh' };
  }
  async fetchQuote(ticker, cached) {
    try {
      if (this.now() - this.window.start >= 60_000) this.window = { start: this.now(), count: 0 };
      if (++this.window.count > this.perMinuteLimit) throw new ProviderError('finnhub', 'local_rate_limit');
      const url = new URL('https://finnhub.io/api/v1/quote');
      url.searchParams.set('symbol', ticker);
      const response = await this.fetcher(url, {
        headers: { 'X-Finnhub-Token': this.apiKey }, signal: AbortSignal.timeout(8_000)
      });
      if (!response.ok) throw new ProviderError('finnhub', [401, 403].includes(response.status) ? 'authentication'
        : response.status === 429 ? 'rate_limited' : 'unavailable', response.status);
      const raw = await response.json();
      const quote = { ticker, name: metadata[ticker]?.[0] ?? ticker, sector: metadata[ticker]?.[1] ?? 'Unknown',
        price: raw.c, previousClose: raw.pc, open: raw.o, high: raw.h, low: raw.l,
        asOf: typeof raw.t === 'number' && raw.t > 0 && raw.t < 1e11 ? new Date(raw.t * 1000).toISOString() : '', source: 'Finnhub' };
      if (!validQuote(quote, this.now())) throw new ProviderError('finnhub', 'invalid_quote');
      if (this.cache.size >= 500) this.cache.delete(this.cache.keys().next().value);
      this.cache.set(ticker, { quote, fetchedAt: this.now() });
      this.lastFailure.delete(ticker);
      return this.withFreshness(quote);
    } catch (error) {
      if (this.lastFailure.size >= 500) this.lastFailure.clear();
      this.lastFailure.set(ticker, this.now());
      if (cached && this.now() - Date.parse(cached.quote.asOf) < 7 * 86_400_000) return { ...this.withFreshness(cached.quote), freshness: 'stale' };
      throw error instanceof ProviderError ? error : new ProviderError('finnhub', error?.name === 'TimeoutError' ? 'timeout' : 'network');
    }
  }
  async quotes(tickers) {
    const unique = [...new Set(tickers.map(symbol))];
    if (unique.length > 50) throw new Error('At most fifty symbols per request');
    const quotes = [], unavailable = [];
    // Bound fan-out to respect provider quotas; per-symbol requests are coalesced.
    for (let i = 0; i < unique.length; i += 4) {
      const batch = await Promise.allSettled(unique.slice(i, i + 4).map(t => this.quote(t)));
      batch.forEach((r, index) => r.status === 'fulfilled' ? quotes.push(r.value) : unavailable.push(unique[i + index]));
    }
    return { quotes, unavailable };
  }
}
