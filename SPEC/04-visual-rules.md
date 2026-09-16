# Mason Phase 4 — Visual rules

Implement this file only. No flyouts, dock graph, or new themes beyond paint.

## Goal

Each piece can follow a **rule** that drives visibility and paint (alpha, desat). Global defaults exist. A piece can use a named preset, a raw macro-condition string, and/or a local override.

Hierarchy (last wins):

1. Theme defaults (constants this phase; no theme editor)
2. Named rule assigned to the piece
3. Per-piece override fields

## Secure vs paint

**Secure (visibility only)**  
`RegisterStateDriver(exec, "visibility", condition)`  
Condition is a macro-state string, e.g. `[@target,exists] show; hide` or `[combat] show; hide`.  
Register/unregister **out of combat only** (`QueueIfCombat`).  
Do not use state drivers for alpha or desat.

**Insecure (paint)**  
On `PLAYER_TARGET_CHANGED`, `PLAYER_REGEN_*`, spec, and a slow OnUpdate (0.1s) while views exist: set `SetAlpha`, icon desat / vertex color. If a value is secret, skip that channel.

Hidden by a rule: `ClearView` is **not** called. The executor is hidden by the driver; layout `views[id].visible` stays true. Edit mode shows all pieces that have a view record so you can still drag them (ignore the driver while unlocked, restore drivers on lock).

## Data

```lua
db.profile.rules = {
  [ruleId] = {
    id = "r_combat",
    name = "Combat",
    -- secure
    visibility = "[combat] show; hide",
    -- paint (insecure)
    alphaCombat = 1,
    alphaOOC = 1,
    desatUnusable = true, -- already LAB; rule may force desat
  }
}

db.char.views[pieceId].ruleId = "r_combat" or nil
db.char.views[pieceId].override = {
  visibility = nil,  -- raw string replaces rule
  alpha = nil,       -- 0-1 constant if set (no driver)
}
```

Kit piece record stays bind-only. Rules live on the view / profile.

## Built-in presets (create if missing)

| id | visibility |
|---|---|
| `r_always` | `show` |
| `r_combat` | `[combat] show; hide` |
| `r_ooc` | `[nocombat] show; hide` |
| `r_target` | `[@target,exists] show; hide` |
| `r_harm` | `[@target,harm] show; hide` |
| `r_help` | `[@target,help] show; hide` |
| `r_stealth` | `[stealth] show; hide` |

No custom-rule UI this phase. Assign by slash.

## Slash

```
/mason rule <key|id|spell> <preset>
/mason rule <key|id|spell> clear
/mason rules
```

`preset` is one of: `always combat ooc target harm help stealth`.  
`/mason rules` lists presets.  
Notify `Void Bolt rule combat`.

Invalid condition must not register; print the error.

## Edit mode

While unlocked: `UnregisterStateDriver(exec, "visibility")`, `Show()` every piece with a view so handles work. On lock / combat-lock: apply drivers again.

## Theme

This phase: one implicit theme.

```lua
DEFAULT_ALPHA = 1
```

No AceConfig theme panel.

## Files

`Mason/Rules/Rules.lua`  
Call `ApplyRule(exec, piece)` from `PlaceView` and on spec/login (queued).

## Acceptance

1. `/mason rule Q combat` — piece hidden OOC, shown in combat, key still works while hidden (crate-style executor still bound).
2. `/mason rule Q target` — shown only with a target.
3. `/mason rule Q clear` — always shown if it has a view.
4. Unlock — hidden-by-rule pieces appear for layout; lock — drivers return.
5. `/reload` — rule assignments persist.
6. Bad `/mason rule Q combat]` — error, previous driver unchanged.
7. Flyouts / Masque / assisted / snap unchanged.

## Out of scope

Custom condition editor, saturation sliders, per-piece colors, hiding keys (binds always on), aura-based rules (macro conditions only).
