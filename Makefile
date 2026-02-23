SHELL := /bin/bash

# Project layout
APP_NAME          ?= Dispel
PROJECT_DIR       ?= ./Dispel
PROJECT           ?= $(PROJECT_DIR)/$(APP_NAME).xcodeproj
XCODEGEN_PROJECT  ?= $(PROJECT_DIR)
XCODEGEN_SPEC     ?= $(PROJECT_DIR)/project.yml
SCHEME            ?= $(APP_NAME)
CONFIGURATION     ?= Release
BUILD_DIR         ?= ./build
BUILD_DIR_STAMP   := $(BUILD_DIR)/.dir-stamp
DERIVED_DATA      := $(BUILD_DIR)/DerivedData
ARCHIVE           := $(BUILD_DIR)/$(SCHEME).xcarchive
EXPORT_OPTIONS    ?= ./ExportOptions.plist
APP_BUNDLE        := $(BUILD_DIR)/$(APP_NAME).app

# Scripts
SIGNING_RESOLVER_SCRIPT := ./scripts/resolve-signing.sh
XCODEGEN_CHECK_SCRIPT   := ./scripts/xcodegen-check.sh

.PHONY: all release xcodegen xcodegen-check lint test verify build devsigned archive export package clean

all: build
release: build

$(BUILD_DIR_STAMP):
	@mkdir -p $(BUILD_DIR)
	@touch $(BUILD_DIR_STAMP)

xcodegen:
	@if [[ ! -f "$(XCODEGEN_SPEC)" ]]; then \
	  echo "--> No xcodegen spec at $(XCODEGEN_SPEC); skipping project generation"; \
	elif ! command -v xcodegen >/dev/null 2>&1; then \
	  echo "error: xcodegen not found in PATH" >&2; \
	  exit 1; \
	else \
	  echo "--> Generating Xcode project from $(XCODEGEN_SPEC)"; \
	  xcodegen generate --spec "$(XCODEGEN_SPEC)" --project "$(XCODEGEN_PROJECT)"; \
	  echo "✅ Xcode project generated at $(PROJECT)"; \
	fi

xcodegen-check:
	@if [[ ! -f "$(XCODEGEN_SPEC)" ]]; then \
	  echo "--> No xcodegen spec at $(XCODEGEN_SPEC); skipping xcodegen-check"; \
	elif [[ -x "$(XCODEGEN_CHECK_SCRIPT)" ]]; then \
	  bash "$(XCODEGEN_CHECK_SCRIPT)"; \
	else \
	  echo "--> Missing $(XCODEGEN_CHECK_SCRIPT); skipping xcodegen-check"; \
	fi

lint:
	@if ! command -v swiftlint >/dev/null 2>&1; then \
	  echo "error: swiftlint not found in PATH. Install SwiftLint to run lint checks."; \
	  exit 1; \
	fi
	@if [[ -f .swiftlint.yml ]]; then \
	  swiftlint lint --config .swiftlint.yml; \
	else \
	  swiftlint lint; \
	fi

test:
	@xcodebuild test \
	  -project "$(PROJECT)" \
	  -scheme "$(SCHEME)" \
	  -destination 'platform=macOS' \
	  CODE_SIGNING_ALLOWED=NO \
	  -only-testing:DispelTests

verify: xcodegen-check lint build test

# -------- Lane A: unsigned local build (default) --------
build: xcodegen $(BUILD_DIR_STAMP)
	@echo "--> Building unsigned $(APP_NAME) (scheme=$(SCHEME), configuration=$(CONFIGURATION))"
	xcodebuild \
	  -project "$(PROJECT)" \
	  -scheme "$(SCHEME)" \
	  -configuration "$(CONFIGURATION)" \
	  -destination 'platform=macOS' \
	  -derivedDataPath "$(DERIVED_DATA)" \
	  CODE_SIGNING_ALLOWED=NO \
	  build
	@rm -rf "$(APP_BUNDLE)"
	@cp -R "$(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/$(APP_NAME).app" "$(APP_BUNDLE)"
	@echo "✅ Unsigned app available at $(APP_BUNDLE)"

# -------- Lane B: automatically signed developer build --------
devsigned: xcodegen $(BUILD_DIR_STAMP)
	@echo "--> Building with Automatic signing"
	@eval "$$($(SIGNING_RESOLVER_SCRIPT))"; \
	identity="$$SIGNING_IDENTITY"; \
	team_id="$$DEVELOPMENT_TEAM"; \
	echo "--> Using team $$team_id"; \
	xcodebuild \
	  -project "$(PROJECT)" \
	  -scheme "$(SCHEME)" \
	  -configuration "$(CONFIGURATION)" \
	  -destination 'platform=macOS' \
	  -derivedDataPath "$(DERIVED_DATA)" \
	  CODE_SIGN_STYLE=Automatic \
	  DEVELOPMENT_TEAM="$$team_id" \
	  CODE_SIGNING_ALLOWED=YES \
	  build
	@rm -rf "$(APP_BUNDLE)"
	@cp -R "$(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/$(APP_NAME).app" "$(APP_BUNDLE)"
	@codesign --verify --verbose "$(APP_BUNDLE)" || true
	@echo "✅ Dev-signed app available at $(APP_BUNDLE)"

# -------- Lane C: distribution archive (maintainers) --------
archive: xcodegen $(BUILD_DIR_STAMP)
	@echo "--> Archiving $(APP_NAME) for distribution"
	@eval "$$(REQUIRE_NONINTERACTIVE=1 ALLOW_INTERACTIVE=0 $(SIGNING_RESOLVER_SCRIPT))"; \
	identity="$$SIGNING_IDENTITY"; \
	team_id="$$DEVELOPMENT_TEAM"; \
	xcodebuild \
	  -project "$(PROJECT)" \
	  -scheme "$(SCHEME)" \
	  -configuration "$(CONFIGURATION)" \
	  -destination 'generic/platform=macOS' \
	  -archivePath "$(ARCHIVE)" \
	  CODE_SIGN_STYLE=Manual \
	  CODE_SIGN_IDENTITY="$$identity" \
	  DEVELOPMENT_TEAM="$$team_id" \
	  archive

export: archive
	@echo "--> Exporting archive using $(EXPORT_OPTIONS)"
	@if xcodebuild -exportArchive \
	  -archivePath "$(ARCHIVE)" \
	  -exportOptionsPlist "$(EXPORT_OPTIONS)" \
	  -exportPath "$(BUILD_DIR)"; then \
	  echo "✅ exportArchive succeeded"; \
	else \
	  echo "⚠️ exportArchive failed; archive remains at $(ARCHIVE)"; \
	fi

package: build
	@echo "--> Creating zip from $(APP_BUNDLE)"
	@ditto -c -k --sequesterRsrc --keepParent "$(APP_BUNDLE)" "$(BUILD_DIR)/$(APP_NAME).zip"
	@echo "✅ Package available at $(BUILD_DIR)/$(APP_NAME).zip"

clean:
	@echo "--> Cleaning build artifacts..."
	@xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" clean || true
	@rm -rf "$(BUILD_DIR)"
	@echo "✅ Clean"
