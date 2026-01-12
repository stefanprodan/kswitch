.PHONY: run build package clean test launch sign-notarize setup-signing help

# Default target
.DEFAULT_GOAL := help

# Load version info
-include version.env
export

APP_NAME ?= kswitch
APP_BUNDLE := $(APP_NAME).app

## run: Build, package, and launch the app (dev loop)
run:
	@./Scripts/compile_and_run.sh

## run-test: Build with tests, package, and launch
run-test:
	@./Scripts/compile_and_run.sh --test

## run-universal: Build universal binary, package, and launch
run-universal:
	@./Scripts/compile_and_run.sh --release-universal

## build: Build debug binary
build:
	@swift build

## build-release: Build release binary
build-release:
	@swift build -c release

## package: Build and package release .app bundle
package:
	@SIGNING_MODE=adhoc ./Scripts/package_app.sh release

## package-universal: Build and package universal .app bundle
package-universal:
	@SIGNING_MODE=adhoc ARCHES="arm64 x86_64" ./Scripts/package_app.sh release

## launch: Launch existing .app bundle
launch:
	@./Scripts/launch.sh

## test: Run tests
test:
	@swift test

## clean: Remove build artifacts and .app bundle
clean:
	@swift package clean
	@rm -rf $(APP_BUNDLE)
	@rm -rf .build

## setup-signing: Create self-signed dev certificate
setup-signing:
	@./Scripts/setup_dev_signing.sh

## sign-notarize: Build, sign, notarize, and create release zip
sign-notarize:
	@./Scripts/sign-and-notarize.sh

## logs: Show last 100 app logs
logs:
	@log show --predicate 'subsystem BEGINSWITH "com.stefanprodan.kswitch"' --style compact --debug | tail -n 100

## logs-stream: Stream app logs in real-time
logs-stream:
	@log stream --predicate 'subsystem BEGINSWITH "com.stefanprodan.kswitch"' --style compact --debug

## print-clusters: Print saved clusters.json
print-clusters:
	@cat ~/Library/Application\ Support/KSwitch/clusters.json | jq .

## print-settings: Print saved settings.json
print-settings:
	@cat ~/Library/Application\ Support/KSwitch/settings.json | jq .

## help: Show this help message
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@sed -n 's/^## //p' $(MAKEFILE_LIST) | column -t -s ':'
