# Mason Phase 5 — Layout tools

Edit-mode only. No flyouts. No rotation. No Visual Rule changes.

## Goal

Select more than one piece, align them, nudge them, dock them into a **course** (a row or column), and scale with the mouse wheel.

## Selection

While unlocked:

- Left-click handle: select that piece only.
- Shift+click: add/remove from the selection.
- Click veil (empty grid): clear selection.
- Selected handles get a 1px gold edge (Backdrop WHITE8X8).

No marquee-drag this phase (it fights piece-drag).

## Nudge

With a non-empty selection, while unlocked and not dragging:

- Arrow keys: move selection 1 px (UIParent space).
- Shift+arrow: move by `gridSize`.

Write layout for every selected id. If snap is on, apply 9-point snap after the nudge.

## Align

`/mason align left|right|top|bottom|hcenter|vcenter`

Uses the **first selected** piece as the anchor (or the last clicked — pick one and keep it; last clicked is fine). Other selected pieces move so the matching edge or center lines up. Does nothing if fewer than two selected.

## Scale

While unlocked, cursor over a piece handle, **mouse wheel**:

- Step `views[id].scale` by 0.1, clamp 0.5–2.0.
- If multiple selected, scale each (not group-scale around a pivot this phase).
- `SetScale` on the executor (Model B). Refit handle size.

`/mason scale <token> <factor>` also works (factor 0.5–2).

## Dock / course

A **course** is a chain of pieces docked edge-to-edge.

On drag-stop of one piece (snap runs first if enabled):

- If its box is within `DOCK_PX = 8` of another placed piece’s edge (N/S/E/W), dock to that edge.
- Store on the view:

```lua
views[id].dock = { parent = otherId, side = "right" } -- parent’s right edge
```

`side` is `left|right|top|bottom` meaning “this piece sits on that side of parent.”

- Moving the **parent** moves docked children (keep edge contact).
- Moving a child undocks it (`dock = nil`) unless Shift is held (then the whole course moves).
- Refuse a dock that would cycle (A→B→A). Print `Mason: dock cycle` and skip.

`/mason undock <token>` clears `dock` on that piece.
`/mason undock` with a selection clears all selected.

No new frame parent: keep all executors on UIParent; docking is data + SetPoint math from parent’s box.

## Data

Existing `views[id]` plus `dock` and `scale` (scale already exists).

## Combat / lock

All of this is edit mode only. Combat still force-locks.

## Acceptance

1. Shift-click two pieces — both gold; click veil — none.
2. `/mason align top` — tops line up to the last clicked.
3. Arrow keys nudge; Shift+arrow jumps a grid cell.
4. Wheel over a piece — scale 0.9 / 1.1; `/reload` keeps scale.
5. Drag A until its left edge kisses B’s right — A docks; moving B moves A; moving A without Shift undocks.
6. `/mason undock` on A — A stays put, no longer follows B.
7. Rules, snap toggle, pickup-to-bar, assisted unchanged.

## Out of scope

Marquee select, rotate, distribute-spacing command, flyout children as a course.
