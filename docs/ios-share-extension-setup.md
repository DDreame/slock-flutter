# iOS Share Extension Setup

The iOS Share Extension requires Xcode for native target creation. The scaffold
files are checked in under `ios/ShareExtension/` but the Xcode project must be
configured manually.

## Prerequisites

- macOS with Xcode 15+
- Valid Apple Developer account with provisioning profiles

## Steps

### 1. Add the Share Extension target

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select the project in the navigator, then click **+** under **TARGETS**.
3. Choose **Share Extension** and click **Next**.
4. Set the product name to `ShareExtension`.
5. Set the bundle identifier to `<your-bundle-id>.ShareExtension`.
6. Click **Finish**. Xcode will create a default target.

### 2. Replace generated files

1. Delete the auto-generated `ShareViewController.swift` from the new target.
2. Add the existing files from `ios/ShareExtension/` to the target:
   - `ShareViewController.swift`
   - `Info.plist`
   - `ShareExtension.entitlements`

### 3. Configure App Group

Both the main Runner target and the ShareExtension target must share the same
App Group so the extension can pass data to the main app.

1. Select the **Runner** target → **Signing & Capabilities** → **+ Capability** → **App Groups**.
2. Add the group `group.app.slock.shared`.
3. Select the **ShareExtension** target → **Signing & Capabilities** → **+ Capability** → **App Groups**.
4. Add the same group `group.app.slock.shared`.

### 4. Configure entitlements

1. In the ShareExtension target → **Build Settings** → search for "Code Signing Entitlements".
2. Set the value to `ShareExtension/ShareExtension.entitlements`.
3. In the Runner target, ensure `Runner/Runner.entitlements` also includes the
   `com.apple.security.application-groups` key with `group.app.slock.shared`.

### 5. Register the `slock` URL scheme

The share extension opens the main app via the `slock://share` URL. The scheme
is already declared in `ios/Runner/Info.plist` under `CFBundleURLTypes`. Verify
the entry exists after merging:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLName</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>slock</string>
    </array>
  </dict>
</array>
```

If it is missing for any reason, add it to the `<dict>` in
`ios/Runner/Info.plist`.

### 6. Set deployment target

1. Select the ShareExtension target → **General** → **Deployment Info**.
2. Set the minimum iOS version to match the Runner target (iOS 15.0+).

### 7. Build and test

1. Select the ShareExtension scheme in Xcode.
2. Build and run on a device or simulator.
3. Open Photos or Safari, tap Share, and look for "Share to Slock".

## How it works

1. User taps "Share to Slock" in the iOS share sheet.
2. `ShareViewController` extracts the shared content (text, URLs, images, videos, files).
3. Content is saved to `UserDefaults(suiteName: "group.app.slock.shared")`.
4. The extension opens the main app via the `slock://share` URL scheme.
5. `receive_sharing_intent` picks up the shared data and triggers `ShareIntentStore`.
6. The app navigates to the share target picker page.

## Troubleshooting

- **Extension doesn't appear in share sheet**: Ensure the extension's bundle ID
  is a child of the main app's bundle ID (e.g., `com.slock.app.ShareExtension`).
- **Data not reaching the main app**: Verify both targets have the same App Group
  configured and that `UserDefaults(suiteName:)` uses the matching group name.
- **Signing errors**: Each target needs its own provisioning profile. The extension
  profile must include the App Group capability.
