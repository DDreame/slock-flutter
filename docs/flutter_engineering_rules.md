# Slock Flutter Engineering Rules

Last revised: 2026-04-19

This document is the implementation-side companion to `flutter_implementation_strategy.md`.

It defines the rules reviewers should enforce on every Flutter task and PR.

## 1. Scope Rule

Every branch/PR must declare:

- exact task
- locked scope
- explicit non-goals

If a change needs contract work, store work, and UI migration, land them in that order unless there is a proven reason they are inseparable.

## 2. Explicit Scope IDs Only

Repositories and use cases must receive explicit ids.

Required examples:

- `serverId`
- `channelId`
- `threadId`
- `agentId`
- `messageId`

Forbidden pattern:

- hidden global state that implicitly changes network/database scope
- writing request results back after the user has already switched to another server scope

Long-running reads should carry a `serverEpoch` or equivalent scope version and must drop stale responses if the active session scope has changed before the response resolves.

## 3. One Shared Truth Per Domain Concept

Examples:

- unread counts belong in `ChannelStore`
- agent latest activity belongs in `AgentStore`
- saved ids belong in `SavedMessagesStore`
- visible channel for notification suppression belongs in `NotificationStore`

Screens may derive view state, but they must not fork shared truth.

If both Drift and an in-memory store exist for the same domain area, the ownership split must be explicit:

- Drift may be the persistence/query truth for entity collections
- canonical stores own ephemeral shared runtime state and optimistic overlays
- the same shared concept must not accept independent writes in both places
- every canonical store write must validate a monotonic freshness key such as `seq`, `version`, `updatedAt`, or a documented scope-local revision
- older payloads must be rejected; a late REST response must not overwrite newer socket-reduced or optimistic-confirmed state

## 4. Realtime Events Are Reduced Once

If an event changes shared state, it must be reduced once in the realtime/store layer.

Scope refreshes must also behave like a single shared-state write:

- normalize the full scope payload first
- commit related data atomically per scope
- emit store updates once after the scoped write completes
- do not let widgets observe half-applied graphs

Only screen-local ephemeral behavior may stay local.

Examples of acceptable local-only state:

- scroll target
- sheet open/closed state
- detail-local chronological activity log
- animation state

## 5. Optimistic Mutations Require Rollback

Any optimistic action must define:

- optimistic state shape
- success reconciliation path
- rollback path
- user-facing failure feedback

No optimistic mutation should ship with an undefined rollback behavior.

Temporary optimistic message IDs should use a deterministic prefix such as `optimistic-`. Any batch API call that takes message IDs must filter those temporary IDs out before sending.

## 6. Compatibility Shims Must Be Temporary and Explicit

If a shim is unavoidable:

- isolate it at the edge
- do not let it re-expand old semantics into the new public API
- name the owner and removal phase in comments or task references

## 7. Notification Rules

- foreground suppression must use an explicit visible-target descriptor, not a bare channel id
- background delivery must rely on push, not a permanent background socket
- deep-link payload parsing must be centralized and tested
- notification preference logic must live in a reusable policy layer, not a widget

## 8. Realtime Recovery Rules

- reconnect recovery must prefer gap-fill (`lastSeq` / `sync:resume` style) over full timeline reload
- forced reconnect watchdogs should track both heartbeat age and any-event age
- socket libraries' built-in reconnect loops are not sufficient as the only health mechanism

## 9. Failure Handling Rules

- map transport failures to typed app failures
- do not leak raw transport exceptions to widgets
- every async operation must choose an explicit user-facing failure mode
- background and realtime failures must create breadcrumbs for diagnostics
- token refresh must be serialized so concurrent 401s wait on the same refresh future
- local diagnostics buffers must be bounded by count and age, with sensitive fields redacted by policy
- diagnostics should prefer request ids, scope ids, seq numbers, and failure types over raw payload dumps

The app should define a typed `AppFailure` hierarchy and use it consistently at repository boundaries.

## 10. Performance Budget Rules

The baseline budgets below are review gates, not aspirations:

- home shell may block on at most 2 requests before first interactive paint
- message-room initial entry should load one page only; secondary enrichment must stay bounded
- pagination and search must declare explicit debounce/threshold rules
- payloads above the agreed threshold must move parse/transform work off the main isolate
- a single item change should not force a whole-list rewrite when an id-scoped update path exists

If a change exceeds one of these budgets, it needs a written exception and a measurement plan.

## 11. Testing Rules

Minimum preferred stack:

- DTO serialization tests
- repository contract tests
- store/reducer tests
- widget tests for high-risk interactions
- deep-link parsing tests
- a very small smoke integration lane

Use structural/source-shape tests only where they protect historically fragile wiring.

## 12. CI Rules

Local development constraint:

- developer workspaces are assumed to have a hard `2GB RAM` limit
- local toolchain choices and verification workflow must be designed around that constraint

Workflow policy:

- run formatting checks, `flutter analyze`, and targeted tests locally as needed
- do not require full app builds or packaging verification on every task branch
- reviewers should reject "please run a full local build" as a default gate for ordinary feature work

Baseline CI should include:

- `dart format --set-exit-if-changed`
- `flutter analyze`
- unit tests
- widget tests
- one smoke integration/build lane

Full build, packaging, and artifact verification belong to CI/CD lanes.

Exception rule:

- if a task explicitly touches the build system, native integration, signing, packaging, or is debugging a build-specific issue, that extra build verification must be declared in the task's locked scope
- even in those cases, the default `2GB RAM` local workspace should not be assumed to carry full-build verification; use CI/CD lanes or a separately provisioned environment when needed

CI should stay fast enough that developers trust it and reviewers can require green runs on every meaningful PR.

## 13. Review Checklist

Reviewers should explicitly ask:

1. Is the scope narrow and clearly locked?
2. Is shared state owned by a canonical store?
3. Are ids explicit, or hidden behind global scope?
4. Are optimistic actions rolling back correctly?
5. Is the implementation using final contracts rather than introducing new shims?
6. Does this change worsen startup load, list recomposition, or cache size?
7. Are failures observable and user-reportable?
8. Are transport failures mapped to typed `AppFailure`, or are raw exceptions leaking to widgets?
9. Are route parameters scalar IDs only, with no serialized objects?
10. Can an older payload overwrite newer state, or do reducers enforce monotonic freshness?
11. Does a scope refresh commit atomically, or can the UI observe half-applied data?
12. Does the change stay within the documented performance budgets?
13. Are local diagnostics bounded and redacted?
14. Is local verification staying test-first under the `2GB RAM` workspace limit, with full-build verification owned by CI/CD rather than local developer machines?

If one of these answers is weak, the change is not ready.
