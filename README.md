# Perch — portfolio tracker and Ask Perch

A SwiftUI iOS app with sourced market quotes and a conversational portfolio assistant. Perch calculates portfolio movement, allocation, diversification, and illustrative sales in code; an LLM explains referenced results through a backend that keeps provider keys off the device.

- Ask Perch: streaming multi-turn chat, bounded tool calling, timestamps, explicit fallback, cancellation/retry, and helpfulness feedback.
- Finnhub quotes: source timestamps, cache expiration, stale/offline labels, and missing-price handling. Demo prices are visibly labeled; no generated quote substitution.
- Deterministic analytics: prior-close contributions, position/sector weights, HHI concentration, effective positions, and sale scenarios that retain proceeds as cash.
- AI reliability: Responses API tools, strict structured answers, numeric fact references, validation, ten evaluation fixtures, and measured latency reports.
- Durable holdings: atomic Application Support storage, legacy-cache migration, validation, JSON export/import, and optional signed CloudKit snapshot sync.
- Release foundations: local reminders, privacy-conscious aggregate analytics, Keychain credentials, and CI checks. Fresh installs start with an empty portfolio.

## Run

```sh
cp backend/.env.example backend/.env
# Set OPENAI_API_KEY and FINNHUB_API_KEY in backend/.env.
cd backend
npm start
```

Open `Perch.xcodeproj`, select `PerchApp`, and run on an iPhone simulator. Open Home → Settings and save `http://127.0.0.1:8787` as the backend URL. Add holdings in Portfolio and ask a question. No keys are needed for labeled demo browsing; real quotes/LLM answers require server configuration. The default LLM is configurable with `OPENAI_MODEL`.

```sh
./scripts/run-ios-simulator.sh
```

## Verify

```sh
(cd backend && npm test && npm run eval)
swift test
./scripts/verify-swift-core.sh
```

The offline evaluation exercises calculated fallback. Live reports separately measure total/first-draft latency, successful model tools, numeric correctness gates, and fallback reasons. Run `npm run verify:providers` and `npm run benchmark:live` from `backend` for the opt-in live-model suite. See the [verification record](docs/VERIFICATION.md) for completed and pending checks, and [release configuration](docs/RELEASE.md) for simulator builds, backend hosting, actual analytics, iCloud setup, and remaining production requirements.

## Architecture

[Architecture and calculation semantics](docs/ARCHITECTURE.md) documents all data flows, trust boundaries, supported calculations, and limitations. The Swift package contains the app library and executable; the Xcode project is the iOS wrapper. The backend uses Node's built-in HTTP, fetch, crypto, and file APIs without third-party dependencies.

```text
Sources/Perch/
  App/                 Shared repository container and tab navigation
  Core/AI/             Assistant contracts, insight service, response validation
  Core/Networking/     Backend requests, SSE client, secure settings
  Core/Persistence/    Durable holdings, quote cache, optional CloudKit snapshots
  Core/Repositories/   Actor-isolated market/holdings orchestration
  Features/Dashboard/  Portfolio snapshot and sourced explanation
  Features/Transactions/  Watchlist and Discover (original directory names)
  Features/Budgets/    Holdings editor and allocation
  Features/Insights/   Ask Perch, settings, feedback, and local chat history
backend/               Quote provider, financial tools, LLM orchestration, API
Tests/                 Swift tests
scripts/               Simulator runner and executable Swift smoke checks
```

Implementation references: [OpenAI function calling](https://developers.openai.com/api/docs/guides/function-calling), [structured outputs](https://developers.openai.com/api/docs/guides/structured-outputs), [streaming responses](https://developers.openai.com/api/docs/guides/streaming-responses), and [Finnhub quote API](https://finnhub.io/docs/api/quote).

The next-stage validation and demonstration guides are [Live benchmark protocol](docs/BENCHMARK.md), [iOS/device verification](docs/DEVICE_QA.md), and [Render deployment](docs/RENDER.md).

The configured local demo requires the private `PERCH_API_TOKEN` from ignored `backend/.env` in Settings. Provider keys stay on the backend. No Render resources were created; hosting remains local by request.

See [recorded live results](docs/LIVE_RESULTS.md) for measured latency, tool outcomes, qualitative review findings, and the remaining Xcode/device work.
