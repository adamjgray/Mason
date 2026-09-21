# Mason 9ab — Source panels without Blizzard raise

Do **not** change scale host, flyouts, profiles, or the crash hard rules from [`09aa-crash-guards.md`](09aa-crash-guards.md).

This is a **thin re-architecture** of `/mason kb` source-panel undim / hover / hotkeys. It replaces the strata/raise arms race (passes 3–7 on the raise-loop PR). Do not patch undim by raising Blizzard chrome again.

**Companion process:** [`review-gates-kb.md`](review-gates-kb.md) · [`qa-kb-source-panels.md`](qa-kb-source-panels.md) · SPEC [`README.md`](README.md)

## Why this exists

Human QA (r2–r6) falsified “raise bags/book/macros above the veil”:

- Bags stay gray even when undim targets were raised to `TOOLTIP` above a `HIGH` veil.
- Raising `MacroFrame` / `MacroSelector` blanks the macro grid (raise itself is the blanking event).
- Hotkeys painted from bind-keypress paths go stale; store-driven clear+paint is the only durable model.
- Multi-delay raise followups and `WatchLazyBindFrames` 12s pulse are compensatory noise.

Crash is fixed when Show→raise and item-button raise are dead (**09aa**). Undim/hover/hotkeys need a different ownership model — not pass-8 on the same raise helpers.

## End goal

In `/mason kb`, first open of bags / spellbook / toy box / macros: hover gold, bind, and store-driven hotkeys work without fighting Blizzard frame strata. Hotkey **display** also works with panels open **without** kb (always-on).

## Architecture (required)

### 1. Veil — dim only

- Fullscreen dim at `BACKGROUND` or `LOW`.
- `EnableMouse(false)`. Never raise the veil to “win” draw order.
- **Never** undim Blizzard panels via `SetFrameStrata` / `SetFrameLevel` / `Raise` on those frames.
- **Product (frozen):** accept the current bind-mode veil dim. Panels may look gray under the dim and still be usable. Do **not** invent cutouts, per-panel undim holes, or Raise undim unless a later product SPEC asks.

### 2. Zero Blizzard strata mutation in kb mode

- No `SetFrameStrata`, `SetFrameLevel`, or `Raise` on Blizzard source chrome (bags, PlayerSpellsFrame, CollectionsJournal, MacroFrame, MacroSelector, ScrollBoxes, item/spell/toy buttons).
- Strata/raise allowed **only** on Mason-owned frames (veil catcher, edit bar, glow, Mason FontStrings parents if already Mason-created).
- Macro reference path stays correct by **not** wrecking ScrollBox.

### 3. Hover — one mixin per source kind

- Install once per kind: `ContainerFrameItem*`, `SpellBookItem*`, `ToySpellButton*`, macro selector buttons (named/pool cells only — 09aa / archived 09z).
- Gold glow only. Bind target attach without per-open Raise.
- No window tree-walk; one `masonKbHook`-style flag per install path.

### 4. Hotkeys — single store painter (always-on)

- One entry: `RepaintSourceHotkeys` (or a named successor that fully replaces it).
- Path: clear tracked hosts → `PaintKbAdapter` / `PaintKbOverlay` from `KeyForIdentity` on binding **state data**.
- **Triggers:**
  - panel Show — deferred `C_Timer.After(0, …)` **once** per open (**not** gated on `/mason kb`)
  - bind/clear via `AfterBindChange` (or equivalent store hook)
  - page / scroll Update hooks
  - kb mode on (also triggers repaint; hover/attach only)
  - reload / login when hooks install
- Hotkey **display** is always-on from binding state data. `/mason kb` only mutates bindings.
- **Forbidden:** paint from bind keypress success alone. Bind changes must clear stale + show current from the store.
- **Frozen:** do not re-gate paint on kb mode (older chase SPECs did; those are archived).

### 5. Collectors — named / pool cells only

- Bags / book / toys / macros: named buttons or pool actives only. No window `GetChildren` walks.
- **Cell-local OK:** `btn:GetChildren` / `GetRegions` on a **known cell** to find the icon host is allowed. Walking source **windows** is forbidden (09aa).
- If identity is nil: one deferred probe per kind per session — then stop. Do not add more timers.
- No `WatchLazyBindFrames` 12s OnUpdate pulse. No multi-delay raise spam (`{0, 0.05, 0.15, 0.35}` followup waves).

### 6. Crash guards — retain

Keep [`09aa-crash-guards.md`](09aa-crash-guards.md) intact:

- No raise from bag `Show` (schedule paint/attach only).
- `RaiseBindItemButtons` stays a no-op (or deleted with no callers).
- No BindMode window tree-walk.
- No `HookBindUndimShow` → raise path.
- CombinedBags-only bag **frame** targeting if any bag frame reference remains for paint/attach — never item-button raise.
- No `print` from bag/book/toy/macro `Show`.

### 7. Legacy Raise* names (historical)

Shipped code may still export symbols named `RaiseBindBagFrames`, `RaiseBindMacroFrames`, `PassBagsRaiseAndPaint`, `KbWantsRaise`, etc. Under 09ab those bodies are **paint/hook/schedule only** (or permanent no-ops) — they must **not** `Raise` / mutate Blizzard strata for undim.

- Reviewers: do not treat the name as proof that raise-undim returned.
- Rename to Hook/Schedule/Paint is Track B debt (behavior-identical); not required to claim 09ab compliance.

## What to delete (or permanently no-op)

- `WatchLazyBindFrames` pulse and any timer that re-raises Blizzard chrome.
- Multi-delay `ScheduleBagFollowup` raise waves / recursive followup flags used for undim.
- `RaiseBindMacroFrames` / any MacroFrame or MacroSelector raise-for-undim.
- TOOLTIP / HIGH undim helpers applied to Blizzard frames (`RaiseBindUndimFrame` strata war).
- Dual hotkey stacks that paint outside `RepaintSourceHotkeys` (delegate or delete; one painter wins).

## Forbidden

- Veil strata churn as the undim strategy (LOW↔HIGH↔TOOLTIP games).
- Raising MacroFrame / MacroSelector / ScrollBox to undim or “fix” a blank grid.
- TOOLTIP / HIGH undim war on bags, book, toys, or macros.
- Painting source hotkeys from the bind keypress process alone.
- Re-gating hotkey display on `/mason kb`.
- New OnUpdate scanners or multi-second probe loops.
- `print` from bag / book / toy / macro `Show`.
- Editing the working macro hover/bind path except to call the shared painter / mixin install.
- Hardcoded keys or spell names.
- Mapping `visible[i]` → `pieces[i]`.
- Implementing Acceptance from `SPEC/archive/kb-chase/`.

## Out of scope

- Resetting or rewriting the crash-only raise-loop work beyond what this SPEC requires for the no-raise model.
- Product redesign of the veil (cutouts, per-panel dim) — **declined for now** (accept dim).
- Scale host, flyouts, profiles, Edit Mode, CDM.

## Done when

Human QA after `/reload` (see [`qa-kb-source-panels.md`](qa-kb-source-panels.md)):

1. **Bags** — first Combined Bags open: usable under accepted veil dim, gold hover (in kb), bind, hotkey from store on the matching item cell.
2. **Spellbook** — first open: gold hover, bind, `piece.key` on the matching spellID cell (not slot-index).
3. **Toys** — first open: gold hover, bind, `piece.key` on the matching toyID.
4. **Macros** — full selector grid visible (no flash-then-blank), hover, bind, store hotkeys; no hitch from raise/pulse.
5. **Always-on** — after `/reload`, open panels **without** `/mason kb`: chords match store.
6. Crash hard rules still hold (09aa).
7. No new Lua errors; Debug off stays quiet on Show.

“Undimmed enough” in older drafts meant **usable**, not Raise-bright. Gray-under-dim is an accepted product outcome.
