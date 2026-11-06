# Changelog

All notable changes to this plugin are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow the `Version` field in `manifest.json`.

## [Unreleased]

## [1.1.0] - 2026-11-06

### Added

- Native Apple silicon support: the plugin binary is now universal (arm64 + x86_64).
- Releases are built and published by GitHub Actions. Download the plugin from the [Releases page](https://github.com/gabrielperales/streamdeck-osascript/releases).

### Changed

- Minimum macOS version raised from 10.11 to 10.13.
- Minimum Stream Deck software version raised from 4.1 to 6.4, the oldest version Elgato's validation accepts.
- Every release package is now validated and packed with Elgato's Stream Deck CLI.
- New high-resolution plugin icon (256 × 256 and 512 × 512 px) and a category icon.

### Removed

- The prebuilt plugin is no longer stored in the repository under `Release/`.

## [1.0.0] - 2021-01-26

### Added

- First release: run an AppleScript or JavaScript (JXA) script when a Stream Deck key is pressed. The script and language are set per key in the Property Inspector.

[Unreleased]: https://github.com/gabrielperales/streamdeck-osascript/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/gabrielperales/streamdeck-osascript/releases/tag/v1.1.0
[1.0.0]: https://github.com/gabrielperales/streamdeck-osascript/tree/ed1b300
