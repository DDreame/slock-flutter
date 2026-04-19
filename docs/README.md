# Slock Flutter Docs

This repository is still at a docs-first stage.

The current deliverable is a reviewable Flutter architecture and engineering baseline derived from:

- the current Android `origin/main` implementation shape
- the current Web product behavior in `/home/slock/shared/slock-web/`
- the Android team's recent cleanup work around shared state, notifications, and review discipline

Recommended reading order:

1. `flutter_implementation_strategy.md`
2. `flutter_engineering_rules.md`
3. `android_to_flutter_parity_matrix.md`

What these docs are for:

- decide the Flutter architecture before scaffolding code
- keep Flutter aligned with Android/Web product behavior without copying Android's temporary debt
- give reviewers a concrete basis for approving, tightening, or objecting to the implementation direction

What these docs intentionally do not do:

- they do not lock exact package versions
- they do not pre-commit the repo to a multi-package monorepo
- they do not promise 1:1 Android implementation details where Flutter/iOS need different runtime behavior
