# Mason 9y — Button adapters, not windows

Do **not** rewrite the working macro hover/bind/scroll path except to call the shared attach/paint.

Do not change scale host, flyouts (combat), or profiles.

## What is actually the same

Blizzard does **not** use one widget for “thing you drag to a bar.”

| Family | Frame-ish | Identity on the button |
|---|---|---|
| Spellbook | spell slot / SpellBookItemMixin | `spellID` (elementData / GetSpellBookItemInfo) |
| Bags | ItemButton | `itemID` (GetBagAndSlot / GetItemID) |
| Toys | ToyBox button | `toyID` / itemID |
| Macros | MacroButton | macro name / index |

Pickup is the same *cursor* (`GetCursorInfo`). Overlay + hover-bind must use the **button**, not the window.

The same row/col key on every spellbook page means paint is `visible[i] → keys[i]`. That is forbidden.

## Adapter (one table per family)

```
{
  name = "spell" | "item" | "toy" | "macro",
  buttons = function() → { button, ... },  -- visible cells only
  identity = function(button) → id or nil, -- number or macro name
}
```

Shared only:

```
Mason:PaintKbOverlay(button, kind, id)     -- already specified
Mason:AttachKbHover(button, kind, id)      -- OnEnter gold + bind owner
Mason:KeyForIdentity(kind, id) → piece.key or ""
```

No other SetText. No window-level “paint page N.”

## Spellbook

`buttons()` = the spell **icon buttons** on screen now (not name rows, not the frame).

`identity(button)` = that button’s current `spellID` (override/base). If you cannot read it from the button, skip that cell. Do **not** use `i` from a page list.

Page flip: `buttons()` again, clear texts, paint by identity.

Raise `PlayerSpellsFrame` with the same helper as MacroFrame (veil only).

## Bags

`buttons()` = Combined Bags item buttons only.

First `/mason kb` and bag OnShow both: for each button, `AttachKbHover` + `PaintKbOverlay`. Same functions as the second kb. One hook flag per button.

## Toys

`buttons()` = visible toy cells. `identity` = toyID. Paint/attach those cells only.

## Macros

Keep the current walk; it already is this pattern. Point it at `PaintKbOverlay` / `AttachKbHover` if it is not already.

## Forbidden

- Mapping slot index or row/col to a piece
- Hardcoded key / spell name
- `print` from Show
- OnUpdate full-tree walks
- A fifth painter

## Done when

1. First kb + bags: hover + bind.
2. Book: undimmed; key follows **spellID** across pages (not the same cell).
3. Toys: key on the matching toy cell.
4. Macros unchanged.
