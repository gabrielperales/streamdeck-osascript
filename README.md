# streamdeck-osascript

![](screenshot.png)

## Description

`Run OSA Script` is a plugin that allows you to run arbitrary OSA language scripts (AppleScript and JavaScript for automation). It's based on the plugin `streamdeck-applescript` but this one has been rewritten from the scratch to update it to the Stream Deck SDK v2.

## Features

- code written in Objective-C
- macOS only
- executes AppleScript scripts
- executes JXA (JavaScript for automation) scripts

## Installation

In the Release folder, you can find the file `com.gabrielperales.osascript.streamDeckPlugin`. If you double-click this file on your machine, Stream Deck will install the plugin.

## Building a release

The packaged executable includes both `arm64` and `x86_64`, so it runs natively
on Apple silicon and Intel Macs. An Intel-only build cannot start on an Apple
silicon Mac without Rosetta and may cause Stream Deck to show an alert when a
key is pressed, before the script runs.

This release requires macOS 12 or later. Its deployment target and plugin
manifest both declare that minimum; the previous Intel-only package targeted
macOS 10.11.

With Xcode 13 or later selected and Python 3 installed, run:

```sh
./scripts/build-release.sh
```

If Command Line Tools is selected instead of Xcode, set `DEVELOPER_DIR` to your
Xcode installation's `Contents/Developer` directory when running the script.

The script builds both architectures, verifies and ad-hoc signs the executable,
and updates the executable in `Sources/com.gabrielperales.osascript.sdPlugin/`
and the installer in `Release/`. It preserves the existing action UUID and
settings, so existing profiles continue to work. The ad-hoc signature is for
local execution; it does not provide Developer ID signing or notarization.

Quit Stream Deck before replacing an installed copy, then relaunch it. Scripts
that target `Shortcuts Events` can continue running shortcuts in the background.

## Source code

The Sources folder contains the source code of the plugin.


## Examples

### Open VS Code

```JavaScript
var code = Application('Visual Studio Code');
code.activate();
```

## Resources to learn AppleScript and JXA

- [JXA-Cookbook](https://github.com/JXA-Cookbook/JXA-Cookbook)
- [Automating macOS with JXA presentation](https://github.com/josh-/automating-macOS-with-JXA-presentation)
- [Stackoverflow JXA](https://stackoverflow.com/questions/tagged/javascript-automation)
- [Stackoverflow AppleScript](https://stackoverflow.com/questions/tagged/applescript)
