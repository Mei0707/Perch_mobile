import { readFile, writeFile } from 'node:fs/promises';
import { ask, OpenAIModel } from './assistant.mjs';
import { evaluationCases } from './evaluation-cases.mjs';
import { gradeAnswer, percentile, summarize } from './benchmark.mjs';
const live = process.argv.includes('--live');
const analyticsIndex = process.argv.indexOf('--analytics');
const repeatIndex = process.argv.indexOf('--repeat');
const repeat = repeatIndex < 0 ? 1 : Number(process.argv[repeatIndex + 1]);
if (!Number.isInteger(repeat) || repeat < 1 || repeat > 20) throw new Error('--repeat must be an integer from 1 to 20');
if (analyticsIndex >= 0) {
  const events = (await readFile(process.argv[analyticsIndex + 1], 'utf8')).trim().split('\n').filter(Boolean).map(line => JSON.parse(line));
  const answers = events.filter(e => e.type === 'answer');
  const ratings = events.filter(e => e.type === 'feedback');
  console.log(JSON.stringify({ samples: answers.length, p50Ms: percentile(answers.map(e => e.latencyMs), 0.5),
    p95Ms: percentile(answers.map(e => e.latencyMs), 0.95),
    firstDraftP95Ms: percentile(answers.filter(e => e.mode === 'llm').map(e => e.metrics?.firstDraftMs), 0.95),
    modelToolSuccessRate: summarize(answers).modelToolSuccessRate,
    fallbackRate: answers.length ? answers.filter(e => e.mode === 'fallback').length / answers.length : null,
    feedbackCount: ratings.length, helpfulRate: ratings.length ? ratings.filter(e => e.rating === 'helpful').length / ratings.length : null }, null, 2));
} else {
  if (live && !process.env.OPENAI_API_KEY?.trim()) {
    console.error('Live evaluation blocked: configure OPENAI_API_KEY in backend/.env. No live requests were made.');
    process.exitCode = 2;
  } else {
    const results = [];
    for (let iteration = 1; iteration <= repeat; iteration++) for (const item of evaluationCases()) {
      const market = { quotes: async () => ({ quotes: item.quotes, unavailable: [] }), quote: async ticker => item.quotes.find(q => q.ticker === ticker) };
      const answer = await ask({ holdings: item.holdings, watchlist: [], messages: [...(item.history ?? []), { role: 'user', content: item.question }], market, model: live ? new OpenAIModel() : null });
      results.push({ id: `${item.id}:${iteration}`, caseID: item.id, iteration, ...gradeAnswer(answer, item, live),
        mode: answer.mode, latencyMs: answer.latencyMs, metrics: answer.metrics,
        factIDs: answer.factIDs, explanation: answer.explanation, limitations: answer.limitations });
      if (live) console.error(`${item.id}:${iteration} ${answer.mode} ${answer.latencyMs}ms`);
    }
    const report = { mode: live ? 'live-llm-with-fixture-quotes' : 'offline-rule-based-fixtures', model: live ? process.env.OPENAI_MODEL ?? 'gpt-4.1-mini' : null,
      generatedAt: new Date().toISOString(), repeat, ...summarize(results), results };
    await writeFile(new URL(live ? './eval-results-live.json' : './eval-results-offline.json', import.meta.url), JSON.stringify(report, null, 2));
    console.log(JSON.stringify({ ...report, results: results.map(({ id, passed, errors }) => ({ id, passed, errors })) }, null, 2));
    if (report.passed !== report.samples) process.exitCode = 1;
  }
}
