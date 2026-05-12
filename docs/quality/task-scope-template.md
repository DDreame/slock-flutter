# PM Task Scope Template

Use this template when defining new tasks. Each scope should be a
self-contained assignment that an engineer can claim and execute without
ambiguity.

**Related docs:**
[A1 Review Checklist](review-checklist.md) |
[Merge Gate Rules](merge-gate-rules.md) |
[Invariant Registry](invariants.md)

---

## Header

```
Task:    #NNN
Title:   <short title>
Type:    代码 (code) | 测试 (test) | 测试迁移 (test migration)
Phase:   A (test-only) | B (implementation-only) | N/A (docs/config)
Base:    main@<commit-sha>
Branch:  j1/task-NNN-<description>
```

---

## Write Set

List the files and directories that are in scope for modification.
Anything outside this set is out of scope unless explicitly noted.

```
- [ ] test/core/invariants/<new-file>.dart
- [ ] test/support/fakes/<shared-fake>.dart
- [ ] lib/features/<domain>/application/<store>.dart  (Phase B only)
```

**Phase constraints:**
- **Phase A (test-only):** Only `test/` files. No `lib/` changes.
- **Phase B (impl-only):** Only `lib/` files. No `test/` changes.
- **N/A:** No phase restriction (e.g., docs, config, CI).

---

## Boundary Invariants

Reference invariants from [`docs/quality/invariants.md`](invariants.md)
that this task must not break.

```
- INV-BADGE-1 (source partition)
- INV-LIVE-2 (idempotency)
- RT-INBOX-1 (baseline snapshot)
```

If the task introduces new invariants, list the proposed IDs here.

---

## Acceptance Criteria

Concrete, verifiable conditions for completion.

```
- [ ] N tests pass (specify suite path)
- [ ] No skip+TODO without documented reason
- [ ] dart format clean
- [ ] dart analyze clean
- [ ] Net test count: +N or preserved
```

---

## Out of Scope

Explicitly list what this task does NOT include.

```
- No production code changes (Phase A)
- No changes to <unrelated-domain>
- UI tests deferred to task #NNN
```

---

## Example

```
Task:    #485
Title:   CT — Message Edit Invariants
Type:    测试 (test)
Phase:   A (test-only)
Base:    main@fad81f3
Branch:  j1/task-485-message-edit-invariants

Write Set:
- [ ] test/core/invariants/message_edit_test.dart (new)
- [ ] test/support/fakes/fake_conversation_repository.dart (add editMessage support)

Boundary Invariants:
- INV-PREVIEW-1 (preview never empty — must hold after edit)
- RT-SEND-2 (send lifecycle — must not regress)

Acceptance Criteria:
- [ ] INV-EDIT-1, INV-EDIT-2, INV-EDIT-3 defined and passing
- [ ] No skip+TODO without documented reason
- [ ] dart format + analyze clean
- [ ] Net test count: +12

Out of Scope:
- No lib/ changes
- No UI/widget tests
- message:updated realtime path deferred (RT-SEND-4 skip+TODO)
```
