# Release configuration

## Run locally

1. Use Node 22.9 or newer (`--env-file-if-exists` is used).
2. Copy `backend/.env.example` to `backend/.env`, then set `FINNHUB_API_KEY` and `OPENAI_API_KEY`. Choose a supported `OPENAI_MODEL` if your account does not have access to the default.
3. In `backend`, run `npm start`. The service listens on `127.0.0.1:8787`. `npm run runtime` verifies the Node runtime used by npm; select Node 22.9+ if it reports an older version.
4. Build Perch with Xcode. In Home or Ask → Settings, set Backend URL to `http://127.0.0.1:8787` for the simulator. For the configured local demo, enter `PERCH_API_TOKEN` from the ignored `backend/.env` into the personal backend token field. Keep provider keys on the server. Settings may instead use an HTTPS deployment URL and a personal backend token. Never enter a provider API key here.
5. Add holdings, refresh Home, then use Ask. With no backend URL, prices are labeled demo; Ask requires a configured backend. With no provider credentials, the backend returns unavailable quotes and rule-based answers with explicit coverage limits.

For a physical device use a reachable HTTPS backend, not the phone's localhost. The app enables local-network ATS support; it does not broadly disable transport security. No deployment has been performed by the implementation.

The app prompts the user before sending each chat via the Send action and explains which financial data is transmitted. Automatic dashboard explanations send the same holdings/watchlist once a backend is configured. Review provider terms and data licensing for your intended distribution.

## Verification

```sh
cd backend
npm test
npm run eval
# Optional; this sends fixture positions and questions to the provider and incurs API usage.
npm run verify:providers
npm run verify:http
npm run benchmark:live
# Aggregate actual collected product metrics, including p95 and helpfulness rate.
node evaluate.mjs --analytics ./data/events.jsonl
```

`npm run eval` tests deterministic fallback using ten known-value fixtures. Its latency is local fixture timing, **not LLM latency**. `--live` evaluates the configured LLM against those fixtures, requires a validated LLM result (fallback counts as failure), and reports measured p50/p95. The report includes explanations for human semantic review. Live-market provider verification is separate: configure Finnhub and compare timestamps/prices in `/v1/quotes` with your account's entitled feed.

```sh
swift test
./scripts/verify-swift-core.sh --with-backend
./scripts/verify-ios.sh
```

The smoke script compiles the actual Swift sources and runs ten core checks and seven chat/portfolio behavior checks without XCTest, plus three native JSON/SSE/feedback checks when `--with-backend` is supplied; it can work with only Command Line Tools. iOS simulator builds and XCTest require full Xcode selected as the developer directory. GitHub Actions runs backend checks, offline evaluations, Swift tests, and an iOS simulator build.

## Optional private iCloud holdings sync

This is manual private snapshot sync, not automatic conflict merging.

1. Select your development team and unique app bundle ID in Xcode. Add iCloud → CloudKit capability and create/select the appropriate container for your team.
2. Let Xcode generate the entitlement file and `CODE_SIGN_ENTITLEMENTS`. No team/container IDs are hardcoded in this repository.
3. Create/deploy the CloudKit `PortfolioSnapshot` record type with `holdings` (Bytes) and `updatedAt` (Date) fields. Use a private database. Development schema may be created from a signed development build; deploy the schema before production.
4. Set `PerchCloudSyncEnabled` to YES in `PerchApp_Info.plist` only for builds with the matching capability. Sign in to iCloud on the device.
5. Upload from Settings. On a second device download, review the incoming holdings, then replace local holdings. Concurrent upload conflicts are surfaced instead of automatically overwriting a newer record.

Validate account sign-out, offline failures, empty snapshots, multi-device conflicts, and local restore on signed devices. Quotes, chats, tokens, and feedback do not sync. This environment has no signing team or iCloud container, so these flows require device verification before distribution.

## Notifications

Settings provides an opt-in daily reminder at 4:15 PM in the device's local time. Permission denial is surfaced. Disabling removes the scheduled request. This is not a market-close scheduler: weekends, holidays, time-zone changes, and live price monitoring are outside its scope. No push credentials are required.

## Before public distribution

Use verified per-user identity and server-side quotas instead of a shared personal token; deploy over TLS, rotate secrets, and configure shared caches and provider budgets. Add persistent operational metrics, analytics retention/rotation, a privacy policy, and feed licensing appropriate for distribution. Test signed iOS builds, accessibility, cancellation/retry, data recovery, provider errors, and iCloud conflicts on devices. Fill App Store privacy disclosures based on the actual deployed backend and selected providers.

See [live benchmarks](BENCHMARK.md), [physical-device acceptance checks](DEVICE_QA.md), and the prepared [Render deployment](RENDER.md).
