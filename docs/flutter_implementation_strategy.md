# Slock Flutter Architecture Blueprint

Last revised: 2026-04-19

## 1. Inputs and Goal

This document is the current proposed architecture baseline for `slock-flutter`.

It is based on three sources of truth:

1. `slock-Android` `origin/main` at `3a77cce`
2. current Web behavior in `/home/slock/shared/slock-web/`
3. the Android team's recent delivery/review patterns that have already exposed which architecture choices are safe and which ones create regressions

The goal is not to port Android screen-by-screen.

The goal is to start Flutter from the cleaner shape that Android has been converging toward:

- explicit route and data scope
- canonical shared stores
- centralized realtime reduction
- message-level saved semantics from day 1
- push-first background notification delivery
- bounded cache and predictable loading paths
- explicit crash and diagnostics feedback

The success criteria for the Flutter app are:

- data state stays stable under reconnect, refresh, and deep-link reopen
- notifications are reliable and platform-correct
- large message surfaces stay fast to enter and scroll
- failures are observable and easy for users and developers to report

## 2. What I Keep From the Initial Draft, and What I Tighten

The existing RC draft already points in the right direction on several fundamentals:

- keep a single Flutter app repo, not a premature monorepo
- use explicit scope instead of copying Android's `ActiveServerHolder` debt
- centralize shared agent/unread state in canonical stores
- use final Saved Messages contracts instead of recreating `SavedChannels`
- prefer push notifications for background delivery, not a permanent background socket

What this revision tightens is the execution detail.

The most important tightened decisions are:

1. **Repositories must never depend on implicit active scope.**
   `serverId`, `channelId`, `threadId`, `agentId`, and `messageId` must stay explicit across repository and reducer boundaries.

2. **All shared realtime state must be reduced once.**
   Flutter should not repeat Android's historical phase where list/detail/notification logic all patched the same event independently.

3. **Notifications need their own architecture, not just a plugin choice.**
   The design must explicitly separate foreground socket behavior from background push delivery and must include visible-channel suppression as a first-class rule.

4. **Observability is not optional.**
   Crash capture, local diagnostics, request/realtime breadcrumbs, and user-facing failure reporting need to exist before the app scales out to more feature surfaces.

5. **Performance rules need budgets and constraints, not just "use cache".**
   We need a bounded storage policy, startup load policy, and list/pagination rules that keep the app predictable.

## 3. Evidence From Android and Web That Should Shape Flutter

### 3.1 Android patterns worth copying

- `AgentStore` is now the canonical owner for shared agent state such as agent catalog, latest activity, and runtime status.
- `ChannelStore` is now the canonical owner for unread counts and current visible channel tracking.
- notification suppression is no longer guesswork; it depends on explicit `currentVisibleChannelId` tracking.
- Saved Messages contract has already been corrected to `messageId` semantics and should not be reinterpreted as channel bookmark state.

### 3.2 Android debts that Flutter should not inherit

- `ActiveServerHolder` still exists widely across Android repositories and view models. Flutter should not recreate that implicit global scope pattern.
- Android still contains platform-specific service assumptions around notification transport that are not suitable as Flutter/iOS truth.
- Android had to spend multiple cleanup tasks to move duplicated list/detail/shared state into stores. Flutter should start from the post-cleanup shape, not repeat the cleanup journey.

### 3.3 Web behaviors Flutter should preserve

The current Web client makes several product truths explicit even through the bundled build:

- Saved Messages is message-level, not channel-level
- `/saved`, `/release-notes`, billing, and settings already exist as first-class product destinations
- push subscription is handled through explicit push APIs / service worker logic, not through background sockets alone
- websocket/socket-based live sync is important for foreground freshness, but Web still separates push subscription concerns from normal realtime concerns

Flutter should preserve those semantics while implementing them with mobile-appropriate runtime behavior.

## 4. Recommended Technical Stack

### 4.1 Core stack

- Flutter stable + Dart 3
- `flutter_riverpod` + `riverpod_annotation`
- `freezed` + `json_serializable`
- `go_router`
- `dio`
- `socket_io_client`
- `drift` + SQLite
- `flutter_secure_storage`
- `shared_preferences`
- `flutter_local_notifications`
- Firebase Cloud Messaging / APNs bridge for background push delivery
- Sentry (preferred) or equivalent crash/error telemetry layer

### 4.2 Why this stack

#### Riverpod

Riverpod gives us:

- DI and reactive state in one system
- provider families keyed by explicit runtime scope
- testable store/controller wiring without a global service locator

That is a strong fit for Slock's server/channel/thread/agent scoped data model.

#### Drift

A bounded relational cache is the pragmatic choice because the product already needs:

- server-scoped lists
- recent message timelines
- local search over cached data
- reconnect recovery
- saved message list pagination metadata

Drift gives enough structure for that without forcing a full offline sync engine.

#### Dio

The backend surface needs:

- auth refresh
- multipart upload
- request interceptors
- scoped headers and retries
- typed failure mapping

Dio is the most pragmatic fit.

Token refresh in the Dio layer must be serialized:

- only one refresh request may be in flight at a time
- concurrent 401s must wait on the same refresh future
- repositories/controllers must not each trigger their own refresh race
- do not use blocking primitives that would stall the Dart event loop

#### GoRouter

Deep-link semantics are not optional in this product:

- notification taps
- channel open
- thread reply entry
- profile detail entry
- agent detail entry
- saved messages entry

GoRouter keeps those semantics explicit and testable.

## 5. Proposed App Structure

Start as a single Flutter app with clean internal boundaries.

```text
lib/
  app/
    bootstrap/
    router/
    shell/
    theme/
    widgets/
  core/
    auth/
    config/
    errors/
    logging/
    network/
    notifications/
    realtime/
    storage/
    telemetry/
    utils/
  stores/
    session/
    channel/
    message/
    thread/
    agent/
    presence/
    saved_messages/
    notification/
  features/
    auth/
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
    usecase/
  application/
    controller/
    state/
    provider/
  presentation/
    page/
    section/
    widget/
```

Do not split into multiple packages until there is an actual extraction need.

## 6. Canonical State Model

Flutter should start with canonical stores for shared state, not grow them later through cleanup work.

| Concern | Canonical owner | Notes |
| --- | --- | --- |
| auth session, user, selected server | `SessionStore` | `selectedServerId` is UI/session convenience only, not implicit repository scope |
| channel previews, unread counts, current visible channel | `ChannelStore` | mirrors Android's cleaned-up unread model |
| message timelines, pagination cursors, pending optimistic ops | `MessageStore` | channel-scoped data, not a global message bag |
| thread summaries, follow state, done state | `ThreadStore` | shared between thread inbox and thread detail entry |
| agent catalog, latest activity, runtime status | `AgentStore` | mirrors Android's cleaned-up agent model |
| presence / online ids | `PresenceStore` | separate from agent or member stores |
| saved message ids and saved list pagination | `SavedMessagesStore` | start directly with message-level semantics |
| foreground/background + visible channel + push token metadata | `NotificationStore` | do not bury notification state in random widgets |

Rule:

- screens and controllers may derive view state
- shared truth belongs in stores
- repositories fetch/write data; they do not own presentation state

## 7. Data Stability Rules

This is the most important part of the Flutter architecture.

### 7.1 Read path

For list and timeline surfaces, the default flow should be:

1. controller requests data with explicit scope
2. repository returns cached local snapshot immediately if it exists
3. repository refreshes from network in the background
4. normalized models are written back to Drift and canonical stores
5. before writing back, verify the request still belongs to the current session scope
6. UI updates from local/store observation, not from ad hoc callback state

This gives fast re-entry without turning the whole app into an uncontrolled offline sync engine.

The read path must explicitly guard against stale responses after a server switch.

Recommended pattern:

- capture a `serverEpoch` or equivalent session-scope version when the request starts
- when the response resolves, verify that the epoch and `serverId` still match the active session scope
- if the user switched servers while the request was in flight, drop the result silently instead of writing cross-server data into the cache/store

### 7.2 Write path

For message send, mark read/unread, save/unsave, task mutations, agent control, and similar actions:

1. controller captures intent
2. optimistic mutation is applied in the canonical store
3. previous state is retained for rollback
4. REST request is performed
5. socket or refresh reconciliation de-duplicates by id/seq/version
6. failure rolls back and emits user-facing feedback

Any batch API that takes message IDs must filter out optimistic IDs before sending. Temporary optimistic message IDs should use a deterministic prefix such as `optimistic-` so they are easy to exclude from real API calls.

### 7.3 Explicit rules

- no widget talks directly to a repository
- no controller owns authoritative shared truth if a store exists for that concept
- every mutation must define its optimistic and rollback behavior up front
- every socket event must be classified as either **shared state** or **screen-local consumption**

### 7.4 Cache scope and budget

Recommended V1 cache policy:

- cache server/channel/DM/task/agent lists per server
- cache only recent messages per channel/DM, not full history by default
- keep saved message pagination metadata, not an unbounded full dump
- keep search indexes bounded to cached local windows

The first implementation should prefer **bounded freshness** over fake offline completeness.

## 8. Realtime Architecture

### 8.1 Single reduction path

Flutter should have one normalized realtime flow:

1. `RealtimeService` receives raw Socket.IO events
2. event mapper converts them to typed domain events
3. reducers update canonical stores once
4. controllers/pages watch stores

Do not let both list and detail controllers patch the same shared event separately.

### 8.2 Shared vs local consumption

The Android cleanup work shows the right distinction:

- **shared**: unread counts, agent latest activity, runtime status, saved message ids
- **local**: ephemeral activity log ordering, current menu open state, transient scroll target, screen-local animation state

Flutter should preserve that line from day 1.

### 8.3 Scope rules

No repository or reducer should silently read a global server id.

Good:

```dart
await ref.read(channelRepositoryProvider).getChannels(serverId: serverId);
```

Bad:

```dart
await ref.read(channelRepositoryProvider).getChannels();
```

### 8.4 Reconnect recovery

Flutter should not fall back to a full reload on every reconnect.

Recommended reconnect recovery model:

- persist a last known sequence number (`lastSeq`) for each active timeline scope
- on reconnect, emit a `sync:resume` style request with that sequence number
- process the server's gap-fill response through the same reducer/store path as normal realtime events
- if the response indicates `hasMore`, continue incremental fetch from the same scope
- fall back to a full reload only when the gap is truly unbridgeable

This keeps reconnect recovery fast and avoids unnecessary visual reset on large timelines.

### 8.5 Connection health watchdog

Do not rely on the socket library's built-in reconnection loop alone.

Flutter should implement a connection-health watchdog with two independent clocks:

- `lastHeartbeatAt`
- `lastAnyEventAt`

If the heartbeat age exceeds one threshold and the any-event age exceeds a larger threshold, force a reconnect. This protects against half-open TCP connections, silent proxy drops, and other states where the socket appears connected but no useful traffic is flowing.

## 9. Notification Architecture

Notifications need their own architecture document-worthy rules because Android already proved they regress easily.

### 9.1 Foreground behavior

Keep the current product semantics:

- if the app is foregrounded and the user is already viewing the same channel, suppress the extra notification
- if the app is foregrounded but the incoming event belongs to another channel, allow local/in-app notification behavior

Do this through an explicit `currentVisibleChannelId` in `NotificationStore`, not through route guessing.

### 9.2 Background behavior

Do **not** architect Flutter around a permanently alive background socket.

Production model:

- foreground live sync: socket
- background delivery: FCM/APNs
- local rendering / tap handling: `flutter_local_notifications`
- deep-link routing: centralized `DeepLinkRouter`

This is the only approach that stays sane across Android and iOS.

### 9.3 Deep-link contract

Every notification-triggered route must be reconstructable from explicit params:

- server id / slug when needed
- channel id
- optional channel name / message id / thread id

The deep-link parser must be tested directly.

### 9.4 Push token lifecycle

The app must explicitly handle:

- permission state
- token registration
- token refresh
- logout/unsubscribe cleanup
- notification preference changes

No feature should assume push setup is already complete.

## 10. Performance Rules

Flutter should be fast by policy, not by accident.

### 10.1 Startup

On cold launch, only bootstrap:

- session restore
- selected server
- minimal workspace shell state
- notification permission/token initialization

Do not eagerly load all domains on app start.

### 10.2 Lists and timelines

- paginate timelines in bounded pages
- virtualize every long list
- avoid provider graphs that recompute whole lists on single-item changes
- use normalized ids and derived item view models where needed

### 10.3 Search

- search should merge bounded local cache and remote fetch
- debounce input
- do not block the main isolate with large JSON transforms if the payload is large enough to justify isolate work

### 10.4 Media and attachments

- render thumbnails/previews lazily
- avoid decoding large images synchronously during list build
- keep upload state in dedicated operation state, not mixed into unrelated screen flags

### 10.5 Performance budget direction

Before shipping a vertical slice, reviewers should ask:

- does entering this screen require more data than the user can currently see?
- is the cache bounded?
- is the optimistic state scoped narrowly?
- can the same socket event cause multiple list rewrites?

If the answer is yes, the implementation is probably over-fetching or over-reducing.

## 11. Error Handling and Crash Feedback

This area needs to be stronger than Android's current custom crash dialog alone.

### 11.1 Global capture

Install all three:

- `FlutterError.onError`
- `PlatformDispatcher.instance.onError`
- `runZonedGuarded`

### 11.2 Telemetry

Use Sentry or an equivalent crash/error telemetry layer to capture:

- fatal crashes
- uncaught async exceptions
- request failures with context
- route breadcrumbs
- notification and realtime breadcrumbs

### 11.3 Local diagnostics bundle

Also keep a local ring buffer of recent diagnostics so the user can export a report even if remote telemetry is unavailable.

The exported bundle should include:

- app version / build number
- current user id if available
- current server/channel/thread route context if available
- recent logs
- recent network failures
- recent realtime connection state transitions

### 11.4 User-facing failure feedback

Every async action should choose one of these intentionally:

- inline error state
- transient toast/snackbar
- blocking dialog
- silent retry with bounded backoff

"Do nothing" is not an acceptable failure policy.

Repositories must map transport and backend errors into a typed failure domain. The app should define a sealed `AppFailure` hierarchy at minimum covering:

- `NetworkFailure`
- `AuthExpired`
- `ServerError(code, message)`
- `NotFound`
- `Timeout`
- `Unknown`

Widgets should receive typed failures or presentation-ready messages, never raw `DioException` objects.

## 12. Routing Model

Recommended primary routes:

- `/splash`
- `/login`
- `/register`
- `/forgot-password`
- `/home`
- `/servers/:serverId/channels/:channelId`
- `/servers/:serverId/dms/:channelId`
- `/servers/:serverId/threads`
- `/threads/:threadId/replies`
- `/servers/:serverId/tasks`
- `/servers/:serverId/agents`
- `/agents/:agentId`
- `/servers/:serverId/machines`
- `/saved-messages`
- `/settings`
- `/profile`
- `/profile/:userId`
- `/billing`
- `/release-notes`

Rules:

- params carry scope explicitly
- params must be scalar ids only; never serialize full domain objects into route params
- notification deep links are built in one helper layer
- route parsing gets direct tests

If a destination needs a full object, it should resolve that object from a store or repository using the passed id.

## 13. Delivery Order

### Phase 0: Foundation

- CI, lint, formatting, codegen
- route shell and design tokens
- auth bootstrap
- Dio / storage / socket / notifications / telemetry foundation

### Phase 1: Workspace scope and home shell

- selected server persistence
- channel list + DM list
- `ChannelStore` unread pipeline
- explicit scoped repository calls

### Phase 2: Message room

- paginated timeline
- send message
- attachments
- read/unread actions
- saved message toggle and `savedIds`
- foreground notification suppression wiring

### Phase 3: Saved Messages final UI

- saved messages list page
- route and entry placement
- deep-link open to source message

### Phase 4: Threads and tasks

- thread inbox
- reply timeline
- task list and convert-from-message

### Phase 5: Agents, members, machines, profile

- `AgentStore`-driven list/detail
- presence-aware members/profile flows
- machine status flows

### Phase 6: Settings, billing, release notes, hardening

- notification preferences
- release notes
- billing pages
- reconnect, push token, telemetry hardening

## 14. Explicit Non-Goals and Anti-Patterns

Do not do these:

- do not recreate `ActiveServerHolder` in Flutter
- do not let repositories read hidden scope from a global singleton
- do not patch the same shared socket event in both list and detail controllers
- do not build a `SavedChannels` compatibility abstraction in Flutter
- do not rely on background sockets as the primary mobile notification transport
- do not start with an unbounded offline sync engine
- do not split the repo into packages before real extraction pressure exists

## 15. Bottom Line

The first draft had the right direction. This revision turns it into a stricter build contract.

If Flutter follows these rules, it should inherit Android's product maturity **without** inheriting Android's temporary architecture debt.

If someone disagrees with a decision here, the objection should be framed against one of the actual goals:

- data stability
- notification stability
- loading performance
- crash/error feedback
- reviewability of future work

Those are the criteria that matter.
