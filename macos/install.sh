#!/bin/bash
set -euo pipefail
source_dir="$(cd "$(dirname "$0")" && pwd)"
support_dir="$HOME/Library/Application Support/CodeCodexStartup"
agent_app="$support_dir/StartupOverlay.app"
video_path="${1:-$agent_app/Contents/Resources/startup.mp4}"
label="local.codecodex.startup.agent"
plist_path="$HOME/Library/LaunchAgents/$label.plist"
service="gui/$(id -u)/$label"
if [[ ! -f "$video_path" ]]; then
  printf 'Usage: bash macos/install.sh /path/to/startup.mp4\n' >&2
  exit 1
fi
if launchctl print "$service" >/dev/null 2>&1; then
  launchctl bootout "$service"
fi
bash "$source_dir/build.sh" "$agent_app" "$video_path"
mkdir -p "$HOME/Library/LaunchAgents"
/usr/bin/python3 - "$plist_path" "$agent_app/Contents/MacOS/StartupOverlay" "$support_dir" <<'PY'
import plistlib
import sys
from pathlib import Path
plist, executable, support = sys.argv[1:]
with open(plist, "wb") as output:
    plistlib.dump({
        "Label": "local.codecodex.startup.agent",
        "ProgramArguments": [executable],
        "RunAtLoad": True,
        "KeepAlive": True,
        "LimitLoadToSessionType": "Aqua",
        "StandardOutPath": str(Path(support) / "agent.log"),
        "StandardErrorPath": str(Path(support) / "agent-error.log"),
    }, output)
PY
launchctl bootstrap "gui/$(id -u)" "$plist_path"
printf '已启用 ChatGPT / Codex 窗口开场，下次从官方图标启动时生效。\n'
