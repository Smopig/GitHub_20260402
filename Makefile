# RightClickHero — one-command build/install
#
# Common usage:
#   make install                       # build + copy .app to /Applications
#   make dmg                           # build + produce build/RightClickHero.dmg
#   make install TEAM_ID=ABCDE12345    # force a specific Apple Developer team
#   make install BUNDLE_PREFIX=com.foo # override bundle prefix
#
# Requirements (auto-checked):
#   - macOS with Xcode command-line tools
#   - Homebrew + XcodeGen  (the `project` target installs it for you)

SHELL := /bin/bash

PROJECT_NAME   := RightClickHero
SCHEME         := RightClickHero
CONFIG         := Release
BUILD_DIR      := build
DERIVED_DIR    := $(BUILD_DIR)/DerivedData
ARCHIVE_PATH   := $(BUILD_DIR)/$(PROJECT_NAME).xcarchive
EXPORT_DIR     := $(BUILD_DIR)/export
APP_PATH       := $(EXPORT_DIR)/$(PROJECT_NAME).app
DMG_PATH       := $(BUILD_DIR)/$(PROJECT_NAME).dmg
INSTALL_DIR    := /Applications

# Overridable on the command line (also defined in Config.xcconfig as defaults)
BUNDLE_PREFIX  ?=
TEAM_ID        ?=

# Auto-detect a Development Team ID from the user's keychain if TEAM_ID wasn't
# given. This finds e.g. an "Apple Development: foo@bar.com (ABCDE12345)" cert
# created when the user signed into Xcode with any Apple ID (free or paid).
ifeq ($(strip $(TEAM_ID)),)
  TEAM_ID := $(shell security find-identity -v -p codesigning 2>/dev/null \
              | grep -E "Apple Development|Mac Developer" \
              | head -n1 \
              | sed -E 's/.*\(([A-Z0-9]{10})\).*/\1/' \
              | grep -E '^[A-Z0-9]{10}$$')
endif

XCODEBUILD_ARGS := -project $(PROJECT_NAME).xcodeproj \
                   -scheme $(SCHEME) \
                   -configuration $(CONFIG) \
                   -derivedDataPath $(DERIVED_DIR) \
                   -allowProvisioningUpdates \
                   COMPILER_INDEX_STORE_ENABLE=NO
ifneq ($(strip $(BUNDLE_PREFIX)),)
  XCODEBUILD_ARGS += BUNDLE_PREFIX=$(BUNDLE_PREFIX)
endif
ifneq ($(strip $(TEAM_ID)),)
  XCODEBUILD_ARGS += DEVELOPMENT_TEAM=$(TEAM_ID)
endif

.PHONY: help all check-tools check-team project build archive export dmg install uninstall enable-extension clean reset

help:
	@echo "RightClickHero build targets:"
	@echo "  make project          Generate $(PROJECT_NAME).xcodeproj from project.yml (needs XcodeGen)"
	@echo "  make build            Build the app (Debug, into DerivedData)"
	@echo "  make archive          Archive the app (Release)"
	@echo "  make export           Export the .app from the archive"
	@echo "  make dmg              Produce build/$(PROJECT_NAME).dmg"
	@echo "  make install          Build + install to /Applications + enable Finder extension"
	@echo "  make uninstall        Remove from /Applications and disable extension"
	@echo "  make clean            Remove build artifacts"
	@echo ""
	@echo "Variables:"
	@echo "  BUNDLE_PREFIX=com.smopig    Reverse-domain prefix (default in Config.xcconfig)"
	@echo "  TEAM_ID=ABCDE12345          Apple Developer Team ID (auto-detected if omitted)"

# ---------------------------------------------------------------------------
# Tool & project bootstrap
# ---------------------------------------------------------------------------

check-tools:
	@command -v xcodebuild >/dev/null 2>&1 || { \
	  echo "error: xcodebuild not found. Install Xcode from the App Store first."; exit 1; }
	@# Detect "Command Line Tools only" — xcodebuild won't actually work in that case.
	@DEVDIR=$$(xcode-select -p 2>/dev/null); \
	if [ "$$DEVDIR" = "/Library/Developer/CommandLineTools" ] || \
	   ! xcodebuild -version >/dev/null 2>&1; then \
	  echo ""; \
	  echo "error: 'xcodebuild' requires the full Xcode.app, not just Command Line Tools."; \
	  echo "       Current developer directory: $$DEVDIR"; \
	  echo ""; \
	  echo "Fix:"; \
	  echo "  1. Install Xcode from the App Store:"; \
	  echo "     open 'macappstore://itunes.apple.com/app/id497799835'"; \
	  echo "  2. Point xcode-select at it:"; \
	  echo "     sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"; \
	  echo "  3. Accept the license once:"; \
	  echo "     sudo xcodebuild -license accept"; \
	  echo "  4. Re-run: make install"; \
	  echo ""; \
	  exit 1; \
	fi
	@# Verify xcodebuild can actually run (catches missing first-launch components).
	@if ! xcodebuild -showsdks >/dev/null 2>&1; then \
	  echo ""; \
	  echo "error: xcodebuild can't load required system components (likely a fresh Xcode install)."; \
	  echo ""; \
	  echo "Fix (one-time):"; \
	  echo "  sudo xcodebuild -runFirstLaunch"; \
	  echo ""; \
	  echo "Then re-run: make install"; \
	  echo ""; \
	  exit 1; \
	fi
	@command -v xcodegen >/dev/null 2>&1 || { \
	  echo "XcodeGen not found — installing via Homebrew..."; \
	  command -v brew >/dev/null 2>&1 || { echo "Install Homebrew first: https://brew.sh"; exit 1; }; \
	  brew install xcodegen; }

project: check-tools
	@echo "Generating $(PROJECT_NAME).xcodeproj from project.yml…"
	@xcodegen generate --quiet
	@echo "Done. Open $(PROJECT_NAME).xcodeproj in Xcode if you like, or run 'make install'."

# ---------------------------------------------------------------------------
# Build / archive / export
# ---------------------------------------------------------------------------

build: project
	xcodebuild $(XCODEBUILD_ARGS) -configuration Debug build

check-team:
	@if [ -z "$(strip $(TEAM_ID))" ]; then \
	  echo ""; \
	  echo "error: no Apple Development Team ID found in your keychain."; \
	  echo ""; \
	  echo "Code signing is required for Finder Sync Extensions + Login Item Helpers."; \
	  echo "macOS will refuse to load them otherwise — no tool can bypass this."; \
	  echo ""; \
	  echo "One-time setup (free Apple ID is fine, no paid Developer Program needed):"; \
	  echo "  1. Open Xcode"; \
	  echo "  2. Xcode → Settings → Accounts → '+' → Add Apple ID, sign in"; \
	  echo "  3. Close Xcode, then re-run: make install"; \
	  echo ""; \
	  echo "Or supply a Team ID explicitly:"; \
	  echo "  make install TEAM_ID=ABCDE12345"; \
	  echo ""; \
	  echo "Available signing identities on this machine:"; \
	  security find-identity -v -p codesigning 2>/dev/null | sed 's/^/  /' || true; \
	  echo ""; \
	  exit 1; \
	fi
	@echo "Using Apple Development Team: $(TEAM_ID)"

archive: project check-team
	@mkdir -p $(BUILD_DIR)
	xcodebuild $(XCODEBUILD_ARGS) \
	  -archivePath $(ARCHIVE_PATH) \
	  archive

# ExportOptions for a "local development" build — no Developer ID required.
$(BUILD_DIR)/ExportOptions.plist:
	@mkdir -p $(BUILD_DIR)
	@printf '%s\n' \
	  '<?xml version="1.0" encoding="UTF-8"?>' \
	  '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
	  '<plist version="1.0"><dict>' \
	  '  <key>method</key><string>mac-application</string>' \
	  '  <key>signingStyle</key><string>automatic</string>' \
	  '  <key>destination</key><string>export</string>' \
	  '  <key>stripSwiftSymbols</key><true/>' \
	  '</dict></plist>' > $@

export: archive $(BUILD_DIR)/ExportOptions.plist
	@rm -rf $(EXPORT_DIR)
	xcodebuild -exportArchive \
	  -archivePath $(ARCHIVE_PATH) \
	  -exportPath $(EXPORT_DIR) \
	  -exportOptionsPlist $(BUILD_DIR)/ExportOptions.plist \
	  -allowProvisioningUpdates

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

install: export
	@echo "Installing $(APP_PATH) → $(INSTALL_DIR)…"
	@if [ -d "$(INSTALL_DIR)/$(PROJECT_NAME).app" ]; then \
	  rm -rf "$(INSTALL_DIR)/$(PROJECT_NAME).app"; \
	fi
	@cp -R "$(APP_PATH)" "$(INSTALL_DIR)/"
	@$(MAKE) enable-extension
	@echo ""
	@echo "✓ Installed to $(INSTALL_DIR)/$(PROJECT_NAME).app"
	@echo "  Launch it once so the Helper registers as a Login Item:"
	@echo "    open \"$(INSTALL_DIR)/$(PROJECT_NAME).app\""
	@echo ""
	@echo "  If the right-click menu doesn't appear, enable the extension in:"
	@echo "    System Settings → Privacy & Security → Extensions → Finder Extensions"

enable-extension:
	@FINDEREXT_ID=$$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" \
	  "$(APP_PATH)/Contents/PlugIns/RightClickHeroFinderExt.appex/Contents/Info.plist" 2>/dev/null); \
	if [ -n "$$FINDEREXT_ID" ]; then \
	  echo "Enabling Finder extension: $$FINDEREXT_ID"; \
	  pluginkit -e use -i "$$FINDEREXT_ID" 2>/dev/null || true; \
	fi

uninstall:
	@FINDEREXT_ID=$$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" \
	  "$(INSTALL_DIR)/$(PROJECT_NAME).app/Contents/PlugIns/RightClickHeroFinderExt.appex/Contents/Info.plist" 2>/dev/null); \
	if [ -n "$$FINDEREXT_ID" ]; then \
	  echo "Disabling Finder extension: $$FINDEREXT_ID"; \
	  pluginkit -e ignore -i "$$FINDEREXT_ID" 2>/dev/null || true; \
	fi
	@rm -rf "$(INSTALL_DIR)/$(PROJECT_NAME).app"
	@echo "Removed $(INSTALL_DIR)/$(PROJECT_NAME).app"

# ---------------------------------------------------------------------------
# DMG
# ---------------------------------------------------------------------------

dmg: export
	@echo "Building $(DMG_PATH)…"
	@rm -f $(DMG_PATH)
	@STAGING=$$(mktemp -d) && \
	  cp -R "$(APP_PATH)" "$$STAGING/" && \
	  ln -s /Applications "$$STAGING/Applications" && \
	  hdiutil create -volname "$(PROJECT_NAME)" \
	    -srcfolder "$$STAGING" \
	    -ov -format UDZO \
	    "$(DMG_PATH)" && \
	  rm -rf "$$STAGING"
	@echo "✓ $(DMG_PATH)"

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

clean:
	rm -rf $(BUILD_DIR) $(DERIVED_DIR)

reset: clean
	rm -rf $(PROJECT_NAME).xcodeproj
