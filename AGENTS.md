# AGENTS.md

macOS Stream Deck plugin (SDK v2, Objective-C) that runs a per-key AppleScript or JXA script on key down via `OSAKit`.

## Where things live

- `Sources/MyStreamDeckPlugin.m`: the only plugin logic. Edit here.
- `Sources/com.gabrielperales.osascript.sdPlugin/`: the bundle Stream Deck loads. `index.html` is the Property Inspector; `manifest.json` declares the action UUID `com.gabrielperales.osascript.action`.
- `Sources/Common/`: Elgato SDK boilerplate (`ESDConnectionManager` dispatches WebSocket events to the plugin).
- `Sources/Vendor/SocketRocket/`: third-party code. Treat as read-only.
- `.github/workflows/test.yml`: runs `make test` on pull requests. It is also a reusable workflow (`workflow_call`).
- `.github/workflows/build.yml`: runs on pushes to `master` and on `v*` tags. Its `build` job `needs` the reusable Tests workflow, then runs `make package`. On a `v*` tag it also publishes the package as a GitHub release. Keep that `needs: test` dependency, and keep `build: test` in the `Makefile`: no build should happen without the tests passing first.

## Settings contract

The Property Inspector and the plugin share two per-key settings. Keep both sides in sync when changing either:

| Key | Values | Written by | Read by |
| --- | --- | --- | --- |
| `language` | `"AppleScript"` \| `"JavaScript"` (passed to `+[OSALanguage languageForName:]`) | `saveSettings()` in `index.html` | `keyDownForAction:` |
| `scriptText` | script source | `saveSettings()` in `index.html` | `keyDownForAction:` |

The plugin caches settings in `settingsPayload`, keyed by action context, and fills that cache **only in `willAppearForAction:`**. `didReceiveSettings` is defined in `ESDSDKDefines.h` but not dispatched by `ESDConnectionManager` or handled by the plugin, so Property Inspector edits reach the plugin only after the key reappears. Fixing that means adding the dispatch in `ESDConnectionManager.m`, a method on `ESDEventsProtocol`, and an implementation that refreshes `settingsPayload[context]`.

## Building and verifying

- `make package` (needs Xcode) builds the `RunOSAScript` scheme as a universal arm64/x86_64 binary and zips it with the `.sdPlugin` folder into `build/release/com.gabrielperales.osascript.streamDeckPlugin`. Change build flags there, not only in the workflow, so local and CI builds match.
- Run `make test` after changing plugin logic. It compiles `Tests/MyStreamDeckPluginTests.m` with the plugin sources using plain `clang` (Command Line Tools are enough) and drives `MyStreamDeckPlugin` through its event methods; scripts prove they ran by writing a marker file. Add a test function to `Tests/MyStreamDeckPluginTests.m` and list it in `main()`. If you add a source file the plugin depends on, add it to `TEST_SOURCES` in the `Makefile`.
- The tests do not cover the WebSocket layer (`ESDConnectionManager`) or the Property Inspector. For those, install the plugin in the Stream Deck app and press a key; script errors go to the unified log via `NSLog` (filter Console.app by `OSAScript`).
- The `OSAScript` binary and the `.streamDeckPlugin` package are never committed (both are in `.gitignore`). A source change ships when a `v*` tag is pushed.

## Conventions

- Keep the action UUID and plugin folder name `com.gabrielperales.osascript` stable: renaming breaks keys users have already configured.
- When adding user-visible strings, update both `en.json` and `es.json`.
- Bump `Version` in `manifest.json` before tagging a release; the workflow fails if the tag (`v1.2.3`) and `Version` (`1.2.3`) differ.
- Add user-visible changes under `## [Unreleased]` in `CHANGELOG.md`. When releasing, rename that section to the new version and date. The workflow uses that section as the GitHub release notes and fails if it is missing.
- Leave `xcuserdata/` files out of commits.
