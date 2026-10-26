import test from 'node:test';
import assert from 'node:assert/strict';
import { portfolio, simulateTrade, validateHoldings, validQuote, factsFor } from '../finance.mjs';

export const now = Date.now();
export const holdings = [{ ticker: 'NVDA', shares: 35, averageCost: 8 }, { ticker: 'AAPL', shares: 65, averageCost: 8 }];
export const quotes = ['NVDA', 'AAPL'].map(ticker => ({ ticker, price: 10, previousClose: ticker === 'NVDA' ? 12 : 10,
  asOf: new Date(now).toISOString(), source: 'Finnhub', sector: 'Technology', freshness: 'fresh' }));

test('weighted movement uses prior portfolio value and contributions sum to change', () => {
  const p = portfolio(holdings, quotes, now);
  assert.equal(p.totalValue, 1000);
  assert.equal(p.dayChange, -70);
  assert.equal(p.dayChangePercent, -70 / 1070 * 100);
  assert.equal(p.positions.reduce((sum, x) => sum + x.dayCents / 100, 0), p.dayChange);
  assert.equal(p.positions[0].allocation, 35);
});
test('selling twenty percent of shares changes thirty-five allocation to twenty-eight with cash retained', () => {
  const result = simulateTrade(portfolio(holdings, quotes, now), 'NVDA', 20);
  assert.equal(result.beforeAllocation, 35);
  assert.ok(Math.abs(result.afterAllocation - 28) < 1e-9);
  assert.equal(result.sharesSold, 7);
  assert.equal(result.proceeds, 70);
  assert.equal(result.totalValueAfter, 1000);
  assert.equal(holdings[0].shares, 35);
});
test('full liquidation and fractional shares conserve portfolio value', () => {
  const snapshot = portfolio([{ ticker: 'NVDA', shares: 0.123456, averageCost: 1 }], quotes, now);
  const result = simulateTrade(snapshot, 'NVDA', 100);
  assert.equal(result.afterAllocation, 0);
  assert.equal(result.proceeds, snapshot.totalValue);
  assert.equal(result.sharesSold, 0.123456);
});
test('missing, zero, nonfinite, future or unsigned quotes do not produce complete totals', () => {
  for (const invalid of [{ price: 0 }, { price: NaN }, { previousClose: 0 }, { price: Infinity }, { asOf: new Date(now + 120000).toISOString() }, { source: 'Demo' }]) {
    const bad = { ...quotes[0], ...invalid };
    assert.equal(validQuote(bad, now), false);
    const p = portfolio(holdings, [bad, quotes[1]], now);
    assert.equal(p.complete, false);
    assert.equal(p.totalValue, null);
    assert.equal(p.dayChangePercent, null);
    assert.deepEqual(p.missing, ['NVDA']);
    assert.equal(p.hhi, null);
    assert.equal(p.positions[0].allocation, null);
    assert.throws(() => simulateTrade(p, 'AAPL', 20));
  }
});
test('zero holdings and tiny positions never divide by zero', () => {
  const empty = portfolio([], [], now);
  assert.equal(empty.totalValue, 0);
  assert.equal(empty.dayChangePercent, null);
  assert.equal(empty.hhi, null);
  assert.throws(() => simulateTrade(empty, 'NVDA', 20));
  const tiny = portfolio([{ ticker: 'NVDA', shares: 0.000001, averageCost: 0 }], quotes, now);
  assert.equal(tiny.totalValue, 0);
  assert.equal(tiny.positions[0].allocation, null);
});
test('stale timestamps and failed refreshes are explicitly stale', () => {
  const stale = quotes.map(q => ({ ...q, asOf: new Date(now - 3600000).toISOString() }));
  assert.equal(portfolio(holdings, stale, now).freshness, 'stale');
  assert.equal(portfolio(holdings, quotes.map(q => ({ ...q, freshness: 'stale' })), now).freshness, 'stale');
});
test('diversification shows exposure and HHI without invented volatility', () => {
  const p = portfolio(holdings, quotes, now);
  assert.ok(Math.abs(p.hhi - 0.545) < 1e-10);
  assert.equal(p.sectors[0].allocation, 100);
  assert.equal(p.concentration, 'concentrated');
  assert.ok(!Object.hasOwn(p, 'volatility'));
  assert.ok(factsFor(p).some(f => f.id === 'risk.hhi'));
});
test('reject malformed positions and unsupported scenarios', () => {
  for (const shares of [0, -1, NaN, Infinity, 0.1234567]) assert.throws(() => validateHoldings([{ ...holdings[0], shares }]));
  assert.throws(() => validateHoldings([holdings[0], holdings[0]]));
  assert.throws(() => validateHoldings([{ ...holdings[0], ticker: '../../secret' }]));
  const p = portfolio(holdings, quotes, now);
  for (const amount of [0, -5, 101, NaN]) assert.throws(() => simulateTrade(p, 'NVDA', amount));
  assert.throws(() => simulateTrade(p, 'TSLA', 20));
});

test('partial quote coverage exposes valid position facts without aggregate totals or weights', () => {
  const facts = factsFor(portfolio(holdings, [quotes[0]], now));
  assert.ok(facts.some(f => f.id === 'NVDA.value' && f.display === '$350.00'));
  assert.equal(facts.some(f => f.id === 'portfolio.value'), false);
  assert.equal(facts.some(f => f.id === 'NVDA.allocation'), false);
  assert.equal(facts.some(f => f.id === 'risk.hhi'), false);
});

test('sale reduces sector exposure and includes retained cash in concentration', () => {
  const scenario = simulateTrade(portfolio(holdings, quotes, now), 'NVDA', 20);
  assert.equal(scenario.afterSectorAllocation, 93);
  assert.ok(Math.abs(scenario.cashAllocation - 7) < 1e-9);
  assert.ok(Math.abs(scenario.afterHHI - 0.5058) < 1e-9);
});
