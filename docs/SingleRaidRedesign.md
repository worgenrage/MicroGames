# Single Raid UI redesign plan

Status: design proposal only. No runtime changes implemented.

Exclusive release target: current WoW Forever. The verified reference as of 2026-10-12
is **1.60.1.70338**; see [Forever API baseline](ForeverApiBaseline.md).
Classic Era 1.15.x is no longer the design baseline. Modern Forever components
may replace Classic compatibility paths during implementation when source and
client validation support the change.

## Recovery baseline

- Baseline version: 0.2.9.
- Commit: `092c259857c15cecf8a06d383d70d8cebcebc65f`.
- Existing release tag: `v0.2.9`.
- Local and GitHub preservation branch: `archive/v0.2.9-before-ui-redesign`.
- Design branch: `design/single-raid-ui`.
- The baseline preserves the entire tracked source tree, documentation, tests,
  assets, release archives, and reachable Git history.
- The untracked local `release/MicroGames-0.1.3.zip` is not part of the baseline;
  leave it untouched. Ignored IDE configuration is not part of a source release.
- WoW SavedVariables live outside this repository. Git rollback does not restore
  live game data; back those up separately before testing future data migrations.

To inspect the original source alongside ongoing work, from the repository root:

```powershell
git worktree add --detach ../MicroGames-v0.2.9 v0.2.9
```

To return this checkout to the original source, first commit or stash any future
working changes, then use `git switch --detach v0.2.9`. Return to design work with
`git switch design/single-raid-ui`. Do not use a hard reset for routine recovery.

## Scope

The UI and supporting implementation may be rewritten from scratch. Reuse code
only when it helps the new design; the old file layout, UI plumbing, and Classic
compatibility paths are not constraints. Preserve gameplay invariants and plan
legacy Forever SavedVariables handling explicitly. This permission defines the
implementation approach; this document remains planning-only for now.

The new release is Forever-only. Keep the archived Classic-capable release and
its CurseForge files intact. Follow [release policy](ReleasePackage.md) so the
new artifact is not offered as an update for Classic installations.

Prioritize the Single Raid workflow that the user reports worked in practice.
Remove reward management and reward actions from the new workflow. Keep winner
announcements. Preserve historical reward data without requiring new reward data.
Multi Raid has not been tested in practice; keep it separate and experimental.
Research any alternative Forever architecture as a separate task before changing
the Multi Raid protocol or making new compatibility claims.

## Navigation and layout

- Use a persistent left menu: Game, Players, History, and Settings.
- Start with an approximately 820 by 600 window and a 150-170 wide sidebar.
  Validate actual sizing at different WoW UI scales before finalizing dimensions.
- Put Settings at the bottom of the sidebar.
- Move Monitoring to an advanced diagnostics section under Settings.
- Put experimental Multi Raid selection in Settings; lock mode changes during play.
- Keep close, minimize, and automatic trade collapse behavior.
- Retain English UI text, clear disabled-state explanations, and textual status
  alongside color. Keep primary controls in stable positions.

## Game: preparation

Show three progressive steps on the same page:

1. Prepare Raid: explain GM exclusion and movement, perform the existing GM move,
   wait for verified completion, then record the snapshot. Stop on failure and
   explain the failed step. Do not send numbers automatically.
2. Send Numbers: show queued/sent/failed counts and any restriction pause.
   A successful API call must not be presented as confirmed recipient delivery.
3. Start Game: show the recorded participant count and message-send summary;
   starting always requires an explicit user action.

Collapse completed steps to short summaries. Show missing raid membership or
permissions before the user begins. Make the participant list available through
Players rather than placing setup controls below a long roster.

Decision to validate during implementation: whether failed number sends require
an explicit acknowledgement before start. Never silently treat them as complete.

## Game: active session

- Header: session state, current round, recorded participant count.
- Center: current winner name and MG number, or countdown/pending/error state.
- Primary action: Roll Round N, or Reroll This Round after an invalid result.
- Secondary action: reroll a valid round, with confirmation naming the winner
  that will be replaced. Retain earlier attempts in round history.
- Announce Winner: propose one explicit action for raid announcement plus whisper,
  with separate send outcomes. Keep individual channels as secondary actions.
- Preserve the automatic-announcement preference; default off for new installs.
- Right column: a compact recent-round list, without rewards.
- Footer: separate End Game action with confirmation and a saved-history summary.
- When a new roll begins, move the preceding winner to recent rounds so it cannot
  be mistaken for the pending round's result.

State coverage: ready, countdown, waiting for system result, valid winner,
offline/absent winner, timeout, paused sends, partial send failure, and ended.

## Players

Use a scrollable roster with search by name or MG number. Default sort is MG
number. Distinguish recorded membership from current presence and message status.
Provide a selected-player Resend Number action and a Retry Failed bulk action.
Rebuilding the roster is available only before an active game.

Proposed mechanical change to review: allow a single player's recorded number to
be resent during an active game without unlocking snapshot mutation. Keep queue
throttling, restrictions, and cancellation behavior intact.

## History and Settings

History shows session date, participants, and round count, followed by per-round
winner, MG number, and time. Expand a round to see rerolls and invalid attempts.
Show an active session separately as Current Game to avoid apparent missing data.
Read legacy sessions safely, including sessions that contain reward fields.

Settings contains number-message text, countdown/delay, automatic announcement,
advanced diagnostics, and isolated destructive reset controls. Normal setup and
ending a game must not require Reset All.

## Gameplay invariants

- Exclude the GM and keep recorded numbers fixed throughout the game.
- Do not add newcomers or renumber departed players automatically.
- Offline/absent winners require another attempt in the same round.
- Failed round announcements must not advance a round or schedule a roll.
- Pending rolls prevent competing rolls, session ending, and setup mutation.
- Restore active sessions after reload; do not restore scheduled pending rolls.
- Rewards and winner announcements are not prerequisites for another round.
- Repeat winners remain allowed. A one-win-per-player mode is outside this phase.
- Preserve Forever secret-value and restriction safeguards. The redesigned
  release does not support Classic; its legacy release remains separate.

Investigate whether the GM move serves a guild requirement beyond numbering.
Initially retain it inside preparation. Removing it requires a targeted review
and a deliberate workflow decision, not just a visual redesign.

## Implementation sequence and acceptance

1. Build sidebar and page layout using verified Forever components and scaling.
2. Remove reward controls; preserve loading of existing SavedVariables/history.
3. Add guided preparation and the active-game state presentation.
4. Improve Players, History, Settings, and actionable status messages.
5. Validate any separately accepted mechanical changes.

Before release, update the changelog and existing behavior documentation. Run the
WoW Lua static check, relevant mocked regression tests, and `git diff --check`.
Perform actual client checks for preparation, full and partial number sending,
roll/reroll/timeout, offline players, announcement restrictions, reload, end-game
history, trade collapse, and old SavedVariables. Check shared-code changes for
Multi Raid regressions without calling its untested workflow verified.

No release version bump or completed-feature changelog entry belongs in this
planning-only change.
