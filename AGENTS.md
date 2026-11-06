# AGENTS.md

macOS Stream Deck plugin (SDK v2, Objective-C) that runs a per-key AppleScript or JXA script on key down via `OSAKit`.

## Where things live

- `Sources/MyStreamDeckPlugin.m`: the only plugin logic. Edit here.
- `Sources/com.gabrielperales.osascript.sdPlugin/`: the bundle Stream Deck loads. `index.html` is the Property Inspector; `manifest.json` declares the action UUID `com.gabrielperales.osascript.action`.
- `Sources/Common/`: Elgato SDK boilerplate (`ESDConnectionManager` dispatches WebSocket events to the plugin).
- `Sources/Vendor/SocketRocket/`: third-party code. Treat as read-only.
- `.github/workflows/test.yml`: reusable workflow (`workflow_call`) that runs `make test`. It has no push or PR trigger of its own, so the tests run once per event.
- `.github/workflows/build.yml`: runs on pull requests, pushes to `master` and `v*` tags. Its `build` job `needs` the Tests workflow, then runs `make build`, `make stage`, `make validate`, `make pack` and `make e2e` as separate steps. On a `v*` tag it also publishes the package as a GitHub release. Keep that `needs: test` dependency, and keep the step order in both places: the `package` target in the `Makefile` and the steps in `build.yml`. Nothing should be packed without passing the tests and Elgato's validation.

## Settings contract

The Property Inspector and the plugin share two per-key settings. Keep both sides in sync when changing either:

| Key | Values | Written by | Read by |
| --- | --- | --- | --- |
| `language` | `"AppleScript"` \| `"JavaScript"` (passed to `+[OSALanguage languageForName:]`) | `saveSettings()` in `index.html` | `keyDownForAction:` |
| `scriptText` | script source | `saveSettings()` in `index.html` | `keyDownForAction:` |

The plugin caches settings in `settingsPayload`, keyed by action context, and fills that cache **only in `willAppearForAction:`**. `didReceiveSettings` is defined in `ESDSDKDefines.h` but not dispatched by `ESDConnectionManager` or handled by the plugin, so Property Inspector edits reach the plugin only after the key reappears. Fixing that means adding the dispatch in `ESDConnectionManager.m`, a method on `ESDEventsProtocol`, and an implementation that refreshes `settingsPayload[context]`.

## Building and verifying

- The `Makefile` has one target per step: `test`, `build` (the `RunOSAScript` scheme as a universal arm64/x86_64 binary, needs Xcode), `stage` (`.sdPlugin` folder + binary into `build/stage/`), `validate` and `pack` (Elgato's `streamdeck validate` and `streamdeck pack`, need Node.js 20+; the CLI version is pinned as `STREAMDECK_CLI_VERSION`). `make e2e` runs the end-to-end test on the package. `make package` runs them all in order and writes `build/release/com.gabrielperales.osascript.streamDeckPlugin`. Change build flags in the `Makefile`, not in the workflow, so local and CI builds match.
- Run `make test` after changing plugin logic. It compiles `Tests/MyStreamDeckPluginTests.m` with the plugin sources using plain `clang` (Command Line Tools are enough) and drives `MyStreamDeckPlugin` through its event methods; scripts prove they ran by writing a marker file. Add a test function to `Tests/MyStreamDeckPluginTests.m` and list it in `main()`. If you add a source file the plugin depends on, add it to `TEST_SOURCES` in the `Makefile`.
- `make e2e` (`Tests/fake_streamdeck.py`, Python standard library only) plays the Stream Deck app: it unpacks the built package, launches the real binary with Stream Deck's launch arguments, serves the WebSocket and sends `willAppear`/`keyDown`, for both `arm64` and `x86_64` (Rosetta). It covers the compiled binary and `ESDConnectionManager`. Add a check there when changing launch, registration or event handling. The `.streamDeckPlugin` zip does not keep the executable bit; the Stream Deck app sets it on install, and the harness does the same.
- Nothing automated covers the Property Inspector (`index.html`). For that, install the plugin in the Stream Deck app; script errors go to the unified log via `NSLog` (filter Console.app by `OSAScript`).
- The `OSAScript` binary and the `.streamDeckPlugin` package are never committed (both are in `.gitignore`). A source change ships when a `v*` tag is pushed.

## Conventions

- Keep the action UUID and plugin folder name `com.gabrielperales.osascript` stable: renaming breaks keys users have already configured.
- When adding user-visible strings, update both `en.json` and `es.json`.
- Bump `Version` in `manifest.json` before tagging a release. Elgato's validator requires four parts (`1.2.3.0`); the tag and the `CHANGELOG.md` section use the first three (`v1.2.3`, `[1.2.3]`). The workflow fails if they differ.
- `manifest.json` must pass `make validate`. Elgato's validator reports errors in stages: fixing one can reveal more, so re-run it until it is clean.
- Add user-visible changes under `## [Unreleased]` in `CHANGELOG.md`. When releasing, rename that section to the new version and date. The workflow uses that section as the GitHub release notes and fails if it is missing.
- Leave `xcuserdata/` files out of commits.
