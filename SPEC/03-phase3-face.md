# Mason Phase 3 — Button face + Masque

Implement this file only. Edit mode, drops, and executors stay as they are unless LAB cannot wrap them.

## Goal

Placed pieces look like action buttons: cooldown swipe + text, charges, hotkey, usable/OOR paint, proc glow if LAB provides it. Optional Masque group `Mason`.

## Strategy: wrap-first

Keep `MasonExec_<id>` as the `SecureActionButtonTemplate` that receives `SetOverrideBindingClick`.

Vendor **LibActionButton-1.0** under `Mason/libs`. Try to attach LAB’s overlay/cooldown/icon machinery to that existing button (LAB `CreateButton` with an existing frame, or LAB’s documented wrap/hook if present in the vendored version).

If after reading LAB’s API the library **must** create its own SAB:

1. Stop and report the exact `CreateButton` signature you found.
2. Do not invent a second clickable button.
3. Architect will allow: `EnsureExecutor` becomes LAB `CreateButton` with name `MasonExec_<id>` still the bind target. One frame per piece, still.

Do not ship two secure buttons per piece.

## Visuals (LAB defaults)

Required:

- Icon (replace the Phase 2 homemade texture if LAB owns Icon)
- Cooldown swipe
- Cooldown numbers on (Blizzard/LAB default)
- Charges / count
- Hotkey text from `piece.key`
- Usable dim / desat
- Out of range (LAB default color)

If LAB gives these with default config, leave them on:

- Spell activation / proc overlay
- Checked / flash (auto-repeat, current spell)

Do not add a settings UI. Constants at top of `Mason/Face/Face.lua`:

```lua
local SHOW_CD_TEXT = true
local SHOW_HOTKEY = true
local SHOW_COUNT = true
```

## Midnight / secrets

Use LAB and Blizzard cooldown widgets only. Do not poll secret usable/cooldown values to draw your own numbers. If a field is secret and LAB hides it, accept the empty text.

## Masque

`## OptionalDeps: Masque` in the TOC.

On login, if Masque is loaded:

```lua
local MSQ = LibStub("Masque", true)
-- group name exactly "Mason"
```

Add each placed (and, if cheap, crated) button to group `Mason`. Re-skin on `PlaceView`. Removing Masque mid-session is not required.

No custom Mason skin. One group, no per-piece groups in this phase.

## Edit mode

`MasonEdit_<id>` handles stay **above** the LAB face (higher frame level). Drag must still not cast. Veil unchanged.

LAB must follow button size/scale from layout (`SetSize(36,36)` and `views[id].scale`).

## Config / slash

No new required slash. `/mason debug` may append `masque=yes|no lab=yes|no`.

## Files

```
Mason/libs/LibActionButton-1.0/   -- vendor
Mason/Face/Face.lua
```

TOC: LAB after LibStub/CallbackHandler, before Mason modules. `OptionalDeps: Masque, Ace3`.

## Combat

LAB setup (`CreateButton`, region create) only OOC, queued. Do not `SetAttribute` in combat. Cooldown *updates* that LAB does insecurely on OnUpdate are LAB’s problem; do not add your own combat-unsafe attribute writes.

## Acceptance

1. `/reload` — no error with and without Masque installed.
2. Placed spell shows icon + swipe when on cooldown + numbers if the API allows.
3. Charge spells show count.
4. Hotkey matches `piece.key`.
5. Unusable / OOR uses LAB dim (not a custom shader).
6. Click and key still cast; edit-mode drag still does not.
7. Masque: changing the `Mason` group skin updates placed buttons.
8. Hide view / crate: no orphaned LAB frames or extra icons.
9. Combat: existing faces keep animating CD; no taint popup.

## Stop and ask

- LAB cannot wrap `MasonExec_*` and also cannot be created with that exact global name.
- Masque `AddButton` errors on a LAB-wrapped SAB.
- Cooldown widget throws or taints in combat.

## Out of scope

Visual rules, dock, flyouts, bind-on-drop, CDM, per-button color picker, AceConfig.
