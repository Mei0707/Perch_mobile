#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERIFY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/perch-swift-verify.XXXXXX")"
trap 'rm -rf "$VERIFY_DIR"' EXIT
SDK_PATH="$(xcrun --show-sdk-path)"
SOURCES=()
while IFS= read -r source; do SOURCES+=("$source"); done < <(rg --files Sources/Perch -g '*.swift')
swiftc -parse-as-library -target "$(uname -m)-apple-macosx13.0" \
  -sdk "$SDK_PATH" -module-cache-path "$VERIFY_DIR/cache" -module-name Perch \
  "${SOURCES[@]}" scripts/VerifyCore.swift -o "$VERIFY_DIR/verify"
if [[ "${1:-}" == "--with-backend" ]]; then
  node backend/verify-native-client.mjs "$VERIFY_DIR/verify"
else
  "$VERIFY_DIR/verify"
fi
