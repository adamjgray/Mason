# Mason 9c — Options layout

Do not change scale host, flyout populate, dock filters, or bind-mode key catcher logic.

## Chrome

One Mason dialog (same gold-edge as bind/edit).

**Left rail** (fixed, ~160px):

- Buttons (prominent, always visible):
  - **Edit mode** — toggles `/mason edit`. Label **Editing…** while on.
  - **Keybind mode** — toggles `/mason kb`. Label **Binding…** while on.
- Then a vertical menu (not top tabs). Selecting a row swaps the right pane:
  - General
  - Pieces
  - Layout
  - Rules
  - Flyouts
  - Ghosts
  - Profiles
  - About (optional one-liner + spec id)

No separate Keybind or Share menu rows.

## Right panes

### General
- Default piece size
- Debug (toggle `db.char.debug`, default **off**)
- Short notes (keydown CVar, bars not hidden, Masque group Mason)

When Debug is off: **no** `print("Mason: …")` except `Mason:Notify` toasts and explicit user-facing errors (`export is newer`, `cannot toggle flyout in combat`, `dock cycle`). Strip PlaceView, panel level, flyout try, size dumps, drop catcher mouse, hostC, ghosts extras.

### Pieces
Table of current-spec kit (same set as `/mason list`):
- icon
- id
- name
- type
- binding
- rule (preset or empty)
- flyout parent? (yes/no or parent id)

Read-only this phase. Description: “Use Keybind mode (left) and hover the HUD / spellbook / bags / macros. This list does not bind.”

Remove the piece list from any old Keybind page.

### Layout
- Snap toggle
- Grid size
- Done/edit is on the left rail, not duplicated unless you keep a small “Done” here too — prefer left only.

### Rules
- Piece dropdown + preset radios or dropdown + Apply/Clear
- Do not imply the Pieces table is hover-bindable

### Flyouts
- Parent dropdown
- **Side** as **radio buttons**: Top / Bottom / Left / Right
- Columns 0–12 (0 = auto)
- Close flyout button

### Ghosts
Unchanged (icon, id, type+name, Clear)

### Profiles
- AceDBOptions profile picker (kits follow profile; layouts stay `db.char`)
- **Export** — full export only (`kind=full`), existing copy dialog
- **Import…** — existing paste dialog
- Remove kit-only / layout-only buttons from the UI (slash may keep them)

## Keybind copy

Bind panel and left-rail description must say:

Hover a **placed piece**, a **spellbook row**, a **macro**, or a **bag item**, then press a key. This options list cannot be hovered to bind.

## Acceptance

1. Left rail: Edit + Keybind always visible; menu switches panes.
2. No Share tab. Profiles has Export (full) + Import.
3. Pieces pane lists icon/id/name/bind/rule.
4. Flyout side is four radios.
5. Debug off: chat is quiet except Notify.
6. Keybind instructions do not point at the options list.
