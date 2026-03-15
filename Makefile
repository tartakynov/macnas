BUILD_DIR = .build/release
APP_BUNDLE = $(BUILD_DIR)/MacNAS.app
HELPER_INSTALL = /usr/local/bin/com.macnas.helper
PLIST_INSTALL = /Library/LaunchDaemons/com.macnas.helper.plist

.PHONY: all build app helper install-helper uninstall-helper clean

all: build app

build: generate-build-info
	swift build -c release

generate-build-info:
	@echo 'enum BuildInfo { static let gitSHA = "$(shell git rev-parse HEAD)" }' > MacNAS/BuildInfo.swift

app: build
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS" "$(APP_BUNDLE)/Contents/Resources"
	cp $(BUILD_DIR)/MacNAS "$(APP_BUNDLE)/Contents/MacOS/MacNAS"
	cp MacNAS/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	cp MacNAS/Resources/AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns"
	cp "$(BUILD_DIR)/com.macnas.helper" "$(APP_BUNDLE)/Contents/Resources/com.macnas.helper"
	cp com.macnas.helper/com.macnas.helper.plist "$(APP_BUNDLE)/Contents/Resources/com.macnas.helper.plist"
	cp helper-entitlements.plist "$(APP_BUNDLE)/Contents/Resources/helper-entitlements.plist"
	@if [ -d "$(BUILD_DIR)/MacNAS_MacNAS.bundle" ]; then \
		cp -R "$(BUILD_DIR)/MacNAS_MacNAS.bundle" "$(APP_BUNDLE)/Contents/Resources/"; \
	fi

helper: build

install-helper: build
	sudo cp "$(BUILD_DIR)/com.macnas.helper" "$(HELPER_INSTALL)"
	sudo codesign --force --sign - --entitlements helper-entitlements.plist "$(HELPER_INSTALL)"
	sudo cp com.macnas.helper/com.macnas.helper.plist "$(PLIST_INSTALL)"
	sudo launchctl bootout system/com.macnas.helper 2>/dev/null || true
	sudo launchctl bootstrap system "$(PLIST_INSTALL)"

uninstall-helper:
	sudo launchctl bootout system/com.macnas.helper 2>/dev/null || true
	sudo rm -f "$(HELPER_INSTALL)" "$(PLIST_INSTALL)"

run: app
	open "$(APP_BUNDLE)"

clean:
	swift package clean
	rm -rf "$(APP_BUNDLE)"
