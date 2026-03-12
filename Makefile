APP_NAME    = MediaMover
BUNDLE_NAME = MediaMover
APP_BUNDLE  = $(BUNDLE_NAME).app
DMG_NAME    = $(BUNDLE_NAME).dmg
BUILD_DIR   = .build/release

.PHONY: all app dmg clean icon-help

all: app

## Build release binary
build:
	swift build -c release

## Create the .app bundle
app: build
	@echo "→ Creating $(APP_BUNDLE)..."
	@rm -rf "$(APP_BUNDLE)"
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp "$(BUILD_DIR)/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/"
	@cp Info.plist "$(APP_BUNDLE)/Contents/"
	@# Copy icon if it exists
	@if [ -f AppIcon.icns ]; then \
		cp AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/"; \
		echo "  ✓ Icon included"; \
	else \
		echo "  ⚠ No AppIcon.icns found (run 'make icon-help' to learn how to add one)"; \
	fi
	@# Ad-hoc code signing (allows running locally without Gatekeeper block)
	@codesign --deep --force --sign - "$(APP_BUNDLE)" 2>/dev/null && \
		echo "  ✓ Ad-hoc signed" || echo "  ⚠ Code signing skipped"
	@echo "✓ $(APP_BUNDLE) created"

## Create DMG for distribution
dmg: app
	@echo "→ Creating $(DMG_NAME)..."
	@rm -f "$(DMG_NAME)"
	@# Create a temp staging folder with app + Applications symlink
	@rm -rf /tmp/photomove_dmg_staging
	@mkdir -p /tmp/photomove_dmg_staging
	@cp -r "$(APP_BUNDLE)" /tmp/photomove_dmg_staging/
	@ln -s /Applications /tmp/photomove_dmg_staging/Applications
	@hdiutil create \
		-volname "$(BUNDLE_NAME)" \
		-srcfolder /tmp/photomove_dmg_staging \
		-ov \
		-format UDZO \
		-imagekey zlib-level=9 \
		"$(DMG_NAME)"
	@rm -rf /tmp/photomove_dmg_staging
	@echo "✓ $(DMG_NAME) created"

## Open the app directly
run: app
	open "$(APP_BUNDLE)"

## Remove build artifacts
clean:
	@rm -rf "$(APP_BUNDLE)" "$(DMG_NAME)" .build
	@echo "✓ Cleaned"

## Instructions for adding an app icon
icon-help:
	@echo ""
	@echo "To add a custom icon:"
	@echo ""
	@echo "1. Create a 1024x1024 PNG named 'icon.png' in this folder"
	@echo ""
	@echo "2. Run this script to convert it to .icns:"
	@echo "   mkdir -p AppIcon.iconset"
	@echo "   sips -z 16 16     icon.png --out AppIcon.iconset/icon_16x16.png"
	@echo "   sips -z 32 32     icon.png --out AppIcon.iconset/icon_16x16@2x.png"
	@echo "   sips -z 32 32     icon.png --out AppIcon.iconset/icon_32x32.png"
	@echo "   sips -z 64 64     icon.png --out AppIcon.iconset/icon_32x32@2x.png"
	@echo "   sips -z 128 128   icon.png --out AppIcon.iconset/icon_128x128.png"
	@echo "   sips -z 256 256   icon.png --out AppIcon.iconset/icon_128x128@2x.png"
	@echo "   sips -z 256 256   icon.png --out AppIcon.iconset/icon_256x256.png"
	@echo "   sips -z 512 512   icon.png --out AppIcon.iconset/icon_256x256@2x.png"
	@echo "   sips -z 512 512   icon.png --out AppIcon.iconset/icon_512x512.png"
	@echo "   cp icon.png            AppIcon.iconset/icon_512x512@2x.png"
	@echo "   iconutil -c icns AppIcon.iconset"
	@echo "   rm -rf AppIcon.iconset"
	@echo ""
	@echo "3. Run 'make app' or 'make dmg' again"
