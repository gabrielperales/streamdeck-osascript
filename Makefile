# `make test` builds and runs the plugin tests with clang (Command Line Tools
# are enough). `make package` needs Xcode: it builds a universal OSAScript
# binary and zips it with the .sdPlugin folder into build/release/.

BUILD_DIR := build/tests
CFLAGS := -fobjc-arc -fmodules -Wall -Wno-deprecated-declarations \
          -ISources -ISources/Common
FRAMEWORKS := -framework Foundation -framework AppKit -framework OSAKit

TEST_SOURCES := Tests/MyStreamDeckPluginTests.m \
                Sources/MyStreamDeckPlugin.m \
                Sources/Common/ESDUtilities.m

.PHONY: test build package clean

PLUGIN := com.gabrielperales.osascript
XCODE_DIR := build/xcode
STAGE_DIR := build/stage
RELEASE_DIR := build/release
PACKAGE := $(RELEASE_DIR)/$(PLUGIN).streamDeckPlugin

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

package: build
	rm -rf $(STAGE_DIR) $(PACKAGE)
	mkdir -p $(STAGE_DIR) $(RELEASE_DIR)
	cp -R Sources/$(PLUGIN).sdPlugin $(STAGE_DIR)/
	cp $(XCODE_DIR)/Build/Products/Release/OSAScript $(STAGE_DIR)/$(PLUGIN).sdPlugin/
	cd $(STAGE_DIR) && zip -r -X ../../$(PACKAGE) $(PLUGIN).sdPlugin -x '*.DS_Store'
	@echo "Built $(PACKAGE)"

clean:
	rm -rf build
