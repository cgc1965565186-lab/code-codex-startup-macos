#!/bin/bash
set -euo pipefail
source_dir="$(cd "$(dirname "$0")" && pwd)"
app_path="${1:-$source_dir/dist/StartupOverlay.app}"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
xcrun swiftc -O -target "$(uname -m)-apple-macosx13.0" \
  -framework AppKit -framework AVFoundation -framework CoreGraphics \
  "$source_dir/StartupOverlay.swift" -o "$app_path/Contents/MacOS/StartupOverlay"
cat > "$app_path/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.codecodex.startup.agent</string>
<key>CFBundleName</key><string>ChatGPT Codex Startup Overlay</string>
<key>CFBundleExecutable</key><string>StartupOverlay</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>2.0</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
if [[ -n "${2:-}" && ! "$2" -ef "$app_path/Contents/Resources/startup.mp4" ]]; then
  cp "$2" "$app_path/Contents/Resources/startup.mp4"
fi
xattr -cr "$app_path"
codesign --force --sign - "$app_path"
printf '%s\n' "$app_path"
