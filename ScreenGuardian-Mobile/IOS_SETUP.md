# iOS Setup Guide — ScreenGuardian with ScreenTime API

## Prerequisites

- macOS with Xcode 14+
- Flutter 3.x
- iOS 16+ device (real device, not simulator)
- Apple Developer account (free account works for testing, paid needed for App Group)

## Quick Start

```bash
cd ScreenGuardian-Mobile
chmod +x setup_ios.sh
./setup_ios.sh
```

Then follow the Xcode steps below.

## Manual Xcode Configuration

### Step 1: Add ScreenTime Extension Target

1. Open `ios/Runner.xcworkspace` in Xcode
2. **File → New → Target...**
3. Search for **"Device Activity Monitor"**
4. Click **Next**
5. Configure:
   - Product Name: `ScreenTimeExtention`
   - Team: Your developer team
   - Project: `Runner`
   - Embed in Application Extension: `Runner`
6. Click **Finish** → Click **Activate** when prompted

### Step 2: Configure App Groups

For **BOTH** targets (Runner AND ScreenTimeExtention):

1. Select the target in the project navigator
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **App Groups**
5. Add group: `group.com.timbertrail.screenguardian`
6. Make sure the checkbox is checked

### Step 3: Add Family Controls Capability

For **BOTH** targets:

1. **+ Capability** → **Family Controls**

### Step 4: Replace Extension Code

Xcode generates a default `DeviceActivityMonitorExtension.swift`. Replace it:

1. In Xcode's file navigator, find `ScreenTimeExtention/DeviceActivityMonitorExtension.swift`
2. Select all content (Cmd+A), delete it
3. Copy the content from `ios/ScreenTimeExtention/DeviceActivityMonitorExtension.swift` in this repo
4. Paste it into Xcode

### Step 5: Configure Extension Info.plist

In Xcode, select `ScreenTimeExtention/Info.plist` and ensure it contains:

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.deviceactivity.monitor</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).DeviceActivityMonitorExtension</string>
</dict>
```

### Step 6: Add ScreenTimePlugin to Build

1. In Xcode, right-click on the `Runner` group
2. **Add Files to "Runner"...**
3. Select `ios/Runner/ScreenTimePlugin/ScreenTimePlugin.swift`
4. Make sure **"Add to targets"** has `Runner` checked
5. Click **Add**

### Step 7: Build & Run

```bash
# List connected devices
flutter devices

# Run on your device
flutter run -d <your-device-name>

# Or just open Xcode and press Cmd+R
open ios/Runner.xcworkspace
```

## Troubleshooting

### "No signing certificate found"
→ Select your developer team in both targets' Signing & Capabilities

### "App Group entitlement not found"
→ Make sure BOTH targets have the same App Group added

### "Family Controls authorization failed"
→ Go to Settings → Screen Time → enable it on the device first

### Extension not triggering
→ Check that the device is running iOS 16+
→ Make sure you accepted the Family Controls authorization prompt

### "Module 'ScreenTimePlugin' not found"
→ Make sure ScreenTimePlugin.swift is added to the Runner target (not just the extension)

## Architecture

```
┌─────────────────────────────────┐
│  Main App (Flutter)             │
│  → Requests Family Controls auth│
│  → Registers activity schedule  │
│  → Reads usage data            │
└──────────┬──────────────────────┘
           │ App Group (UserDefaults)
┌──────────▼──────────────────────┐
│  ScreenTimeExtention            │
│  (DeviceActivityMonitor)        │
│  → Triggers at 20min/40min     │
│  → Shows Shield overlay        │
│  → Logs events                 │
└─────────────────────────────────┘
```
