#!/bin/bash
set -e

# Change to the macOS platform directory
cd "$(dirname "$0")/.."

echo "======================================"
echo "🚀 Building & Archiving CopyM8..."
echo "======================================"
rm -rf build/
xcodebuild clean archive \
    -project CopyM8.xcodeproj \
    -scheme CopyM8 \
    -archivePath build/CopyM8.xcarchive

echo "======================================"
echo "📦 Exporting Archive for Developer ID..."
echo "======================================"
xcodebuild -exportArchive \
    -archivePath build/CopyM8.xcarchive \
    -exportOptionsPlist scripts/ExportOptions.plist \
    -exportPath build/ExportedApp

echo "======================================"
echo "💿 Creating DMG..."
echo "======================================"
create-dmg \
    --volname "CopyM8" \
    --volicon "build/ExportedApp/CopyM8.app/Contents/Resources/AppIcon.icns" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "CopyM8.app" 150 190 \
    --hide-extension "CopyM8.app" \
    --app-drop-link 450 190 \
    "build/CopyM8.dmg" \
    "build/ExportedApp/CopyM8.app"

echo "======================================"
echo "🔐 Submitting DMG for Notarization..."
echo "======================================"
xcrun notarytool submit build/CopyM8.dmg \
    --keychain-profile "AC_PASSWORD" \
    --wait

echo "======================================"
echo "📎 Stapling Notarization Ticket..."
echo "======================================"
xcrun stapler staple build/CopyM8.dmg

echo "======================================"
echo "✅ Success! CopyM8.dmg is ready in platforms/copym8-macos/build/!"
