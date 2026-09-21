# Mason 9g — Spellbook hotkey, bags, macros, quiet mode toasts

Do not change scale host, flyout populate, or overwrite dialog.

## 1. Spellbook hotkey look

Midnight spellbook is a **row** (icon + name). Do not put a tiny “9” on the name baseline.

- Parent a FontString to the **spell icon** (left art), BOTTOMLEFT or BOTTOMRIGHT of the icon only
- Size ~12, outline, white
- Do not cover the spell name
- Same chord string Mason already computes (`9`, `SHIFT-Q`)

If the row template has no icon child, walk children for the Texture used as the icon.

## 2–3. Bags vs keybind veil

The Combined Backpack / bag frames must work whether they were **open or closed** when `/mason kb` started.

**Do not** `EnableMouse(false)` or `Disable` bag item buttons.

On kb enter, on `BAG_CONTAINER_UPDATE` / bag OnShow, and on backpack search:

- Raise `ContainerFrameCombinedBags`, `ContainerFrame1`–`N`, and their item buttons **above** the veil
- Veil stays mouse-through
- Do **not** call Blizzard bag `UpdateItems` in a way that marks empty slots disabled and leaves them that way
- Do not parent bag frames to the veil

If a slot looks “locked/grey” only during kb, Mason is toggling `Desaturated` or `Disable` — stop that. Highlight for hover-bind is an outline only, same as toys.

Closed-on-enter then open: OnShow raise must run. If Combined Bags is created lazily, hook its creation / first Show.

## 4. Bag hotkey vs count

Stack count stays where Blizzard puts it.

Mason chord goes **BOTTOMLEFT** of the item icon, or above the count (count stays BOTTOMRIGHT). Never the same corner as `Count`.

Font ~10–11 so it does not cover the icon art.

## 5. Macro window

Kb mode must not hide `MacroButton1`–`N` / the scroll child.

Compare: outside kb the grid is visible; inside kb only the selected name remains.

Cause is usually: raising a parent that clips, or hiding `MacroFrame.MacroSelector` / scroll child, or the dim veil covering that region with a higher draw layer.

- Raise `MacroFrame` and `MacroFrame.MacroSelector` (12.x names) above the veil
- Do not Hide any MacroFrame child
- Do not SetAlpha < 1 on those children
- After kb enter, if MacroFrame is shown, force `MacroFrame_Update` / selector refresh **once** if buttons are missing

## 6. Mode toasts

Remove `Notify` for:

- edit on / edit off
- keybind on / keybind off
- locked / unlocked if those still fire

The panels and button labels already show state. Debug may still print those lines.

## Acceptance

1. Spellbook: chord sits on the **icon**, name stays clean.
2. Kb on with bags **closed**, then open Combined Backpack — items look normal, hover-bind works, no full-grid grey-out.
3. Kb on with bags **already open** — no random enabled/disabled slots.
4. Bound bag item: count visible, key not on top of the number.
5. Macro window: full button grid visible in kb mode.
6. Toggle edit/kb — no Mason toast.
