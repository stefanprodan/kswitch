# KSwitch - Kubernetes context switcher for macOS
# This Makefile builds, packages, and launches the app for local development

.DEFAULT_GOAL := run

APP_NAME := KSwitch
APP_BUNDLE := $(APP_NAME).app
BUNDLE_ID := com.stefanprodan.kswitch
MACOS_MIN_VERSION := 15.0
MARKETING_VERSION := 0.0.1-devel
BUILD_NUMBER := 1

## run: Build, package, and launch the app
.PHONY: run
run:
	@APP_NAME=$(APP_NAME) BUNDLE_ID=$(BUNDLE_ID) MACOS_MIN_VERSION=$(MACOS_MIN_VERSION) \
		MARKETING_VERSION=$(MARKETING_VERSION) BUILD_NUMBER=$(BUILD_NUMBER) ./Scripts/run.sh

## build: Build debug binary
.PHONY: build
build:
	@swift build

## test: Run tests
.PHONY: test
test:
	@swift test

## clean: Remove build artifacts and .app bundle
.PHONY: clean
clean:
	@swift package clean
	@rm -rf $(APP_BUNDLE)
	@rm -rf .build

## reset: Delete app settings
.PHONY: reset
reset:
	@rm -rf ~/Library/Application\ Support/$(APP_NAME)

## logs: Show last 100 app logs
.PHONY: logs
logs:
	@log show --predicate 'subsystem BEGINSWITH "$(BUNDLE_ID)"' --style compact --debug | tail -n 100

## logs-stream: Stream app logs in real-time
.PHONY: logs-stream
logs-stream:
	@log stream --predicate 'subsystem BEGINSWITH "$(BUNDLE_ID)"' --style compact --debug

## print-clusters: Print clusters.json from app settings
.PHONY: print-clusters
print-clusters:
	@cat ~/Library/Application\ Support/$(APP_NAME)/clusters.json | jq .

## print-settings: Print settings.json from app settings
.PHONY: print-settings
print-settings:
	@cat ~/Library/Application\ Support/$(APP_NAME)/settings.json | jq .

## help: Show this help message
.PHONY: help
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@sed -n 's/^## //p' $(MAKEFILE_LIST) | column -t -s ':'
