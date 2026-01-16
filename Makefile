# Copyright 2026 Stefan Prodan.
# SPDX-License-Identifier: Apache-2.0

# Makefile that builds, tests, packages, and launches KSwitch for local development

.DEFAULT_GOAL := run

APP_NAME := KSwitch
APP_BUNDLE := $(APP_NAME).app
BUNDLE_ID := com.stefanprodan.kswitch
MACOS_MIN_VERSION := 15.0
APP_VERSION := 0.0.1-devel
BUILD_NUMBER := 1
SPARKLE_PUBLIC_KEY := MfrlXRkKGSeOdKGJiIgMSmOX9oZQJHd1DSiNhM2WpT4=
SPARKLE_FEED_URL := https://raw.githubusercontent.com/stefanprodan/kswitch/main/appcast.xml

## run: Build, package, and launch in production mode
.PHONY: run
run:
	@APP_NAME=$(APP_NAME) BUNDLE_ID=$(BUNDLE_ID) MACOS_MIN_VERSION=$(MACOS_MIN_VERSION) \
		APP_VERSION=$(APP_VERSION) BUILD_NUMBER=$(BUILD_NUMBER) \
		SPARKLE_PUBLIC_KEY=$(SPARKLE_PUBLIC_KEY) SPARKLE_FEED_URL=$(SPARKLE_FEED_URL) ./Scripts/run.sh

## dev: Build and launch in debug mode
.PHONY: dev
dev:
	@APP_NAME=$(APP_NAME) BUNDLE_ID=$(BUNDLE_ID) MACOS_MIN_VERSION=$(MACOS_MIN_VERSION) \
		APP_VERSION=$(APP_VERSION) BUILD_NUMBER=$(BUILD_NUMBER) \
		BUILD_CONFIG=debug ./Scripts/run.sh

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

## reset: Delete app local storage
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

## print-clusters: Print clusters.json from app storage
.PHONY: print-clusters
print-clusters:
	@cat ~/Library/Application\ Support/$(APP_NAME)/clusters.json | jq .

## print-settings: Print settings.json from app storage
.PHONY: print-settings
print-settings:
	@cat ~/Library/Application\ Support/$(APP_NAME)/settings.json | jq .

## package: Build and package app bundle
.PHONY: package
package:
	@APP_NAME=$(APP_NAME) BUNDLE_ID=$(BUNDLE_ID) MACOS_MIN_VERSION=$(MACOS_MIN_VERSION) \
		APP_VERSION=$(APP_VERSION) BUILD_NUMBER=$(BUILD_NUMBER) \
		SPARKLE_PUBLIC_KEY=$(SPARKLE_PUBLIC_KEY) SPARKLE_FEED_URL=$(SPARKLE_FEED_URL) ./Scripts/package.sh

## sign: Sign app bundle (requires APPLE_SIGNING_IDENTITY env var)
.PHONY: sign
sign:
	@APP_NAME=$(APP_NAME) ./Scripts/sign.sh

## notarize: Notarize app bundle (requires APP_STORE_CONNECT_* env vars)
.PHONY: notarize
notarize:
	@APP_NAME=$(APP_NAME) APP_VERSION=$(APP_VERSION) ./Scripts/notarize.sh

## release: Package, sign, and notarize the app
.PHONY: release
release: package sign notarize

## appcast: Generate appcast.xml from latest GitHub release (requires SPARKLE_PRIVATE_KEY env var)
.PHONY: appcast
appcast:
	@APP_NAME=$(APP_NAME) ./Scripts/appcast.sh

## help: Show this help message
.PHONY: help
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@sed -n 's/^## //p' $(MAKEFILE_LIST) | column -t -s ':'
