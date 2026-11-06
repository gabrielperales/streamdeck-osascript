# Each target does one step, so CI can run them as separate steps:
#   test      build and run the plugin tests with clang (Command Line Tools are enough)
#   build     build a universal OSAScript binary with xcodebuild (needs Xcode)
#   stage     copy the .sdPlugin folder and the binary into build/stage/
#   validate  run Elgato's `streamdeck validate` on the staged plugin (needs Node.js 20+)
#   pack      run `streamdeck pack` into build/release/
#   e2e       unpack the package and drive the real binary with a fake Stream Deck
#             (Tests/fake_streamdeck.py), once per architecture in E2E_ARCHS
# `make package` runs all of them in that order and stops at the first failure.

BUILD_DIR := build/tests
CFLAGS := -fobjc-arc -fmodules -Wall -Wno-deprecated-declarations \
          -ISources -ISources/Common
FRAMEWORKS := -framework Foundation -framework AppKit -framework OSAKit

TEST_SOURCES := Tests/MyStreamDeckPluginTests.m \
                Sources/MyStreamDeckPlugin.m \
                Sources/Common/ESDUtilities.m

.PHONY: test build stage validate pack e2e package clean

PLUGIN := com.gabrielperales.osascript
XCODE_DIR := build/xcode
STAGE_DIR := build/stage
RELEASE_DIR := build/release
PACKAGE := $(RELEASE_DIR)/$(PLUGIN).streamDeckPlugin
BINARY := $(XCODE_DIR)/Build/Products/Release/OSAScript
E2E_DIR := build/e2e
# x86_64 runs under Rosetta on Apple silicon.
E2E_ARCHS := arm64 x86_64
# Elgato's Stream Deck CLI validates and packs the plugin (needs Node.js 20+).
STREAMDECK_CLI_VERSION := 1.10.4
STREAMDECK := npx --yes @elgato/cli@$(STREAMDECK_CLI_VERSION)

test: $(BUILD_DIR)/PluginTests
	$(BUILD_DIR)/PluginTests

$(BUILD_DIR)/PluginTests: $(TEST_SOURCES) Sources/MyStreamDeckPlugin.h
	@mkdir -p $(BUILD_DIR)
	clang $(CFLAGS) $(TEST_SOURCES) $(FRAMEWORKS) -o $@

build:
	xcodebuild -project Sources/OSAScript.xcodeproj -scheme RunOSAScript \
	  -configuration Release -derivedDataPath $(XCODE_DIR) \
	  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
	  build

stage:
	@test -f $(BINARY) || { echo "$(BINARY) not found: run 'make build' first"; exit 1; }
	rm -rf $(STAGE_DIR)
	mkdir -p $(STAGE_DIR)
	rsync -a --exclude .DS_Store Sources/$(PLUGIN).sdPlugin $(STAGE_DIR)/
	cp $(BINARY) $(STAGE_DIR)/$(PLUGIN).sdPlugin/

validate:
	@test -d $(STAGE_DIR)/$(PLUGIN).sdPlugin || { echo "Nothing staged: run 'make stage' first"; exit 1; }
	$(STREAMDECK) validate $(STAGE_DIR)/$(PLUGIN).sdPlugin --no-update-check

pack:
	@test -d $(STAGE_DIR)/$(PLUGIN).sdPlugin || { echo "Nothing staged: run 'make stage' first"; exit 1; }
	rm -f $(PACKAGE)
	mkdir -p $(RELEASE_DIR)
	$(STREAMDECK) pack $(STAGE_DIR)/$(PLUGIN).sdPlugin --output $(RELEASE_DIR) --force --no-update-check
	@test -f $(PACKAGE) || { echo "streamdeck pack did not produce $(PACKAGE)"; ls -l $(RELEASE_DIR); exit 1; }
	@echo "Built $(PACKAGE)"

e2e:
	@test -f $(PACKAGE) || { echo "$(PACKAGE) not found: run 'make pack' first"; exit 1; }
	rm -rf $(E2E_DIR)
	mkdir -p $(E2E_DIR)
	unzip -q $(PACKAGE) -d $(E2E_DIR)
	for arch in $(E2E_ARCHS); do \
	  echo "== $$arch"; \
	  python3 Tests/fake_streamdeck.py --arch $$arch $(E2E_DIR)/$(PLUGIN).sdPlugin || exit 1; \
	done

# Runs every step in order and stops at the first failure. CI runs the same
# targets as separate steps.
package:
	$(MAKE) test
	$(MAKE) build
	$(MAKE) stage
	$(MAKE) validate
	$(MAKE) pack
	$(MAKE) e2e

clean:
	rm -rf build
