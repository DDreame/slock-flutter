# Slock Flutter Implementation Strategy

## 1. Snapshot and Goal

This document proposes the best implementation strategy for `slock-flutter` based on two inputs:

1. the current Android client capability set on `slock-Android` main
2. the Android team's current engineering rules that have emerged through recent delivery work

The goal is not to mechanically port Android screen-by-screen.

The goal is to build the Flutter client from the final architectural shape that Android is moving toward:

- explicit server/channel scope
- single source of truth for shared state
- centralized socket event reduction
- message-level saved state instead of legacy channel-level shims
- bounded cache instead of premature full offline sync
- narrow, reviewable phases with architecture guardrails

## 2. What Exists on Android Today

Android main already covers a broad product surface:

- auth: login, register, forgot password, token refresh, logout, profile refresh
- workspace shell: splash, home, server switcher, settings entry
- channels and DMs: list, create, edit, delete, leave, DM creation, previews, unread badges
- messaging: paginated timeline, send message, attachments upload, socket updates, search-in-channel helpers
- message actions: mark read, mark unread, convert message to task
- threads: inbox, reply timeline, follow/unfollow, done/undone
- tasks: server task list, create, update status, delete, convert from message
- agents: list, detail, start, stop, reset, update, activity display, runtime state
- machines: list and delete, plus machine-related status events
- members and profiles: member list, own profile, other profile, presence display
- saved messages data layer: message-level API contract already landed on Android
- settings and notification preferences
- billing and release notes pages
- socket-driven realtime sync, presence, unread counts, foreground notification suppression, deep links

At the same time, Android also shows where the architecture has already needed cleanup:

- shared agent state moved into `AgentStore`
- unread state moved into `ChannelStore`
- notification suppression depends on explicit visible-channel tracking
- saved messages are being migrated from legacy `SavedChannels*` consumers toward real message-level semantics
- global `ActiveServerHolder` is still a known debt and should not be copied into a fresh Flutter codebase

## 3. Strategy in One Paragraph

Build Flutter as a single app repository with a feature-first structure, Riverpod-driven scoped state, Dio for REST, Socket.IO for live events, Drift for bounded local cache, GoRouter for typed deep links, and a small set of canonical domain stores for shared state. Start directly from the final data contracts and state shapes that Android is converging on instead of recreating Android's temporary compatibility layers.

## 4. Recommended Technical Stack

### 4.1 Core stack

- Flutter stable + Dart 3
- `flutter_riverpod` and `riverpod_annotation`
- `freezed` + `json_serializable`
- `go_router`
- `dio`
- `socket_io_client`
- `drift` + SQLite
- `flutter_secure_storage`
- `shared_preferences`
- `flutter_local_notifications`
- `firebase_messaging` for real background push delivery

### 4.2 Why this stack

#### Riverpod

Riverpod is the best fit because it can replace both DI and reactive store wiring in one system.

It also gives us provider families keyed by runtime scope, which matters for Slock:

- server-scoped lists
- channel-scoped message timelines
- agent-scoped details
- thread-scoped reply flows

That is a better fit than a global service locator and better aligned with the Android cleanup trend away from implicit global state.

#### Drift

Drift is preferred over key-value stores because the current product already relies on relational local reads:

- server-scoped channel search
- server-scoped message search
- server-scoped agent search
- cached channel/message/task data for instant re-entry

This matches SQLite better than Hive/Isar-first modeling.

#### Dio

The backend surface is a conventional REST API with headers, auth refresh, retries, multipart upload, and server-scoped requests. Dio is the most pragmatic fit for interceptors and request policy.

#### GoRouter

The app already depends on deep links and route arguments for:

- notification taps
- channel open
- thread reply entry
- profile detail entry
- agent detail entry

GoRouter gives a clean way to keep route semantics explicit and testable.

## 5. Architecture Decisions

### 5.1 Do not copy Android 1:1

Flutter should preserve product behavior, not Android implementation debt.

Copy these ideas:

- normalized shared stores
- explicit route params
- cache + refresh pattern
- optimistic actions with rollback
- centralized socket reducers
- source-level architecture guardrails where they materially prevent regressions

Do not copy these debts:

- global mutable `ActiveServerHolder` as the implicit transport source of truth
- duplicate list/detail socket patching
- legacy `SavedChannels` abstraction
- Android-specific background socket service assumptions

### 5.2 Use explicit scope, not global active server mutation

The Flutter app should keep `selectedServerId` for UI/navigation convenience, but repository and reducer code must still receive explicit scope.

Good:

```dart
ref.watch(channelListControllerProvider(serverId));
await ref.read(channelRepositoryProvider).getChannels(serverId: serverId);
```

Bad:

```dart
await ref.read(channelRepositoryProvider).getChannels(); // reads implicit global server
```

Rule:

- server selection may live in a UI/session store
- network and cache operations must still receive `serverId`/`channelId`/`agentId` explicitly

### 5.3 Create canonical stores for shared state

Use domain stores for state that must be shared across multiple screens.

Recommended initial set:

- `SessionStore`
  - auth status
  - current user
  - selected server id
- `ChannelStore`
  - unread counts by channel id
  - current visible channel id
  - lightweight channel previews
- `MessageStore`
  - cached timelines keyed by channel id
  - pagination cursors
  - pending optimistic mutations
- `ThreadStore`
  - followed thread summaries
  - done state
- `AgentStore`
  - agents by id
  - latest activity by agent id
  - runtime status by agent id
- `PresenceStore`
  - online ids
- `SavedMessagesStore`
  - saved message ids
  - paginated saved message list metadata
- `NotificationStore`
  - app foreground state
  - current visible channel id
  - notification preference

Controllers should derive screen state from these stores instead of owning duplicate truth.

### 5.4 Centralize socket event reduction

Android has already shown why this matters.

Flutter should have a single normalized realtime layer:

- `RealtimeService` converts raw Socket.IO payloads into typed domain events
- reducers/stores consume those domain events once
- pages/controllers subscribe to store output, not raw socket events

This prevents the same event from being patched separately in:

- channel list
- detail screen
- task list
- notification service

### 5.5 Keep cache bounded and purposeful

Use local cache for:

- fast re-entry into channels/DMs
- search over recent local data
- reconnect recovery
- lightweight task and agent hydration

Do not start with a heavy offline-first sync engine for every entity.

Recommended cache scope for V1:

- servers
- channels and DMs
- recent messages per open channel
- tasks
- agents
- user/session metadata

### 5.6 Saved Messages should start at the final contract

Android is in transition here.

Flutter should start directly with:

- `GET /channels/saved?limit&offset`
- `POST /channels/saved` with `messageId`
- `POST /channels/saved/check` with `messageIds`
- `DELETE /channels/saved/{messageId}`

Do not create any `SavedChannels` compatibility abstraction in Flutter.

## 6. Proposed Repository Structure

Do not over-engineer into a multi-package monorepo yet. Start with one Flutter app and clean internal module boundaries.

```text
lib/
  app/
    bootstrap/
    router/
    theme/
    widgets/
  core/
    config/
    errors/
    logging/
    network/
    realtime/
    storage/
    utils/
  features/
    auth/
      data/
      domain/
      application/
      presentation/
    workspace/
    channels/
    messages/
    threads/
    tasks/
    agents/
    machines/
    members/
    saved_messages/
    profile/
    settings/
    billing/
    release_notes/
```

Within each feature:

```text
feature_x/
  data/
    dto/
    datasource/
    repository/
  domain/
    model/
    service/
  application/
    controller/
    state/
    provider/
  presentation/
    page/
    section/
    widget/
```

If later a real shared SDK becomes necessary, extract after the first stable vertical slices, not before.

## 7. Routing Model

Mirror Android route semantics, but simplify naming where Flutter can be clearer.

Recommended primary routes:

- `/splash`
- `/login`
- `/register`
- `/forgot-password`
- `/home`
- `/servers/:serverId/channels/:channelId`
- `/servers/:serverId/agents`
- `/agents/:agentId`
- `/servers/:serverId/threads`
- `/threads/:threadId/replies`
- `/servers/:serverId/tasks`
- `/servers/:serverId/machines`
- `/saved-messages`
- `/settings`
- `/profile`
- `/profile/:userId`
- `/billing`
- `/release-notes`

Rules:

- route params carry scope explicitly
- deep-link building lives in one helper layer
- route parsing and notification deep-link handling get dedicated tests

## 8. UI System Recommendation

Android has already established a Neo-Brutalism visual language.

Flutter should preserve the product identity, but implement it as reusable design tokens and primitives instead of ad hoc screen styling.

Create:

- `NeoThemeExtension`
- `NeoButton`
- `NeoCard`
- `NeoInput`
- `NeoTopBar`
- `NeoBottomNav`
- `NeoBadge`
- `NeoEmptyState`
- `NeoErrorState`

This preserves the existing brand direction while making Flutter review easier and reducing one-off styling drift.

## 9. Notifications and Background Behavior

This is the biggest place where Flutter must not mechanically copy Android.

### 9.1 Foreground behavior

Keep Android product behavior:

- if the user is already viewing the same channel in the foreground, suppress the extra notification
- if the app is foregrounded but the incoming channel is different, allow in-app/local notification behavior

### 9.2 Background behavior

Do not build the Flutter client around a permanently alive background socket, especially for iOS.

Recommended production approach:

- use socket connection for foreground live sync
- use FCM/APNs for true background delivery
- use local notification rendering for foreground presentation and tapped deep links

This keeps product semantics aligned while respecting Flutter/mobile platform reality.

## 10. Feature Delivery Order

### Phase 0: Bootstrap

- initialize Flutter app shell
- add linting, formatting, CI, codegen
- add auth/session bootstrap
- add theme tokens and route shell
- add Dio, secure storage, preferences, socket, local notifications

### Phase 1: Auth and Workspace Scope

- login/register/forgot password
- token refresh and logout
- session bootstrap on app start
- selected server persistence
- explicit server scope plumbing in router and repositories

### Phase 2: Home, Channels, DMs, Unread, Search

- home shell with server switcher
- channel list and DM list
- unread badge pipeline through `ChannelStore`
- message/channel/agent search with bounded local cache plus remote merge

### Phase 3: Message Room and High-Frequency Message Actions

- paginated message timeline
- send/edit/update/render
- attachments upload
- mark read/unread
- saved message toggle and `savedIds` lookup
- saved messages page
- local optimistic rollback for message actions

### Phase 4: Threads and Tasks

- thread inbox
- reply timeline
- follow/unfollow and done/undone
- server tasks
- create task
- convert message to task

### Phase 5: Agents and Related Secondary Flows

- agent list
- agent detail
- start/stop/reset/update
- latest activity state from `AgentStore`
- members list and presence
- machines list and related status signals
- profile screens

### Phase 6: Settings, Billing, Release Notes, Notification Hardening

- settings and notification preferences
- billing plans
- release notes
- push token lifecycle
- reconnect and resume hardening

This order follows actual usage frequency and architectural dependencies rather than UI completeness alone.

## 11. Delivery Rules for Flutter

These should match the Android team's current working rules.

### 11.1 Scope stays narrow

Every branch/PR should declare:

- exact task
- locked scope
- explicit non-goals

Do not mix architecture cleanup, UI rewrite, and data contract changes in the same slice unless they are inseparable.

### 11.2 Data contract before UI migration

If a feature needs both API contract correction and UI work, land them in order:

1. DTO/API/repository alignment
2. shared store/reducer alignment
3. UI migration
4. cleanup of compatibility shims

### 11.3 One shared truth per domain concept

Examples:

- unread count belongs in `ChannelStore`
- latest agent activity belongs in `AgentStore`
- saved message ids belong in `SavedMessagesStore`

Screens may derive view state, but must not fork those truths.

### 11.4 Socket events are reduced once

Never patch the same socket event in both list and detail layers if the state is shared.

### 11.5 Optimistic updates require rollback

For message save, mark unread, task status update, agent control, and similar actions:

- store previous value
- apply optimistic state
- rollback on failure
- surface user feedback

### 11.6 Compatibility shims are temporary and explicit

If a temporary compatibility layer is unavoidable:

- isolate it at the edge
- forbid it from expanding old semantics back into the new public contract
- track the removal owner and removal phase

### 11.7 Guard architecture with tests

Use a layered test strategy:

- DTO serialization and repository contract tests
- reducer/store tests
- widget tests for high-risk interactions
- route/deep-link tests
- integration smoke tests for auth, home, message room

Do not default to massive brittle end-to-end suites.

Targeted structural/source-shape tests are acceptable only where they protect high-risk wiring that has already regressed on Android.

### 11.8 CI must stay cheap enough to trust

Flutter CI should start with:

- `flutter format --set-exit-if-changed`
- `flutter analyze`
- unit tests
- widget tests
- a very small smoke integration lane

Avoid building a huge slow matrix before the repository has working vertical slices.

## 12. Known Risks and How to Avoid Them

### Risk 1: Porting Android debt instead of Android product value

Mitigation:

- start from final contracts and canonical store shapes
- reject legacy shims unless they are temporary and owned

### Risk 2: Hidden server scope bugs

Mitigation:

- explicit `serverId` in provider families and repository methods
- no network call that depends on an implicit mutable singleton

### Risk 3: Cross-platform background notification mismatch

Mitigation:

- socket for foreground sync
- FCM/APNs for background delivery
- unified deep-link entry helpers

### Risk 4: CI collapse from test sprawl

Mitigation:

- keep most coverage at unit/store/widget level
- only a few smoke integration flows
- add deeper suites only after feature stabilization

## 13. First Concrete Milestone

The first implementation milestone for this repo should be:

1. scaffold the Flutter app shell
2. land theme tokens and routing shell
3. land session/auth/bootstrap flow
4. land explicit server scope plumbing
5. land `ChannelStore`, `AgentStore`, `PresenceStore`, and normalized realtime event definitions
6. land minimal home/channel/DM/message vertical slice

That milestone creates the base that every later feature depends on.

## 14. Final Recommendation

The best path is:

- single Flutter app repository now
- feature-first modular internals
- Riverpod families as the replacement for Hilt + StateFlow wiring
- Drift for bounded relational cache
- centralized realtime reducers and canonical stores
- direct adoption of final message-level Saved Messages semantics
- explicit scoped APIs instead of global active server state
- phased delivery that lands contract and store shape before complex UI

If we follow this, Flutter will stay aligned with the Android product while avoiding the cleanup work Android is still paying down.
