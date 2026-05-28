SHELL := /bin/bash

SKIP_MESSAGE := Skipping: Flutter app skeleton has not landed yet (missing pubspec.yaml).
RUNTIME_DART_DEFINE_FLAGS := --dart-define=SLOCK_API_BASE_URL=$(SLOCK_API_BASE_URL) --dart-define=SLOCK_REALTIME_URL=$(SLOCK_REALTIME_URL)
RUNTIME_BUILD_NUMBER_FLAG := $(if $(BUILD_NUMBER),--build-number=$(BUILD_NUMBER),)
MISSING_RUNTIME_DART_DEFINE_MESSAGE := Missing required runtime endpoint configuration: SLOCK_API_BASE_URL and SLOCK_REALTIME_URL must be set for produced app-binary builds.

.PHONY: format analyze test ci-test-all ci-test-core ci-test-regression ci-build-smoke ci-build-ios-smoke ci-benchmark

format:
	@if [ ! -f pubspec.yaml ]; then \
		echo "$(SKIP_MESSAGE)"; \
	else \
		dart format --set-exit-if-changed .; \
	fi

analyze:
	@if [ ! -f pubspec.yaml ]; then \
		echo "$(SKIP_MESSAGE)"; \
	else \
		flutter analyze; \
	fi

test:
	@if [ ! -f pubspec.yaml ]; then \
		echo "$(SKIP_MESSAGE)"; \
	elif [ -z "$(TARGET)" ]; then \
		echo "Usage: make test TARGET=test/<path>_test.dart"; \
		exit 2; \
	else \
		flutter test $(TARGET); \
	fi

ci-test-all:
	@if [ ! -f pubspec.yaml ]; then \
		echo "$(SKIP_MESSAGE)"; \
	else \
		flutter test; \
	fi

ci-test-core:
	@if [ ! -f pubspec.yaml ]; then \
		echo "$(SKIP_MESSAGE)"; \
	elif ! find test/core -name '*_test.dart' 2>/dev/null | grep -q .; then \
		echo "No core tests found in test/core/ — skipping."; \
	else \
		flutter test test/core/; \
	fi

ci-test-regression:
	@if [ ! -f pubspec.yaml ]; then \
		echo "$(SKIP_MESSAGE)"; \
	elif ! find test/regression -name '*_test.dart' 2>/dev/null | grep -q .; then \
		echo "No regression tests found in test/regression/ — skipping."; \
	else \
		flutter test test/regression/; \
	fi

ci-build-smoke:
	@if [ ! -f pubspec.yaml ]; then \
		echo "$(SKIP_MESSAGE)"; \
	elif [ -z "$(SLOCK_API_BASE_URL)" ] || [ -z "$(SLOCK_REALTIME_URL)" ]; then \
		echo "$(MISSING_RUNTIME_DART_DEFINE_MESSAGE)"; \
		exit 1; \
	else \
		flutter build apk --release $(RUNTIME_DART_DEFINE_FLAGS) $(RUNTIME_BUILD_NUMBER_FLAG); \
	fi

ci-build-ios-smoke:
	@if [ ! -f pubspec.yaml ]; then \
		echo "$(SKIP_MESSAGE)"; \
	elif [ -z "$(SLOCK_API_BASE_URL)" ] || [ -z "$(SLOCK_REALTIME_URL)" ]; then \
		echo "$(MISSING_RUNTIME_DART_DEFINE_MESSAGE)"; \
		exit 1; \
	else \
		flutter build ios --debug --no-codesign $(RUNTIME_DART_DEFINE_FLAGS); \
	fi

ci-benchmark:
	@if [ ! -f pubspec.yaml ]; then \
		echo "$(SKIP_MESSAGE)"; \
	elif ! find integration_test -name '*_test.dart' 2>/dev/null | grep -q .; then \
		echo "No benchmark tests found in integration_test/ — skipping."; \
	else \
		flutter config --enable-linux-desktop 2>/dev/null || true; \
		flutter test integration_test/ -d linux || echo "Benchmark run completed (non-blocking)."; \
	fi
