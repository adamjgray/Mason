# Mason Phase 8 — Import / export

No AceConfig. No learn-spell prompt. Do not change scale host or bind mode.

## Goal

Share a kit (binds) and/or a layout (views) as a compressed string. Schema version on the blob. Refuse a **newer major**. Accept an older major with a migrate function.

## Libraries

Use vendored **LibDeflate**. If AceSerializer-3.0 is not in `Mason/libs`, vendor it too (or a 40-line table serializer). Do not invent a new compression format.

## Schema

```lua
{
  v = 1,              -- major
  addon = "Mason",
  kind = "kit" | "layout" | "full",
  specID = 258,       -- kit/full
  class = "PRIEST",   -- advisory
  kit = { ... },      -- spec kit pieces (no executors)
  views = { ... },    -- char views keyed by piece id
}
```

`kit` is the current spec’s piece table from AceDB (`id`, `type`, `key`, `spellID` / `itemID` / `macro` / `flyoutId`, `flyout` child ids).  
`views` is `db.char.views` for those ids (`x`, `y`, `size`, `visible`, `dock`, `ruleId`, `flyout` layout fields).

Do not export: executors, handles, hosts, combat queue, bind-mode state.

## Versioning

`SCHEMA_MAJOR = 1`.  
Import: if `v > SCHEMA_MAJOR`, print `Mason: export is newer than this addon` and stop.  
If `v < SCHEMA_MAJOR`, run `Migrate(data)` (v1 has no migrate yet; stub that returns data).

## Slash

```
/mason export kit
/mason export layout
/mason export full
/mason import
```

`export` compresses, encodes printable (LibDeflate print/encode for addon channels), and:

1. Prints a short status: `Mason: exported kit 1842 chars`.
2. Puts the **full string** in a small dialog (same chrome as bind panel) with the text selected so the user can Ctrl+C. Do not dump 2k chars into chat.

`/mason import` with no args **opens the same dialog empty** for paste + an Import button.  
`/mason import <string>` applies immediately if the string is on the command line (short tests).

## Apply

**kit:** replace current spec kit pieces that appear in the blob; keep piece ids from the blob when possible. `ApplyOverrides` after.  
**layout:** write `db.char.views` for ids that exist in the (new) kit. `ApplyLayout`.  
**full:** kit then layout.

Wrong class / spec: still import but `Notify` `imported kit for spec 258 (you are 262)` so the user knows. Do not silently drop.

Combat: queue apply via `QueueIfCombat`.

## Acceptance

1. `/mason export kit` — dialog with a string; copy; `/reload`; `/mason import` paste — keys match.  
2. `/mason export layout` then import on the same character — pieces sit where they were.  
3. String with `v=2` — refused.  
4. Import while in combat — applies after regen.  
5. Bind mode, scale host, flyouts unchanged.

## Out of scope

Battle.net link sharing, WeakAuras-style wago.io, merging two kits piece-by-piece UI.
