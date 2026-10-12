# Forever API baseline for the redesign

Verified on **2026-10-12**. Primary target: **WoW Forever 1.60.1.70338**,
Interface **16001**, Mainline family / Camelot game type.

## Development policy

The redesigned addon is Forever-only. Classic Era 1.15.x APIs are no longer the
design baseline. The archived 0.2.9 release actually targeted Classic **1.15.9**
(not 1.15.8) alongside Forever; that historical support remains preserved.
Modern components confirmed in the Forever export may replace Classic UI and
compatibility paths. The user explicitly excludes Classic from the redesigned
release; preserve the legacy release separately. A complete UI and supporting
code rewrite is allowed. See [release policy](ReleasePackage.md).

This is a reference refresh and design decision, not an implemented runtime
migration or a full compatibility audit of build 70338.

## Source provenance

Primary technical material is Blizzard's exported UI and generated API
documentation, distributed through the Gethe source mirror. This is a source
mirror, not an official Blizzard-hosted documentation service.

- Repository: <https://github.com/Gethe/wow-ui-source>
- Checked branch: `forever` (not `live`, `beta`, or `classic_era`).
- Current branch commit: `943764493e6b16d63ded3ab304150d1f05e58b57`.
- Source commit timestamp: **2026-10-10T05:16:18Z**.
- [Pinned version file](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/version.txt): `1.60.1.70338`.
- [Pinned source tree](https://github.com/Gethe/wow-ui-source/tree/943764493e6b16d63ded3ab304150d1f05e58b57).
- [Changes since the previous audit](https://github.com/Gethe/wow-ui-source/compare/70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e...943764493e6b16d63ded3ab304150d1f05e58b57): 11 commits after the 69913 reference.

This is the latest available export verified on the checked branch at the time
of this review, not a claim about every installed client or unpublished build.

## Downloaded local reference

[forever-1.60.1.70338-reference.zip](api/forever-1.60.1.70338-reference.zip)
contains 929 source/reference files, copied unchanged from the pinned source
archive, with the upstream archive's outer directory removed:

- `version.txt` and available root README/license files;
- complete `Interface/AddOns/Blizzard_APIDocumentationGenerated/`;
- `Blizzard_APIDocumentation/`;
- `Blizzard_Menu/`;
- `Blizzard_SharedXML/`;
- `Blizzard_RaidUI/`;
- `Blizzard_UIPanelTemplates/`.

The last five directories are under `Interface/AddOns/` as well. This is a
selected API/UI reference, not the entire exported client UI tree. Upstream
notices remain in the copied files; the reference is not MicroGames-authored MIT
code and is not a runtime dependency. Do not include it in addon release ZIPs.

Archive SHA-256:
`F3BFAC463BB3364CA18A4355210A3A2B02CEEF9420E43CBEA20A231C25D1C645`.

## Findings relevant to MicroGames

The source comparison showed the following changes in the chat documentation:

- `ChatInfoDocumentation.lua`: the secret-during-chat-lockdown annotation was
  removed from `CHAT_MSG_COLLECTED_APPEARANCE`. This is not the roll event.
- `ChatConstantsDocumentation.lua`: three Discord channel enum entries were
  added. They do not establish a replacement transport for multi-raid addon data.

Do not infer from either change that system rolls are freely readable or addon
messages bypass chat restrictions. Retain `issecretvalue` checks, pending-roll
timeouts, send queues, send-result enum handling, and deferred restriction checks.
The current `SendChatMessage` contract still has restrictions; a successful local
call does not establish delivery to a recipient.

Pinned contracts:

- [Chat API and events](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua)
- [Chat enums](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatConstantsDocumentation.lua)
- [Restriction events](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/Interface/AddOns/Blizzard_APIDocumentationGenerated/RestrictedActionsDocumentation.lua)
- [Party API](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/Interface/AddOns/Blizzard_APIDocumentationGenerated/PartyInfoDocumentation.lua)

## Implementation candidates, not completed replacements

| Existing design | Forever-first candidate | Required check |
| --- | --- | --- |
| `UIDropDownMenu_*` mode selector | `DropdownButtonMixin:SetupMenu` and Blizzard Menu components | Verify the chosen template and menu interactions in Camelot |
| Classic character tabs plus a separate Forever navigation path | One sidebar for the Forever design | Validate focus, selected states, scaling, and frame behavior |
| Manually paginated player/history lists | SharedXML ScrollBox list views and ScrollUtil | Prototype row binding, selection, scroll behavior, and actual loading |
| Classic API assumptions in compatibility helpers | Direct current contracts where justified | Review callers and result enums before removing fallbacks |
| Custom Multi Raid protocol | Separate transport/architecture investigation | No verified replacement identified in this review; test with multiple clients |

The [Menu TOC](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/Interface/AddOns/Blizzard_Menu/Blizzard_Menu.toc)
explicitly selects a Camelot menu XML, and
[DropdownButton.lua](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/Interface/AddOns/Blizzard_Menu/DropdownButton.lua)
implements `SetupMenu`. SharedXML contains the ScrollBox and ScrollUtil sources
in `Shared/Scroll/`. Their presence supports investigation, not a claim that
every API is unrestricted or already tested in this addon.

## Tooling and future refreshes

`.wowluarc.json` still uses `classic_era`; it is a legacy static-check environment,
not proof of Forever compatibility. Before implementation, identify supported
language-server flavors and/or a pinned Forever definition setup. Do not simply
invent a `forever` setting or equate current Retail definitions with this build.

For the next refresh, query `git ls-remote --heads` for the upstream `forever`
branch, read `version.txt` at that exact commit, compare against this pin, and
download a new versioned reference. Record the date, commit, upstream timestamp,
archive hash, and relevant changes here. Never silently replace a reference under
an old version name. Verify `GetBuildInfo()` on the actual target client and run
the relevant in-game acceptance checks before claiming runtime compatibility.
