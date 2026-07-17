#!/usr/bin/env bash
# 准备 CI 签名钥匙串：可选导入 Distribution .p12，供 Export 后重签嵌套 framework。
set -euo pipefail

KEYCHAIN="${RUNNER_TEMP:-/tmp}/morph-signing.keychain-db"
KEYCHAIN_PASSWORD="${KEYCHAIN_PASSWORD:-actions}"
P12_PATH="${RUNNER_TEMP:-/tmp}/distribution.p12"

create_keychain() {
  if security list-keychains -d user | grep -Fq "$KEYCHAIN"; then
    echo "签名钥匙串已存在: $KEYCHAIN"
  else
    security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
    echo "已创建签名钥匙串: $KEYCHAIN"
  fi

  security set-keychain-settings -lut 21600 "$KEYCHAIN"
  security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"

  local existing=()
  while IFS= read -r line; do
    existing+=("$line")
  done < <(security list-keychains -d user | tr -d '"')

  security list-keychains -d user -s "$KEYCHAIN" "${existing[@]}"
  security default-keychain -s "$KEYCHAIN"
}

import_p12_if_present() {
  local p12_b64="${IOS_DISTRIBUTION_P12_BASE64:-}"
  local p12_password="${IOS_DISTRIBUTION_P12_PASSWORD:-}"

  if [[ -z "$p12_b64" ]]; then
    echo "未配置 IOS_DISTRIBUTION_P12_BASE64，跳过 .p12 导入（Export 后依赖 xcodebuild 写入的 Distribution 证书）"
    return 0
  fi

  if [[ -z "$p12_password" ]]; then
    echo "::error::已配置 IOS_DISTRIBUTION_P12_BASE64 但缺少 IOS_DISTRIBUTION_P12_PASSWORD"
    exit 1
  fi

  printf '%s' "$p12_b64" | base64 --decode > "$P12_PATH"
  security import "$P12_PATH" \
    -k "$KEYCHAIN" \
    -P "$p12_password" \
    -T /usr/bin/codesign \
    -T /usr/bin/security \
    -A
  security set-key-partition-list \
    -S apple-tool:,apple:,codesign: \
    -s \
    -k "$KEYCHAIN_PASSWORD" \
    "$KEYCHAIN"
  rm -f "$P12_PATH"
  echo "已导入 Distribution .p12"
}

create_keychain
import_p12_if_present

if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "KEYCHAIN_PATH=$KEYCHAIN" >> "$GITHUB_ENV"
fi
echo "当前可用签名身份:"
security find-identity -v -p codesigning || true
