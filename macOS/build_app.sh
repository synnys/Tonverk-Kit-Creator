#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="${1:-Tonverk Kit Forge.app}"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" .build/module-cache
swiftc -parse-as-library -module-cache-path .build/module-cache macOS/TonverkKitForge.swift -o "$APP/Contents/MacOS/TonverkKitForge" -framework SwiftUI -framework AppKit -framework AVFoundation
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Tonverk Kit Forge</string>
<key>CFBundleDisplayName</key><string>Tonverk Kit Forge</string>
<key>CFBundleIdentifier</key><string>audio.tonverk.kitforge</string>
<key>CFBundleExecutable</key><string>TonverkKitForge</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
echo "Built $APP"
