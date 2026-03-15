VERSION = $(shell cat VERSION)
BUILD_DIR = .build/release
APP_BUNDLE = $(BUILD_DIR)/MacNAS.app
HELPER_INSTALL = /usr/local/bin/com.macnas.helper
PLIST_INSTALL = /Library/LaunchDaemons/com.macnas.helper.plist

.PHONY: all build app helper uninstall-helper release clean

all: build app

build: generate-build-info
	swift build -c release

generate-build-info:
	@echo 'enum BuildInfo { static let version = "$(VERSION)" }' > MacNAS/BuildInfo.swift

app: build
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS" "$(APP_BUNDLE)/Contents/Resources"
	cp $(BUILD_DIR)/MacNAS "$(APP_BUNDLE)/Contents/MacOS/MacNAS"
	cp MacNAS/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" "$(APP_BUNDLE)/Contents/Info.plist"
	cp MacNAS/Resources/AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns"
	cp "$(BUILD_DIR)/com.macnas.helper" "$(APP_BUNDLE)/Contents/Resources/com.macnas.helper"
	cp com.macnas.helper/com.macnas.helper.plist "$(APP_BUNDLE)/Contents/Resources/com.macnas.helper.plist"
	cp helper-entitlements.plist "$(APP_BUNDLE)/Contents/Resources/helper-entitlements.plist"
	@if [ -d "$(BUILD_DIR)/MacNAS_MacNAS.bundle" ]; then \
		cp -R "$(BUILD_DIR)/MacNAS_MacNAS.bundle" "$(APP_BUNDLE)/Contents/Resources/"; \
	fi

helper: build

uninstall-helper:
	sudo launchctl bootout system/com.macnas.helper 2>/dev/null || true
	sudo rm -f "$(HELPER_INSTALL)" "$(PLIST_INSTALL)"

release: app
	cd $(BUILD_DIR) && zip -r MacNAS-$(VERSION).zip MacNAS.app
	$(eval SHA256 := $(shell shasum -a 256 $(BUILD_DIR)/MacNAS-$(VERSION).zip | cut -d ' ' -f 1))
	sed -i '' 's/version ".*"/version "$(VERSION)"/' Casks/macnas.rb
	sed -i '' 's/sha256 .*/sha256 "$(SHA256)"/' Casks/macnas.rb
	git tag -f v$(VERSION)
	@echo "Release v$(VERSION) tagged. SHA256: $(SHA256)"
	@echo "Run 'git push --tags' and upload $(BUILD_DIR)/MacNAS-$(VERSION).zip to GitHub Releases."

run: app
	open "$(APP_BUNDLE)"

clean:
	swift package clean
	rm -rf "$(APP_BUNDLE)"
