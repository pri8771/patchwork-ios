# Patchwork developer entry points.
SIM ?= iPhone 17 Pro
SCHEME = Patchwork

.PHONY: bootstrap test build-app sample icon clean

## Generate the Xcode project from project.yml (requires `brew install xcodegen`).
bootstrap:
	xcodegen generate

## Run the pure Swift package tests (core/geo/data) — no Xcode/simulator needed.
test:
	swift test

## Run the release-mode lookup scale benchmark (the locked <10ms p95 gate).
benchmark:
	swift test -c release --filter ResolverScaleBenchmarkTests

## Build the iOS app for the simulator.
build-app: bootstrap
	xcodebuild -project Patchwork.xcodeproj -scheme $(SCHEME) \
		-destination 'platform=iOS Simulator,name=$(SIM)' \
		-configuration Debug build CODE_SIGNING_ALLOWED=NO

## Regenerate the bundled sample geodata SQLite.
sample:
	python3 Tools/geo_build/build_sample.py

## Regenerate the app icon.
icon:
	swift Tools/make_icon.swift Patchwork/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png

clean:
	rm -rf .build build Patchwork.xcodeproj
