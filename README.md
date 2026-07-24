# MicroGames

MicroGames is a World of Warcraft Classic Era / Hardcore addon for running small raid games during guild events.

It was built specifically for the **DICE** guild workflow, with the game master using the addon to prepare the raid, assign stable player numbers, run `/roll` based rounds, announce winners, and keep a local history of completed sessions.

## What It Does

- Opens a movable in-game UI with `/mg` or `/microgames`.
- Supports Single Raid gameplay for one raid group.
- Supports Multi Raid Coordinator / Assistant workflows for larger events.
- Records a raid snapshot and assigns stable MicroGames numbers.
- Excludes the local game master from Single Raid number assignment.
- Moves the game master into the last used raid subgroup before Single Raid recording.
- Sends number whispers through a throttled queue to avoid chat spam limits.
- Runs delayed round rolls with optional raid-warning countdowns.
- Detects the game master's own English client roll result.
- Resolves winners from the recorded snapshot, not the live raid order.
- Records completed sessions, rounds, winners, invalid offline rolls, and rewards in History.
- Provides optional live Monitoring for another MicroGames client in the same party or raid.

## Guild Addon

MicroGames is intentionally designed around a specific guild event style. The visible labels, setup flow, reward workflow, and logo assets are tailored for the **DICE** guild.

The code is still licensed for general use under MIT. Other guilds may use, modify, fork, or redistribute it as long as the license notice is preserved.

## Target Client

- WoW Classic Era / Hardcore
- Interface: `11509`
- English client roll text only

The addon relies on WoW's normal raid APIs and does not use external runtime dependencies.

## Basic Single Raid Flow

1. Join or form the raid as the game master.
2. Open MicroGames with `/mg`.
3. In Setup, press `Move GM to Last Spot`.
4. Wait until the Setup status says `Record Raid` is available.
5. Press `Record Raid`.
6. Press `Send Numbers` when ready.
7. Press `START GAME`.
8. Use `Round Roll` for each round.
9. Use winner and reward buttons as needed.
10. Press `STOP GAME` to save the completed session into History.

## Multi Raid Flow

Multi Raid mode is designed for one Coordinator and one or more accepted Assistants.

- The Coordinator invites Assistants by character name.
- Assistants accept the session, record their local raid, and send their roster.
- The Coordinator records the main raid and assigns global numbers.
- Assignment chunks are sent to Assistants through addon-message whispers.
- The Coordinator starts the Multi Raid game session and runs global rolls.
- Assistants relay Coordinator announcements and results into their own raid chat.
- When a global roll selects an Assistant raid player, that Assistant verifies the winner manually.
- Completed Multi Raid sessions are saved into the shared History list.

## Installation

For normal addon installation, extract the release ZIP so the folder layout is:

```text
World of Warcraft/_classic_era_/Interface/AddOns/MicroGames/
```

The addon folder should contain:

```text
API.lua
CHANGELOG.md
LICENSE
MicroGames.lua
MicroGames.toc
README.md
UI.lua
```

Restart WoW or reload the UI after installing:

```text
/reload
```

## Slash Commands

```text
/mg
/microgames
```

Both commands toggle the MicroGames window.

## License

MIT License.

Copyright (c) 2026 Christian Hamar alias krix
