# Mason 9f — Bind display, rules layout, ghosts crash

Do not change scale host or flyout populate.

## 1. Pieces table refresh

After any `SetPieceKey` / `ClearPieceKey` / bind-mode key / Escape-unbind, refresh the Pieces table immediately. Do not wait for a click.

If the options window is closed, skip. If open on another pane, still refresh so the next visit is current.

## 2. Bind messages + overwrite

- Success bind / unbind / steal toasts are **debug-only** (`IsDebug()`).
- When the new key is already used by another current-spec piece:
  - Do **not** steal immediately.
  - Open a Mason dialog (same chrome as bind panel):
    - “Q is bound to Fireball. Bind it to Frostbolt instead?”
    - **Overwrite** — existing steal path
    - **Cancel** — leave both keys as they were
  - No dialog if the same piece already owns that key (re-bind no-op).

## 3. Hotkey on book / bags / toys / macros

If a current-spec piece has a key and matches that spell / item / toy / macro, draw the chord on that Blizzard button (hotkey FontString, bottom-right, same look as action-button hotkeys).

Update on bind, unbind, spec change, and those frames’ OnShow.

Clear the extra string when Mason no longer owns that bind. Do not call `SetBinding` on the Blizzard button.

## 4. Rules pane layout

From the screenshot: one wrapped checkbox row + a wall of preset text.

Replace with:

- Piece dropdown on its own row (no “not hover-bindable” sentence).
- Checkbox **grid**: 2 rows × 4 (always, combat, ooc, target / harm, help, stealth). Aligned, not flowing off Apply.
- Apply and Clear on the next row, same width as other red buttons.
- Preset macro strings: hide by default. Debug-only, or a collapsed “Show driver strings” toggle off by default.

Sync checks when the Pieces table selection changes (already specced).

## 5. Flyout columns

Changing cols: **no** Notify / print. Relayout if open. Silent.

## 6. Ghosts last-item crash

`AceConfigDialog.lua:840 rootframe nil` is a refresh during the button callback that destroys the dialog.

`Clear view` / `Clear all`:

- Do not call `AceConfigDialog:Open` or rebuild the group inside the same click.
- `C_Timer.After(0, refresh Ghosts group)` after SavedVariables write.
- Empty list: one disabled label `No leftover views.` — never zero Ace widgets with a live button callback.

Do not share AceGUI widgets with the Keybinding addon’s AceGUI if that is a second embed; Mason must use **Mason/libs** AceGUI only. The stack showing `Keybinding/Libs/AceGUI` means two AceGUI embeds are firing — prefer Mason’s lib via LibStub, but the After(0) refresh is still required.

## Acceptance

1. Bind in kb mode — Pieces table bind column updates without clicking the table.
2. Bind Q already on Fireball onto Frostbolt — confirm dialog; Cancel leaves Fireball on Q.
3. Spellbook / toy / bag / macro button shows `SHIFT-Q` when Mason owns it.
4. Rules pane is a tidy grid; no preset dump unless asked.
5. `/mason flyout x cols 3` — no toast.
6. Clear the last ghost — no Lua error; pane shows empty state.
