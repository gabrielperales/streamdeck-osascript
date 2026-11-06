# AGENTS.md

macOS Stream Deck plugin (SDK v2, Objective-C) that runs a per-key AppleScript or JXA script on key down via `OSAKit`.

## Where things live

- `Sources/MyStreamDeckPlugin.m`: the only plugin logic. Edit here.
- `Sources/com.gabrielperales.osascript.sdPlugin/`: the bundle Stream Deck loads. `index.html` is the Property Inspector; `manifest.json` declares the action UUID `com.gabrielperales.osascript.action`.
- `Sources/Common/`: Elgato SDK boilerplate (`ESDConnectionManager` dispatches WebSocket events to the plugin).
- `Sources/Vendor/SocketRocket/`: third-party code. Treat as read-only.
- `Release/*.streamDeckPlugin`: a zip of the `.sdPlugin` folder, committed as the user-facing download.

## Settings contract

The Property Inspector and the plugin share two per-key settings. Keep both sides in sync when changing either:

| Key | Values | Written by | Read by |
| --- | --- | --- | --- |
| `language` | `"AppleScript"` \| `"JavaScript"` (passed to `+[OSALanguage languageForName:]`) | `saveSettings()` in `index.html` | `keyDownForAction:` |
| `scriptText` | script source | `saveSettings()` in `index.html` | `keyDownForAction:` |

The plugin caches settings in `settingsPayload`, keyed by action context, and fills that cache **only in `willAppearForAction:`**. `didReceiveSettings` is defined in `ESDSDKDefines.h` but not dispatched by `ESDConnectionManager` or handled by the plugin, so Property Inspector edits reach the plugin only after the key reappears. Fixing that means adding the dispatch in `ESDConnectionManager.m`, a method on `ESDEventsProtocol`, and an implementation that refreshes `settingsPayload[context]`.

## Building and verifying

- Build with Xcode, scheme `RunOSAScript` in `Sources/OSAScript.xcodeproj`. CLI: `xcodebuild -project Sources/OSAScript.xcodeproj -scheme RunOSAScript -configuration Release build`.
- There are no automated tests. Verify behaviour by installing the plugin in the Stream Deck app and pressing a key; script errors go to the unified log via `NSLog` (filter Console.app by `OSAScript`).
- The committed `OSAScript` binary and the `Release/` package are build outputs that are updated by hand. A source change is not shipped until the binary is copied into the `.sdPlugin` folder and the package is regenerated; say so when you change `.m`/`.h` files without doing it. The committed binary is x86_64 only.

## Conventions

- Keep the action UUID and plugin folder name `com.gabrielperales.osascript` stable: renaming breaks keys users have already configured.
- When adding user-visible strings, update both `en.json` and `es.json`.
- Bump `Version` in `manifest.json` with every new release package.
- Leave `xcuserdata/` files out of commits.
