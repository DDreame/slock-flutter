# A1 Review Checklist

Checklist for code review. Verify each applicable item before posting
a continuity verdict.

**Related docs:**
[Task Scope Template](task-scope-template.md) |
[Merge Gate Rules](merge-gate-rules.md) |
[Invariant Registry](invariants.md)

---

## Phase Compliance

### Phase A (test-only)

- [ ] No `lib/` files modified
- [ ] Only `test/` files in the diff (docs/config changes belong to N/A phase)
- [ ] No production behavior changes (even via test support files)

### Phase B (implementation-only)

- [ ] No `test/` files modified
- [ ] Only `lib/` files in the diff
- [ ] Existing tests still pass (CI green)

### N/A (docs/config)

- [ ] Only `docs/`, config, or CI files in the diff
- [ ] No `lib/` or `test/` changes

---

## Mock-to-State Migration

When reviewing test migration PRs:

- [ ] No `mock.verify()` or `verifyNever()` calls
- [ ] No call-count assertions (`repo.fetchCallCount`,
  `repo.lastFetchFilter`, etc.) **unless** justified with a comment
  explaining why no state-observable equivalent exists
- [ ] Justified call-tracking exceptions have inline comments documenting
  the reason (e.g., debounce verification, re-fetch indistinguishable
  from initial load)
- [ ] `markedDoneIds`, `markedReadIds`, `markAllReadCalled` and similar
  repo-bookkeeping replaced with UI/state assertions
- [ ] State assertions verify outcomes (status, items, counts) not
  implementation paths

---

## RuntimeAppFixture Usage

- [ ] Fixture-compatible tests use `RuntimeAppFixture` + `boot()` +
  `seedHome()` / `seedInbox()` instead of raw `ProviderContainer`
- [ ] Direct `ProviderContainer` usage has a justification comment
  (e.g., null server, Completer timing, Notifier state injection)
- [ ] Local fakes are justified — shared fakes from `test/support/fakes/`
  preferred
- [ ] No duplicate fakes — if a shared fake exists, use it

---

## skip+TODO Documentation

- [ ] Every `skip:` annotation includes a `TODO:` prefix
- [ ] Skip reason explains **what is missing** in production code
- [ ] Skip reason explains **what needs to change** to enable the test
- [ ] Skip items are catalogued in
  [`docs/quality/invariants.md`](invariants.md)

---

## Invariant Coverage

- [ ] New invariants use the naming convention: `INV-{DOMAIN}-{N}` (CT)
  or `RT-{DOMAIN}-{N}` (RT)
- [ ] New invariants are added to
  [`docs/quality/invariants.md`](invariants.md) registry
- [ ] Existing invariants referenced in boundary list are not broken
- [ ] Golden files (RT) are present in `test/regression/{domain}/goldens/`

---

## General

- [ ] `dart format` clean (no `--language-version` flag)
- [ ] `dart analyze` clean (no warnings or errors)
- [ ] Net test count preserved or increased (no silent test deletion)
- [ ] No empty test files (CI fails on files without `main()`)
- [ ] Test file imports use `../support/support.dart` barrel where applicable

---

## Verdict Format

```
Re-review complete on exact head `<sha>`. No further findings.
— OR —
N blocker(s) on exact head `<sha>`:
1. <file:line> — <description>
```

Always specify the exact commit hash reviewed. If a carry fixes a blocker,
re-review must be on the new head.
