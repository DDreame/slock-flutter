SHELL := /bin/bash

SKIP_MESSAGE := Skipping: Flutter app skeleton has not landed yet (missing pubspec.yaml).
RUNTIME_DART_DEFINE_FLAGS := --dart-define=SLOCK_API_BASE_URL=$(SLOCK_API_BASE_URL) --dart-define=SLOCK_REALTIME_URL=$(SLOCK_REALTIME_URL)
MISSING_RUNTIME_DART_DEFINE_MESSAGE := Missing required runtime endpoint configuration: SLOCK_API_BASE_URL and SLOCK_REALTIME_URL must be set for produced app-binary builds.

.PHONY: format analyze test ci-test-all ci-build-smoke ci-build-ios-smoke

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

ci-build-smoke:
	@if [ ! -f pubspec.yaml ]; then \
		echo "$(SKIP_MESSAGE)"; \
	elif [ -z "$(SLOCK_API_BASE_URL)" ] || [ -z "$(SLOCK_REALTIME_URL)" ]; then \
		echo "$(MISSING_RUNTIME_DART_DEFINE_MESSAGE)"; \
		exit 1; \
	else \
		flutter build apk --debug $(RUNTIME_DART_DEFINE_FLAGS); \
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
