# Mason 9i — Profile owns layout, spellbook icon hotkey, dialogs, bags/macros

Do not change scale host or flyout populate.

> **Product (frozen):** profile-owned layouts stay (`db.profile.views`).  
> **Supersession (source panels):** §6–7 CombinedBags/MacroFrame **raise** clauses are **superseded by [`09ab`](09ab-source-panels-no-raise.md) + [`09aa`](09aa-crash-guards.md)**. Profile migration, Escape order, spellbook icon hotkey placement, and Mason-owned dialog strata remain.

## 1. Spellbook hotkey + hover

- Paint the chord on the **spell icon texture/button**, TOP-RIGHT of that icon, not the row container.
- Hover-bind target = the same icon you paint (or the row if Midnight only gives one hit rect — then paint on the icon child, bind from the row).
- Gold highlight should match the hover target. If the row is the only mouse frame, highlight the row; still parent the FontString to the icon.
- Paint on bind, unbind, spec change, SpellBook OnShow, tab change — **not** only after a second bind or after kb.

## 2. Escape closes config

If the Mason options dialog is shown, Escape closes it first.

Order:

1. kb mode → existing kb Escape
2. else options open → close options
3. else edit + selection → clear selection
4. else edit + no selection → exit edit

Do not ClearTarget.

## 3. Profiles include layout + settings

**Change from Phase 8/9:** AceDB profile owns **kit + views + UI settings**.

Move to `db.profile` (keep spec-keyed kits as they are):

- kits / pieces
- `views` (positions, size, visible, dock, flyout cols/side, ruleIds)
- `defaultSize`, `snap`, `gridSize`, `debug`

`db.char` no longer stores views.

On profile switch (`AceDB` callback): `ApplyOverrides` + `ApplyLayout` for the current spec. Pieces on screen must match that profile.

Migration once: copy existing `db.char.views` (and those settings) into the **current** profile if the profile has empty views.

Export **full** already dumps kit+views — after this, that blob is the same as the AceDB profile payload.

Description on Profiles pane: switching Existing Profiles loads binds **and** layout.

## 4–5. Dialog strata + overwrite clicks

**Mason-owned** frames only (MasonBindPanel, edit panel, overwrite dialog, options):

- `FULLSCREEN_DIALOG` or `TOOLTIP`
- `Raise()` on Show (Mason frames — not Blizzard source chrome)
- Overwrite: buttons **above** the backdrop (`SetFrameLevel` backdrop 1, text 2, buttons 10+). EnableMouse on buttons only. Backdrop must not cover the hit rects.

## 6. Bags either order

Kb then bags, or bags then kb: hover-bind works, no Disable. ~~Combined Bags stay raised.~~ **Superseded by 09ab** — no Blizzard Raise undim; schedule paint/attach only (09aa: never raise from bag Show).

## 7. Macro grid + hotkey

If kb is on before `/macro`: hooks + store paint on Show (09ab). ~~OnShow: raise MacroFrame + selector / force populate via raise timing.~~ **Superseded by 09ab** — never raise MacroFrame/Selector for undim.

Hotkey: parent to the **macro icon**, TOP-RIGHT of that icon. Not the selector cell/container.

## Acceptance

1. Bind Polymorph, never kb — `9` on the **sheep icon**, not the row’s top-right. Hover highlight matches what you bind.
2. Options open, Escape — options close.
3. Profile A layout left, Profile B layout right, switch Existing Profiles — buttons jump to that profile’s layout.
4. Overwrite dialog on top of the book; Overwrite/Cancel clickable.
5. Bags open before or after kb — bind works.
6. Kb then `/macro` — full grid; bound macro key sits on the icon.
