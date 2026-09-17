# Mason Phase 7 — Bind mode

No AceConfig. No import. Combat: cannot enter bind mode; if a pull starts, exit bind mode.

## Goal

`/mason kb` turns on hover-to-bind. Point at a Mason piece, spellbook row, macro, or bag item; press a key (with modifiers) to bind; hover + Escape clears that bind.

## Bind mode

- `/mason kb` toggles. Notify `keybind on` / `keybind off`.
- Can also be turned on from a small **edit bar** (below) when unlocked.
- While on: a full-screen insecure key catcher (`EnableKeyboard(true)`, frame strata DIALOG) receives `OnKeyDown`.
- Allowed keys: letters, digits, function keys, mouse buttons if `GetBindingFromClick` / `GetKey` supports them, plus modifiers `SHIFT- CTRL- ALT-`.
- Ignore modifier-only keydowns (just Shift). Bind on the non-modifier key with modifiers held: `SHIFT-Q`.
- While on, do **not** run piece nudge arrows as bind keys? Arrow keys may bind (`UP`) — disable nudge while kb is on.

## Hover targets

Resolve in this order under the cursor (`GetMouseFocus` / `GetMouseFoci` 12.x):

1. Mason edit handle or `MasonExec_*` → that piece.
2. Spellbook button → spell ID.
3. Macro UI button → macro name.
4. Bag item button → item ID.

If none, key is ignored (do not steal). Escape with no hover target **exits bind mode** (does not clear target, close bags, or deselect pieces).

## Bind

- Existing Mason piece: `SetPieceKey` (steal + notify).
- Spellbook / macro / bag with no piece: `CreatePiece` + `SetPieceKey`. Do **not** PlaceView (crate). User drops later to show it.
- Spellbook / macro / bag that already has a current-spec piece: bind that piece, still no forced PlaceView.

## Escape

While kb on:

| Hover | Escape |
|---|---|
| Mason piece with a key | `ClearPieceKey`, stay in kb mode |
| Spellbook/macro/bag with a kit piece | `ClearPieceKey` on that piece |
| Nothing bindable | exit kb mode only |

Must not: `ClearTarget`, close Spellbook/Bags, clear Mason selection, exit edit mode.

Implement: catcher `OnKeyDown` for `ESCAPE` → `handled` / do not pass through. Do not `SetBinding("ESCAPE")` globally.

## Edit bar (minimal)

When **unlocked**, show a small bar on the veil (mouse enabled **only on the bar**, not the veil):

- **Lock** — same as `/mason lock` (leave edit mode; “save” is already live-write).
- **Cancel** — restore `views` snapshot taken at unlock; then lock. Snapshot = copy of `db.char.views` when entering edit mode.
- **Keybind** — `/mason kb` on.

Bar title: `Mason edit`. Hide the bar when locked.

## Combat

`InCombatLockdown` → exit kb, hide catcher. Cannot bind in combat (queue not required this phase).

## Acceptance

1. `/mason kb`, hover a placed piece, press `SHIFT-Q` — bound, notify.  
2. Hover that piece, Escape — key cleared, still in kb, target still selected if you had one.  
3. Hover Fireball in the book, press `E` — piece exists in `/mason list`, not forced onto HUD.  
4. Escape with cursor on empty world — kb off, bags still open.  
5. Unlock — edit bar visible; Keybind works; Cancel reverts a move you made this edit session.  
6. Pull while kb on — kb off, no error.

## Out of scope

Blizzard Quick Keybind frame. AceConfig. Binding in combat.
