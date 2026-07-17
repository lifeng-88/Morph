#!/usr/bin/env bash
# 从钥匙串查找 Apple Distribution 身份（返回 40 位 SHA-1，供 codesign 使用）。
set -euo pipefail

TEAM_ID="${APPLE_TEAM_ID:-}"

find_distribution_identity_hash() {
  local line hash name

  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*[0-9]+\)[[:space:]]*([A-F0-9]{40})[[:space:]]+\"(.+)\"$ ]] || continue
    hash="${BASH_REMATCH[1]}"
    name="${BASH_REMATCH[2]}"

    if [[ "$name" != *"Apple Distribution"* && "$name" != *"iPhone Distribution"* ]]; then
      continue
    fi
    if [[ -n "$TEAM_ID" && "$name" != *"($TEAM_ID)"* ]]; then
      continue
    fi

    echo "$hash"
    echo "Using signing identity: $name ($hash)" >&2
    return 0
  done < <(security find-identity -v -p codesigning 2>/dev/null)

  return 1
}

if hash="$(find_distribution_identity_hash)"; then
  echo "$hash"
  exit 0
fi

echo "::error::未找到带私钥的 Apple Distribution 身份" >&2
echo "请配置 GitHub Secrets: IOS_DISTRIBUTION_P12_BASE64 + IOS_DISTRIBUTION_P12_PASSWORD" >&2
security find-identity -v -p codesigning >&2 || true
exit 1
