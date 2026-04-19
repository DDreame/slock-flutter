# Slock Flutter Docs

This repository is currently starting from an empty baseline.

The initial deliverable in this branch is a reviewable implementation plan derived from:

- the current Android `main` branch feature surface
- the Android team's recent architecture decisions
- the current delivery/review rules that have been used to ship Android work safely

Recommended reading order:

1. `flutter_implementation_strategy.md`
2. `android_to_flutter_parity_matrix.md`

What these docs are for:

- decide the Flutter architecture before scaffolding code
- keep Flutter aligned with Android product behavior without copying Android's historical baggage
- give reviewers a concrete basis for approving or adjusting the implementation direction

What these docs intentionally do not do:

- they do not lock exact package versions
- they do not pre-commit the repo to a multi-package monorepo
- they do not promise 1:1 Android implementation details where Flutter/iOS need different runtime behavior
