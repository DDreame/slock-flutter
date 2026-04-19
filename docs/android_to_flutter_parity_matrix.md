# Android to Flutter Parity Matrix

## Status Key

- `Merged`: already on Android main
- `In flight`: actively landing on Android but not yet the clean final user-facing state
- `Legacy shim`: works on Android today but should not be copied into Flutter

## Product Surface Snapshot

| Domain | Android status | Important Android behavior | Flutter starting point |
| --- | --- | --- | --- |
| Auth | Merged | login, register, forgot password, token refresh, logout | Build as Phase 1 baseline |
| Home shell | Merged | home merges server/channel workspace tabs and quick navigation | Keep unified workspace shell |
| Servers | Merged | server switch, server selection persistence | Persist selection, but keep repository calls explicitly scoped |
| Channels | Merged | list, create, edit, delete, leave | Port in Phase 2 |
| DMs | Merged | DM list, preview, create DM | Port in Phase 2 |
| Unread state | Merged | unread comes from centralized `ChannelStore` | Start directly with canonical `ChannelStore` |
| Search | Merged | local cache search plus remote message search merge | Port with bounded cache, not global search service magic |
| Messages | Merged | paginated timeline, socket insert/update, attachments | Phase 3 core slice |
| Message read/unread actions | Merged | optimistic mutation with rollback and feedback | Keep same UX semantics |
| Message convert-to-task | Merged | long-press action to create task from message | Phase 4 after core timeline |
| Message reactions | Partial/in flight elsewhere | recent Android work indicates message action surface is expanding | Reserve space in message action model early |
| Threads | Merged | inbox, reply flow, follow/unfollow, done/undone | Phase 4 |
| Tasks | Merged | server task list, create, update, delete | Phase 4 |
| Agents | Merged | list/detail/control with shared `AgentStore` | Start directly with canonical `AgentStore` |
| Agent runtime/activity | Merged | latest activity and runtime status are centralized | Do not duplicate list/detail activity state |
| Machines | Partial but present | list/delete plus machine status events | Phase 5 secondary module |
| Members | Merged | server member list and DM entry | Phase 5 |
| Profile | Merged | own profile, other user profile, presence-aware state | Phase 5 |
| Settings | Merged | account refresh, notification preferences | Phase 6 |
| Notifications | Partial/hardening | foreground same-channel suppress, deep-link open, socket-based local notifications | Keep semantics; re-implement background strategy for Flutter/iOS |
| Billing | Merged | subscription summary and plans page | Phase 6 |
| Release notes | Merged | standalone release notes page | Phase 6 |
| Saved Messages contract | Merged | data layer already moved to message-level contract | Use as-is from day 1 |
| Saved Messages toggle | Merged | message-level save/unsave + savedIds lookup are now landed | Build directly on final contract |
| Saved Messages UI | In flight | Android still has old `SavedChannels` UI path | Flutter should skip old path and build final message-level screen |

## Architecture Parity Decisions

| Concern | Android current state | Flutter decision |
| --- | --- | --- |
| Shared agent state | `AgentStore` is now canonical | Mirror with `AgentStore` from day 1 |
| Shared unread state | `ChannelStore` is now canonical | Mirror with `ChannelStore` from day 1 |
| Visible channel tracking | explicit lifecycle tracking for notification suppression | Keep explicit `currentVisibleChannelId` in notification/session store |
| Socket event reduction | moving toward store-level reduction | Centralize all shared reducers behind `RealtimeService` |
| Server scope | Android still carries `ActiveServerHolder` debt | Do not copy this debt; pass `serverId` explicitly |
| Saved messages semantics | Android has temporary compatibility shim | Start directly from message-level semantics |
| Cache layer | Room-backed bounded local cache | Use Drift-backed bounded local cache |
| Design system | Neo-Brutalism component set | Preserve visual language via reusable Flutter design tokens/components |

## Delivery Rules to Carry Over

| Rule from Android delivery process | Flutter equivalent |
| --- | --- |
| lock exact scope per task/PR | every Flutter branch must declare scope and non-goals |
| land contract before UI | do DTO/repository/store work before page rewrites |
| keep one source of truth | shared state belongs in stores, not duplicated controllers |
| minimize compatibility shims | shims only at edges and only temporarily |
| targeted re-review after small CI-only deltas | keep follow-up diffs narrow and easy to re-review |
| merge only after approved review + green CI | keep same merge discipline |
| protect risky wiring with structural/source tests | use targeted architecture and route tests where warranted |

## Explicit Anti-Patterns for Flutter

Do not do these:

- do not introduce a global mutable active server holder for network transport
- do not patch the same socket event in both list and detail layers
- do not recreate `SavedChannels` in the public API or UI model
- do not treat Android foreground-service notification design as cross-platform truth
- do not begin with a multi-package repo unless a real extraction need appears
- do not overbuild offline sync before the online-first message workflow is stable

## Recommended Review Lens for Future Flutter Work

When Flutter implementation starts, reviewers should ask:

1. Is the scope locked and narrow?
2. Is state shared through a canonical store, or duplicated?
3. Is `serverId`/`channelId` explicit, or hidden in global state?
4. Are optimistic actions rolling back correctly?
5. Is the implementation using final contracts or adding a new shim?
6. Is the test coverage focused on the real regression risk?

If those answers stay clean, Flutter will track Android product maturity without inheriting Android's temporary architecture debt.
