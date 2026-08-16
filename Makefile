.PHONY: help build run test clean copy-metallibs live2d-test

help:
	@echo "Available targets:"
	@echo "  make build          - Build the project (swift build)"
	@echo "  make run            - Copy metallibs and run the app (recommended)"
	@echo "  make run-debug      - Copy metallibs for debug and run"
	@echo "  make run-release    - Copy metallibs for release and run"
	@echo "  make test           - Run tests (swift test)"
	@echo "  make clean          - Clean build artifacts (swift package clean)"
	@echo "  make copy-metallibs - Copy Metal shader libraries (debug by default)"
	@echo "  make live2d-test    - Run Live2D-only visual verification (no API key needed)"

build:
	swift build

copy-metallibs:
	./Scripts/copy-metallibs.sh

run: copy-metallibs
	swift run

run-debug: copy-metallibs
	swift run

run-release:
	./Scripts/copy-metallibs.sh release
	swift run --configuration release

live2d-test: copy-metallibs
	swift run AriaApp -- --live2d-test

test:
	swift test

clean:
	swift package clean
