MicroGames 0.2.9 improves compatibility and fixes shared gameplay issues for WoW Classic Era / Hardcore 1.15.9 and WoW Forever 1.60.1 / Camelot.

Changes:
- Correctly handles addon-message prefix registration success and error codes.
- Finds online winners even when raid roster indices contain gaps.
- Rechecks chat restrictions after restriction-change events before resuming queued messages.
- Fixes Assistant number-whisper dispatch and Multi Raid winner state handling.
- Updates installation, packaging, development documentation, and the source-linked Forever API audit.

Install the attached MicroGames-0.2.9.zip into your client's Interface/AddOns directory. Keep both TOCs and all Lua files in the MicroGames folder.

- Classic Era / Hardcore: MicroGames.toc, Interface 11509.
- Forever: MicroGames_Camelot.toc, Interface 16001.

Validation: seven mocked regression tests pass; all five runtime Lua files pass the WoW Lua static check. In-game verification on both clients remains necessary; mocks do not reproduce engine secret values, taint, or server chat restrictions.
