#!/bin/bash
# Verifies: DIARY-OPS-single-promotable-artifact/C
# Proves the compiled Dart (libapp.so) is identical across flavors: the
# per-flavor package delta excludes the compilation. Env comes from the
# bundled assets/config/env.json (unchanged here), not a per-flavor
# dart-define, so dev and qa must produce byte-identical libapp.so.
# Run from the clinical_diary directory.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Regenerating Flutter plugin codegen (config-cache wrapper failure is expected/ignored)"
flutter build apk --flavor dev || true

echo "==> Building dev + qa flavors via Gradle (config cache disabled)"
( cd android && ./gradlew :app:assembleDevRelease :app:assembleQaRelease --no-configuration-cache )

# Compare the arm64-v8a libapp.so for the two flavors.
abi="arm64-v8a"
dev_so="$(find build -path "*devRelease*/$abi/libapp.so" | head -1)"
qa_so="$(find build -path "*qaRelease*/$abi/libapp.so" | head -1)"

if [ -z "$dev_so" ] || [ -z "$qa_so" ]; then
  echo "FAIL: could not locate libapp.so for both flavors (dev='$dev_so' qa='$qa_so')"
  echo "Available libapp.so paths:"; find build -name libapp.so
  exit 1
fi

sha_dev="$(sha256sum "$dev_so" | cut -d' ' -f1)"
sha_qa="$(sha256sum "$qa_so" | cut -d' ' -f1)"
echo "dev ($dev_so): $sha_dev"
echo "qa  ($qa_so): $sha_qa"
if [ "$sha_dev" = "$sha_qa" ]; then
  echo "PASS: Dart AOT (libapp.so) is byte-identical across dev and qa flavors"
else
  echo "FAIL: libapp.so differs across flavors — the compilation is NOT flavor-independent"
  exit 1
fi
