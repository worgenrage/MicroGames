# MicroGames Agent Notes

## Target Runtime

- Target client: WoW Classic Era / Hardcore 1.15.9.
- Supported client language: English only.
- TOC interface/API compatibility: `## Interface: 11509`.
- `Interface: 11509` is the WoW client/interface API compatibility number, not a Lua version.
- Lua target: Blizzard WoW addon sandbox, Lua 5.1 subset.
- Language Server flavor: `classic_era`.

## Lua Compatibility Rules

- Write only WoW Lua / Lua 5.1 compatible code.
- Do not use Lua 5.2, 5.3, or 5.4-only syntax or standard library features.
- Do not use:
  - `goto`
  - `_ENV`
  - `table.pack`
  - `table.unpack`
  - `__pairs`
  - `bit32`
  - normal Lua `require` / `package`
- Load order is controlled by the `.toc` file.
- Use ASCII-only identifiers, file/module names, slash command tokens, SavedVariables names, and constants.
- Use only WoW APIs available in Classic Era 1.15.9.

## WoW Lua LS

- Local executable:
  `C:\Users\hamar\AppData\Roaming\JetBrains\Rider2026.1\plugins\wowlua-ls\server\win32-x64\wowlua_ls.exe`
- If JetBrains updates move the plugin, search for `wowlua_ls.exe` under:
  `C:\Users\hamar\AppData\Roaming\JetBrains\`
- In Codex managed sandbox mode, AppData paths may be present but not readable/executable without an escalated shell command.
- Diagnostic command from project root:
  `& 'C:\Users\hamar\AppData\Roaming\JetBrains\Rider2026.1\plugins\wowlua-ls\server\win32-x64\wowlua_ls.exe' check .`
- Use the direct `check .` subcommand, not LSP stdio mode.
- After code changes, also run:
  `git diff --check`

## Local Tooling

- `rg.exe` is installed, but the current Codex PowerShell sandbox may not resolve it because the executable lives under AppData.
- Current Winget ripgrep executable:
  `C:\Users\hamar\AppData\Local\Microsoft\WinGet\Packages\BurntSushi.ripgrep.MSVC_Microsoft.Winget.Source_8wekyb3d8bbwe\ripgrep-15.1.0-x86_64-pc-windows-msvc\rg.exe`
- Current Codex-bundled ripgrep executable:
  `C:\Users\hamar\AppData\Local\JetBrains\Rider2026.1\acp-agents\.runtimes\node\24.13.0\npm-cache\_npx\6722ddab116cb282\node_modules\@openai\codex-win32-x64\vendor\x86_64-pc-windows-msvc\codex-path\rg.exe`
- If plain `rg` fails with "not recognized", first check sandbox access/PATH with `where.exe rg` and then use the full executable path with an escalated shell command when needed.
- For Markdown discovery, use a case-inclusive glob such as `-g '*.[mM][dD]'` because project files include uppercase `.MD`.

## Raid Numbering Model

- Do not use live WoW raid roster indexes as stable game identifiers.
- `GetRaidRosterInfo(index)` and `UnitInRaid(unit)` return current roster positions that can shift when the raid changes.
- Do not count or assign raid numbers during addon load.
- MicroGames should assign stable game numbers from a raid roster snapshot only when the game master explicitly starts numbering from the UX.
- Single Raid snapshots must exclude the local player running the addon.
- Store assignments by player name and by game number.
- A player leaving the raid does not free or shift their assigned game number.
- New players do not receive a number automatically during an active game unless explicit game logic is added.
- Stop should mark numbering inactive without clearing recorded assignments.
- Reset should clear recorded assignments.
- Number whispers must use the recorded snapshot from `StartRaidNumbering()`, not the current live raid roster.
- `StartRaidNumbering()` must not send whispers automatically; sending numbers is a separate explicit UX action through `SendNumbers()`.
- Single Raid recording must require the GM move step to be ready before `StartRaidNumbering()` creates the snapshot.
- Number whispers require active numbering; stopped snapshots may be viewed but must not be used for sending.
- Bulk number whispers must use the internal throttled send queue, not a tight loop of `SendChatMessage`.
- The default number whisper text is `Your MG number is: XX`; UI-provided text should be saved through the API and use `XX` as the number placeholder.
- Number whisper text must persist through `MicroGamesDB.numberWhisperText`.
- Single Raid scope is game-master-driven from one client. Multi Raid uses Coordinator/Assistant addon-message synchronization.
- Keep the detailed model in `docs/RaidNumbering.md` in sync with implementation changes.

## Rounds Model

- Do not advance rounds during addon load.
- `RoundRoll()` is the explicit UX action for the `Round Roll` button.
- `RoundRoll()` and `RerollCurrentRound()` require an active game session.
- Each `RoundRoll()` call increments the round counter by 1.
- `RerollCurrentRound()` must roll again for the current round without incrementing the round counter.
- Rerolls should be recorded under the same round in session data.
- The UI should show both the current round and the previous completed round.
- During `ROUND 1`, there is no previous completed round, so show `-`.
- Announce rounds in raid chat as `ROUND X`.
- If the `ROUND X` raid announcement cannot be sent, do not advance the round or schedule the roll; show a clear GM warning.
- After a short delay, roll from 1 to the recorded eligible raid number count.
- The roll range must use the `StartRaidNumbering()` snapshot count, not the current live raid size.
- Use `RandomRoll(1, recordedCount)` for the actual roll; `BuildRollCommand()` is only a display preview.
- Detect the pending roll result from `CHAT_MSG_SYSTEM`, accept only the game master's own roll, and resolve the winner against the recorded snapshot.
- If the resolved snapshot player is offline in the current live raid roster, record the roll as invalid and require a reroll for the same round.
- Offline invalid rolls must not change or shift assigned player numbers.
- Roll result parsing only needs to support English client `CHAT_MSG_SYSTEM` roll messages.
- Pending roll state must not persist through `/reload` because scheduled roll timers do not survive reload.
- The UI should prominently show the winner number and matching player name after a roll.
- Winner display should be visually separated from normal status text with a highlighted panel/color.
- Winner buttons should send `You win ROUND X! Your MG number #N was rolled. Come closer! :)` through say or whisper as separate explicit actions.
- Single Raid Control should expose a prominent, persisted `Auto Announce winner + whisper` checkbox that defaults to off.
- When enabled, a valid online Single Raid winner should queue `{rt1} ROUND X WINNER: [PlayerName] - MG #N! {rt1}` in raid chat and whisper the winner message.
- Automatic winner messages must use the throttled visible-chat queue, pause during chat lockdown, report partial failures, and never run for invalid/offline rolls, timeouts, Multi Raid rolls, or restored winner state after `/reload`.
- Reward templates should start with `10 GOLD!`, `20 GOLD!`, and `KROLL BLADE BOSS`.
- Reward templates must be expandable from the UI.
- Reward templates must persist through `MicroGamesDB.rewardTemplates`.
- Round roll delay must persist through `MicroGamesDB.roundRollDelay`.
- Roll countdown sound must persist through `MicroGamesDB.rollCountdownSoundEnabled`.
- Reward yells must be explicit button actions and must not be automatic after a roll.
- Reward history entries must only be recorded by an explicit reward button action through `SendRewardYell()`.
- Reward yell text should start with the winner name in `[WinnerName]: reward` format.
- Reward yell buttons should be available from the Control tab during gameplay.
- `Round Roll` should be the visually dominant gameplay action, with setup/reset controls kept compact.
- `Rounds 0` must not run while a roll is pending.
- `Roll Countdown Sound` should send `RAID_WARNING` countdown messages during the configured roll delay when enabled, so raid members receive the normal raid warning alert.
- Keep the detailed model in `docs/Rounds.md` in sync with implementation changes.

## UI Model

- Keep visible UI text in English.
- The main UI must be movable.
- Closing the UI must only hide it and must not reset numbering, rounds, whisper text, or game state.
- The main UI should support a collapsed mini mode that keeps state and can be expanded again.
- Opening a trade window should automatically collapse the main UI if it is visible.
- Closing a trade window should expand the main UI only if trade opening collapsed it automatically.
- Use tabs for separate concerns such as Control, Setup, Rewards, History, and Settings.
- Loading the addon may create UI and register slash commands, but must not count raid members, send whispers, or advance rounds.
- Keep UI behavior documented in `docs/UI.md`.

## Game Session Model

- Active Single Raid games must persist in `MicroGamesDB.activeSession`.
- Active Multi Raid games must persist in `MicroGamesDB.multiRaid.activeSession`, including round and winner state restored after `/reload`.
- Completed games must be appended to `MicroGamesDB.history`.
- `START GAME` starts or resumes the active session.
- `START GAME` must not create a second session if one is already active; return/report `ACTIVE_SESSION_EXISTS`.
- `STOP GAME` stops the active session, saves collected data to history, and clears runtime roster/round/winner state so the next game starts from a fresh raid snapshot.
- `STOP GAME` must not run while a roll is pending.
- UI buttons should visually reflect session state: START disabled while active, STOP disabled while inactive.
- UI should show a clear state line such as `EVENT STARTED - ROUND X - MEMBERS X`.
- Setup controls must use a Setup-local status line.
- Setup controls must be locked while a game session is active or a roll is pending.
- Active session state must survive `/reload`, window close/open, and addon UI recreation.
- Keep session persistence documented in `docs/Sessions.md`.

## Multi Raid Model

- Assistant selection/auth and Assistant roster readiness are separate states.
- The Coordinator may request an Assistant roster, but the request must not remotely create a roster snapshot.
- Assistants record their own local raid snapshot and send it to the Coordinator.
- Assistant local roster snapshots exclude the Assistant character.
- If the Assistant's local raid roster changes after recording, mark the local roster stale and require a new record before sending.
- The Coordinator records its own main raid separately, assigns one global number range, and sends Assistant ranges through addon-message whispers.
- The Coordinator can dispatch number whispers after global assignment: local main-raid players are whispered by the Coordinator, Assistant raid players are whispered by their accepted Assistant.
- Chunked Multi Raid roster and assignment sync should use the internal addon-message queue to avoid per-prefix addon-message throttling.
- Chat or addon-message lockdown must pause queued sends without dropping items; resume them after `ADDON_RESTRICTION_STATE_CHANGED` once `C_ChatInfo.InChatMessagingLockdown()` is false.
- Treat `Enum.SendAddonMessageResult.AddOnMessageLockdown` as a temporary restriction, not as a permanent send failure.
- Multi Raid round rolls and rerolls require an active Multi Raid game session started by the Coordinator.
- Active Multi Raid games must lock roster recording, roster sending, and global assignment mutation.
- Completed Multi Raid games are stored in the shared `MicroGamesDB.history` list with `sessionType = "multi"`.
- Multi Raid history should retain the multi session ID, Coordinator, global assignments, raid ranges, Assistant summaries, winner raid IDs, and manual Assistant-check status.
- Cross-raid winner presence is checked manually by the responsible Assistant; do not send automatic winner verification requests.
- Roster and assignment chunk receivers must reject incomplete, duplicated, out-of-range, or header/footer-mismatched payloads.
- Reset and clear operations must cancel pending visible-chat and addon-message queues.
- Coordinator multi-raid rolls are authoritative, but other raids cannot see the native system roll; Assistants relay Coordinator round and roll result messages into their own raid chat.
- Assistant relay must only run for the accepted Coordinator/session pair.
