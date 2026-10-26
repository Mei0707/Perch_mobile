# Live verification results — October 26, 2026

Actual OpenAI and Finnhub requests were exercised from the development machine. Positions used in all checks were synthetic. No cloud service was provisioned.

## Recorded model benchmark

Model: `gpt-4.1-mini`. Ten known-answer cases repeated 3 times sequentially, with real LLM calls and synthetic quote fixtures. Results generated at `2026-10-26T18:57:31.240Z`.

| Metric | Observed result |
| --- | --- |
| Automated fact/schema/tool checks | 29/30 (96.7%) |
| Validated LLM answers | 29 |
| Calculated fallbacks | 1 |
| Total latency p50 / p95 | 3.74 s / 5.61 s |
| First readable draft p50 / p95 (LLM answers) | 1.84 s / 3.75 s |
| Model adapter request attempts | 60 |
| Sale tools | 6/6 succeeded |
| Quote-refresh tools | 0/1 succeeded (deliberately missing quote fixture) |

The rejected scenario answer failed the numeric-output validator and returned calculated data instead. This is counted as a failed live-model case, even though the fallback displayed correct scenario calculations. All six model-requested sale calculations succeeded. Tool availability failures are retained in the metrics rather than hidden.

These are observed validation/task checks, **not a claim of semantic correctness or a production SLA**. Provider/cache state was not controlled, the sample is small, and the backend was not hosted on Render. A final title-enum constraint was added after this recorded run and verified through the live local HTTP smoke below; a repeated full benchmark was not rerun after that final metadata constraint.

## Real-provider and local HTTP smoke checks

- Finnhub quote smoke: passed, source Finnhub, 283.66 ms.
- OpenAI explanation using a real provider quote: passed, 5.03 s.
- Authenticated local HTTP/SSE scenario: passed, 4.90 s total and 2.62 s to first readable draft.
- The HTTP check verified rejection without a token, streamed draft/completion events, complete real quote coverage, and a successful model-requested sale tool.

One smoke sample is not a percentile benchmark. The raw local reports remain ignored by Git: `backend/eval-results-live.json`, `backend/eval-results-providers.json`, and `backend/eval-results-http.json`.

## Financial regression example

For the synthetic portfolio of NVDA worth $350 and AAPL worth $650, both classified Technology, selling one fifth of the NVDA shares and retaining cash gives:

| Quantity | Before | After illustrative sale |
| --- | --- | --- |
| Total value | $1,000 | $1,000 |
| NVDA allocation | 35% | 28% |
| Cash allocation | 0% | 7% |
| Technology exposure | 100% | 93% |
| Concentration index including cash | 0.5450 | 0.5058 |

These values are computed and tested in code. They exclude execution costs, fees, taxes, price impact, and reinvestment. Current sector/risk facts are removed from the scenario explanation context so they cannot be confused with calculated after-sale exposure.

## Correctness review and practical limits

Agent review of selected outputs identified semantic and clarity issues beyond the automated gates: mixing a value with a timestamp, malformed text in an injection refusal, references to current sector exposure as if it were after-sale exposure, and broad wording about overall portfolio decline when only a subset was quoted. Timestamp/sector-name facts, after-sale calculations, ASCII prose constraints, and mandatory incomplete-coverage disclosure were added in response.

The final sample still contains occasional awkward refusal wording and a quoted-subset explanation that refers to a portfolio drop after disclosing incomplete coverage. These remain qualitative review findings; no independent human semantic-accuracy score is claimed. The app continues to show sources, coverage, draft status, and limitations. Human review using [the benchmark rubric](BENCHMARK.md) is still needed before a public release.

## Other completed checks and remaining work

- 43 backend tests passed.
- 10 deterministic fallback fixtures passed.
- 20 executable Swift checks passed: 10 core, 7 chat/portfolio state, and 3 native HTTP/SSE/feedback checks.
- Docker image built successfully; five isolation/authentication/storage smoke checks passed with dummy provider keys and no provider calls.
- The selected developer installation has Command Line Tools rather than full Xcode. iOS simulator build, XCTest execution, rendered UI/accessibility, physical-device behavior, and signed CloudKit checks remain pending.
- Deployment remains local by request. The prepared Render blueprint is available for future review; no Render resources or monthly charges were created.
