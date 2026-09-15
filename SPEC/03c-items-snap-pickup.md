# Mason Phase 3c — Items, snap, pickup to bars

No visual rules. No flyouts.

## 1. Item destroy vs place

Drop catcher must **not** enable mouse for `item` (or toy) while **locked**.
Bags → world / destroy keep the default UI.

While **unlocked** (edit mode), item/toy on cursor still places or moves a Mason piece as today.

Spell and macro catcher behavior unchanged (place even if locked, then unlock — existing P2 rule). If that fights macros, same as spells.

## 2. Item stack count

For `type == "item"`, Count text = stack size (`GetItemCount` / 12.x bag count API), not spell charges.
Update on `BAG_UPDATE_DELAYED`. Charges still used for spells.

## 3. Macro / toy dim

- `macro`: do not apply LAB usable/OOR/OOM desat. Full color.
- toy (item flagged toy or `type == "toy"`): usable paint from `PlayerHasToy` + `C_ToyBox.IsToyUsable` (or 12.x equivalent), not spell usable.
- Normal items: item usable + range as now.

## 4. Snap toggle

`db.char.snap` default `true`.
`/mason snap` toggles. Notify `snap on` / `snap off`.
Edit grid still draws when snap is off.
Drag-stop: if snap off, save raw x,y; if on, 9-point snap below.

## 5. Nine-point snap

When snap is on, consider 9 points of the button box (`S0 * scale`): center, 4 edge midpoints, 4 corners.
Snap the candidate with smallest error to the grid; then move CENTER so that point sits on the grid.
Grid size remains `db.char.gridSize`.

## 6. Drag to a default bar (locked only)

While **locked**:
- Left-drag a placed piece calls `PickupSpell` / `PickupItem` / `PickupMacro` (toy: pickup toy/item).
- Do not move the piece.
- Set `masonPickupId = piece.id` until the cursor is empty.

If a Blizzard action slot accepts the drop (`ACTIONBAR_SLOT_CHANGED` / cursor cleared after a slot place while `masonPickupId` set):
- `ClearView(id)` (crate). Kit + key stay.
- Notify `shown on bar` or `hidden Fireball`.
- Clear `masonPickupId`.

If the player right-clicks to cancel pickup: do **not** ClearView. Clear `masonPickupId` only.

While **unlocked**: left-drag still moves; no pickup.

Do not enable LAB’s generic drag-pickup in edit mode.

## Combat

No pickup or item-place in combat. Catcher already refuses place in combat.

## Acceptance

1. Locked, drag item from bags to world — destroy prompt, Mason does not eat it.
2. Unlocked, drop item from bags onto HUD — Mason piece; stack number correct.
3. Macro and toy pieces are not greyed out when usable.
4. `/mason snap` off — free place; on — 9-point snap.
5. Locked, drag Mason spell onto an empty default-bar slot — spell on bar, Mason view gone, `/mason list` still has the piece/key.
6. Locked, drag Mason piece then right-click cancel — view stays.
