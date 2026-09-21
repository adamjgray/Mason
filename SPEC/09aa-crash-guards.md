# Mason 09aa — Crash guards (source panels)

Formal record of the **crash hard rules** shipped with the 09aa raise-loop fix and retained by **09ab**. These are durable SoT alongside `SPEC/09ab-source-panels-no-raise.md` and Project `preferences.md`.

Pre-09ab chase SPECs that once described raise/undim behavior are **archived** under `SPEC/archive/kb-chase/`. Durable bits from `09w` / `09x` / `09y` / `09z` / `09r` are folded here (and restated in 09ab). Do **not** re-implement archived raise Acceptance.

## End goal

Bags / spellbook / toys / macros can open during bind-mode and always-on hotkey paint **without**:

- C stack overflow from Show → raise → Show
- Multi-second freezes from window tree-walks
- Chat re-entry from `print` inside Blizzard `Show`

## Crash hard rules (frozen)

1. **No raise from bag `Show`.** Bag open may schedule paint/attach only (`ScheduleBagFollowup` / `RepaintSourceHotkeys`). Never call Raise*/undim helpers from bag Show.
2. **`RaiseBindItemButtons` is a permanent no-op** (or deleted with no callers). Never raise item buttons.
3. **No BindMode window tree-walk.** Do not recurse `GetChildren` / `GetRegions` on source **windows** (bags, `PlayerSpellsFrame`, `MacroFrame`, `CollectionsJournal`, CombinedBags chrome). Named/pool cells and adapters only.
4. **Cell-local region walks are OK.** Walking `btn:GetChildren` / `GetRegions` on a **known cell** to find an icon host is not a window tree-walk. Window walks are forbidden; cell-local host find is cost/style, not a crash-guard violation.
5. **No `HookBindUndimShow` → raise path.** That OnShow → raise loop is the overflow. Keep the hook a no-op or delete it.
6. **No `print` from bag / book / toy / macro `Show`** (folded from 09w). Chat `AddMessage` re-entry through container generate caused C stack overflow. Prefer silence; if a one-shot probe is needed, defer with `C_Timer.After(0, …)` once per kind — never print from Show.
7. **CombinedBags-only bag frame targeting** when a bag frame reference is needed for paint/attach. Do not expand to every `ContainerFrame*` for raise/undim (raise is banned anyway).
8. **One deferred identity probe per kind per session** if identity is nil on cells — then stop (handoff / 09ab). No multi-second `WatchLazyBindFrames` pulse; no multi-delay raise followup waves.

## Painter / adapter durables (folded)

From **09x** (kept; raise clauses discarded):

- One store-driven painter entry: `RepaintSourceHotkeys` (clear tracked hosts → paint). Overlay cell helper: `PaintKbOverlay(button, kind, id)` via `KeyForIdentity`.
- Do not add parallel SetText loops outside that path.

From **09y** (kept; “raise book like MacroFrame” discarded):

- Per-kind adapters: `buttons()` → visible cells; `identity(button)` → spellID / itemID / toyID / macro name.
- Shared only: `PaintKbOverlay`, `AttachKbHover`, `KeyForIdentity`. No `visible[i] → pieces[i]`.

From **09z** (kept):

- Collectors use named / pool actives only — never start at the window and walk descendants.
- One `masonKbHook`-style install flag per path.

From **09r** (folded):

- Nil-safe `PlayerSpellsFrame` / spellbook root: if the frame is missing, skip paint/attach for that kind; do not error.

## Relationship to 09ab

| Concern | Owner |
|---------|--------|
| Crash / overflow / tree-walk / print-from-Show | **This file (09aa)** |
| No Blizzard Raise/strata undim; veil dim-only; always-on store paint; hover mixins | **09ab** |
| Product: accept current veil dim (no cutouts / no Raise undim) | **09ab** + preferences (decided) |
| Review / QA process | `SPEC/review-gates-kb.md`, `SPEC/qa-kb-source-panels.md` |

## Forbidden

- Restoring Show→raise, item-button raise, or `HookBindUndimShow` raise.
- Window `GetChildren` walks “to undim” or “to find every button.”
- Treating archived `09g`–`09v` Acceptance as requirements.
- Inventing veil cutouts or Raise undim without a new product SPEC (current product: **accept dim**).

## Done when

Docs + code comments/no-ops agree with this checklist. Behavior verification is human `/reload` QA under `SPEC/qa-kb-source-panels.md` — not a Lua change in Track A.
