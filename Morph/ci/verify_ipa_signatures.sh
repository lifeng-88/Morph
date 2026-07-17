#!/usr/bin/env bash
# 上传前校验 IPA 内主包与嵌套 framework 的 Distribution 签名。
set -euo pipefail

IPA_PATH="${1:-}"
if [[ -z "$IPA_PATH" || ! -f "$IPA_PATH" ]]; then
  echo "::error::用法: verify_ipa_signatures.sh <path-to.ipa>"
  exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

unzip -q "$IPA_PATH" -d "$WORK"
APP="$(find "$WORK/Payload" -maxdepth 1 -name '*.app' -print -quit)"
if [[ -z "$APP" ]]; then
  echo "::error::IPA 内未找到 .app"
  exit 1
fi

echo "Verifying app bundle: $APP"
codesign --verify --deep --strict --verbose=2 "$APP"

fail=0
while IFS= read -r -d '' fw; do
  name="$(basename "$fw" .framework)"
  bin="$fw/$name"
  if [[ ! -f "$bin" ]]; then
    continue
  fi
  echo "Verifying framework: $bin"
  if ! codesign --verify --verbose=2 "$bin"; then
    fail=1
    continue
  fi
  authority="$(codesign -d -vv "$bin" 2>&1 | grep 'Authority=' | head -1 || true)"
  echo "  $authority"
  if [[ "$authority" == *"Apple Development"* ]]; then
    echo "::error::$name 使用了 Development 证书，App Store 上传会失败 (90035)"
    fail=1
  elif [[ "$authority" != *"Apple Distribution"* && "$authority" != *"iPhone Distribution"* ]]; then
    echo "::error::$name 未检测到 Distribution 证书: ${authority:-<none>}"
    fail=1
  fi
done < <(find "$APP/Frameworks" -type d -name '*.framework' -print0 2>/dev/null || true)

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

echo "IPA 签名校验通过"
