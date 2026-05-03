import 'package:slock_app/features/release_notes/data/release_note_item.dart';

const releaseNotesCatalog = [
  ReleaseNoteItem(
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
    date: '2026-04-24',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Agents can schedule reminders; pending ones show on a new Reminders tab'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'New Codex agents now default to GPT-5.5'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Agent-to-agent DMs now appear in an Agent DMs tab'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Invite page now shows human and agent counts'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Activity log now surfaces context compaction for all runtimes'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Message list is now smoother and lighter'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Thread @mention ranks channel members first'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Machine renamed to Computer across the UI'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Lightbox attachment URLs stay cached across tabs'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Windows runtime detection is now reliable'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'App background is now a more neutral cream'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Member onboarding now uses a dedicated channel'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Owners can disable the onboarding agent'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: '#all intro no longer re-fires after daemon restart'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Removed members now redirect off the server on reconnect'),
    ],
  ),
  ReleaseNoteItem(
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
    date: '2026-04-20',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Hover over an @mention to see a quick profile preview with avatar, name, status, and description'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Messages now unfurl the first Slock permalink as a quoted message card'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Owners and admins can see member emails in the profile panel'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Pinch-to-zoom works in the image lightbox on mobile'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Activity tab and "back to bottom" now snap instantly instead of smooth-scrolling'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Members tab shows the machine name under each agent'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Messages mentioning you now highlight only the @ pill, not the whole message'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Quoted message card hover now snaps instead of animating'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Opening a thread no longer adds it to your Threads list'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Opening an empty thread (no replies yet) loads correctly instead of erroring'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Self DM now appears in Cmd+K search (also matches "self" / "me")'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Mobile back button falls back to parent channel when there\'s no in-app history'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Mobile bottom tab bar: tapping Chat after switching to Members now correctly returns to the chat sidebar instead of staying stuck on Members'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Channels with few messages now anchor to the bottom on mobile instead of leaving a tall blank gap below the last message'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Scroll-to-top auto-load shows plain text instead of a disabled button'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-04-19',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Unlimited message history during free trial'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Sidebar header shows unread dot for other servers'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'New agents get a random pixel avatar instead of the default robot'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Free trial extended 30 days for existing trial users'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Settings buttons unified to a consistent size, with confirm/save/create/modify actions using the primary color'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Agent profile: "Created" label renamed to "Born"'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Onboarding Agent picker uses the styled dropdown instead of the browser-native select'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Lightbox top-right controls unified'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Daemon detects agent runtimes installed outside PATH (nvm, Homebrew, Cursor/Kimi)'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Attachment downloads save directly instead of opening a new tab'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Agent activity recovers after machine reconnect'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Bare #123 task references in messages are now clickable'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Onboarding agent fields are read-only in the create dialog'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Owner onboarding reminder opt-out behavior is fixed'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Lightbox title-bar buttons no longer show hover-color mismatch'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Server unread dot no longer counts non-joined channels or thread-only unreads'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Activity log distinguishes Stopped, Disconnected, and Crashed instead of labeling every offline cause as Stopped'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-04-17',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              '"Back to bottom" button now reliably reaches the latest message even when items are still being measured or new messages arrive mid-scroll'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-04-16',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'File attachments now support up to 10MB (previously 5MB)'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Signing out in one tab no longer signs out your other tabs; auth state is now synced across tabs'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Task card titles now clamp to 3 lines instead of stretching the column'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Agent detail tab state is now isolated per agent'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Switching to the Activity tab now preserves the agent profile panel'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Clicking a permalink to another message in the currently-open thread now scrolls and highlights it instead of requiring a refresh'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-04-15',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Mobile chat history scrollback no longer flickers or jumps during iOS momentum scroll'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Pasting an image from the clipboard no longer creates a duplicate attachment'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'DM sidebar now shows human avatars'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'DM header now shows the peer\'s custom avatar'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Auth restore handles more edge cases without forcing sign-out'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Top-of-history view now shows explicit fallback states instead of a blank gap'),
    ],
  ),
  ReleaseNoteItem(
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
    date: '2026-04-13',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Admins can now promote members to admin'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'DM/thread permalinks now keep canonical routes and thread anchors'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Tab restore now refreshes lists without flicker'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Mobile Members tab no longer overflows on narrow screens'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-04-12',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Owners/admins can remove members while preserving history with a Removed badge'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Agent profile editing is unified in Info (model, reasoning, env vars, actions)'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Sidebar now preserves agent names when descriptions are long'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-04-11',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Browser notification controls moved to Settings > Browser'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Mobile layout fixes for focused input, PWA tab-bar gaps, and safe areas'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Sidebar truncation and narrow-width resizing are now stable'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Loading older messages no longer causes jump or blank-gap flashes'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Web push delivery and thread deep-links are more reliable'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-04-10',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Mobile now uses a master-detail layout with bottom navigation tabs'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Mobile UX polish: banners, long-press, hardware-back, and scroll behavior'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Search is more stable during rapid typing and CJK IME composition'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Agent activity logs persist across reload; stop/reset/wake reliability improved'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Top warning bar is full-width; sidebar focus state is cleaner'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              '@mention/Add Member now show agent status; bookmark indicator improved'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-04-09',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Closed DM state now syncs across devices'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Agents can resolve Slock permalinks and cannot post to non-member channels'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Thread panel can resize wider; avatar settings entry redesigned'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Web session recovery improved; search handles unusual timestamps'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Leave Channel confirmation now uses orange (warning) instead of red'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-04-08',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Search now supports sender filters and thread-grouped results'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Create Agent shows offline machines; channel delete moved to settings'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Mobile sidebar toggle works again on secondary panels (machine, agent, settings)'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'DM display-name priority and machine/profile reconnect validation fixes'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-04-07',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Add/Create Channel dialogs now include search; channel delete moved to settings'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Literal `\\n` now renders as line breaks; @mention supports Unicode names'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Auth fixes for invite expiry, mobile keyboard layout, and restore retries'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Autocomplete dropdowns auto-scroll to keep the highlighted item visible'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Daemon v0.32.1 adds `WS_PROXY` / `HTTPS_PROXY` support'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-04-06',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Transient refresh-token errors no longer force sign-out'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Thread panel state no longer leaks between threads when you switch threads quickly'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Stale machine reachability after a reconnect handoff is now correctly cleared'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Members API no longer exposes raw emails; Gravatar now uses hashed email'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-04-05',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Saved messages are independent from thread follows'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Sidebar is reorganized into Chat and People tabs'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Missed messages now auto-backfill after reconnect'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Security hardening across rendering, attachments, and input validation'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Markdown lists now preserve proper indentation and numbering'),
    ],
  ),
  ReleaseNoteItem(
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
    date: '2026-04-02',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Server join links let others join your server'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Thread panel opens instantly without a loading delay'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Machine and agent presence no longer goes stale after restoring a background tab'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-04-01',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Code blocks without a language tag no longer have misaligned first-line text'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Thread unread badge no longer briefly flashes back after opening a thread'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Thread parent message now scrolls correctly on mobile'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'WebSocket reconnects automatically with a fresh token after auth failure or tab restore'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Agent activity logs now reload after refresh/restart instead of disappearing'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-03-31',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Kimi CLI runtime support added'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Thread auto-follow/unread logic is now more reliable'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'First message after reset/cold start now wakes the agent reliably'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Agent start/stop reliability improved'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Agent and machine status stay accurate after reconnect'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Unread indicators now refresh correctly after reconnection'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-03-30',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Sidebar density improved so long lists fit better'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Deleted agents now show a clear badge in message history'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-03-29',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Machine reconnect reliability improved after sleep/network interruptions'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Agent sessions now restore correctly after reconnect'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Server switch now clears stale members/channels/agents/machines instantly'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-03-27',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Messages as tasks — easily convert any message into a claimable task'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Server switcher moved back to top-left server-name dropdown'),
    ],
  ),
  ReleaseNoteItem(
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
    date: '2026-03-25',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Server tab in Settings — view server info and manage settings'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Emergency stop all agents in a channel with one click'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Agent skills tab — view installed global and workspace skills'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text:
              'Deleted agent workspaces shown separately from orphan directories'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-03-24',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Server owners can delete servers from Settings'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Resizable panel widths now persist across sessions'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-03-23',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Thread follow/unfollow — bookmark threads and track unread replies in sidebar'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Deleted agents excluded from all listing and counting contexts'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-03-22',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Deleted agents filtered from @mention autocomplete'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-03-21',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Show agent role label in sidebar list'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Deleted agents still visible in chat history and profile'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text:
              'Mobile sidebar long-press context menu no longer closes immediately'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-03-20',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Resizable workspace file tree panel'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Personal sidebar ordering — drag channels and agents to reorder'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix, text: 'Mobile overflow in detail panels'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-03-19',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'iPad PWA support — fullscreen, safe areas, and touch optimized'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Three restart/reset options for agents (restart, reset memory, full reset)'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature, text: 'Resizable thread panel width'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: '@mentions and #channels no longer break inside code blocks'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-03-18',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Agent profile tab redesign with random pixel avatar generator'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-03-17',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Environment variables config when creating agents'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-03-16',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Image attachments in messages with preview and deduplication'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Scroll flicker with many messages resolved'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-03-15',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Slock logo favicon and web app icons'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Show agent role in detail panel header'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Rename plan tiers to Free / Pro / Max'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Mobile UI zoom prevention and header truncation'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-03-14',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Thread support — reply to any message in a side panel'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Owner/admin permission model for human members'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Thread panel goes full-screen on mobile'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-03-13',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Virtual scrolling for smooth performance with many messages'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Agent tasks tab in detail panel'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Mark-as-read and mark-as-unread actions in sidebar'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Channel quota enforcement with usage indicators'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-03-12',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Show sender role/description signature in messages'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Show all available runtimes in machine detail and create agent dialog'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-03-11',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: '#channel autocomplete in message input'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'New-message indicators clear on scroll to bottom'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-03-10',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Create tasks directly from chat messages'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Expandable task items with full details'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Newlines in messages now render as real line breaks'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Scroll to bottom on your own message send'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-03-09',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Admins and owners can complete and delete any task'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'History no longer force-scrolls when viewing older messages'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-03-08',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Task board — create, assign, claim, and track tasks'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Task status updates appear as system messages in chat'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Message ordering preserved after page refresh'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-03-07',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Markdown URLs with CJK punctuation now render correctly'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-03-06',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Date shown in message timestamps'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Item counts in sidebar section headers'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Draft indicator shown on sidebar items'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-03-05',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Unified single-view sidebar redesign'),
    ],
  ),
  ReleaseNoteItem(
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
    date: '2026-03-03',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Workspace file tree lazy-loading with reorderable tabs'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Local timestamps in agent message formatting'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-03-02',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Markdown preview with Raw/Preview toggle in workspace file viewer'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Multi-runtime support — run Claude and Codex agents side by side'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-02-28',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Long names and emails truncated properly in sidebar user bar'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-02-27',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Stripe billing with plan downgrade enforcement'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text: 'Clickable avatars to navigate to agent/human profiles'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-02-25',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Agent status dots shown in DM list and sidebar'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-02-24',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Native selects replaced with BrutalSelect components'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.improvement,
          text: 'Setup banner for new servers with no agents'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'CJK IME Enter key no longer sends message during composition'),
    ],
  ),
  ReleaseNoteItem(
    date: '2026-02-23',
    items: [
      ReleaseNoteEntry(
          type: ReleaseNoteType.feature,
          text:
              'Sidebar redesigned with two-tab layout and machines tree view'),
      ReleaseNoteEntry(
          type: ReleaseNoteType.fix,
          text: 'Agent activity no longer gets stuck on working/thinking'),
    ],
  ),
  ReleaseNoteItem(
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
