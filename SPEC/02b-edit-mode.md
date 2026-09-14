# Mason Phase 2b — Edit mode

Playtest fix. Not Phase 3 (LAB/Masque). Not Phase 5 dock graph.

## Problem

Unlocked views are the same SecureActionButton that casts. Drag/click therefore casts. Ground-targeted spells steal focus and the piece does not move. Alt+RightClick hide is not discoverable. Lock state has no HUD.

## Goal

`/mason lock` when unlocking enters **Mason Edit Mode** (Ellesmere-style unlock): dimmed veil, variable grid, pieces move without casting, easy mouse remove.

When locked, pieces click-cast again and the veil is gone.

## Edit mode rules

- Enter/leave: `/mason lock` still toggles. Notify `unlocked` / `locked`.
- Cannot enter edit mode in combat. If already editing and combat starts: auto-lock, hide veil, restore click-cast, queue any in-flight SetPoint.
- Default remains **locked** on login.

## Do not cast while editing

Do **not** rely on “don’t RegisterForClicks.” Override binds still click the executor.

Required pattern:

- Each placed piece gets an **insecure edit handle** `MasonEdit_<id>`:
  - Parent: `UIParent` (or the veil), `SetAllPoints` on the executor each draw.
  - FrameLevel above the executor.
  - EnableMouse true only in edit mode.
  - `RegisterForDrag("LeftButton")`.
  - `OnDragStart` / `OnDragStop`: move the **executor**, write `db.char.views`.
  - `OnMouseUp` RightButton: `ClearView` (crate). No cast.
  - Left click without drag: do nothing (no cast).
- While editing, handles shown; while locked, handles hidden and `EnableMouse(false)` so clicks reach the executor.
- Do not `SetAttribute("type", nil)` as the only cast-prevention — keys would die in edit mode. Handles block mouse; keys may still fire (acceptable). If a key press during edit is awkward, leave it; do not clear attributes.

## Veil + grid

One insecure frame `MasonEditVeil`:

- `SetAllPoints(UIParent)`, strata `HIGH` or `DIALOG`, below handles.
- Black texture alpha default **0.35** (constant `VEIL_ALPHA` at top of file; do not add a settings UI).
- Mouse: veil does **not** capture clicks except empty-space (let drop catcher still work). `EnableMouse(false)` on the veil itself so drop-from-spellbook still hits `MasonDropCatcher`.
- Grid: draw lines or use a repeating texture. Spacing from `db.char.gridSize` default **32**. Slash `/mason grid <pixels>` sets 8–128 and redraws. No snap required in this addendum; if snap-to-grid on drag stop is a ten-line add, do it (round CENTER to nearest grid). If it fights drag, skip snap and draw the grid only.

Show veil+grid+handles only when unlocked and out of combat.

## Remove pieces with the mouse

In edit mode only:

- **Right-click handle** → `ClearView` (keep kit + key). Notify `hidden Fireball`.
- Optional small “×” on the handle corner, same action.
- Do not require Alt.

`/mason hide` remains.

## Drop catcher

Still mouse-enabled only when the cursor holds spell/item/macro. Works in edit mode (veil must not eat the drop). Re-drop still moves the one piece.

## Files

Extend `Mason/Canvas/View.lua`, `Layout.lua`, add `Mason/Canvas/EditMode.lua` if cleaner. No new phase-3 visuals.

## Acceptance

1. Locked: click button casts; no veil.
2. `/mason lock` unlocked: veil + grid; click button does **not** cast; drag moves it; ground-target spell does not drop a targeting reticle from that click.
3. Right-click placed button in edit mode: view gone, list still has piece/key.
4. Drop from spellbook still places while unlocked.
5. Combat while unlocked: auto-lock, veil off, clicks cast again.
6. `/mason grid 64` changes spacing; `/reload` keeps gridSize and view positions.

## Out of scope

Dock, multi-select, align tools, LAB swipe, Masque, bind-on-place.
