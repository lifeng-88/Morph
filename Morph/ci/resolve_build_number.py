#!/usr/bin/env python3
"""解析 CI Build Number：手动指定优先，否则取 App Store Connect 最新值 + 1。"""
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Optional

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


def get_app_id(token: str, bundle_id: str) -> str:
    query = urllib.parse.urlencode({"filter[bundleId]": bundle_id, "limit": 1})
    payload = api_request("GET", f"/apps?{query}", token)
    apps = payload.get("data", [])
    if not apps:
        print(f"::warning::App Store Connect 未找到 App `{bundle_id}`，使用工程默认 Build Number")
        return ""
    return apps[0]["id"]


def latest_uploaded_build_number(token: str, app_id: str) -> int:
    query = urllib.parse.urlencode(
        {
            "filter[app]": app_id,
            "sort": "-version",
            "limit": 20,
            "fields[builds]": "version",
        }
    )
    payload = api_request("GET", f"/builds?{query}", token)
    versions = []
    for item in payload.get("data", []):
        raw = item.get("attributes", {}).get("version", "")
        if str(raw).isdigit():
            versions.append(int(raw))
    return max(versions) if versions else 0


def project_build_number() -> int:
    raw = os.environ.get("PROJECT_BUILD_NUMBER", "").strip()
    if raw.isdigit():
        return int(raw)

    pbx = Path(__file__).resolve().parents[1] / "Morph.xcodeproj" / "project.pbxproj"
    if pbx.exists():
        match = re.search(r"CURRENT_PROJECT_VERSION = (\d+);", pbx.read_text(encoding="utf-8"))
        if match:
            return int(match.group(1))
    return 1


def write_outputs(build_number: int) -> None:
    print(f"Build Number: {build_number}")
    github_env = os.environ.get("GITHUB_ENV")
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_env:
        with open(github_env, "a", encoding="utf-8") as handle:
            handle.write(f"CURRENT_PROJECT_VERSION={build_number}\n")
    if github_output:
        with open(github_output, "a", encoding="utf-8") as handle:
            handle.write(f"build_number={build_number}\n")


def main() -> None:
    explicit = os.environ.get("INPUT_BUILD", "").strip()
    if explicit:
        if not explicit.isdigit():
            print(f"::error::build_number 须为正整数，当前为 `{explicit}`")
            sys.exit(1)
        write_outputs(int(explicit))
        return

    bundle_id = os.environ.get("BUNDLE_ID", "com.morph.app").strip()
    project_build = project_build_number()

    key_id = require_env("APP_STORE_CONNECT_KEY_ID")
    issuer_id = require_env("APP_STORE_CONNECT_ISSUER_ID")
    key_path = Path(require_env("APP_STORE_CONNECT_KEY_PATH"))
    if not key_path.exists():
        print(f"::error::找不到 API Key 文件：{key_path}")
        sys.exit(1)

    token = make_token(key_id, issuer_id, key_path)
    app_id = get_app_id(token, bundle_id)
    if not app_id:
        write_outputs(project_build)
        return

    latest = latest_uploaded_build_number(token, app_id)
    next_build = max(latest + 1, project_build)
    if latest:
        print(f"App Store Connect 最新 Build Number: {latest}")
    write_outputs(next_build)


if __name__ == "__main__":
    ensure_runtime()
    main()
