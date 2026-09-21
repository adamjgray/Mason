# Mason — Architect brief

Paste this entire file as the first message to the Architect (Grok Bot **or** a Cursor Project coordinator). You are the architect for a World of Warcraft Retail Midnight (Interface 120100) addon. You write specs and review results. You do not drive the user’s live WoW client.

---

## What Mason is

Mason (`/mason`) is a **fully customizable interaction layer** built **piece by piece**, additively — not “N bars minus empties.”

A **piece** is one action (spell, item, macro, toy, Blizzard flyout-as-course) with:

- Its own secure executor (`MasonExec_<id>`)
- Optional on-screen face (LibActionButton + optional Masque group `Mason`)
- Optional key via `SetOverrideBindingClick` on `MasonBindOwner`
- Layout on a canvas (position, size, dock, scale/size px) stored on the **AceDB profile** (`db.profile.views`)
- Visual rules (`RegisterStateDriver` presets: always, combat, ooc, target, harm, help, stealth)

**Binds are per spec. Layout is per AceDB profile** (09i — not per-character-only).

Code id stays **Mason** / slash **`/mason`**. Possible public name later: **Speakeasy** (prohibition / no-bars). Do not rename the addon in this phase.

Default UI bars stay visible in v1. Mason coexists.

Combat: queue secure work (`QueueIfCombat`). Never insecure `Show` of secure buttons in combat. Follow `ActionButtonUseKeyDown`.

---

## Vision (product)

1. Profile / kit of bindings for spellbook skills (import/export; schema version on blob).
2. Drag a spell/item/macro/flyout from Blizzard UI onto empty UI → create or reuse the current-spec piece and place it. No bar rows/cols, no “show empty slots.”
3. Edit mode (`/mason edit` / `/mason lock`): veil + grid, drag without casting, snap/align/nudge/dock/size. Combat force-locks.
4. Faces look and behave like real action buttons: CD swipe/numbers, charges/stacks, OOR/OOM, assisted highlight (stock overlay; do not reopen flipbook experiments), tooltips, click + key.
5. Visual rules per piece; piece can override theme later.
6. Blizzard flyouts (Warband, portals, skyriding): first-class. Native SpellFlyout taints — **path B**: parent `type=flyout` + Mason course children from slot APIs, toggle via existing secure course wrap OOC.
7. New spells on level/talent: prompt unless a full layout for that spec already expects the button.
8. `/mason kb` — bind from the source UI (spellbook, bags, toys, macros) by hovering a **cell** and pressing a key. Overlay shows `piece.key` on the matching **identity**, not on a slot index. Hotkey **display** is always-on from store (not gated on kb).

Not in scope now: Cooldown Manager integration, hiding default bars, Classic.

---

## Architecture decisions (do not reopen)

| Topic | Decision |
|---|---|
| Client | Retail Midnight 12.x only (`Interface` 120100) |
| Binds | Named secure executor + `SetOverrideBindingClick`. Steal key + toast what was unbound |
| Data | Ace3 + AceDB + AceConfig + LibDeflate + vendor LAB + optional Masque |
| Canvas | Custom lock/unlock (Ellesmere-like). Not Blizzard Edit Mode for v1 |
| Actions | spell, item, macro, toy, flyout-as-course |
| Flyouts | Max 12 children, one open, no nest. Blizzard flyout ID stored numeric after `GetFlyoutInfo` succeeds |
| Size | User size in **pixels** (`views[id].size`, default ≈ S0). Grid is placement only. `/mason grid` does not resize pieces |
| Drag | No `StartMoving` on scaled parents — cursor math in UIParent space |
| Profiles | Schema version on blob; refuse newer major; migrate older. **Profile owns kit + views + UI settings** (09i) |
| Stack | Do not use `SetBinding` / action slots for Mason keys |
| Source panels | **09ab** no Blizzard Raise undim; veil dim accepted; **09aa** crash guards |
| Hotkeys | Store-driven `RepaintSourceHotkeys`; display always-on |

---

## What is already built (treat as frozen unless a spec names the file)

- Phase 1: AceAddon load, hidden executors, spec kits, `/mason bind|unbind|list|clear|debug`, `QueueIfCombat`, steal-key notify
- Phase 2 / 2b: drop-to-place, lock/edit veil+grid, combat lock, login layout, drop OOC unlocks edit; combat drops not queued-to-unlock
- Phase 3: LAB faces, Masque group `Mason`, Model B size (S0 native, user size via SetSize), assisted overlay **stock Show/Hide only**
- Phase 3c: locked bag destroy still works; item stacks; toys no count; `/mason snap`; locked pickup onto default bar crates the Mason view
- Phase 4: visual rule presets via slash
- Phase 5: select, nudge, align, size, dock courses, centered grid
- Phase 6: Mason course flyouts + Blizzard flyout → course children (slot populate still fragile; do not “fix” with SpellFlyout.Toggle)
- Phase 7–9: bind mode panel, AceConfig, import/export, edit/bind chrome, ghosts, profiles-own-layout
- **Landed: 09aa crash guards + 09ab source panels without Blizzard raise** (`main` @ `df2d402`; human QA r7 passed)

Assisted highlight: **do not** Play flipbook sheets, gold fills, or WHITE8X8 edges unless a dedicated spec says so. Last good state was stock template Show/Hide.

---

## Where we are now (post-09ab / tip `df2d402`)

**Landed on main:** `SPEC/09ab-source-panels-no-raise.md` + `SPEC/09aa-crash-guards.md`.

### Works (SoT met; do not reopen raise)

- **Veil dim-only** — no Blizzard undim Raise/strata in the live path; product **accepts** current dim (no cutouts).
- **Crash guards held** through QA r7: no bag Show→raise, no item-button raise, no window tree-walk, no Show `print` overflow.
- **Always-on store hotkeys** — chords paint from binding state; display not gated on `/mason kb`; bind changes clear+paint.
- **Macros / bags / book / toys** — usable under the no-raise model (hover/bind/store paint direction per 09ab). SoftFill / WatchLazy raise waves dead as behavior.
- **Profile-owned layout** — `db.profile.views` (09i).

### Open product / remediation (not “finish archived raise SPECs”)

- BindMode **obsolete-SPEC debt**: Raise*/SoftFill*/Rebuild tombstones and misleading names — **delete/rename** (Track B), do not restore raise.
- Live 09ab completeness gaps (single painter consolidation, clear-on-recycle, CombinedBags tighten, hook/OnUpdate trim) — see Project remediation plan Track B.
- Core P0/P1 (steal toasts debug-gated, combat drop queue, etc.) — Track C.
- Do **not** score against `SPEC/archive/kb-chase/` Acceptance.

### Rules for the next specs

1. One concern per spec. Prefer delete tombstones over new timers/Raise helpers.
2. Source panels: cite **only** 09ab + 09aa + preferences. Pass `review-gates-kb.md`.
3. Overlay + hover attach only on **named/pool cells**; cell-local icon host walks OK; **window** walks forbidden.
4. `identity(button)` = spellID / itemID / toyID / macro name. `PaintKbOverlay` + `KeyForIdentity`. **Forbidden:** `visible[i] → pieces[i]`.
5. No `print` from bag/book/toy/macro `Show`.
6. Do not hardcode keys or spell names.
7. If identity is nil: one deferred probe per kind per session — then stop.
8. **Next specs must not reopen Blizzard raise** to undim panels.

---

## How you work

1. Read this brief + `SPEC/README.md` in the Mason repo.
2. Write **one** small spec with End goal / Forbidden / Done when — never a raise-undim remake of archived chase files.
3. Give the human a **single Cursor Agent prompt** (implement that spec only).
4. Wait for: agent summary, `git status`/`diff` names, in-game QA (`qa-kb-source-panels.md`), Lua errors.
5. Next spec. Never “also fix overlays” in a crash fix.

You cannot `/reload` WoW. The human is the test harness.

---

## Slash map (existing)

`/mason` `edit` `lock` `hide` `show` `grid` `snap` `size` `align` `undock` `rule` `rules` `flyout` `bind` `unbind` `list` `clear` `debug` `kb` `export` `import` `config` `scale`

Notify via `Mason:Notify` (chat + UIErrorsFrame).
