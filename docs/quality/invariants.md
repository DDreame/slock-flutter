# Invariant Registry

Living reference of all test invariants, regression snapshots, and migration
records established in Batch 10.

---

## CT (Core Test) Invariants

### Preview Contract (`test/core/invariants/preview_contract_test.dart`)

Task: #469

| ID | Description | Assertion Type | Status |
|----|-------------|----------------|--------|
| INV-PREVIEW-1 | Preview result is never empty, null, or `"[No preview]"` | property-based | Active |
| INV-PREVIEW-2 | Preview result length <= 200 characters | property-based | **Skip+TODO** |
| INV-PREVIEW-3 | Every MessageType x attachment x state combination produces a valid preview | property-based / exhaustive | Active |

**Skip+TODO details:**

- **INV-PREVIEW-2** `resolve() output length <= 200` — Resolver does not
  truncate content. Requires adding truncation logic to
  `MessagePreviewResolver`. The sibling label-constant sub-test is active.

---

### Unread/Badge Parity (`test/core/invariants/unread_badge_parity_test.dart`)

Task: #470

| ID | Description | Assertion Type | Status |
|----|-------------|----------------|--------|
| INV-BADGE-1 | Source partition: `sources == visible U hidden`; count: `total == sum(visible) + sum(hidden)` | algebraic | Active |
| INV-BADGE-2 | After mark-read, unread count strictly decreases and remains >= 0 | algebraic | Active |
| INV-BADGE-3 | After server switch, old server unread data is completely zeroed | contract | **Partial skip** |
| INV-BADGE-4 | Badge counts decompose consistently: `channelTotal + dmTotal + threadTotal == totalUnreadCount` | algebraic | Active |

**Skip+TODO details:**

- **INV-BADGE-3** `clearSelection zeroes badge providers (not just
  projection)` — InboxStore does not rebuild on server selection change;
  badge providers retain stale counts after `clearSelection`. Requires
  InboxStore to watch `activeServerScopeId` or clear on server switch.

---

### Realtime Liveness (`test/core/invariants/realtime_liveness_test.dart`)

Task: #471

| ID | Description | Assertion Type | Status |
|----|-------------|----------------|--------|
| INV-LIVE-1 | Event delivery: replaying a domain event updates projection surface (preview, timestamp, ordering) | event-driven | **Partial skip** |
| INV-LIVE-2 | Idempotency: replaying the same event N times produces the same state as once | algebraic | Active |
| INV-LIVE-3 | Ordering convergence: events in any order converge to correct per-channel state | event-driven | Active |
| INV-LIVE-4 | Server scope isolation: events for non-current server are not applied to visible projections | contract | **Partial skip** |

**Skip+TODO details:**

- **INV-LIVE-1** `message:new reorders Home channels by activity` — Home
  channel ordering is driven by `SidebarOrder` (user-controlled), not by
  `lastActivityAt`. Realtime events update preview/timestamp but do not
  mutate sidebar order.

- **INV-LIVE-4** `server switch reveals events scoped to the new server` —
  Router does not buffer cross-server events for later replay.
  Channel/task events trigger fire-and-forget refreshes; message events
  match by channelId. Requires router-level event buffering or
  server-scoped queues.

---

### Task API / Agent Grouping / Server Isolation (`test/core/invariants/task_agent_server_test.dart`)

Task: #472

| ID | Description | Assertion Type | Status |
|----|-------------|----------------|--------|
| INV-TASK-1 | Task state transitions follow `todo -> in_progress -> in_review -> done`; `done` requires assignee | contract | **Partial skip** |
| INV-AGENT-1 | Agent status grouping produces a correct partition: all agents appear exactly once across groups | algebraic | Active |
| INV-AGENT-2 | Agent group labels match the actual resolved statuses of agents within each group | algebraic | Active |
| INV-SERVER-1 | Server switch fully isolates data: channels, DMs, agents, tasks from server A absent when B is active | contract | Active |

**Skip+TODO details:**

- **INV-TASK-1** `done status requires an assignee` — `TaskItem` data model
  and `TasksStore.updateTaskStatus()` do not enforce the "done requires
  assignee" constraint. A task with `status=done` and `claimedById=null` is
  silently accepted. Requires server-side or store-level validation.

- **INV-TASK-1** `task status transitions follow todo -> in_progress ->
  in_review -> done` — `TasksStore.updateTaskStatus()` accepts arbitrary
  status strings with no transition validation. Invalid transitions
  (e.g., `todo -> done`) are silently accepted. Requires store-level or
  server-side state machine validation.

---

## RT (Regression Test) Snapshots

### Home Projection (`test/regression/home/home_projection_snapshot_test.dart`)

Task: #473. Goldens: `test/regression/home/goldens/`

| ID | Description | Golden File | Status |
|----|-------------|-------------|--------|
| RT-HOME-1 | Baseline home list state snapshot | `home_baseline.json` | Active |
| RT-HOME-2 | Home state after `message:new` event | `home_after_message_new.json` | Active |
| RT-HOME-3 | Home state after channel mark-read | _none_ | **Skip+TODO** |
| RT-HOME-4 | Home state after `agent:activity` event (no-op) | `home_after_agent_activity.json` | Active |
| RT-HOME-5 | Home state after `task:updated` event | `home_after_task_updated.json` | Active |

**Skip+TODO details:**

- **RT-HOME-3** — Channel mark-read only modifies `InboxStore` (unread
  projection), not `HomeListState`. `_hydrateUnreadCounts` is a no-op. A
  Home projection golden for mark-read would be identical to the baseline.

---

### Inbox/Unread Projection (`test/regression/inbox/inbox_unread_snapshot_test.dart`)

Task: #474. Goldens: `test/regression/inbox/goldens/`

| ID | Description | Golden File | Status |
|----|-------------|-------------|--------|
| RT-INBOX-1 | Inbox list state baseline snapshot | `inbox_baseline.json` | Active |
| RT-INBOX-2 | Unread source projection baseline snapshot | `unread_projection_baseline.json` | Active |
| RT-INBOX-3 | Inbox state after `message:new` event | `inbox_after_message_new.json` | Active |
| RT-INBOX-4 | Inbox state after mark-read | `inbox_after_mark_read.json` | Active |
| RT-INBOX-5 | Unread projection after mark-read | `unread_projection_after_mark_read.json` | Active |
| RT-INBOX-6 | Inbox state after mark-done | `inbox_after_mark_done.json` | Active |
| RT-INBOX-7 | Inbox state with mention-type item | _none_ | **Skip+TODO** |

**Skip+TODO details:**

- **RT-INBOX-7** — `InboxItemKind` only supports `channel`, `dm`, `thread`,
  and `unknown`. There is no mention-specific kind in the current data
  model. When a mention kind is added, this test should seed a mention inbox
  item and snapshot its projection behavior.

---

### Send/Conversation State (`test/regression/send/send_conversation_snapshot_test.dart`)

Task: #475. Goldens: `test/regression/send/goldens/`

| ID | Description | Golden File | Status |
|----|-------------|-------------|--------|
| RT-SEND-1 | Conversation list state snapshot | _none_ | **Skip+TODO** |
| RT-SEND-2 | Message send lifecycle snapshot (optimistic + confirmed) | `send_lifecycle_stages.json` | Active |
| RT-SEND-3 | Conversation state after `message:new` event | `conversation_after_message_new.json` | Active |
| RT-SEND-4 | Conversation state after `message:updated` event | _none_ | **Skip+TODO** |
| RT-SEND-5 | Conversation state after `message:deleted` event | `conversation_after_delete.json` | Active |
| RT-SEND-6 | Send failure snapshot | `conversation_after_send_failure.json` | Active |

**Skip+TODO details:**

- **RT-SEND-1** — No conversation-list projection store exists.
  `ConversationDetailStore` is per-conversation (`autoDispose`, keyed by
  target). Multi-conversation list surfaces are covered by RT-INBOX suite.

- **RT-SEND-4** — `_handleMessageUpdated` delegates to
  `repo.updateStoredMessageContent()`, which returns `null` in
  `FakeConversationRepository`, so state is never patched. When the shared
  fake supports `updateStoredMessageContent` (returning a patched message),
  this test should replay a `message:updated` event and snapshot the
  resulting state.

---

## Phase 4: Mock-to-State Migration Summary

Tasks: #476, #477, #478

### Migrated Suites

| File | Task | Before | After | Justified Exceptions |
|------|------|--------|-------|----------------------|
| `test/features/home/application/home_list_store_test.dart` | #476 | 6 private fakes, plain `ProviderContainer` | Shared fakes from `test/support/fakes/`, `RuntimeAppFixture` | `_DelayedHomeRepository` (Completer timing); null-server tests (boot always selects server) |
| `test/features/unread/application/unread_badge_parity_test.dart` | #477 | 2 Notifier fakes (`_FakeInboxStore`, `_FakeHomeListStore`), `createContainer()` | `RuntimeAppFixture` + `seedHome` + `seedInbox`, real `InboxStore.load()` | "home not loaded" test retains local fakes (boot auto-loads home) |
| `test/features/inbox/application/inbox_store_test.dart` | #478 | Local `FakeInboxRepository`, `createContainer()`, call-tracking fields | Shared `FakeInboxRepository`, `RuntimeAppFixture`, state assertions on `InboxState` | "no active server" (boot selects server); `_ControllableInboxRepository` (Completer timing) |
| `test/features/inbox/application/inbox_realtime_refresh_binding_test.dart` | #478 | Local `_FakeInboxRepository` | Shared `FakeInboxRepository` | `fetchCallCount` retained (debounce verification has no state equivalent) |
| `test/features/inbox/presentation/inbox_page_test.dart` | #478 | `markedDoneIds`, `markedReadIds`, `markAllReadCalled` tracking | UI-state assertions (item gone, badge cleared, button hidden) | `lastFilter`, `loadMoreCalled` retained (re-fetch result indistinguishable from initial load) |

### Key Patterns

- **`RuntimeAppFixture`** — Creates `ProviderContainer` with all shared
  fakes wired. `boot()` selects server and auto-loads `HomeListStore`.
  Does NOT auto-load `InboxStore`.
- **`seedHome(channels, directMessages, sidebarOrder)`** — Pre-fills
  `FakeHomeRepository` snapshot.
- **`seedInbox(items, {totalUnreadCount})`** — Pre-fills
  `FakeInboxRepository.fetchResponse` with `hasMore: false`.
- **Direct `fixture.inboxRepository`** — Used for pagination tests where
  `hasMore: true` is needed.
- **`failNext`** — One-shot failure injection on shared
  `FakeInboxRepository` for testing error→retry paths.

### Assertions Removed

All call-tracking / path assertions eliminated from migrated tests:
- `repo.lastFetchFilter`, `repo.lastFetchOffset`, `repo.fetchCallCount`
- `repo.lastMarkReadChannelId`, `repo.lastMarkDoneChannelId`
- `repo.markAllReadCalled`, `repo.markedDoneIds`, `repo.markedReadIds`
- `repository.requestedServerIds`

Replaced with state assertions on `InboxState` (status, items, filter,
offset, counts) and UI assertions (widget presence/absence via
`find.byKey`).

---

## How to Add New Invariants

### CT Invariant

1. Choose the right file or create a new one under `test/core/invariants/`.
2. Pick an ID following the existing scheme:
   - Format: `INV-{DOMAIN}-{N}` (e.g., `INV-BADGE-5`)
   - Domains: `PREVIEW`, `BADGE`, `LIVE`, `TASK`, `AGENT`, `SERVER`
   - For new domains: `INV-{NEWDOMAIN}-1`
3. Write the test with a descriptive group/test name that includes the ID:
   ```dart
   group('INV-BADGE-5: new-message increments unread count', () {
     test('count increases by 1 for each new message', () {
       // ...
     });
   });
   ```
4. If the invariant cannot be fully tested due to missing production code,
   use `skip:` with a `TODO:` explanation:
   ```dart
   test('some behavior', skip: 'TODO: <what is missing and what needs to change>');
   ```
5. Add a row to the appropriate table in this registry.

### RT Snapshot

1. Choose the right file or create a new one under `test/regression/{domain}/`.
2. Pick an ID: `RT-{DOMAIN}-{N}` (e.g., `RT-INBOX-8`).
3. Use `RuntimeAppFixture` to seed state, then serialize the projection:
   ```dart
   test('RT-INBOX-8: inbox state after <scenario>', () async {
     final fixture = RuntimeAppFixture();
     fixture.seedInbox([...]);
     await fixture.boot();
     // ... trigger scenario ...
     final state = fixture.container.read(inboxStoreProvider);
     expectGoldenMatch(state.toJson(), 'inbox_after_scenario.json');
   });
   ```
4. Golden files go in `test/regression/{domain}/goldens/`.
5. For skip+TODO: omit the golden file and document the reason.
6. Add a row to the appropriate table in this registry.

---

## Summary

| Category | Total | Active | Skip+TODO |
|----------|-------|--------|-----------|
| CT invariants | 15 | 9 | 6 (across 5 IDs) |
| RT snapshots | 18 | 14 | 4 |
| Phase 4 migrations | 5 files | -- | -- |
| **Total test points** | **33** | **23** | **10** |
