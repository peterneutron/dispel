SHELL := /bin/bash

# Config
PROJECT := Dispel/Dispel.xcodeproj
SCHEME := Release
CONFIGURATION := Release
BUILD_DIR := build
ARCHIVE := $(BUILD_DIR)/$(SCHEME).xcarchive
EXPORT_OPTIONS := ExportOptions.plist
EXPORT_PATH := $(BUILD_DIR)

.PHONY: all clean archive export open

all: build

build: archive export ## Archive and export the .app into ./build

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

archive: $(BUILD_DIR)
	@echo "==> Archiving $(SCHEME) (configuration=$(CONFIGURATION))"
	xcodebuild \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-destination 'generic/platform=macOS' \
		-archivePath "$(ARCHIVE)" \
		archive

export: archive
	@echo "==> Exporting archive to $(EXPORT_PATH) using $(EXPORT_OPTIONS)"
	xcodebuild -exportArchive \
		-archivePath "$(ARCHIVE)" \
		-exportOptionsPlist "$(EXPORT_OPTIONS)" \
		-exportPath "$(EXPORT_PATH)"
	@echo "==> Normalizing exported .app location"
	@appPath="$(EXPORT_PATH)/$(SCHEME).app"; \
	if [[ ! -d "$$appPath" ]]; then \
	  if [[ -d "$(EXPORT_PATH)/Products/Applications/$(SCHEME).app" ]]; then \
	    cp -R "$(EXPORT_PATH)/Products/Applications/$(SCHEME).app" "$(EXPORT_PATH)/$(SCHEME).app"; \
	  elif [[ -d "$(EXPORT_PATH)/Applications/$(SCHEME).app" ]]; then \
	    cp -R "$(EXPORT_PATH)/Applications/$(SCHEME).app" "$(EXPORT_PATH)/$(SCHEME).app"; \
	  fi; \
	fi; \
	if [[ -d "$(EXPORT_PATH)/$(SCHEME).app" ]]; then \
	  echo "Exported app: $(EXPORT_PATH)/$(SCHEME).app"; \
	else \
	  echo "Warning: Could not locate exported .app in $(EXPORT_PATH)."; \
	fi

open:
	@open "$(BUILD_DIR)/$(SCHEME).app" || true

clean:
	@echo "==> Cleaning build artifacts"
	rm -rf "$(BUILD_DIR)"
