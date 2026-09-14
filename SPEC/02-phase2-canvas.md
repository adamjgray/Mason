# Mason Phase 2 — Drop canvas

Implement this file only. Do not implement snap/nudge/dock/multi-select, LibActionButton, Masque, visual rules, flyouts, import/export, or the learn-prompt UI.

Phase 1 remains the bind spine. Reuse `CreatePiece`, `SetPieceKey`, `QueueIfCombat`, `EnsureExecutor`, `ApplyOverrides`. Do not create a second action object per piece.

## Goal

Drop a spell, item, or macro from the cursor onto empty UI. Mason creates (or reuses) a kit piece and **places its executor** at the drop point as a 36×36 visible button. No bars, rows, columns, or empty slots.

## Success

Out of combat: pick up Fireball from the spellbook, drop on empty screen. A button appears there. If that spell already has a piece with a key, the key still works. Dragging the button (unlocked) moves it. `/mason lock` stops moving. Combat: drop is queued; after combat the button appears at the stored cursor position.

## Architecture

One secure frame per piece: `MasonExec_<id>`.

- Crate (no view): parked off-canvas, `Hide()`, `EnableMouse(false)` — Phase 1 behavior.
- Placed: `Show()`, `SetAlpha(1)`, `EnableMouse(true)`, size 36×36, `SetPoint` on `UIParent` from layout.

Do **not** parent to Blizzard action bars or reparent ChatFrame1. Parent is `UIParent` only.

The visible button is still `SecureActionButtonTemplate` only. Icon: a `$parentIcon` texture (`SetAllPoints`) using `C_Spell.GetSpellTexture` / item icon / macro icon. No cooldown swipe yet (Phase 3). Hotkey text optional: a FontString with `piece.key` if set.

## Data

Kit stays `db.profile.specKits` (Phase 1).

Layout is **per character**:

```lua
db.char = {
  locked = true,  -- drag-to-move off until /mason lock
  views = {
    [pieceId] = {
      visible = true,
      point = "TOPLEFT",
      relPoint = "BOTTOMLEFT",
      x = 0,          -- UIParent-effective coordinates
      y = 0,
      scale = 1,
    }
  }
}
```

AceDB: add `char` defaults in `InitDB`. Do not put `x,y` on the kit piece record.

Position math:

```text
scale = UIParent:GetEffectiveScale()
x, y = GetCursorPosition()
x, y = x / scale, y / scale
SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
```

Store the point used so reload restores the same place.

## Drop catcher

One frame `MasonDropCatcher`:

- Full screen, `SetAllPoints(UIParent)`.
- `FrameStrata` = `DIALOG` or `HIGH`, below Blizzard dialogs if possible.
- `EnableMouse(true)` **only** while the cursor holds a Mason-accepted type.
- Hidden / mouse disabled otherwise so other UI and Ellesmere Unlock keep working.

Poll or events: `CURSOR_CHANGED`, `OnUpdate` while shown. `GetCursorInfo()`:

| cursor | piece type | fields |
|---|---|---|
| `"spell"` | spell | spellID from cursor payload (12.x: confirm index; also `C_Spell`) |
| `"item"` | item | itemID |
| `"macro"` | macro | macro name |

On receive (`OnReceiveDrag` / `OnMouseUp` with cursor):

1. If combat: snapshot cursor type + id + x,y; `ClearCursor`; queue place; print `Mason: queued until combat ends`. After regen, place at stored x,y and `Notify` the same line you would have shown OOC (`Placed Fireball` or similar).
2. If OOC: resolve spell/item/macro. Unknown → error, clear cursor.
3. Find existing current-spec piece of that action (`spellID` / `itemID` / `macroName`). If none, `CreatePiece`.
4. If that piece already has `views[id].visible`, **move** it to the drop point (do not clone).
5. Write layout, `PlaceView(id)`, `ClearCursor`.
6. `Notify` a short line: `placed Fireball`.

Do not assign a key on drop. Keys stay Phase 1 slash (bind-on-place is later).

## Lock / move / delete

`/mason lock` toggles `db.char.locked`. Notify `locked` / `unlocked`.

- **Locked:** views are not draggable. Clicks cast (secure). Drop-from-cursor still allowed (additive place/move).
- **Unlocked:** Left-drag moves the view; on drag stop write layout. Combat: cannot start a drag (protected). If combat starts mid-drag, queue the last point.

Delete view (piece stays in kit, key stays):

- Unlocked: Alt+RightClick on the view → `ClearView` (park executor, `views[id].visible = false`).
- `/mason hide <pieceId|key>` optional.
- `/mason unplace` as alias for hide if you want one command.

`DeletePiece` (Phase 1) already parks; also clear `views[id]`.

## Slash additions

| Command | Behavior |
|---|---|
| `/mason lock` | Toggle layout lock |
| `/mason hide <key\|id>` | Clear view, keep kit/key |

Keep all Phase 1 commands.

## Events

- Login / spec change: `ApplyOverrides` then `ApplyLayout` for current spec. Pieces in kit with `views[id].visible` get `PlaceView`; others stay crated.
- `PLAYER_REGEN_ENABLED`: flush queue (place/move/lock apply).
- Do not implement learn-spell auto-place in this phase beyond: if layout says visible and the piece exists, show it. Creating pieces on learn is Phase 5/7.

## Combat

Forbidden in combat (queue): `CreateFrame` for the catcher is done at load OOC; `SetAttribute`; `SetPoint` on the secure executor; `EnableMouse` on the executor; `Show`/`Hide` on the secure executor if those are protected — treat Show/Hide/SetPoint/EnableMouse on executors as queued.

Drop catcher mouse enable/disable is not protected; OK in combat. Accepting a drop in combat = store intent + `ClearCursor` + queue.

## Files

```
Mason/Canvas/DropCatcher.lua
Mason/Canvas/Layout.lua
Mason/Canvas/View.lua
```

Wire from `Mason:OnEnable`. TOC append those files **after** Executors.

## Out of scope

Snap, grid, align, dock, rotate, multi-select, flyouts, cooldown swipe, Masque, Edit Mode, hiding Blizzard bars, assigning keys on drop, learn prompt.

## Acceptance

1. `/reload` — no error. Existing `/mason bind` still works with no view.
2. Unlock if needed (`/mason lock` until Notify `unlocked`).
3. Drag a known spell from the spellbook onto empty UI — button appears at cursor, cursor clears.
4. Drop the same spell elsewhere — **one** button, moved, not duplicated.
5. Button click casts OOC and in combat.
6. Key from Phase 1 still casts when a view exists and when the view is hidden.
7. `/mason lock` — cannot drag; click still casts.
8. Alt+RightClick unlocked — button gone, `/mason list` still has the piece and key.
9. Drop in combat — queued; after combat button appears at the captured position.
10. `/reload` — placed buttons return to saved positions.

## Stop and ask

- 12.x `GetCursorInfo` payload for spells does not include a spellID you can resolve.
- Show/Hide on the executor is protected in a way that breaks crate vs place.
- Drop catcher steals clicks from the spellbook or bags (lower strata / enable only when cursor is loaded).
