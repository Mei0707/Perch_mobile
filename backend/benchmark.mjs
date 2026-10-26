// Importable grading/reporting helpers. No network or file effects on import.
export const percentile = (values, p) => {
  const finite = values.filter(value => typeof value === 'number' && Number.isFinite(value));
  return finite.length ? [...finite].sort((a, b) => a - b)[Math.max(0, Math.ceil(p * finite.length) - 1)] : null;
};
export function gradeAnswer(answer, item, live = false) {
  const errors = [];
  const required = [...(item.expect ?? []), ...(live ? item.liveExpect ?? [] : [])];
  if (required.some(id => !answer.factIDs.includes(id))) errors.push('Missing expected fact reference');
  if (item.coverage && answer.coverage !== item.coverage) errors.push('Incorrect quote coverage');
  if (item.freshness && answer.freshness !== item.freshness) errors.push('Incorrect freshness');
  if (item.contains && !answer.explanation.includes(item.contains)) errors.push('Expected calculated quantity is absent');
  if (item.excludes && answer.explanation.toLowerCase().includes(item.excludes.toLowerCase())) errors.push('Unsupported claim');
  if (live && answer.mode !== 'llm') errors.push('Live model did not produce a validated answer');
  const attempts = answer.metrics?.toolResults?.filter(t => t.origin === 'model') ?? [];
  if (live && item.requiredTool && !attempts.some(t => t.name === item.requiredTool && t.success)) errors.push('Expected model-requested tool did not succeed');
  if (live && item.liveContains && !answer.explanation.includes(item.liveContains)) errors.push('Incorrect conversational scenario quantity');
  if (live && item.forbidTools?.some(name => attempts.some(t => t.name === name))) errors.push('An unsupported request was reinterpreted as a scenario');
  return { passed: errors.length === 0, errors };
}
export function summarize(results) {
  const liveAnswers = results.filter(r => r.mode === 'llm');
  const attempts = results.flatMap(r => r.metrics?.toolResults ?? []).filter(t => t.origin === 'model');
  const toolsByName = Object.fromEntries([...new Set(attempts.map(t => t.name))].map(name => {
    const entries = attempts.filter(t => t.name === name);
    return [name, { attempts: entries.length, succeeded: entries.filter(t => t.success).length,
      successRate: entries.filter(t => t.success).length / entries.length }];
  }));
  return { samples: results.length, passed: results.filter(r => r.passed).length,
    automatedPassRate: results.length ? results.filter(r => r.passed).length / results.length : null,
    llmAnswers: liveAnswers.length, fallbackAnswers: results.filter(r => r.mode === 'fallback').length,
    p50Ms: percentile(results.map(r => r.latencyMs), 0.5), p95Ms: percentile(results.map(r => r.latencyMs), 0.95),
    llmP50Ms: percentile(liveAnswers.map(r => r.latencyMs), 0.5), llmP95Ms: percentile(liveAnswers.map(r => r.latencyMs), 0.95),
    firstDraftP50Ms: percentile(liveAnswers.map(r => r.metrics?.firstDraftMs), 0.5),
    firstDraftP95Ms: percentile(liveAnswers.map(r => r.metrics?.firstDraftMs), 0.95),
    modelToolAttempts: attempts.length, modelToolSuccessRate: attempts.length ? attempts.filter(t => t.success).length / attempts.length : null,
    toolsByName,
    modelRequests: results.reduce((sum, r) => sum + (r.metrics?.modelRequests ?? 0), 0),
    correctnessReview: 'Human semantic review required; automated gates check known quantities, fact references, tools, and coverage.' };
}
