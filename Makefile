.PHONY: build test install install-login clean

SHELL := /bin/bash

PROJECT := SpaceLabeler.xcodeproj
SCHEME := SpaceLabeler
LABEL := com.jeremywatt.SpaceLabeler
APP_NAME := SpaceLabeler.app
BUILD_DIR := build

build:
	xcodegen generate
	xcodebuild build \
	  -project $(PROJECT) -scheme $(SCHEME) \
	  -configuration Release -destination 'platform=macOS' \
	  -derivedDataPath $(BUILD_DIR)

test:
	xcodegen generate
	xcodebuild test \
	  -project $(PROJECT) -scheme $(SCHEME) \
	  -destination 'platform=macOS' \
	  -derivedDataPath $(BUILD_DIR)

install: build
	mkdir -p $(HOME)/Applications
	rm -rf $(HOME)/Applications/$(APP_NAME)
	cp -R $(BUILD_DIR)/Build/Products/Release/$(APP_NAME) $(HOME)/Applications/
	@if [ -f "$(HOME)/Library/LaunchAgents/$(LABEL).plist" ]; then \
	  echo "LaunchAgent detected — restarting managed instance"; \
	  launchctl kickstart -k "gui/$$(id -u)/$(LABEL)"; \
	else \
	  open $(HOME)/Applications/$(APP_NAME); \
	fi

install-login:
	./scripts/install-login-item.sh

clean:
	rm -rf $(PROJECT) $(BUILD_DIR)
