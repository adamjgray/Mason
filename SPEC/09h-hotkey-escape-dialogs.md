# Mason 9h — Uniform hotkeys, Escape, overwrite strata, toy/macro kb

Do not change scale host, bag enable logic that is now working, or overwrite *behavior* (only strata).

## 1. One hotkey look everywhere

Same placement as a **placed Mason piece**: **TOP-RIGHT of the icon**.

Apply to:

- Mason piece / LAB HotKey
- Spellbook row icon
- Bag item icon
- Toy box icon
- Macro button icon

Font, outline, color, and offset should match the piece (read offset from a placed piece’s HotKey if present).

Spellbook must show the chord **without** entering kb mode. Update on:

- bind / unbind / overwrite
- spec change
- SpellBookFrame OnShow
- PLAYER_LOGIN / spellbook tab change

If it only appears after `/mason kb`, the painter is tied to bind-mode raise. Split **paint hotkeys** from **kb raise**.

## 2. Escape in edit mode

If edit is on and **no** piece is selected: Escape exits edit (`/mason edit` off).

If a selection exists: Escape clears selection only (existing).

Do not ClearTarget. Bind-mode Escape rules unchanged (unbind hover / exit kb).

## 3. Overwrite dialog strata

`MasonOverwriteDialog` (or whatever it is):

- `SetFrameStrata("TOOLTIP")` or `FULLSCREEN_DIALOG`
- `SetFrameLevel` above SpellBookFrame, bags, toys, macros, options, bind panel, veil
- `Raise()` on Show

Must be clickable when the spellbook is open.

## 4. Bags

Leave bag *behavior* as the last good pass.

Only move the Mason chord to **TOP-RIGHT** of the item icon. Count stays BOTTOMRIGHT. Do not Disable slots.

## 5. Macros opened after kb

If MacroFrame is created/shown **after** kb is on, the grid is empty.

Hook MacroFrame OnShow (and 12.x `MacroFrame.MacroSelector` OnShow) **every time**, not only if it existed at kb enter.

On that Show: raise above veil, do not Hide children, then call the stock update (`MacroFrame_Update` / selector refresh).

If Mason options is open, still raise MacroFrame above the veil (options can stay; macros must paint).

## 6. Toy box regression

Restore hover-bind + hotkey paint on toys.

On kb enter and ToyBox OnShow:

- raise ToyBox / CollectionsJournal toy pane above the veil
- do not Disable toy buttons
- hover walk must find the toy button id again (parent walk)
- paint TOP-RIGHT hotkey even when kb is off

Debug (only if debug on) on key: `Mason: kb hover toy <id>` so a miss is obvious.

## Acceptance

1. Bind Polymorph to 9, never enter kb — spellbook icon shows 9 at top-right, same as the piece.
2. Edit on, nothing selected, Escape — edit off. Selection + Escape — deselect only.
3. Spellbook open, steal a key — overwrite dialog on top of the book.
4. Bag item key top-right; count still readable.
5. Kb on, then `/macro` — full macro grid, hover-bind works.
6. Kb on, toy box — hover-bind works again; chord top-right when bound.
