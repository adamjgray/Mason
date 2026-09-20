# Mason 9e — Pieces table + bind targets

Do not change scale host.

## 1. Flyout close is silent

Closing a flyout crates children with **no** `Notify` and **no** `print`, even if debug is on (debug may print one line total: `flyout closed <parentId>`).

Do not toast `hidden Fireball` per child.

## 2. Pieces pane

- Remove the instruction paragraph.
- Table fills the **full remaining height** of the right pane (scroll if needed).
- Columns: icon | id | name | type | bind | rule
- Real cells (AceGUI table / ScrollFrame + rows with FontStrings), not one wrapped label per piece.
- Rows are **selectable** (one at a time). Selection:
  - highlights the row
  - sets the Rules pane current piece
  - if type=flyout, sets the Flyouts parent dropdown
- No bind-on-click from this table.

## 3. Flyout side

Dropdown again (top / bottom / left / right). Remove the four radios.

## 4. Bind-mode hover

Must work at the same time for:

- placed Mason pieces
- **spellbook** (regressed — fix first)
- default bags
- macro UI
- toy box (keep working)

On kb enter **and** OnShow of SpellBookFrame / bag frames / MacroFrame / ToyBox:

- Raise that frame and its item/spell/macro buttons above the veil
- Do not lower spellbook when raising bags

Hover resolve: walk `GetMouseFoci()` parents until one of:

- `MasonExec_*` / edit handle
- spellbook button with a spell id
- container item button with bag+slot or item id
- macro button with macro name/index
- toy button with toy/item id

If focus is the kb catcher or veil, ignore those and use the focus **under** them (`GetMouseFoci` list, skip MasonBindVeil / catcher).

Debug (only when debug on): `Mason: kb hover <kind> <id or name>` on key press so a miss is visible.

## Acceptance

1. Close a flyout — no per-child hidden toasts.
2. Pieces table fills the pane; click a row — Rules dropdown matches.
3. Flyout side is a dropdown.
4. Kb on: bind from spellbook **and** toy box. Open bags after kb — items above veil and hover+key binds the item. Same for macros.
