#!/bin/bash
# ScreenGuardian iOS Setup Script
# Run this after cloning the repo on your Mac

set -e

echo "🛡️ ScreenGuardian iOS Setup"
echo "=========================="

# Check prerequisites
command -v flutter >/dev/null 2>&1 || { echo "❌ Flutter not found. Install from https://flutter.dev"; exit 1; }
command -v xcodebuild >/dev/null 2>&1 || { echo "❌ Xcode not found. Install from App Store"; exit 1; }

cd "$(dirname "$0")"

echo ""
echo "📦 Step 1: Flutter pub get..."
flutter pub get

echo ""
echo "🔧 Step 2: Checking iOS project structure..."
if [ ! -d "ios/Runner.xcworkspace" ]; then
  echo "  iOS project not found, creating..."
  flutter create --platforms=ios --org com.timbertrail --project-name screenguardian .
  flutter pub get
fi

echo ""
echo "📱 Step 3: Opening Xcode..."
echo ""
echo "┌──────────────────────────────────────────────────────────┐"
echo "│  Please complete these steps in Xcode:                    │"
echo "│                                                           │"
echo "│  1. File → New → Target → 'Device Activity Monitor'       │"
echo "│     Product Name: ScreenTimeExtension                     │"
echo "│     Team: Your developer team                             │"
echo "│     Project: Runner                                       │"
echo "│                                                           │"
echo "│  2. For BOTH Runner and ScreenTimeExtension targets:      │"
echo "│     → Signing & Capabilities → + App Groups               │"
echo "│     → Add: group.com.timbertrail.screenguardian           │"
echo "│     → + Capability → Family Controls                      │"
echo "│                                                           │"
echo "│  3. Replace ScreenTimeExtension/DeviceActivityMonitor..   │"
echo "│     .swift with the one from ios/ScreenTimeExtension/     │"
echo "│                                                           │"
echo "│  4. Copy entitlements files to the correct locations      │"
echo "│                                                           │"
echo "│  5. Build & Run on a real device (not simulator)          │"
echo "└──────────────────────────────────────────────────────────┘"
echo ""

open ios/Runner.xcworkspace

echo "✅ Setup script complete. Follow the Xcode steps above."
echo ""
echo "After Xcode setup, run:"
echo "  flutter run -d <your-device>"
