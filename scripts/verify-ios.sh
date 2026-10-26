#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
REPORT_DIR="${PERCH_IOS_REPORT_DIR:-.verification/ios}"
mkdir -p "$REPORT_DIR"
if ! xcodebuild -version > "$REPORT_DIR/xcode-version.txt" 2>&1; then
  cat > "$REPORT_DIR/status.json" <<'JSON'
{"status":"blocked","reason":"Full Xcode is unavailable in the selected developer directory. Set DEVELOPER_DIR to an installed Xcode.app/Contents/Developer and rerun. No iOS build or XCTest execution occurred."}
JSON
  cat "$REPORT_DIR/status.json"
  exit 2
fi
# Discover a usable simulator instead of hardcoding a model or runtime version.
SIMULATOR_ID="${1:-}"
if [[ -z "$SIMULATOR_ID" ]]; then
  SIMULATOR_ID="$(xcrun simctl list devices available --json | python3 -c 'import json,sys; d=json.load(sys.stdin); devices=[x for group in d["devices"].values() for x in group if x.get("isAvailable") and "iPhone" in x["name"]]; devices.sort(key=lambda x:x.get("state")!="Booted"); print(devices[0]["udid"] if devices else "")')"
fi
if [[ -z "$SIMULATOR_ID" ]]; then
  printf '%s\n' '{"status":"blocked","reason":"No available iPhone simulator. Install an iOS runtime and create a simulator in Xcode."}' > "$REPORT_DIR/status.json"
  cat "$REPORT_DIR/status.json"
  exit 2
fi
RUN_DIR="$REPORT_DIR/$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$RUN_DIR"
# xcodebuild test performs the simulator build and executes the scheme's XCTest target.
set +e
xcodebuild -project Perch.xcodeproj -scheme PerchApp \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath .derivedData -resultBundlePath "$RUN_DIR/Perch.xcresult" \
  CODE_SIGNING_ALLOWED=NO test 2>&1 | tee "$RUN_DIR/xcodebuild.log"
BUILD_STATUS=${PIPESTATUS[0]}
set -e
python3 - "$REPORT_DIR/status.json" "$BUILD_STATUS" "$RUN_DIR" "$SIMULATOR_ID" <<'PY'
import json,sys,datetime
path,code,directory,device=sys.argv[1:]
with open(path,'w') as f: json.dump({'status':'passed' if code=='0' else 'failed','exitCode':int(code),'generatedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'simulatorID':device,'artifacts':directory},f,indent=2)
PY
exit "$BUILD_STATUS"
