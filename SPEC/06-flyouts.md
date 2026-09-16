# Mason Phase 6 — Flyouts

No new visual-rule language. No rotation.

## Goal

A piece can be a **flyout parent**. Up to 12 **children** expand along one edge. Only one Mason flyout is open at a time.

Two kinds:

1. **Mason course flyout** — children are normal Mason pieces (spell/item/macro) owned by this parent.
2. **Blizzard flyout** — `type = "flyout"` + Blizzard flyout ID if LAB/API allows. If that API is unclear, implement (1) only and STOP with the payload you found.

## Data

```lua
views[id].flyout = {
  kind = "mason",          -- or "blizzard"
  blizzardId = nil,
  side = "top",            -- left|right|top|bottom
  childIds = { "p_3", "p_4" }, -- max 12
  open = false,
}
```

Children stay in the kit. They may be crated (`views[child].visible = false`) until the flyout opens.

## Pool

At addon load (OOC), ensure a parent can show 12 children without `CreateFrame` in combat. Existing `EnsureExecutor` per child id is enough if children already exist as pieces.

Do not create frames in combat.

## Open / close

- **One open globally.** Opening B closes A.
- Click parent while **locked**: toggle flyout (OOC). In combat, use a `SecureHandlerClickTemplate` snippet on the parent that Shows/Hides the child executors if you can do it without taint. If the snippet fails, STOP and report; do not toggle flyouts from insecure code in combat.
- Parent **key** (Phase 1 bind): same toggle when the key fires the parent. Prefer secure click handler so the key works in combat.
- Click a child: cast as normal; flyout **stays open** this phase (no auto-close).
- `/mason flyout close` or Escape while locked: close.
- Edit mode: flyout children are always shown if they have views, so they can be laid out; parent `open` is ignored until lock.

## Layout

Children sit in a line on `side` of the parent, `size` apart (use each child’s `size` or parent size), no extra gap beyond 2px.

Opening: `PlaceView` each child along that line.  
Closing: `ClearView` children (crate). Kit + keys on children remain — **child keys work even when crated**.

Dragging the parent while the flyout is open moves the children as a course. Dock math may reuse Phase 5 courses: parent is the course root.

## Edit / assign

```
/mason flyout <parentToken> add <childToken>
/mason flyout <parentToken> remove <childToken>
/mason flyout <parentToken> side top|bottom|left|right
/mason flyout <parentToken> clear
```

`add` fails if parent already has 12 or child is already a parent.  
Do not allow cycles (A child of B child of A).

No drag-to-parent-to-add this phase unless it falls out of drop-on-handle cheaply. Slash is enough.

## Combat

Cannot `add` / `remove` / `CreateFrame` / `SetAttribute` on children in combat — queue or print `cannot edit flyout in combat`.

Toggle in combat only via the secure handler.

## Acceptance

1. `/mason flyout Q add E` — press Q (locked): E’s view appears above Q; press Q again: E crates; E’s key still casts.
2. Open Q, then open another parent: Q’s children crate.
3. `/reload` — assignment persists; flyout starts closed.
4. Edit mode: children visible for layout.
5. 13th add — error.
6. Combat: if secure toggle works, Q opens/closes; if not, agent stops with the snippet error, no insecure Show in combat.

## Out of scope

Hold-to-open vs tap (tap only). Official profession flyouts unless API is obvious. Auto-close on child click. Nested flyouts.
