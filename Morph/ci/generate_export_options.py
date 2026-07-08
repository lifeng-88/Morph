#!/usr/bin/env python3
"""生成含 teamID 的 ExportOptions.plist，修复 exportArchive No Team Found in Archive。"""
import os
import sys
from pathlib import Path


def main() -> None:
    team_id = os.environ.get("APPLE_TEAM_ID", "").strip()
    if not team_id:
        print("::error::缺少环境变量 APPLE_TEAM_ID")
        sys.exit(1)

    output = Path(os.environ.get("EXPORT_OPTIONS_PATH", "ci/ExportOptions.generated.plist"))
    output.parent.mkdir(parents=True, exist_ok=True)

    plist = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>method</key>
\t<string>app-store-connect</string>
\t<key>destination</key>
\t<string>export</string>
\t<key>signingStyle</key>
\t<string>automatic</string>
\t<key>teamID</key>
\t<string>{team_id}</string>
\t<key>uploadSymbols</key>
\t<true/>
\t<key>generateAppStoreInformation</key>
\t<true/>
</dict>
</plist>
"""
    output.write_text(plist, encoding="utf-8")
    print(f"已生成 ExportOptions（teamID={team_id}）：{output}")


if __name__ == "__main__":
    main()
