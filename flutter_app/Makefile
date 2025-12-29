.PHONY: all clean deps build-android build-ios build-web run-android run-ios run-web test lint help

all: deps

help:
	@echo "Wink Flutter App Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make deps          Install dependencies"
	@echo "  make run-android   Run on Android device/emulator"
	@echo "  make run-ios       Run on iOS device/simulator"
	@echo "  make run-web       Run in web browser"
	@echo "  make build-android Build Android APK"
	@echo "  make build-ios     Build iOS app"
	@echo "  make build-web     Build web app"
	@echo "  make test          Run tests"
	@echo "  make lint          Run linter"
	@echo "  make clean         Clean build artifacts"
	@echo "  make gen           Run code generation"

deps:
	@echo "Installing dependencies..."
	flutter pub get

run-android:
	@echo "Running on Android..."
	flutter run -d android

run-ios:
	@echo "Running on iOS..."
	flutter run -d ios

run-web:
	@echo "Running on web..."
	flutter run -d chrome

build-android:
	@echo "Building Android APK..."
	flutter build apk --release

build-android-bundle:
	@echo "Building Android App Bundle..."
	flutter build appbundle --release

build-ios:
	@echo "Building iOS app..."
	flutter build ios --release --no-codesign

build-web:
	@echo "Building web app..."
	flutter build web --release

test:
	@echo "Running tests..."
	flutter test

lint:
	@echo "Running linter..."
	flutter analyze

gen:
	@echo "Running code generation..."
	flutter pub run build_runner build --delete-conflicting-outputs

gen-watch:
	@echo "Running code generation (watch mode)..."
	flutter pub run build_runner watch --delete-conflicting-outputs

clean:
	@echo "Cleaning..."
	flutter clean
	rm -rf build/
	rm -rf .dart_tool/

doctor:
	@echo "Checking Flutter installation..."
	flutter doctor -v

upgrade:
	@echo "Upgrading dependencies..."
	flutter pub upgrade
