#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${ROOT_DIR}/.derivedData"
APP_PATH="${DERIVED_DATA}/Build/Products/Debug-iphonesimulator/PerchApp.app"
BUNDLE_ID="com.perch.mobile"
DEVICE_NAME="${1:-}"

cd "$ROOT_DIR"

if [[ -n "$DEVICE_NAME" ]]; then
  DEVICE_ID="$(xcrun simctl list devices available | awk -v name="$DEVICE_NAME" -F '[()]' '$0 ~ name && $0 ~ /(Shutdown|Booted)/ {print $2; exit}')"
else
  DEVICE_ID="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ && /(Shutdown|Booted)/ {print $2; exit}')"
fi

if [[ -z "${DEVICE_ID:-}" ]]; then
  echo "No available iPhone simulator found."
  echo "Create one with: xcrun simctl create \"iPhone 14\" com.apple.CoreSimulator.SimDeviceType.iPhone-14 com.apple.CoreSimulator.SimRuntime.iOS-16-2"
  exit 1
fi

echo "Building Perch for iOS Simulator..."
xcodebuild \
  -project Perch.xcodeproj \
  -scheme PerchApp \
  -configuration Debug \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$DERIVED_DATA" \
  build

echo "Booting simulator ${DEVICE_ID}..."
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_ID" -b
open -a Simulator --args -CurrentDeviceUDID "$DEVICE_ID"

echo "Installing ${APP_PATH}..."
xcrun simctl uninstall "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$DEVICE_ID" "$APP_PATH"

echo "Launching ${BUNDLE_ID}..."
xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID"
echo "Perch is installed and launched on ${DEVICE_ID}."
