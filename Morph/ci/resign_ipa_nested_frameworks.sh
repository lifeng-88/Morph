#!/usr/bin/env bash
# Export 后重签 IPA 内嵌套 framework（修复 AppsFlyerLib 等 SPM 静态库 designated requirement 失败）。
set -euo pipefail

IPA_PATH="${1:-}"

if [[ -z "$IPA_PATH" || ! -f "$IPA_PATH" ]]; then
  echo "::error::用法: resign_ipa_nested_frameworks.sh <path-to.ipa>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIGN_IDENTITY="$("$SCRIPT_DIR/find_distribution_identity.sh")"

WORK="$(mktemp -d)"
ENTITLEMENTS="$(mktemp)"
trap 'rm -rf "$WORK"; rm -f "$ENTITLEMENTS"' EXIT

unzip -q "$IPA_PATH" -d "$WORK"
APP="$(find "$WORK/Payload" -maxdepth 1 -name '*.app' -print -quit)"
if [[ -z "$APP" ]]; then
  echo "::error::IPA 内未找到 .app"
  exit 1
fi

echo "Re-signing nested binaries with identity hash: $SIGN_IDENTITY"

if [[ -d "$APP/Frameworks" ]]; then
  while IFS= read -r -d '' path; do
    if file "$path" | grep -q "Mach-O"; then
      echo "Re-sign Mach-O: $path"
      codesign --remove-signature "$path" 2>/dev/null || true
      codesign --force --sign "$SIGN_IDENTITY" --options runtime "$path"
    fi
  done < <(find "$APP/Frameworks" -depth -type f -print0)

  while IFS= read -r -d '' fw; do
    echo "Re-sign framework bundle: $fw"
    codesign --remove-signature "$fw" 2>/dev/null || true
    codesign --force --sign "$SIGN_IDENTITY" --options runtime "$fw"
  done < <(find "$APP/Frameworks" -type d -name '*.framework' -print0)
fi

codesign -d --entitlements "$ENTITLEMENTS" "$APP" 2>/dev/null || true
if [[ -s "$ENTITLEMENTS" ]]; then
  codesign --force --sign "$SIGN_IDENTITY" --entitlements "$ENTITLEMENTS" --options runtime "$APP"
else
  codesign --force --sign "$SIGN_IDENTITY" --options runtime "$APP"
fi

RESIGNED_IPA="${IPA_PATH%.ipa}.resigned.ipa"
(
  cd "$WORK"
  zip -qr "$RESIGNED_IPA" Payload
)
mv "$RESIGNED_IPA" "$IPA_PATH"

echo "Re-signed IPA: $IPA_PATH"
