// Only fixed codes are exposed to clients/metrics. Never include provider response bodies.
export class ProviderError extends Error {
  constructor(provider, code, status = null) {
    super(`${provider}: ${code}`);
    this.name = 'ProviderError'; this.provider = provider; this.code = code; this.status = status;
  }
}
export class AnswerValidationError extends Error {
  constructor(message) { super(message); this.name = 'AnswerValidationError'; }
}
export function failureCode(error) {
  if (error instanceof ProviderError) return error.code;
  if (error instanceof AnswerValidationError || error instanceof SyntaxError) return 'invalid_output';
  if (['TimeoutError', 'AbortError'].includes(error?.name)) return 'timeout';
  return 'provider_error';
}
export const elapsed = started => Math.max(0, Math.round((performance.now() - started) * 100) / 100);
