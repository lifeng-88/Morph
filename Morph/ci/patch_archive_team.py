#!/usr/bin/env python3
"""向 .xcarchive/Info.plist 写入 Team，避免 exportArchive No Team Found in Archive。"""
import os
import plistlib
import sys
from pathlib import Path


def main() -> None:
    team_id = os.environ.get("APPLE_TEAM_ID", "").strip()
    archive_path = os.environ.get("ARCHIVE_PATH", "").strip()
    if not team_id:
        print("::error::缺少环境变量 APPLE_TEAM_ID")
        sys.exit(1)
    if not archive_path:
        print("::error::缺少环境变量 ARCHIVE_PATH")
        sys.exit(1)

    info_plist = Path(archive_path) / "Info.plist"
    if not info_plist.exists():
        print(f"::error::找不到 {info_plist}")
        sys.exit(1)

    with info_plist.open("rb") as handle:
        data = plistlib.load(handle)

    app_props = data.setdefault("ApplicationProperties", {})
    previous = app_props.get("Team")
    app_props["Team"] = team_id

    with info_plist.open("wb") as handle:
        plistlib.dump(data, handle)

    if previous and previous != team_id:
        print(f"::warning::Archive Team 已从 {previous} 更新为 {team_id}")
    else:
        print(f"已写入 Archive Team = {team_id}")


if __name__ == "__main__":
    main()
