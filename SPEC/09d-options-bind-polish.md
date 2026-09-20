# Mason 9d — Options polish + bind targets

Do not change scale host or flyout populate.

## 1. Debug gate

`db.char.debug` default false.

**Only** `Mason:Notify` and hard errors may print when debug is off.

Wrap every other `print("Mason:` behind `if self:IsDebug() then`. Grep the addon for `print(` and fix leftovers (PlaceView, drop catcher, panel level, flyout, size, ghosts dump unless `/mason debug ghosts` was explicit).

`/mason debug` with no args still dumps when invoked. Passive spam must stop.

## 2. Pieces list scroll

Pieces pane is a **scroll frame**. Max visible ~8–10 rows, rest scroll. Do not grow the dialog off-screen.

## 3–4. Rules

Presets are **not** exclusive. Use **checkboxes**, not radios.

A piece may have multiple visibility conditions combined as:

`[combat][@target,exists] show; hide`

or store `views[id].ruleIds = { "r_combat", "r_target" }` and build one driver string with AND of the preset fragments (all must match to show).

Document the combine rule in the pane: “Shown only when every checked preset matches.”

When the piece dropdown changes, **set checkbox state from that piece’s stored rules**. Apply writes the new set.

Clear unchecks all and clears the driver.

## 5. Ghosts

A ghost is **leftover data**, not a live kit piece.

Ghost if **any**:

- `views[id]` exists and there is **no** current-spec kit piece with that id
- kit piece exists but has **no key**, **no visible view**, and **no ruleIds** (unbound + unplaced + no rules)

**Not** ghosts:

- flyout children while the parent exists in the kit (open or closed)
- `/mason hide` pieces that still have a key
- placed pieces

Ghosts tab and `/mason debug ghosts` use that definition. Clear view deletes `views[id]` (and kit row only if it meets the unbound+unplaced+no-rules case).

## 6. Left rail copy

Remove hover/bind instructions from the left rail. Bind panel already has them.

## 7. Bind mode targets + veil

Hover-bind must resolve:

- Mason piece
- Spellbook
- **Toy box** (`ToySpellButton` / 12.x toy buttons) → `type=toy` or item-that-is-toy
- **Default bags** and the open bag frame’s item buttons
- **Macro UI** macro buttons

On entering kb mode **and** whenever those frames show (`BAG_UPDATE`, toy box/macro OnShow):

- Raise spellbook, bags, toy box, macro frame, Mason pieces, MasonBindPanel **above** the dim veil
- Veil stays `EnableMouse(false)`
- Re-apply raise if the player opens bags/macros/toys **after** kb is already on

Highlight on hover is not enough: `OnKeyDown` must use the **same** hover target as the gold outline.

If `GetMouseFoci` returns the highlight overlay instead of the toy/item button, walk `GetParent()` until a button with item/toy/macro/spell id is found.

Bag items appearing **under** the veil = veil frame level too high or bags not raised. Fix raise, do not EnableMouse on the veil.

Macros missing inside the window = macro buttons parented under a dimmed child or clipped; raise `MacroFrame` (or 12.x name) and its scroll children.

## Acceptance

1. Debug off, `/reload`, drop/bind/edit — almost no Mason chat except Notify.
2. Many pieces — list scrolls inside the dialog.
3. Check combat + target on one piece; both stick; dropdown to another piece shows that piece’s checks.
4. Open flyout children do not appear on Ghosts. An unbound leftover view does.
5. Left rail has no bind how-to paragraph.
6. Kb on, then open bags / macros / toy box — they sit above the dim. Hover toy + key binds that toy. Hover bag item + key binds that item. Hover macro + key binds that macro.
