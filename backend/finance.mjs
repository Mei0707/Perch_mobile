// Monetary arithmetic uses integer micro-units and rounds each position to cents.
// Long-only USD equities; quantities have at most six decimal places.
export const SYMBOL = /^[A-Z][A-Z0-9.-]{0,7}$/;
export const FRESH_MS = 15 * 60_000;
export function symbol(value) {
  const result = String(value ?? '').trim().toUpperCase();
  if (!SYMBOL.test(result)) throw new Error('Invalid ticker');
  return result;
}
const finite = (n, min, max) => typeof n === 'number' && Number.isFinite(n) && n >= min && n <= max;
export function validateHoldings(input) {
  if (!Array.isArray(input) || input.length > 50) throw new Error('Invalid holdings');
  const seen = new Set();
  return input.map(h => {
    const ticker = symbol(h.ticker);
    if (seen.has(ticker) || !finite(h.shares, 0.000001, 1e7) || !finite(h.averageCost, 0, 1e7)) throw new Error('Invalid position');
    if (Math.abs(h.shares * 1e6 - Math.round(h.shares * 1e6)) > 0.01) throw new Error('Shares support six decimal places');
    seen.add(ticker);
    return { ticker, shares: h.shares, averageCost: h.averageCost };
  });
}
export function validQuote(q, now = Date.now()) {
  return q && SYMBOL.test(q.ticker) && finite(q.price, 0.000001, 1e7)
    && finite(q.previousClose, 0.000001, 1e7)
    && typeof q.asOf === 'string' && Number.isFinite(Date.parse(q.asOf))
    && Date.parse(q.asOf) > 0 && Date.parse(q.asOf) <= now + 60_000
    && q.source === 'Finnhub';
}
const micro = n => BigInt(Math.round(n * 1e6));
function cents(shares, price) {
  const product = micro(shares) * micro(price);
  const result = (product + 5_000_000_000n) / 10_000_000_000n;
  if (result > BigInt(Number.MAX_SAFE_INTEGER)) throw new Error('Position value exceeds supported precision');
  return Number(result);
}
export const money = value => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(value);
export const percent = value => `${value.toFixed(2)}%`;
export function portfolio(holdings, quotes, now = Date.now()) {
  const byTicker = new Map(quotes.filter(q => validQuote(q, now)).map(q => [q.ticker, q]));
  const missing = holdings.filter(h => !byTicker.has(h.ticker)).map(h => h.ticker);
  const positions = holdings.flatMap(h => {
    const q = byTicker.get(h.ticker);
    if (!q) return [];
    const valueCents = cents(h.shares, q.price);
    const previousCents = cents(h.shares, q.previousClose);
    return [{ ticker: h.ticker, shares: h.shares, price: q.price, sector: q.sector ?? 'Unknown', valueCents,
      previousCents, dayCents: valueCents - previousCents,
      costCents: cents(h.shares, h.averageCost), asOf: q.asOf }];
  });
  const totalCents = positions.reduce((s, p) => s + p.valueCents, 0);
  const previousCents = positions.reduce((s, p) => s + p.previousCents, 0);
  if (!Number.isSafeInteger(totalCents) || !Number.isSafeInteger(previousCents)) throw new Error('Portfolio value exceeds supported precision');
  const complete = missing.length === 0;
  for (const p of positions) p.allocation = complete && totalCents > 0 ? p.valueCents / totalCents * 100 : null;
  const sectorValues = {};
  for (const p of positions) sectorValues[p.sector] = (sectorValues[p.sector] ?? 0) + p.valueCents;
  const sectors = complete && totalCents > 0 ? Object.entries(sectorValues).map(([sector, value]) => ({ sector, allocation: value / totalCents * 100 })) : [];
  const hhi = complete && totalCents > 0 ? positions.reduce((s, p) => s + (p.valueCents / totalCents) ** 2, 0) : null;
  const timestamps = positions.map(p => Date.parse(p.asOf));
  return { complete, missing, positions, sectors, totalValue: complete ? totalCents / 100 : null,
    dayChange: complete ? (totalCents - previousCents) / 100 : null,
    dayChangePercent: complete && previousCents > 0 ? (totalCents - previousCents) / previousCents * 100 : null,
    hhi, effectivePositions: hhi ? 1 / hhi : null,
    asOf: timestamps.length ? new Date(Math.min(...timestamps)).toISOString() : null,
    freshness: !complete || !timestamps.length ? 'unavailable' : now - Math.min(...timestamps) > FRESH_MS || positions.some(p => byTicker.get(p.ticker).freshness === 'stale') ? 'stale' : 'fresh',
    // These are exposure measures, not volatility, VaR, or a prediction of loss.
    concentration: hhi === null ? 'unavailable' : positions.some(p => p.allocation > 25) ? 'concentrated' : 'distributed' };
}
export function simulateTrade(snapshot, ticker, reductionPercent) {
  ticker = symbol(ticker);
  if (!finite(reductionPercent, 0.000001, 100)) throw new Error('Reduction must be above zero and at most one hundred percent');
  if (!snapshot.complete || !snapshot.totalValue) throw new Error('A complete valued portfolio is required');
  const position = snapshot.positions.find(p => p.ticker === ticker);
  if (!position) throw new Error('Ticker is not held');
  const sharesSold = Number((position.shares * reductionPercent / 100).toFixed(6));
  if (sharesSold <= 0) throw new Error('Reduction rounds below supported share precision');
  // Value the sold fraction at the same price as the snapshot, retaining proceeds as cash.
  const proceedsCents = cents(sharesSold, position.price);
  return { ticker, reductionPercent, sharesSold, proceeds: proceedsCents / 100,
    beforeAllocation: position.allocation,
    afterAllocation: (position.valueCents - proceedsCents) / Math.round(snapshot.totalValue * 100) * 100,
    totalValueAfter: snapshot.totalValue,
    assumptions: 'Illustrative sale at the quoted price; proceeds remain as cash. No fees, taxes, slippage, or execution. Holdings are unchanged.' };
}
export function factsFor(snapshot) {
  const facts = [];
  const add = (id, label, display) => facts.push({ id, label, display });
  if (snapshot.complete) {
    add('portfolio.value', 'Portfolio value', money(snapshot.totalValue));
    add('portfolio.day', 'Daily change', money(snapshot.dayChange));
    if (snapshot.dayChangePercent !== null) add('portfolio.dayPercent', 'Daily change', percent(snapshot.dayChangePercent));
    for (const p of snapshot.positions) {
      add(`${p.ticker}.value`, `${p.ticker} market value`, money(p.valueCents / 100));
      add(`${p.ticker}.day`, `${p.ticker} daily contribution`, money(p.dayCents / 100));
      if (p.allocation !== null) add(`${p.ticker}.allocation`, `${p.ticker} allocation`, percent(p.allocation));
    }
    for (const [i, sector] of snapshot.sectors.entries()) add(`sector.${i}`, `${sector.sector} exposure`, percent(sector.allocation));
    if (snapshot.hhi !== null) add('risk.hhi', 'Concentration index (HHI)', snapshot.hhi.toFixed(4));
    if (snapshot.effectivePositions !== null) add('risk.effective', 'Effective number of equally weighted positions', snapshot.effectivePositions.toFixed(2));
  }
  return facts;
}
