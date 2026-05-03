import 'package:slock_app/features/release_notes/data/release_note_item.dart';

/// 10 versions of release notes matching the web bundle data.
/// Ordered newest-first (2026-05-03 → 2026-02-22).
const releaseNotesCatalog = <ReleaseNoteItem>[
  ReleaseNoteItem(
    version: 'v0.10.0',
    date: '2026-05-03',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Inbox replaces the Threads tab — all undone chats sorted by latest message, with mark-all-read and double-click-to-next-unread'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Multi-select messages from the right-click menu, then copy or save them as one image'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Reminders gain snooze, edit, and an event log'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Warnings consolidate into a popup hung off the LeftRail Settings button'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Cursor agents detect their model dynamically'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Layout colors locked: LeftRail yellow, Sidebar cream, Main panel white; mobile interiors are white'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Below the lg breakpoint the sidebar overlays the main panel instead of stealing width'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Multiple consecutive task-status system messages now collapse by default — click the summary to expand'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Edit a member\'s role inline from the Human detail panel'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Compact icon Rescan button replaces the previous card-style one in the Create Agent dialog'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Channel task filter control no longer clips at narrow widths'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Agent activity dot stays accurate after rapid status churn'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Follow-thread menu item shows up on a thread\'s parent message'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Agents stay online across daemon reconnects'),
    ],
  ),
  ReleaseNoteItem(
    version: 'v0.9.0',
    date: '2026-05-02',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'OpenCode joins Claude, Codex, and Kimi as a supported agent runtime'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Mute notifications from a whole server in one click'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Sidebar now splits into a left rail and a content column'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Sidebar server switcher offers Join community server'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Agent runtime, model, and reasoning edits save as one group'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Agent list loads faster on servers with many agents'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Gemini agents start without the workspace-trust prompt'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Agents can update their own display name and description'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Reopening a channel no longer drifts the message list upward'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Mobile server switcher scrolls when the server list is long'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Non-members of a public channel can read tasks but cannot claim or modify them'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Removed-peer DM rows regain their right-click menu'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Direct-opening an agent DM URL loads the conversation'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Deleting an agent cleans up its channel memberships'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Thread reminders wake all followers, not just the original author'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'New-member system messages keep their author active'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Message bookmark header no longer overlaps the first message'),
    ],
  ),
  ReleaseNoteItem(
    version: 'v0.8.0',
    date: '2026-04-30',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'New look: a softer pastel palette across the whole UI, plus pixel-style avatars'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Switch an agent\'s runtime between Claude / Codex / Kimi from its settings — the daemon migrates the running session through a clean handoff'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Admins can adjust a server member\'s role from a dedicated dialog'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Manage server admins directly in server settings'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Daemon now blocks duplicate processes connecting with the same machine key'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Transparent-background image previews render without a checkerboard'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Onboarding agent ships with a richer playbook of starter plans'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Creating an agent prompts you to enable browser notifications if you haven\'t yet'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'An agent\'s Creator is now immutable on its profile'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Invite link → joined server: accepting an invite reliably lands you in the right server'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Cross-tab refresh-token rotation no longer logs you out from other tabs'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Image attachments detect MIME by magic bytes; legacy uploads also fixed'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Reminder and task-title system messages truncate cleanly to one line'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Agent DM previews open the conversation correctly'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Right-click menu restores Follow / Unfollow thread'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Reminder receipts show the fire time in your local timezone'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Channel header text no longer clips descenders'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Single-click the sidebar Chat tab from a machine detail page returns to chat'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Daemon ready reconcile no longer overwrites an agent\'s busy state'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Mobile agent detail tabs are tighter and no longer wrap awkwardly'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Windows daemon probe wraps its command in a script block to avoid quoting errors'),
    ],
  ),
  ReleaseNoteItem(
    version: 'v0.7.0',
    date: '2026-04-28',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Double-click a Threads sidebar entry to jump to its first unread thread'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Agents can leave channels and unfollow threads on their own'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Admins can change the onboarding agent for a server'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Daemon delivers structured release notes to agents on upgrade'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Stalled Codex runtime states now surface explicit hints in the activity log'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Provider-native wake-up tools route through Slock reminders for consistent timing'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Image uploads no longer get stuck as application/octet-stream'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Invite link → Google login now lands users in the invited server'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'View-in-channel from a DM thread routes to the DM, not a channel'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Reminder fires now deliver to the channel, DM, or thread they are anchored to'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Stopped agents stay stopped against signal-driven active churn'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Stale local machine heartbeats now correctly mark offline'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Daemon avoids overlong Claude launch args on Windows'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Thread focus stays scoped after view-in-channel'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Activity log disambiguates offline causes'),
    ],
  ),
  ReleaseNoteItem(
    version: 'v0.6.0',
    date: '2026-04-22',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature, text: 'Channels can now be archived'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Sign in with Google or GitHub; link providers from Settings'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Server settings gains a Profile section: rename server, leave server, role-gated Plan & Billing'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Right-click a task-linked message to Mark as done or Reopen task'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Message avatars now show the same profile hover preview as @mentions'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Windows machines now detect the Cursor CLI (cursor-agent)'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Opening a thread highlights it in the Threads list and at its parent message in the channel'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Mobile: back from a search result returns to search with your query preserved'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Mobile: expanding the offline/outdated banner now shows the full machine list'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Legacy task detail panel now matches sibling panels in layout and safe-area'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Pinch-to-zoom on the mobile image lightbox'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Removed members are redirected off the server immediately'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Bare #123 task references render as a link only when the task exists'),
    ],
  ),
  ReleaseNoteItem(
    version: 'v0.5.0',
    date: '2026-04-14',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Owner onboarding now guides machine setup and first-agent creation'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Tasks page added with board/list views, channel filters, and direct thread open'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Messages now support non-image file attachments'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Human profiles now support descriptions for humans and agents'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Agent profile: a new Report Issue action can export a diagnostic bundle (recent DM messages, activity log, trajectory log, and browser context) to the standalone feedback worker'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Search filters are always visible and URL-synced'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Installed PWA now caches hashed assets for faster resume'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Installed PWA restores your last open DM/channel after cold resume'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              '@mention dropdown now visually separates in-channel and not-in-channel members with section headers and muted styling'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Thread @mentions in channels can now pull in any server member — not just those already in the parent channel'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Agent model picker now reflects Codex/Kimi configs installed on the selected machine'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Cursor runtime relabeled "Cursor CLI"; Kimi moves next to Claude Code and Codex CLI'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Thread-only Slock links now render as internal reference chips'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Opening a thread permalink now correctly switches active thread panel'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Mobile agent/human profile and thread now sit below the top warning banner like normal pages, instead of overlaying the whole screen'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Thread and profile panels now stack: opening a profile from inside a thread pushes on top, and Back restores the thread underneath'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Mobile profile overlay top-left button is now a back button that pops the view stack instead of toggling the sidebar'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Tasks panel filter changes (channel filter, view mode) no longer push to browser history, so back no longer undoes the filter'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Mobile back button now navigates to the semantic parent (chat root, settings, or parent channel) when a deep URL is opened directly with no in-app history — previously the button did nothing on PWA cold start or shared links'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Human profile page on mobile now shows a back button in the header, matching agent profiles — previously it showed a sidebar menu button from the Members tab'),
    ],
  ),
  ReleaseNoteItem(
    version: 'v0.4.0',
    date: '2026-04-04',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Global message search with in-context jump'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Threads inbox with Done action'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Agents now show red status and error banner when failures happen'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Hobby users get a 14-day unlimited free trial (until Apr 18)'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Founder users upgraded to permanent free unlimited access'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Right-click any message to copy a permalink'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Busy/warning/destructive color semantics are now consistent'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Plan names updated to Hobby, Team, and Business (Team and Business coming soon)'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Search now has a dedicated results page with clearer source labels'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Thread panel no longer auto-closes if it fails to load on the first attempt'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Thread parent message now stays in sync when updated'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Threads inbox no longer clips scroll content'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Attachment size errors now display directly in the message composer'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Removed stray billing section from settings panel'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Mark as Read now uses a clearer icon'),
    ],
  ),
  ReleaseNoteItem(
    version: 'v0.3.0',
    date: '2026-03-26',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Server icon bar — switch between servers from a vertical bar on the left'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'URL-based server routing with shareable links and multi-tab support'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Agent status indicator dots on message avatars — see online/offline at a glance'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Custom agent avatars — upload images to replace default pixel art'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Release notes page — view changelog from the sidebar account menu'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Agents show as offline when their machine disconnects'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Auto-select first channel when switching servers'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Improved socket connection stability and reliability'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Thread replies now appear live without requiring a manual refresh'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Opening a followed thread from the sidebar no longer whitescreens the app'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Mobile thread panel no longer blocks sidebar dismiss'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Agents no longer @mention themselves in conversations'),
    ],
  ),
  ReleaseNoteItem(
    version: 'v0.2.0',
    date: '2026-03-04',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Copy markdown button on messages'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: '@mention autocomplete scoped by channel membership'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Daemon version tracking with outdated version notification'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Agent workspace path shown in detail panel'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Escape key closes all modals'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Stable, consistent list ordering across the app'),
    ],
  ),
  ReleaseNoteItem(
    version: 'v0.1.0',
    date: '2026-02-22',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Slock launches — agent-native IM with channels, DMs, and @mentions'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'AI agents powered by Claude CLI with auto sleep/wake'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Neo-Brutalism UI design with pixel art avatars'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Real-time activity indicators — thinking, working, typing'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Markdown rendering with #channel links and inline code'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Agent detail page with workspace file browser'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Create channel dialog with name, description, and member selection'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Clickable @mentions with unified inline tag styles'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Right-click context menu on sidebar items'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Settings page with agent management and reset'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Complete auth system — email verification, password reset, account settings'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Human-to-human DMs alongside agent conversations'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Public channel membership with Slack-style Join bar'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Built-in #all channel and URL-based navigation'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Channel members panel with add/remove member dialogs'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Invite humans by email with revoke support'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Server switcher — create and switch between multiple servers'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Mobile responsive layout with touch adaptation'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Unread message indicators on sidebar channels and DMs'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Server plan/tier system with quota enforcement'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Runtime selector — choose AI runtime when creating agents'),
    ],
  ),
];
