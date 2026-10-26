# Live verification and benchmark protocol

The benchmark now records total answer latency, time to first nonempty readable draft, quote retrieval, cumulative planning, final explanation generation, model adapter request attempts, and individual tool attempts (name, origin, success, duration). Fallback reasons use fixed codes such as `authentication`, `rate_limited`, `incomplete`, and `invalid_output`; raw provider error bodies are not recorded.

## Run live providers first

Configure `backend/.env` (ignored by Git):

```text
OPENAI_API_KEY=...
FINNHUB_API_KEY=...
OPENAI_MODEL=gpt-4.1-mini
```

From `backend`:

```sh
npm run verify:providers
```

This checks a real AAPL quote and a real model explanation for a **synthetic** position. If Finnhub fails, the OpenAI check explicitly labels its market input as a fixture so that it can test LLM connectivity independently. The overall check passes only when both providers pass. Missing keys yield exit code 2 (`blocked`); a configured but failed provider yields exit code 1. Output is saved to ignored `backend/eval-results-providers.json`. Key values and provider error bodies are never printed. This smoke check makes only one sample; its duration is not a p95 benchmark.

The full authenticated HTTP/SSE path can be tested against a running local backend with `npm run verify:http`. This makes real provider requests using synthetic positions, checks unauthenticated rejection, and requires streamed drafts plus a validated LLM scenario.

## Evaluate real model behavior

```sh
npm run benchmark:live
# Optional larger sample; multiplies API usage by the repetition count.
npm run benchmark:live -- --repeat 3
```

Ten cases cover portfolio movement, an exact sale scenario, concentration, missing/invalid/stale quotes, empty holdings, prompt injection, conversational follow-up, and an unsupported buy. Known synthetic quotes isolate model correctness from changing prices. Reports explicitly label this as **live LLM with fixture quotes**, not a live-market benchmark. Reports identify the model, sample count, and repetition count. Do not compare fixture fallback timing to real LLM timing.

Automated gates check expected numeric displays, fact references, quote coverage/freshness, successful model-requested scenario tools, the conversational sale quantity, and whether a buy was incorrectly reinterpreted as a sale. Fallback counts as failure in live mode. Automatic `getPortfolio` reads and fallback calculations are excluded from the model tool-success denominator; zero model attempts yields `null`, not perfect success.

`llmP50Ms` / `llmP95Ms` include only validated LLM answers. `p50Ms` / `p95Ms` include all submitted cases, including failures. `firstDraftP50Ms` / `firstDraftP95Ms` measure the first readable nonempty draft; drafts are still explicitly unverified. With ten cases, p95 is effectively the slowest observed sample, not a robust production SLA. Record deployment region, cache state, model, sample size, and runtime when comparing runs. The runner is sequential to avoid creating accidental load or exceeding provider quotas.

## Review answer correctness

The ignored `eval-results-live.json` includes each explanation, limitations, fact IDs, metrics, and failed checks. Before showcasing results, review every case against this rubric:

| Review dimension | Pass criterion |
| --- | --- |
| Numbers | Every quantity matches its intended fact, not merely another allowed fact |
| Intent | Scenario ticker, direction, and amount match the latest question and conversation |
| Coverage | Missing quotes do not produce complete totals or weights |
| Freshness | Stale data is described with uncertainty and never claimed as live |
| Causality | Price contributions are not presented as evidence of a specific news/business cause |
| Actions | No trade execution or portfolio mutation is claimed |
| Clarity | The user can identify assumptions, sources, and the answer to the actual question |

Record per-case pass/fail and a short reason in a separate review artifact. Automated numeric checks do not prove semantic correctness; no human correctness score is reported until this review is performed.

## Product metrics

```sh
node evaluate.mjs --analytics ./data/events.jsonl
```

This reports actual server p50/p95, first-draft p95 for LLM answers, model tool success, fallback rate, and helpfulness. Analytics omit message text, holdings, arguments, tool outputs, provider secrets, and user identifiers. The server does not log full evaluation reports from real users. For a signed-in multi-user deployment, replace the shared demo token and per-instance metrics/quota storage with verified identities and transactional shared services.

Implementation references: [OpenAI latency optimization](https://developers.openai.com/api/docs/guides/latency-optimization) and [streaming responses](https://developers.openai.com/api/docs/guides/streaming-responses).

The generation schema constrains plain English prose separately from referenced facts. Timestamp and sector-name facts are supplied explicitly. Incomplete coverage requires a server-validated disclosure; it is prompted explicitly rather than enforced as a long literal decoder prefix. Sale explanations use calculated after-sale sector/cash exposure, not the original portfolio exposure.
