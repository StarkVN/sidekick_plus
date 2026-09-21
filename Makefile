.PHONY: help default run run-release build build-debug open dmg get clean analyze test

# Flutter binary configuration (auto-detect fvm if installed and .fvmrc exists, otherwise flutter)
FLUTTER ?= $(shell if command -v fvm >/dev/null 2>&1 && [ -f .fvmrc ]; then echo "fvm flutter"; else echo "flutter"; fi)

APP_NAME = Sidekick
BUILD_DIR_MACOS = build/macos/Build/Products/Release
APP_PATH = $(BUILD_DIR_MACOS)/$(APP_NAME).app

# Default target
default: help

## help: Hien thi danh sach cac lenh ho tro
help:
	@echo "============================================================"
	@echo " Sidekick Plus - Makefile commands for macOS"
	@echo "============================================================"
	@echo "Su dung: make <target>"
	@echo ""
	@echo "Targets chinh:"
	@echo "  make run             Chay ung dung tren macOS (Debug mode)"
	@echo "  make run-release     Chay ung dung tren macOS (Release mode)"
	@echo "  make build           Build app macOS (Release bundle)"
	@echo "  make build-debug     Build app macOS (Debug bundle)"
	@echo "  make open            Mo app macOS da build trong $(BUILD_DIR_MACOS)"
	@echo "  make dmg             Dong goi file cai dat .dmg cho macOS"
	@echo ""
	@echo "Targets tien ich:"
	@echo "  make get             Cai dat dependencies (flutter pub get)"
	@echo "  make clean           Don dep thu muc build va cache (flutter clean)"
	@echo "  make analyze         Kiem tra loi ma nguon (flutter analyze)"
	@echo "  make test            Chay unit test (flutter test)"
	@echo "============================================================"

## run: Chay app tren macOS o che do Debug
run:
	@echo "🚀 Dang chay $(APP_NAME) tren macOS (Debug mode)..."
	$(FLUTTER) run -d macos

## run-release: Chay app tren macOS o che do Release
run-release:
	@echo "🚀 Dang chay $(APP_NAME) tren macOS (Release mode)..."
	$(FLUTTER) run -d macos --release

## build: Build ung dung macOS Release bundle (.app)
build:
	@echo "🔨 Dang build $(APP_NAME) cho macOS (Release mode)..."
	$(FLUTTER) build macos --release
	@echo "✅ Build hoan tat tai: $(APP_PATH)"

## build-debug: Build ung dung macOS Debug bundle
build-debug:
	@echo "🔨 Dang build $(APP_NAME) cho macOS (Debug mode)..."
	$(FLUTTER) build macos --debug
	@echo "✅ Build hoan tat tai: build/macos/Build/Products/Debug/$(APP_NAME).app"

## open: Mo ung dung macOS sau khi da build Release
open:
	@if [ -d "$(APP_PATH)" ]; then \
		echo "📂 Dang mo $(APP_PATH)..."; \
		open "$(APP_PATH)"; \
	else \
		echo "❌ Chua tim thay $(APP_PATH). Hay chay 'make build' truoc."; \
		exit 1; \
	fi

## dmg: Dong goi macOS DMG installer
dmg: build
	@echo "📦 Dang tao file DMG..."
	@chmod +x ./scripts/create_mac_dmg.sh
	./scripts/create_mac_dmg.sh
	@echo "✅ File DMG da tao thanh cong."

## get: Cap nhat pub dependencies
get:
	$(FLUTTER) pub get

## clean: Xoa cache va thu muc build
clean:
	$(FLUTTER) clean

## analyze: Phan tich static analysis
analyze:
	$(FLUTTER) analyze

## test: Chay tests
test:
	$(FLUTTER) test
