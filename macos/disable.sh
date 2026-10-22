#!/bin/bash
set -euo pipefail
label="local.codecodex.startup.agent"
service="gui/$(id -u)/$label"
plist_path="$HOME/Library/LaunchAgents/$label.plist"
support_dir="$HOME/Library/Application Support/CodeCodexStartup"
if launchctl print "$service" >/dev/null 2>&1; then
  launchctl bootout "$service"
fi
if [[ -f "$plist_path" ]]; then
  mv "$plist_path" "$support_dir/disabled-agent.plist"
fi
printf '已停用 ChatGPT / Codex 窗口开场。视频和本地组件保留，重新运行 install.sh 可恢复。\n'
