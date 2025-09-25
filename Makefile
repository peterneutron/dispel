SHELL := /bin/bash

# Config
APP_NAME ?= Dispel
PROJECT ?= Dispel/Dispel.xcodeproj
SCHEME ?= Release
CONFIGURATION ?= Release
BUILD_DIR ?= build
ARCHIVE := $(BUILD_DIR)/$(SCHEME).xcarchive
EXPORT_OPTIONS ?= ExportOptions.plist
EXPORT_PATH ?= $(BUILD_DIR)
APP_BUNDLE := $(EXPORT_PATH)/$(APP_NAME).app
SIGNING_IDENTITY_SCRIPT := scripts/select_signing_identity.sh

.PHONY: all clean archive export open

all: build

build: archive export ## Archive and export $(APP_NAME).app into ./build

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

archive: $(BUILD_DIR)
	@identity="$$SIGNING_IDENTITY"; \
	if [[ -z "$$identity" ]]; then \
	  if [[ ! -x "$(SIGNING_IDENTITY_SCRIPT)" ]]; then \
	    echo "error: missing signing identity script at $(SIGNING_IDENTITY_SCRIPT)" >&2; \
	    exit 1; \
	  fi; \
	  identity="$$($(SIGNING_IDENTITY_SCRIPT))"; \
	fi; \
	echo "==> Archiving $(SCHEME) (configuration=$(CONFIGURATION)) [signing: $$identity]"; \
	xcodebuild \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-destination 'generic/platform=macOS' \
		-archivePath "$(ARCHIVE)" \
		CODE_SIGN_IDENTITY="$$identity" \
		archive

export: archive
	@echo "==> Exporting archive to $(EXPORT_PATH) using $(EXPORT_OPTIONS)"
	xcodebuild -exportArchive \
		-archivePath "$(ARCHIVE)" \
		-exportOptionsPlist "$(EXPORT_OPTIONS)" \
		-exportPath "$(EXPORT_PATH)"
	@echo "==> Normalizing exported .app location"
	@appPath="$(APP_BUNDLE)"; \
	srcCandidates=( \
	  "$(EXPORT_PATH)/Products/Applications/$(APP_NAME).app" \
	  "$(EXPORT_PATH)/Applications/$(APP_NAME).app" \
	  "$(EXPORT_PATH)/Products/Applications/$(SCHEME).app" \
	  "$(EXPORT_PATH)/Applications/$(SCHEME).app" \
	); \
	if [[ ! -d "$$appPath" ]]; then \
	  for candidate in "$${srcCandidates[@]}"; do \
	    if [[ -d "$${candidate}" ]]; then \
	      cp -R "$${candidate}" "$$appPath"; \
	      break; \
	    fi; \
	  done; \
	fi; \
	if [[ -d "$$appPath" ]]; then \
	  echo "Exported app: $$appPath"; \
	else \
	  echo "Warning: Could not locate exported .app in $(EXPORT_PATH)."; \
	fi

open:
	@open "$(APP_BUNDLE)" || true

clean:
	@echo "==> Cleaning build artifacts"
	rm -rf "$(BUILD_DIR)"
