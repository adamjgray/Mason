# Mason Phase 1 — Executor spine

Implement this file only. Do not implement drop-to-place, LAB faces, Masque, visual rules, flyouts, import/export, or learn prompts.

Goal: a piece can exist with a key and cast in combat with **no visible widget**.

## Success

Out of combat, `/mason bind SpellName KEY` (or equivalent slash in this spec) creates a piece, applies an override binding, and pressing KEY casts the spell in combat. No icon appears on the HUD.

## Dependencies

- Ace3: AceAddon-3.0, AceDB-3.0, AceConsole-3.0 (vendor under `Mason/libs` or document `## RequiredDeps: Ace3` if you assume a shared Ace3 install). Prefer **embedding** Ace3 libs in `Mason/libs` so the addon loads standalone.
- No LibActionButton, no Masque, no AceConfig UI in this phase.

TOC:

```
## Interface: 120000
## Title: Mason
## Notes: Place your abilities.
## SavedVariables: MasonDB
## OptionalDeps: Ace3
```

Replace `120000` with `select(4, GetBuildInfo())` if the stub already has a correct build. Do not add Classic interfaces.

## Data

### Piece id

Stable string. Pattern: `p_<counter>` incrementing per profile, never reused after delete.

Do **not** encode spell name in the frame name in a way that breaks on rename. Store the action on the piece record. Frame name is derived from piece id only.

### Piece record (kit)

```lua
{
  id = "p_1",
  type = "spell",          -- "spell" | "item" | "macro"
  spellID = 133,           -- when type == "spell"; use ID not locale name
  spellName = "Fireball",  -- cache for toast / debug; resolve ID at apply
  itemID = nil,
  macroName = nil,
  key = "Q",               -- WoW binding token, e.g. "Q", "SHIFT-Q", "CTRL-E"
  specID = 63,             -- GetSpecializationInfo at save time
}
```

Phase 1 must accept spell (by name or id). Item and macro types may be stored and applied if easy; spell is required.

### AceDB

```lua
MasonDB
  profile            -- AceDB default profile is fine
    pieces = { [id] = piece }
    nextPieceIndex = 1
    specKits = {                 -- preferred shape
      [specID] = {
        pieces = { [id] = piece },
        nextPieceIndex = 1,
      }
    }
```

Use **spec-scoped kits**. On `PLAYER_SPECIALIZATION_CHANGED` / login, apply only the current spec’s pieces. Do not keep other specs’ override bindings active.

If AceDB profiles vs `specKits` conflicts with AceDB-3.0 habits: store `specKits` inside the character or global SV as above. Do not use one AceDB profile per spec unless you also auto-switch; specKits is simpler.

Layout keys (`x`, `y`, `visible`) must not be required. You may ignore them if present.

### Executor frame

- Type: `Button` inheriting `SecureActionButtonTemplate`.
- Name: `MasonExec_<id>` with `id` sanitized (`p_1` → `MasonExec_p_1`). Name must be a valid global frame name (alphanumeric + underscore).
- Parent: `UIParent`.
- Size: 1×1 or 36×36. Place off-canvas (`SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -2000, -2000)`).
- `EnableMouse(false)` and `Hide()` or `SetAlpha(0)`. Not a HUD widget.
- Attributes:
  - spell: `type` = `"spell"`, `spell` = spellID (number preferred) or name
  - item: `type` = `"item"`, `item` = itemID or item:link name
  - macro: `type` = `"macro"`, `macro` = macro name
- Clicks: register both up and down. Honor CVar `ActionButtonUseKeyDown`:
  - If key-down: `RegisterForClicks("AnyDown")` or both edges so SecureActionButton matches Blizzard’s rule.
  - Read `GetCVarBool("ActionButtonUseKeyDown")` when applying. Update on `CVAR_UPDATE` for that CVar if practical; otherwise apply at login and bind time.
- Do not inherit `ActionButtonTemplate` in Phase 1 (no art).

Create all executors for the current spec out of combat. If a spec change happens in combat, queue apply until `PLAYER_REGEN_ENABLED`.

## Bindings

Use **override** bindings only:

```lua
SetOverrideBindingClick(owner, false, key, frameName, "LeftButton")
```

- `owner`: a single frame `MasonBindOwner` (or the addon frame). `ClearOverrideBindings(owner)` then re-apply the current spec kit.
- Do **not** call `SetBinding`, `SetBindingSpell`, or `SaveBindings`.
- Priority: non-priority override (`false`) is enough unless you discover default binds winning; document if you must use priority `true`.

### Steal + toast

When assigning `key` to piece A:

1. If another Mason piece on this spec has that key, clear that piece’s `key` and toast that Mason moved it.
2. `GetBindingAction(key, true)` (or equivalent that sees current binds). Toast the previous command if any, e.g. `ACTIONBUTTON1`.
3. Apply override.
4. Print via `print` or a named toast function:

```
Mason: Q → Fireball (was ACTIONBUTTON1)
Mason: Q moved from Frostbolt
```

Locale-independent is fine in Phase 1 (English strings).

### Clear

`/mason unbind KEY` or `/mason unbind pieceId` removes the key from the piece and reapplies overrides.

Deleting a piece: remove record, destroy or park executor, reapply overrides.

## Combat lockdown

Never in combat:

- `CreateFrame` for secure buttons
- `SetAttribute`
- `SetOverrideBinding*` / `ClearOverrideBindings`
- `RegisterForClicks` if it taints; do it out of combat
- Destroying secure frames

`Mason:QueueIfCombat(fn)` — if `InCombatLockdown()` then store `fn` and run on `PLAYER_REGEN_ENABLED` (stable order). Otherwise run now.

Slash commands that would mutate secure state must use this queue and print `Mason: queued until combat ends` if deferred.

## Slash (`/mason`)

Phase 1 commands:

| Command | Behavior |
|---|---|
| `/mason` | Print usage. |
| `/mason bind <spell> <key>` | Resolve spell by name (or id if numeric), create/update piece for current spec, set key, apply. Key is last token (`Q`, `SHIFT-Q`). Spell name may contain spaces: parse key as the last argument. |
| `/mason unbind <key>` | Clear that key on this spec. |
| `/mason list` | Print current spec pieces: id, type, name, key. |
| `/mason clear` | Remove all pieces for current spec and clear overrides. Confirm not required in P1. |
| `/mason debug` | Print specID, piece count, CVar key-down, combat state. |

Examples:

```
/mason bind Fireball Q
/mason bind 133 SHIFT-E
/mason unbind Q
/mason list
```

If the spell is unknown / not in spellbook, print an error and do not create a piece.

## Events

Register:

- `PLAYER_LOGIN` or `ADDON_LOADED` for Mason → init DB, create executors for current spec, apply overrides (must be out of combat; login is).
- `PLAYER_SPECIALIZATION_CHANGED` → queue rebuild for new spec kit.
- `PLAYER_REGEN_ENABLED` → flush queue.
- Optional: `CVAR_UPDATE` for `ActionButtonUseKeyDown`.

## Module files

Suggested:

```
Mason/Mason.toc
Mason/Mason.lua          -- AceAddon embed, slash, events
Mason/Core/Queue.lua     -- QueueIfCombat
Mason/Core/DB.lua        -- AceDB defaults, spec kit accessors
Mason/Executors/Executor.lua
Mason/Executors/Binds.lua
```

Keep it small. No unused packages.

## API to export on `LibStub` or addon table `Mason`

```lua
Mason:QueueIfCombat(fn)
Mason:GetCurrentSpecID()
Mason:GetKit(specID?)          -- table of pieces
Mason:CreatePiece(fields)      -- returns piece; queues if combat
Mason:SetPieceKey(id, key)     -- steal + toast + apply
Mason:ClearPieceKey(id)
Mason:DeletePiece(id)
Mason:ApplyOverrides()         -- current spec only
```

Do not create a public UI API.

## Acceptance (human in-game)

Out of combat unless noted.

1. `/reload` — no Lua error, Mason in addon list.
2. `/mason debug` — prints spec and zero or more pieces.
3. `/mason bind Fireball Q` (use a spell you know) — toast; `/mason list` shows the piece.
4. No new icon visible on the default HUD from Mason.
5. Press Q — spell casts (or begins targeting) out of combat.
6. Enter combat, press Q — spell still casts. No error/taint popup.
7. `/mason bind Frostbolt Q` — toast that Q moved / previous action; Frostbolt now on Q; Fireball piece has no key (or updated list).
8. `/mason unbind Q` — Q no longer casts the Mason spell; Blizzard/default bind behavior for Q returns (override gone).
9. Switch spec if available — other spec’s Mason keys apply; previous spec overrides cleared.
10. `/mason bind ...` during combat — message queued; after combat ends, piece exists and key works.

If a class has no Fireball, substitute any known spell name.

## Out of scope

Visible buttons, drag/drop, snap, flyouts, Masque, AceConfig, import strings, learn-spell scanner, vehicle/possess drivers, hiding Blizzard bars.

## Stop conditions

Stop and ask Architect if:

- SecureActionButton will not fire from `SetOverrideBindingClick` after matching the key-down CVar.
- Ace3 cannot be vendored cleanly.
- Spec change API differs on 12.x from `PLAYER_SPECIALIZATION_CHANGED` / `GetSpecializationInfo`.

Do not work around by switching to `SetBinding` or writing action slots.
