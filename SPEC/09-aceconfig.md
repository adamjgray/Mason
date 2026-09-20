# Mason Phase 9 — AceConfig window

Beta-facing settings UI. Slash commands stay. No learn-spell prompt. Do not change scale host, flyout populate, or bind-mode key catcher.

## Goal

`/mason` with no args (and `/mason config` / `/mason options`) opens **one** AceConfig dialog. Testers can change defaults, snap/grid, rules, flyout side/cols, and import/export without memorizing slash.

Use **AceConfig-3.0 + AceConfigDialog-3.0 + AceDBOptions-3.0**. Vendor them into `Mason/libs` if they are not already there. TOC Interface stays 120100.

## Open

- `/mason` (no args) → AceConfigDialog:Open("Mason")
- `/mason config` and `/mason options` → same
- Keep existing subcommands (`lock`, `kb`, `export`, …) unchanged
- A **Config** button on the edit panel (next to Keybind) opens the same dialog
- Combat: opening the dialog is fine (insecure). Writes that need attributes still use `QueueIfCombat`

## Window

AceConfigDialog standard Blizzard-like dialog, title **Mason**. Width ~500, height ~420 (dialog can scroll).

Tabs (AceConfig groups):

1. **General**
2. **Keybind**
3. **Layout**
4. **Rules**
5. **Flyouts**
6. **Share**
7. **Profiles**

## Tab: General

- Header: spec name + specID (read-only)
- **Default piece size** — range 16–128, step 2, binds `db.char.defaultSize`. Description: new drops only; does not resize existing pieces. Button **Reset selected to default** calls existing `/mason size reset` logic.
- **Show debug line** — toggle `db.char.debug` (default off). When on, `/mason debug` prints stay; when off, strip noisy prints (PlaceView, flyout dumps). Keep `Mason:` Notify toasts.
- Notes (description text, not inputs):
  - Binds follow `ActionButtonUseKeyDown`
  - Default bars are not hidden
  - Masque group name is `Mason`

## Tab: Keybind

- Button **Enter keybind mode** / **Exit keybind mode** — same as `/mason kb`
- Description of hover+key and Escape rules (static text)
- Read-only list of current spec pieces: `key  type  name  id` (from `/mason list` data). No inline rebind this phase (kb mode does that).

## Tab: Layout

- **Snap to grid** — toggle `db.char.snap`
- **Grid size** — range 8–128, step 8, `db.char.gridSize`. Redraws veil if edit mode is on.
- **Lock / Unlock** — button, same as `/mason lock`
- Description: Shift+arrow snaps to next line; plain arrow is 1px; flyout children never snap.

Do not put align/dock/undock buttons here this phase (selection lives on the canvas).

## Tab: Rules

- Dropdown of placed pieces (token = key or id or spell name)
- Dropdown of presets: `always combat ooc target harm help stealth`
- Button **Apply** — existing `rule` assign
- Button **Clear** — existing `rule clear`
- Static list of preset visibility strings (read-only)

No raw condition editor this phase.

## Tab: Flyouts

- Dropdown of current-spec `type=flyout` parents
- **Side** — select left/right/top/bottom
- **Columns** — range 1–12, or 0 meaning auto (`ceil(sqrt(n))`). 0 stores `cols = nil`
- Button **Close flyout** — `/mason flyout close`
- Description: Blizzard flyouts (Portal, Warband, Skyriding) become Mason children. Toggle is locked + OOC only.

No add/remove child widgets this phase (`/mason flyout add` remains slash).

## Tab: Share

- Buttons **Export kit**, **Export layout**, **Export full** — open the existing copy dialog
- Button **Import…** — open the existing paste dialog
- Static text: schema v1; newer exports are refused

Do not duplicate the string widget inside AceConfig (the existing dialog already selects text for Ctrl+C).

## Tab: Profiles

AceDBOptions-3.0 group for `Mason.db` (profile copy/delete/reset).  
Warn in description: **profiles store kits (binds per spec). Layouts are per character** and do not follow AceDB profile switches unless we later copy `db.char`. This phase: switching AceDB profile changes kits only; say that in the description so testers are not surprised.

## Files

`Mason/Options/Options.lua`  
Register table `Mason.options` with AceConfig.  
Call `AceConfigDialog:Open("Mason")` from slash and the edit-bar button.

## Combat / lockdown

All AceConfig widgets are insecure. They may only:

- write AceDB
- call existing Mason APIs that already queue (`SetPieceKey`, `RegisterStateDriver`, `SetAttribute`, `PlaceView`)

Do not `SetAttribute` directly from a widget `set` function without `QueueIfCombat`.

## Acceptance

1. `/mason` opens the dialog. `/mason lock` still locks.
2. Change default size to 64, drop a new spell — 64px host path unchanged.
3. Toggle snap from the UI — `/mason snap` state matches.
4. Apply rule `combat` to a listed piece — same as slash.
5. Export kit from Share — existing copy dialog appears.
6. Profiles tab lists AceDB profiles. Switching profile does not wipe `db.char.views` (layouts stay).
7. Scale host, bind-mode catcher, flyout children: unchanged.

## Out of scope

Learn-spell prompt, raw macro-condition editor, in-panel key capture, combat flyout toggle, hiding default bars, theme editor.
