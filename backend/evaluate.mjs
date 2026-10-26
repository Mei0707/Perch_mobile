import { readFile, writeFile } from 'node:fs/promises';
import { ask, OpenAIModel } from './assistant.mjs';
import { evaluationCases } from './evaluation-cases.mjs';
export const percentile = (values, p) => values.length ? [...values].sort((a, b) => a - b)[Math.max(0, Math.ceil(p * values.length) - 1)] : null;
const live = process.argv.includes('--live');
const analyticsIndex = process.argv.indexOf('--analytics');
if (analyticsIndex >= 0) {
  const events = (await readFile(process.argv[analyticsIndex + 1], 'utf8')).trim().split('\n').filter(Boolean).map(line => JSON.parse(line));
  const answers = events.filter(e => e.type === 'answer');
  const ratings = events.filter(e => e.type === 'feedback');
  console.log(JSON.stringify({ samples: answers.length, p50Ms: percentile(answers.map(e => e.latencyMs), 0.5),
    p95Ms: percentile(answers.map(e => e.latencyMs), 0.95),
    fallbackRate: answers.length ? answers.filter(e => e.mode === 'fallback').length / answers.length : null,
    incompleteRate: answers.length ? answers.filter(e => e.coverage === 'incomplete').length / answers.length : null,
    feedbackCount: ratings.length, helpfulRate: ratings.length ? ratings.filter(e => e.rating === 'helpful').length / ratings.length : null }, null, 2));
} else {
  if (live && !process.env.OPENAI_API_KEY) throw new Error('--live requires OPENAI_API_KEY');
  const results = [];
  for (const item of evaluationCases()) {
    const market = { quotes: async () => ({ quotes: item.quotes, unavailable: [] }), quote: async ticker => item.quotes.find(q => q.ticker === ticker) };
    const answer = await ask({ holdings: item.holdings, watchlist: [], messages: [...(item.history ?? []), { role: 'user', content: item.question }], market, model: live ? new OpenAIModel() : null });
    const required = [...(item.expect ?? []), ...(live ? item.liveExpect ?? [] : [])];
    const errors = [];
    if (required.some(id => !answer.factIDs.includes(id))) errors.push('Missing expected fact reference');
    if (item.coverage && answer.coverage !== item.coverage) errors.push('Incorrect quote coverage');
    if (item.freshness && answer.freshness !== item.freshness) errors.push('Incorrect freshness');
    if (item.contains && !answer.explanation.includes(item.contains)) errors.push('Expected calculated quantity is absent');
    if (item.excludes && answer.explanation.includes(item.excludes)) errors.push('Unsupported claim');
    if (live && answer.mode !== 'llm') errors.push('Live model did not produce a validated answer');
    results.push({ id: item.id, passed: errors.length === 0, errors, mode: answer.mode, latencyMs: answer.latencyMs,
      factIDs: answer.factIDs, explanation: answer.explanation, limitations: answer.limitations });
  }
  const report = { mode: live ? 'live-llm-with-fixture-quotes' : 'offline-rule-based-fixtures',
    generatedAt: new Date().toISOString(), samples: results.length, passed: results.filter(r => r.passed).length,
    p50Ms: percentile(results.map(r => r.latencyMs), 0.5), p95Ms: percentile(results.map(r => r.latencyMs), 0.95), results };
  await writeFile(new URL(live ? './eval-results-live.json' : './eval-results-offline.json', import.meta.url), JSON.stringify(report, null, 2));
  console.log(JSON.stringify({ ...report, results: results.map(({ id, passed, errors }) => ({ id, passed, errors })) }, null, 2));
  if (report.passed !== report.samples) process.exitCode = 1;
}
