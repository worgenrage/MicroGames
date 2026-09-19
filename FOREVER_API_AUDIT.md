# MicroGames – WoW Forever 1.60.1 compatibility audit

Branch baseline: MicroGames 0.2.7  
Compatibility build: 0.2.8-forever-beta1

## Design rule

Classic Era / Hardcore 1.15.9 remains the legacy/stable code path.
Forever-specific behavior is enabled only by `MicroGames_Camelot.toc`, which loads
`CompatForever.lua`. No runtime project-ID guess is used to identify Forever.

## Verified API compatibility

The following APIs used by MicroGames are current on both Classic Era 1.15.9
and the Midnight-era API used by Forever:

- `C_ChatInfo.SendChatMessage`
- `C_ChatInfo.RegisterAddonMessagePrefix`
- `C_ChatInfo.SendAddonMessage`
- `C_ChatInfo.InChatMessagingLockdown`
- `ADDON_RESTRICTION_STATE_CHANGED`
- `issecretvalue`
- `GetRaidRosterInfo`
- `SwapRaidSubgroup` (nocombat)
- `RandomRoll`
- `UnitIsGroupLeader`
- `UnitIsGroupAssistant`

The existing `IsRaidLeader`, `IsRaidOfficer`, and `UnitIsRaidOfficer` checks are
left only as guarded compatibility fallbacks. Modern clients use the group APIs.

## Forever-specific fixes

### Flavor detection
Forever 1.60.1 is Camelot (`Interface: 16001`) and reports
`WOW_PROJECT_MAINLINE` at runtime. Therefore `WOW_PROJECT_ID` must not be used
as the Forever discriminator.

### Navigation tabs
Forever does not expose `CharacterFrameTabButtonTemplate` in the tested beta
environment. The Forever code path now uses `UIPanelButtonTemplate` for the six
MicroGames navigation buttons and does not call `PanelTemplates_*` on those
buttons. Classic keeps the original character-tab + PanelTemplates path.

### Secret chat values
`CHAT_MSG_SYSTEM` is guarded by `SecretInChatMessagingLockdown` in the modern
API. `/roll` parsing now checks `issecretvalue(message)` before using Lua string
operations. A secret roll message is ignored rather than causing a Lua error.

### Raid roster iteration
The roster snapshot helper now scans `1..MAX_RAID_MEMBERS` (fallback 40) rather
than assuming the first `GetNumGroupMembers()` raid slots are contiguous.

## Intentionally unchanged

- Existing saved-variable schema.
- Existing chat queue and addon-message queue protocol.
- Existing `C_ChatInfo` send paths.
- Existing raid move behavior and permissions.
- Existing English-client `/roll` parser.
- Existing UIDropDownMenu UI, which is present in the tested Forever beta.

## Beta caveat

WoW Forever is still a beta client. Blizzard can change Camelot UI templates or
Midnight-era restriction behavior before release. Keep Lua errors enabled while
testing each beta build.
