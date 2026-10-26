# Verification record

Local verification on October 23, 2026 (America/Los_Angeles):

- 22 backend tests passed, including a real localhost HTTP/SSE test for authentication, completion, feedback deduplication, and analytics privacy.
- 10 deterministic evaluation fixtures passed. These exercise rule-based fallback with known prices; they do not establish live LLM accuracy or latency.
- 10 executable Swift core checks passed against the actual app sources: migration, cache purge, empty-store persistence, repository saving, unavailable quotes, incomplete totals, cents rounding, daily contributions, ticker validation, and preservation of corrupted data.
- All Swift app-library sources passed a macOS type-check with the installed Swift 5.8 / macOS 13.3 SDK.
- Xcode project and app Info.plist passed `plutil` validation; source whitespace passed `git diff --check`.
- All 2,146 DerivedData artifacts and the root `.DS_Store` were removed from Git tracking; local artifacts remain available and are ignored.

Three native Swift-to-Node integration checks passed via `scripts/verify-swift-core.sh --with-backend`: real Foundation quote decoding, SSE draft/completion parsing, and feedback submission with a local fixture provider. This check caught and verified a fix for lost SSE frame separators in Foundation’s line iterator. The client now preserves separators by parsing bytes.

At that initial verification stage, live providers and model evaluation, XCTest/iOS builds, signed CloudKit, device behavior, and public hosting had not been verified. Live provider/model/HTTP checks were subsequently completed as recorded below. The checked-in CI workflow runs XCTest and an iOS simulator build when pushed to GitHub; that workflow has not been run in this workspace.


## October 26 follow-up

- Real Finnhub and OpenAI smoke checks passed. The full authenticated local HTTP/SSE path also passed with synthetic holdings and real providers.
- A recorded 30-sample live benchmark passed 29 automated cases; one model answer was rejected and safely fell back. Observed p95 completion was 5.61 s. All six sale tools succeeded; a quote refresh of intentionally missing data failed as expected.
- Final title metadata was constrained after the recorded benchmark and then verified through the live HTTP smoke. See the [full result record](LIVE_RESULTS.md) for scope, review findings, and exact timing definitions.
- 43 backend tests, 10 offline fixtures, 20 executable Swift checks, and five container checks passed.
- Provider keys were moved from the tracked template to ignored `backend/.env` with file mode 0600. The template is blank, and configured secret values were not found in trackable files.
- `scripts/verify-ios.sh` records the iOS build/XCTest state as blocked because full Xcode is unavailable in the selected developer directory. No simulator or device success is claimed.
- Hosting remains local at the user's request. The backend is configured for loopback with a private authentication token. No Render resources were provisioned.
