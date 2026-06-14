# MicroGames Agent Notes

## Target Runtime

- Target client: WoW Classic Era / Hardcore 1.15.8.
- TOC interface/API compatibility: `## Interface: 11508`.
- `Interface: 11508` is the WoW client/interface API compatibility number, not a Lua version.
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
- Use only WoW APIs available in Classic Era 1.15.8.

## WoW Lua LS

- Local executable:
  `C:\Users\hamar\AppData\Roaming\JetBrains\Rider2026.1\plugins\wowlua-ls\server\win32-x64\wowlua_ls.exe`
- Diagnostic command from project root:
  `& 'C:\Users\hamar\AppData\Roaming\JetBrains\Rider2026.1\plugins\wowlua-ls\server\win32-x64\wowlua_ls.exe' check .`
- Use the direct `check .` subcommand, not LSP stdio mode.
- After code changes, also run:
  `git diff --check`

## Raid Numbering Model

- Do not use live WoW raid roster indexes as stable game identifiers.
- `GetRaidRosterInfo(index)` and `UnitInRaid(unit)` return current roster positions that can shift when the raid changes.
- Do not count or assign raid numbers during addon load.
- MicroGames should assign stable game numbers from a raid roster snapshot only when the game master explicitly starts numbering from the UX.
- Store assignments by player name and by game number.
- A player leaving the raid does not free or shift their assigned game number.
- New players do not receive a number automatically during an active game unless explicit game logic is added.
- Stop should mark numbering inactive without clearing recorded assignments.
- Reset should clear recorded assignments.
- Number whispers must use the recorded snapshot from `StartRaidNumbering()`, not the current live raid roster.
- `StartRaidNumbering()` must not send whispers automatically; sending numbers is a separate explicit UX action through `SendNumbers()`.
- The default number whisper text is `Your MG number is: XX`; UI-provided text should be saved through the API and use `XX` as the number placeholder.
- The current scope is game-master-only, so addon-message synchronization is not required yet.
- Keep the detailed model in `docs/RaidNumbering.md` in sync with implementation changes.

## Rounds Model

- Do not advance rounds during addon load.
- `RoundRoll()` is the explicit UX action for the future `Round Roll` button.
- Each `RoundRoll()` call increments the round counter by 1.
- The UI should show both the current round and the previous completed round.
- During `ROUND 1`, there is no previous completed round, so show `-`.
- Announce rounds in raid chat as `ROUND X`.
- After a short delay, roll from 1 to the recorded raid number count.
- The roll range must use the `StartRaidNumbering()` snapshot count, not the current live raid size.
- Use `RandomRoll(1, recordedCount)` for the actual roll; `BuildRollCommand()` is only a display preview.
- Detect the pending roll result from `CHAT_MSG_SYSTEM` and resolve the winner against the recorded snapshot.
- The UI should prominently show the winner number and matching player name after a roll.
- Winner buttons should send `You win ROUND X come closer! :)` through say or whisper as separate explicit actions.
- Reward templates should start with `10 GOLD!`, `20 GOLD!`, and `KROLL BLADE BOSS`.
- Reward templates must be expandable from the UI.
- Reward templates must persist through `MicroGamesDB.rewardTemplates`.
- Reward yells must be explicit button actions and must not be automatic after a roll.
- Keep the detailed model in `docs/Rounds.md` in sync with implementation changes.

## UI Model

- Keep visible UI text in English.
- The main UI must be movable.
- Closing the UI must only hide it and must not reset numbering, rounds, whisper text, or game state.
- Use tabs for separate concerns such as Control, Roster, and Settings.
- Loading the addon may create UI and register slash commands, but must not count raid members, send whispers, or advance rounds.
- Keep UI behavior documented in `docs/UI.md`.
