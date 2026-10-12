# MicroGames - WoW Forever 1.60.1 compatibility audit

> Historical 0.2.9 audit. For the redesign, the newer verified reference is
> **1.60.1.70338** (checked 2026-10-12); see
> [the current baseline](docs/ForeverApiBaseline.md). The findings and validation
> results below remain evidence for the original build, not a completed audit
> or live-client validation of the newer build.

Audit date: 2026-09-20. Addon baseline: 0.2.8, commit `3a1f6bc`.
The fixes described below are included in MicroGames **0.2.9**.

## Evidence and scope

Reviewed all five runtime Lua files, both TOCs, and the 0.2.5-0.2.8 compatibility history: chat lockdown handling, winner auto-messages, then the Forever port. The source comparison covers chat/addon messaging, event payloads, timers, raid setup and winner lookup, Single/Multi Raid state and history, UI construction, dropdowns, navigation, slash commands, and trade events.

The primary technical evidence is Blizzard's exported UI and generated API documentation, hosted by the Gethe mirror. Sources are pinned to commits, not assumed from the latest Retail client:

- [Forever version](https://github.com/Gethe/wow-ui-source/blob/70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e/version.txt): **1.60.1.69913**.
- [Classic Era version](https://github.com/Gethe/wow-ui-source/blob/33e177d9bf38d76d5c6c6e05d5da78db1899659a/version.txt): **1.15.9.69722**.
- Forever [chat API and event contracts](https://github.com/Gethe/wow-ui-source/blob/70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua).
- Forever [chat result enums](https://github.com/Gethe/wow-ui-source/blob/70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatConstantsDocumentation.lua).
- Forever [restriction events](https://github.com/Gethe/wow-ui-source/blob/70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e/Interface/AddOns/Blizzard_APIDocumentationGenerated/RestrictedActionsDocumentation.lua) and [restriction states](https://github.com/Gethe/wow-ui-source/blob/70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e/Interface/AddOns/Blizzard_APIDocumentationGenerated/RestrictedActionsConstantsDocumentation.lua).
- Classic [chat contracts](https://github.com/Gethe/wow-ui-source/blob/33e177d9bf38d76d5c6c6e05d5da78db1899659a/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua).

Source availability confirms contracts and Blizzard usage. It does **not** certify all calls from an untrusted addon, server delivery, or in-game visuals.

## Client selection and packaging

| Client | TOC | Interface | Load order |
| --- | --- | --- | --- |
| Classic Era / Hardcore 1.15.9 | `MicroGames.toc` | `11509` | Compat, API, UI, MicroGames |
| Forever 1.60.1 / Camelot | `MicroGames_Camelot.toc` | `16001` | Compat, CompatForever, API, UI, MicroGames |

Keep both TOCs and all five Lua files in the same `MicroGames` folder. The existing port selects Forever through `CompatForever.lua`, before UI initialization. Do not infer the flavor from `WOW_PROJECT_ID`: Forever uses the Mainline API family. Preserve Lua 5.1-compatible shared code and the English-client roll parser.

Both client TOCs declare addon version 0.2.9. The old `0.2.8-forever-beta1` audit label described the pre-merge branch. Packaging details are in [ReleasePackage.md](docs/ReleasePackage.md).

## API findings

| Area | Finding and implementation |
| --- | --- |
| Prefix registration | Both audited clients return `Enum.RegisterAddonMessagePrefixResult`. Accept `Success` (0) and `DuplicatePrefix` (1), reject `InvalidPrefix` (2) and `MaxPrefixes` (3). The old `~= false` test wrongly accepted numeric failures. `Compat.RegisterAddonMessagePrefix` now handles these values and legacy booleans; errors or a missing API fail registration. |
| Addon sends | `C_ChatInfo.SendAddonMessage` remains available and returns `Enum.SendAddonMessageResult`. Existing result handling covers throttling, lockdown, offline targets, and failures. The queued chunk sends retain an item during lockdown and retry throttling. Direct control messages report failure for the caller to retry; Monitoring can send a fresh snapshot on its next tick. |
| Visible chat | `C_ChatInfo.SendChatMessage` remains available, has restrictions, and has no delivery result. Existing lockdown checks and protected calls are retained. A successful call is not a server acknowledgement; server permissions, channel restrictions, and hardware-event requirements still need client testing. |
| Roll messages | Forever marks `CHAT_MSG_SYSTEM` as secret during chat messaging lockdown; the audited Classic contract does not. The 0.2.8 secret-value guard runs before string matching. Secret or non-string messages are ignored; no fabricated winner is recorded. A pending roll can time out and require a manual reroll. |
| Restriction transition | `ADDON_RESTRICTION_STATE_CHANGED` fires before activation or after deactivation. A query inside dispatch may still appear unrestricted during activation. Queue recovery now waits until the next timer turn and queries lockdown again. |
| Addon receive events | `CHAT_MSG_ADDON` still starts with prefix, text, channel, sender. The current generated event is not marked secret like system chat. The existing callback argument mapping remains valid. |

Do not use `pcall` to claim a restricted action was delivered or to bypass client restrictions. The addon must respect unreadable data and paused communication.

## Raid, timers, and identity

[Blizzard's Forever raid UI](https://github.com/Gethe/wow-ui-source/blob/70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e/Interface/AddOns/Blizzard_RaidUI/Mainline/Blizzard_RaidUI.lua) still uses `GetRaidRosterInfo` and `SwapRaidSubgroup`. The addon keeps its combat-lockdown and raid-permission checks before requesting a GM swap.

The snapshot helper already scanned all raid slots in 0.2.8. The winner-online helper still stopped at the member count, so it could report an online player beyond a roster gap as offline. It now scans the complete supported range too. This is shared correctness hardening; the exported API does not promise that gaps occur on every client.

The [Forever unit contracts](https://github.com/Gethe/wow-ui-source/blob/70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua) retain `UnitName`, `UnitFullName`, `UnitIsGroupLeader`, and `UnitIsGroupAssistant`, with identity restriction annotations. MicroGames uses these unit queries only for `player`; it does not inspect enemy combat units, auras, health, or cooldowns. Existing guarded legacy leader/officer fallbacks are not used as the primary API.

[Blizzard's Forever slash commands](https://github.com/Gethe/wow-ui-source/blob/70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e/Interface/AddOns/Blizzard_ChatFrameBase/Shared/SlashCommands.lua) still use `RandomRoll`. MicroGames continues to use its recorded number range and `C_Timer.After` / `C_Timer.NewTicker`. In-game testing must verify delayed rolls under the actual client restrictions; slash-command usage alone does not prove a timer callback is allowed in every context.

## UI and initialization

- The Forever navigation path added in 0.2.8 uses highlighted panel buttons and never invokes the Classic character-tab template or `PanelTemplates_*`.
- [Forever UIPanelTemplates](https://github.com/Gethe/wow-ui-source/blob/70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e/Interface/AddOns/Blizzard_UIPanelTemplates/Mainline/UIPanelTemplates.xml) retains `BasicFrameTemplateWithInset` and its `TitleBg` anchor used by MicroGames.
- The [SharedXML load list](https://github.com/Gethe/wow-ui-source/blob/70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e/Interface/AddOns/Blizzard_SharedXML/Blizzard_SharedXML.toc) includes input boxes, panel buttons, and family-specific dropdown files. The [dropdown implementation](https://github.com/Gethe/wow-ui-source/blob/70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e/Interface/AddOns/Blizzard_SharedXML/Mainline/UIDropDownMenu.lua) still exposes the initialization, selection, width, enable/disable, and item functions used here. No speculative menu rewrite is required.
- `MicroGames.lua` retains lazy UI creation via `/mg` and `/microgames`, plus the login message. Trade collapse/expand remains event-driven.
- Shared SavedVariables, history layout, reward templates, and the Multi Raid wire protocol remain unchanged. Supporting both clients does not imply they can communicate across separate game services.

## Additional defects fixed during the full review

These are pre-existing Lua logic defects, not newly removed Forever APIs:

1. The Assistant number-dispatch handler called `ResetChatQueue` before that local function's declaration was in scope. A forward declaration now binds the correct helper.
2. `HandleMultiRaidRollResult` wrote `state.manualWinnerCheck` without defining its local state. It now obtains the Multi Raid state explicitly for local winners, remote winners, and missing assignments.

## Validation performed

- The initial WoW Lua language-server check reported the undefined `ResetChatQueue` call.
- The final check passed for all five runtime files with no diagnostics; `git diff --check` passed and every Lua file listed by both TOCs exists.
- Seven standalone regression tests cover prefix outcomes, both client flags, sparse online rosters, offline winners, secret/non-string system messages and timeout, restriction-transition queue recovery, Assistant number dispatch, and all three Multi Raid winner branches.
- Tests use mocked WoW APIs. The secret-message case models refusal to parse; it cannot reproduce the engine's secret-value type or taint rules.
- The standalone tests run using Fengari (Lua 5.3 semantics); production code is also checked with the project's WoW language server using the `classic_era` baseline. Standalone tests are excluded from that WoW-only environment because `loadfile` is not an addon API.
- No live WoW client session was exercised during this audit. Follow the checks below before calling this build fully tested on Forever.

## In-game acceptance checks

Run on both Classic Era / Hardcore 1.15.9 and Forever 1.60.1; record the exact `GetBuildInfo()` output and enable `/console scriptErrors 1`.

1. Install a ZIP containing both TOCs and all five Lua files. Verify the correct client TOC loads, then test login, `/mg`, all six pages, mode selection, Min/Max, close/reopen, trade collapse/expand, and `/reload`.
2. As raid leader/assistant, move the GM, record the eligible roster, and send numbers. Confirm the GM is excluded and snapshot numbers stay fixed when members leave.
3. Start a Single Raid session; run delayed rolls, rerolls, offline-winner rerolls, optional countdowns, automatic winner messages, manual say/whisper, and reward yells. Check history after stopping and session restoration after reload.
4. During a genuine client chat restriction, verify sends pause, secret results do not produce Lua errors or winners, and queues resume only after restrictions end. After a timeout, manually reroll.
5. With two clients on the same service, complete Multi Raid invite/accept, roster chunks, assignment chunks, number dispatch, start/stop, local and Assistant-raid winners, manual Assistant checking, and history restoration.
6. Test Monitoring, disconnect/offline failures, raid-warning permissions, and server throttling. Verify actual recipients see the messages; a local successful API call alone is insufficient.

Repeat relevant checks when a newer Forever build changes its API or UI sources.
