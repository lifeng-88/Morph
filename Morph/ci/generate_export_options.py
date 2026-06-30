#!/usr/bin/env python3
"""生成带 teamID 的 ExportOptions.plist，修复 exportArchive No Team Found in Archive。"""
import os
import plistlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT / "ExportOptions.generated.plist"


def main() -> None:
    team_id = os.environ.get("APPLE_TEAM_ID", "").strip()
    if not team_id:
        print("::error::缺少环境变量 APPLE_TEAM_ID")
        sys.exit(1)

    bundle_id = os.environ.get("BUNDLE_ID", "com.morph.net").strip()
    upload = os.environ.get("EXPORT_DESTINATION", "export").strip() or "export"
    if upload not in {"export", "upload"}:
        print(f"::error::EXPORT_DESTINATION 须为 export 或 upload，当前为 `{upload}`")
        sys.exit(1)

    options = {
        "method": "app-store-connect",
        "destination": upload,
        "signingStyle": "automatic",
        "teamID": team_id,
        "uploadSymbols": True,
        "generateAppStoreInformation": True,
    }

    OUTPUT.write_bytes(plistlib.dumps(options))
    print(f"已生成 {OUTPUT} teamID={team_id} bundle={bundle_id} destination={upload}")


if __name__ == "__main__":
    main()
