# Release Package

## Redesigned release: Forever only

Policy recorded 2026-10-12. The redesigned release must be distributed only for
WoW Forever. The dual-client instructions later in this document describe the
archived 0.2.9 package and do not apply to the redesigned artifact.

- Publish a new, distinctly named file such as `MicroGames-<version>-Forever.zip`.
  Final version numbering is not assigned yet.
- Keep one top-level `MicroGames/` folder, installed in the Forever client's
  `Interface/AddOns/` directory. Determine its location from the actual install.
- Include only the Forever runtime entry point/TOC and its required modules.
  Do not ship the old Classic `Interface: 11509` TOC in the new ZIP. Validate
  Camelot TOC discovery and current Interface metadata on the target client.
- Use an explicit runtime client guard before SavedVariables initialization or
  gameplay actions, so an unsupported client does not modify data if the package
  is manually installed there. Verify the guard against the actual Forever
  client; `WOW_PROJECT_ID == WOW_PROJECT_MAINLINE` alone is insufficient.
- Preserve the original 0.2.9 source/tag/archive and existing Classic downloads.
- Do not change, archive, delete, or retag existing Classic CurseForge files.
- Exclude downloaded API references and development documents from runtime ZIPs.

## CurseForge distribution

Checked 2026-10-12. CurseForge's upload documentation supports selecting game
versions per file. Its current catalog exposes a separate **Forever** flavor
and **1.60.1** version. Sources:

- [Official file upload guidance](https://support.curseforge.com/support/solutions/articles/9000197242)
- [Official addon flavor FAQ](https://support.curseforge.com/support/solutions/articles/9000198422-addons-faq)
- [Current Forever file classification example](https://www.curseforge.com/wow/addons/foreverforge/files/all)

Plan: keep the existing project, upload a separate normal release file, and
select only the current supported Forever version/flavor. Do not select
Classic Era, Hardcore, Anniversary, other Classic expansions, or Retail.
Retail/Mainline API ancestry does not make the addon a Retail release.

At publication, verify the actual uploader's supported-version options and
resulting file metadata; do not guess numerical CurseForge game-version IDs.
Check the file appears in the Forever filter and is absent from the Classic
filter. Verify a Classic installation in the CurseForge app is not offered the
Forever artifact as an update, while a Forever installation sees it. If this
separation cannot be verified, hold the upload and resolve the classification
rather than publishing a broadly tagged file.

The ZIP name, TOC Interface number, and release type alone do not replace correct
CurseForge metadata. Alpha/Beta/Release selects release maturity, not client
compatibility. Manual downloads can still be copied into the wrong installation;
the runtime guard prevents execution, but cannot undo a user's manual file copy.

No CurseForge upload or project-setting change has been performed by this
documentation task. Check the public description at release time so it clearly
distinguishes the new Forever version from the legacy Classic version.

## Legacy 0.2.9 package

Release ZIPs should be structured with a single top-level addon folder:

```text
MicroGames/
```

The ZIP should extract directly into WoW's addon directory:

```text
World of Warcraft/_classic_era_/Interface/AddOns/MicroGames/
```

The same ZIP supports WoW Forever 1.60.1. Extract it into that client's `Interface/AddOns/MicroGames/` directory; locate the actual installation through the launcher rather than assuming a beta folder name. Keep both TOCs in the same addon folder.

## Recommended ZIP Contents

Include:

```text
MicroGames/API.lua
MicroGames/CHANGELOG.md
MicroGames/Compat.lua
MicroGames/CompatForever.lua
MicroGames/FOREVER_API_AUDIT.md
MicroGames/LICENSE
MicroGames/MicroGames.lua
MicroGames/MicroGames.toc
MicroGames/MicroGames_Camelot.toc
MicroGames/README.md
MicroGames/UI.lua
```

Rationale:

- `Compat.lua`, `API.lua`, `UI.lua`, and `MicroGames.lua` are required by both clients.
- `MicroGames.toc` targets Classic Era / Hardcore (`11509`). `MicroGames_Camelot.toc` targets Forever (`16001`) and also requires `CompatForever.lua`.
- Both TOCs must declare the same addon version and `MicroGamesDB` SavedVariables. Verify every listed Lua file is present in the ZIP.
- `FOREVER_API_AUDIT.md` records the supported build and validation limits.
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
tests/
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
- `tests/` requires a standalone Lua test runner and must not be loaded by the game.

## CurseForge Assets

Use this file for the CurseForge addon logo when a sub-100 KB image is required:

```text
assets/microgames-logo-coin-spotlight-512.jpg
```

Keep the PNG variants in the repository as source/reference assets, but do not include them in the addon runtime ZIP by default.
