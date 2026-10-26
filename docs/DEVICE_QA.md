# iOS and physical-device verification

These are acceptance checks to run, not a claim that a real device was tested.

## Simulator build and XCTest

```sh
./scripts/verify-ios.sh
# Or choose a specific simulator UDID:
./scripts/verify-ios.sh <simulator-udid>
```

The script discovers an available iPhone, runs `xcodebuild test`, and retains an `.xcresult` bundle, build log, and status under ignored `.verification/ios`. If full Xcode or a simulator is missing, it records **blocked** and exits 2 without claiming a build/test pass. To select an installed Xcode without changing global settings:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/verify-ios.sh
```

GitHub Actions runs this script and uploads the iOS verification artifacts. Until that workflow or a local Xcode run actually completes, simulator/XCTest status remains pending.

## Device acceptance matrix

Use synthetic demo holdings first. Record device model, OS version, app build, backend URL/region, and date for each run.

| Flow | Expected result |
| --- | --- |
| First launch without backend | Clearly labeled sample prices, empty portfolio, chat setup explanation and Settings action |
| Connect saved HTTPS endpoint | Connection test distinguishes reachability, rejected token, and missing provider configuration |
| Unconfigured Send | No question is sent or added to chat history; setup remains accessible |
| Add/edit a position | Invalid symbols, nonfinite shares, more than six fractional digits, and negative costs are rejected |
| Rename into another holding | Existing position remains intact; conflict message is shown in the editor |
| Missing quote | Position remains editable; totals/weights are unavailable, with no generated price |
| Streaming chat | Status updates appear, draft is marked unverified, completion replaces it with sourced validated output |
| Stop / switch tabs during request | Request cancels; partial draft is removed and the unanswered question remains retryable |
| Network failure | Clear retry message; retry keeps one copy of the question and never sends a partial draft as history |
| Invalid/expired token | Settings explains how to update the backend credential |
| Minute/daily limit | App explains the request limit; the backend returns 429 and Retry-After |
| Helpful / unhelpful | Buttons disable while saving; double taps submit one rating; failure does not resend the question |
| Clear conversation | Confirmation precedes deleting the device's saved transcript |
| Large text / VoiceOver / keyboard | Composer remains usable, controls have labels, sources remain readable, keyboard does not block Send/Stop |
| Relaunch / offline | Holdings remain durable; cached prices are labeled stale; no cached quote is described as live |
| Notifications / iCloud | Test opt-in, denial, sign-out, restore review, conflicts, and offline behavior on signed builds |

The executable Swift smoke suite exercises chat/portfolio state transitions with a fixture client, and the native JSON/SSE suite verifies the actual backend protocol. Those checks complement physical-device testing; they do not verify rendered layout, keyboard, accessibility, permissions UI, or CloudKit signing.
