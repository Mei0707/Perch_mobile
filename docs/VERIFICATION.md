# Verification record

Local verification on October 23, 2026 (America/Los_Angeles):

- 22 backend tests passed, including a real localhost HTTP/SSE test for authentication, completion, feedback deduplication, and analytics privacy.
- 10 deterministic evaluation fixtures passed. These exercise rule-based fallback with known prices; they do not establish live LLM accuracy or latency.
- 10 executable Swift core checks passed against the actual app sources: migration, cache purge, empty-store persistence, repository saving, unavailable quotes, incomplete totals, cents rounding, daily contributions, ticker validation, and preservation of corrupted data.
- All Swift app-library sources passed a macOS type-check with the installed Swift 5.8 / macOS 13.3 SDK.
- Xcode project and app Info.plist passed `plutil` validation; source whitespace passed `git diff --check`.
- All 2,146 DerivedData artifacts and the root `.DS_Store` were removed from Git tracking; local artifacts remain available and are ignored.

Three native Swift-to-Node integration checks passed via `scripts/verify-swift-core.sh --with-backend`: real Foundation quote decoding, SSE draft/completion parsing, and feedback submission with a local fixture provider. This check caught and verified a fix for lost SSE frame separators in Foundation’s line iterator. The client now preserves separators by parsing bytes.

Not verified locally: live OpenAI/Finnhub calls (provider credentials were not supplied), the opt-in live-model evaluation, XCTest execution and an iOS simulator build (full Xcode is absent), signed CloudKit operations, on-device notification behavior, and public hosting. The checked-in CI workflow runs XCTest and an iOS simulator build when pushed to GitHub; that workflow has not been run in this workspace.
