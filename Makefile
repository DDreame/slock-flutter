SHELL := /bin/bash

SKIP_MESSAGE := Skipping: Flutter app skeleton has not landed yet (missing pubspec.yaml).

.PHONY: format analyze test ci-test-all ci-build-smoke

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
	else \
		flutter build apk --debug; \
	fi
