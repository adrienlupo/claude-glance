.PHONY: build bundle install clean run

BUILD_DIR = ClaudeGlance/.build
BINARY = $(BUILD_DIR)/release/ClaudeGlance
APP_BUNDLE = $(BUILD_DIR)/ClaudeGlance.app
INSTALL_DIR = $(HOME)/.claude-glance

build:
	cd ClaudeGlance && swift build -c release

bundle: build
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp ClaudeGlance/Resources/Info.plist $(APP_BUNDLE)/Contents/
	cp $(BINARY) $(APP_BUNDLE)/Contents/MacOS/
	cp ClaudeGlance/Resources/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/
	codesign --force --sign - $(APP_BUNDLE)

run: bundle
	mkdir -p $(INSTALL_DIR)/hooks
	cp hooks/hook.sh $(INSTALL_DIR)/hooks/
	chmod +x $(INSTALL_DIR)/hooks/hook.sh
	open $(APP_BUNDLE)

install: bundle
	mkdir -p $(INSTALL_DIR)/hooks
	cp -R $(APP_BUNDLE) /Applications/
	@echo "Installed ClaudeGlance.app to /Applications/"
	cp hooks/hook.sh $(INSTALL_DIR)/hooks/
	chmod +x $(INSTALL_DIR)/hooks/hook.sh
	bash hooks/install.sh
	@echo ""

clean:
	cd ClaudeGlance && swift package clean
	rm -rf $(BUILD_DIR)
