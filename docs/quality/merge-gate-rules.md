# RC Merge Gate Rules

Rules for the merge gate. Every PR must pass all applicable checks before
merge.

**Related docs:**
[Task Scope Template](task-scope-template.md) |
[A1 Review Checklist](review-checklist.md) |
[Invariant Registry](invariants.md)

---

## Required Checks

### 1. CI Green on Exact Head

- [ ] `verify` job passes on the exact PR head commit
- [ ] `smoke-build` job passes on the exact PR head commit
- [ ] `ios-smoke-build` job passes on the exact PR head commit
- [ ] CI run ID is documented in the audit comment

**"Exact head" means the SHA that A1 reviewed.** If a carry was pushed
after A1's review, CI must be green on the carry head, not the original.

---

### 2. A1 Continuity-Clear

- [ ] A1 posted a continuity-clear verdict on the exact PR head
- [ ] If blockers were found and fixed, carry chain is documented
  (e.g., `be3ae46` -> `7eb0415` -> `88f2989`)
- [ ] A1's final verdict references the same SHA as the CI run

---

### 3. Carry Chain Documentation

When a PR has multiple review rounds:

- [ ] Each carry commit is listed with its SHA
- [ ] Blocker -> fix mapping is clear
- [ ] Final head is explicitly stated

Example:
```
Carry chain: be3ae46 -> 7eb0415 -> 88f2989
- be3ae46: initial submission (2 blockers)
- 7eb0415: fix blockers 1+2 (1 blocker remaining)
- 88f2989: fix blocker 3 (A1 clear)
```

---

### 4. Synthetic Merge Clean

- [ ] PR merges cleanly against current `main` (zero conflicts)
- [ ] If conflicts exist, author must rebase and A1 must re-review

---

### 5. Audit Comment

Post a merge audit comment on the PR with:

```
## Merge Audit

- **Head:** <exact-sha>
- **A1 verdict:** continuity-clear on <sha> (N review rounds)
- **CI run:** <run-id> — verify + smoke-build + ios-smoke-build green
- **Scope:** <N> files, +/-<N> lines, <description>
- **Synthetic merge:** clean / conflicts (detail)
- **Batch progress:** N/M done
```

---

## Merge Sequence

1. Verify CI is green on exact head
2. Confirm A1 continuity-clear matches the CI head
3. Check synthetic merge is clean
4. Post audit comment on PR
5. Merge (squash or merge commit per repo convention)
6. Post confirmation in task thread with new `main@<sha>`
7. Update batch progress count

---

## Rejection Criteria

Reject the merge gate if any of these are true:

- CI failed or has not run on the exact PR head
- A1 has outstanding blockers (not cleared on current head)
- A1's clear is on a different SHA than the current PR head
- Synthetic merge has conflicts
- PR contains files outside the declared write set (Phase A/B violation)

When rejecting, post the specific reason in the task thread and tag the
author for a fix.

---

## Emergency Overrides

In rare cases where a merge is urgent:

- RC may merge with a documented override reason
- Override must be posted in the task thread before merge
- A follow-up task must be created for any skipped checks
- Emergency overrides should be reviewed in the next batch retrospective
