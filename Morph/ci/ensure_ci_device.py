#!/usr/bin/env python3
"""确保 Apple 团队至少有一台已注册设备，以便 CI 生成 Development 描述文件。"""
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Optional

# 固定占位 UDID，避免每次 CI 都注册新设备
CI_DEVICE_UDID = "00008110-001A001E3C9A00C1"
CI_DEVICE_NAME = "GitHub Actions CI"
API_BASE = "https://api.appstoreconnect.apple.com/v1"
VENV_READY_ENV = "ASC_API_VENV_READY"


def require_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        print(f"::error::缺少环境变量 {name}")
        sys.exit(1)
    return value


def venv_python() -> Path:
    base = Path(os.environ.get("RUNNER_TEMP", "/tmp"))
    return base / "asc-api-venv" / "bin" / "python"


def ensure_runtime() -> None:
    """在 PEP 668 环境下用临时 venv 安装 PyJWT，避免 system pip 报错。"""
    if os.environ.get(VENV_READY_ENV) == "1":
        return

    try:
        import jwt  # type: ignore  # noqa: F401
        os.environ[VENV_READY_ENV] = "1"
        return
    except ImportError:
        pass

    venv_py = venv_python()
    if not venv_py.exists():
        venv_dir = venv_py.parent.parent
        print(f"创建临时 venv：{venv_dir}")
        subprocess.check_call([sys.executable, "-m", "venv", str(venv_dir)])
        subprocess.check_call(
            [str(venv_py), "-m", "pip", "install", "PyJWT", "cryptography"],
        )

    env = os.environ.copy()
    env[VENV_READY_ENV] = "1"
    os.execve(str(venv_py), [str(venv_py), *sys.argv], env)


def make_token(key_id: str, issuer_id: str, key_path: Path) -> str:
    import jwt  # type: ignore

    private_key = key_path.read_text(encoding="utf-8")
    now = int(time.time())
    payload = {
        "iss": issuer_id,
        "iat": now,
        "exp": now + 1200,
        "aud": "appstoreconnect-v1",
    }
    return jwt.encode(payload, private_key, algorithm="ES256", headers={"kid": key_id})


def api_request(method: str, path: str, token: str, body: Optional[dict] = None) -> dict:
    url = f"{API_BASE}{path}"
    data = None
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    if body is not None:
        data = json.dumps(body).encode("utf-8")
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            raw = response.read().decode("utf-8")
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        print(f"::error::App Store Connect API {method} {path} 失败 ({exc.code}): {detail}")
        sys.exit(1)


def list_devices(token: str):
    payload = api_request("GET", "/devices?limit=200", token)
    return payload.get("data", [])


def register_device(token: str) -> None:
    body = {
        "data": {
            "type": "devices",
            "attributes": {
                "name": CI_DEVICE_NAME,
                "platform": "IOS",
                "udid": CI_DEVICE_UDID,
            },
        }
    }
    api_request("POST", "/devices", token, body)
    print(f"已注册 CI 占位设备：{CI_DEVICE_NAME} ({CI_DEVICE_UDID})")


def ensure_bundle_id(token: str, bundle_id: str) -> None:
    query = urllib.parse.urlencode({"filter[identifier]": bundle_id, "limit": 1})
    path = f"/bundleIds?{query}"
    payload = api_request("GET", path, token)
    if not payload.get("data"):
        print(
            f"::error::Developer 后台未找到 App ID `{bundle_id}`，"
            "请先在 https://developer.apple.com/account/ 创建"
        )
        sys.exit(1)
    print(f"已确认 App ID：{bundle_id}")


def main() -> None:
    key_id = require_env("APP_STORE_CONNECT_KEY_ID")
    issuer_id = require_env("APP_STORE_CONNECT_ISSUER_ID")
    key_path = Path(require_env("APP_STORE_CONNECT_KEY_PATH"))
    bundle_id = os.environ.get("BUNDLE_ID", "com.morph.app").strip()

    if not key_path.exists():
        print(f"::error::找不到 API Key 文件：{key_path}")
        sys.exit(1)

    token = make_token(key_id, issuer_id, key_path)
    ensure_bundle_id(token, bundle_id)

    devices = list_devices(token)
    if devices:
        print(f"团队已有 {len(devices)} 台设备，跳过注册")
        return

    register_device(token)


if __name__ == "__main__":
    ensure_runtime()
    main()
