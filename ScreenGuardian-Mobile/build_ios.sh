#!/bin/bash
# ScreenGuardian iOS Build Script
# Run this on macOS with Xcode installed

set -e

echo "=== ScreenGuardian iOS Build ==="

# Check prerequisites
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode not found. Please install Xcode from the App Store."
    exit 1
fi

if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Install from https://flutter.dev"
    exit 1
fi

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Install CocoaPods
echo "🍎 Installing CocoaPods dependencies..."
cd ios
pod install
cd ..

# Build iOS (no code signing for ad-hoc)
echo "🔨 Building iOS app..."
flutter build ios --release --no-codesign

echo ""
echo "✅ Build complete!"
echo ""
echo "📱 To install on a connected device:"
echo "   flutter install"
echo ""
echo "📦 To create IPA for distribution:"
echo "   cd ios"
echo "   xcodebuild -workspace Runner.xcworkspace -scheme Runner -sdk iphoneos -configuration Release archive -build/Runner.xcarchive"
echo "   xcodebuild -exportArchive -archivePath build/Runner.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath build/output"
echo ""
echo "🏪 For App Store submission:"
echo "   Open ios/Runner.xcworkspace in Xcode"
echo "   Product → Archive → Distribute App"
