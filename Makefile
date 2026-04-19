SHELL := /bin/bash

.PHONY: format analyze test ci-test-all ci-build-smoke

define require_flutter_project
	@if [ ! -f pubspec.yaml ]; then \
		echo "Skipping: Flutter app skeleton has not landed yet (missing pubspec.yaml)."; \
		exit 0; \
	fi
endef

format:
	$(require_flutter_project)
	dart format --set-exit-if-changed .

analyze:
	$(require_flutter_project)
	flutter analyze

test:
	$(require_flutter_project)
	@if [ -z "$(TARGET)" ]; then \
		echo "Usage: make test TARGET=test/<path>_test.dart"; \
		exit 2; \
	fi
	flutter test $(TARGET)

ci-test-all:
	$(require_flutter_project)
	flutter test

ci-build-smoke:
	$(require_flutter_project)
	flutter build apk --debug
