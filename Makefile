# `make test` builds and runs the plugin tests with clang (Command Line Tools
# are enough). `make package` needs Xcode and Node.js 20+: it runs the tests,
# builds a universal OSAScript binary, then validates and packs the .sdPlugin
# folder with Elgato's CLI into build/release/. Each step depends on the one
# before it, so a failing test or validation stops the package.

BUILD_DIR := build/tests
CFLAGS := -fobjc-arc -fmodules -Wall -Wno-deprecated-declarations \
          -ISources -ISources/Common
FRAMEWORKS := -framework Foundation -framework AppKit -framework OSAKit

TEST_SOURCES := Tests/MyStreamDeckPluginTests.m \
                Sources/MyStreamDeckPlugin.m \
                Sources/Common/ESDUtilities.m

.PHONY: test build stage validate package clean

PLUGIN := com.gabrielperales.osascript
XCODE_DIR := build/xcode
STAGE_DIR := build/stage
RELEASE_DIR := build/release
PACKAGE := $(RELEASE_DIR)/$(PLUGIN).streamDeckPlugin
# Elgato's Stream Deck CLI validates and packs the plugin (needs Node.js 20+).
STREAMDECK_CLI_VERSION := 1.10.4
STREAMDECK := npx --yes @elgato/cli@$(STREAMDECK_CLI_VERSION)

test: $(BUILD_DIR)/PluginTests
	$(BUILD_DIR)/PluginTests

$(BUILD_DIR)/PluginTests: $(TEST_SOURCES) Sources/MyStreamDeckPlugin.h
	@mkdir -p $(BUILD_DIR)
	clang $(CFLAGS) $(TEST_SOURCES) $(FRAMEWORKS) -o $@

build: test
	xcodebuild -project Sources/OSAScript.xcodeproj -scheme RunOSAScript \
	  -configuration Release -derivedDataPath $(XCODE_DIR) \
	  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
	  build

stage: build
	rm -rf $(STAGE_DIR)
	mkdir -p $(STAGE_DIR)
	rsync -a --exclude .DS_Store Sources/$(PLUGIN).sdPlugin $(STAGE_DIR)/
	cp $(XCODE_DIR)/Build/Products/Release/OSAScript $(STAGE_DIR)/$(PLUGIN).sdPlugin/

validate: stage
	$(STREAMDECK) validate $(STAGE_DIR)/$(PLUGIN).sdPlugin --no-update-check

package: validate
	rm -f $(PACKAGE)
	mkdir -p $(RELEASE_DIR)
	$(STREAMDECK) pack $(STAGE_DIR)/$(PLUGIN).sdPlugin --output $(RELEASE_DIR) --force --no-update-check
	@test -f $(PACKAGE) || { echo "streamdeck pack did not produce $(PACKAGE)"; ls -l $(RELEASE_DIR); exit 1; }
	@echo "Built $(PACKAGE)"

clean:
	rm -rf build
