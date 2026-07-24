# Release Package

Release ZIPs should be structured with a single top-level addon folder:

```text
MicroGames/
```

The ZIP should extract directly into WoW's addon directory:

```text
World of Warcraft/_classic_era_/Interface/AddOns/MicroGames/
```

## Recommended ZIP Contents

Include:

```text
MicroGames/API.lua
MicroGames/CHANGELOG.md
MicroGames/LICENSE
MicroGames/MicroGames.lua
MicroGames/MicroGames.toc
MicroGames/README.md
MicroGames/UI.lua
```

Rationale:

- `MicroGames.toc`, `API.lua`, `UI.lua`, and `MicroGames.lua` are required runtime files.
- `CHANGELOG.md` helps users understand what changed in the packaged version.
- `README.md` gives GitHub, CurseForge, and downloaded ZIP users a short feature and install overview.
- `LICENSE` should be included because the project is MIT licensed.

## Do Not Include By Default

Do not include these in the runtime addon ZIP unless there is a specific reason:

```text
AGENT.MD
DEBUG.MD
DEV.MD
docs/
assets/
release/
.git/
.idea/
.wowluarc.json
MicroGames.sln
```

Rationale:

- `AGENT.MD`, `DEV.MD`, `DEBUG.MD`, and `docs/` are development notes.
- `assets/` contains project/page assets, including CurseForge logo files, not runtime addon files.
- `release/` contains generated archives and must not be nested into another release archive.
- IDE, Git, and language-server files are not needed by addon users.

## CurseForge Assets

Use this file for the CurseForge addon logo when a sub-100 KB image is required:

```text
assets/microgames-logo-coin-spotlight-512.jpg
```

Keep the PNG variants in the repository as source/reference assets, but do not include them in the addon runtime ZIP by default.
