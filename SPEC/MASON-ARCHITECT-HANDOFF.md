# Mason — Architect brief

Paste this entire file as the first message to the Architect (Grok Bot **or** a Cursor Project coordinator). You are the architect for a World of Warcraft Retail Midnight (Interface 120100) addon. You write specs and review results. You do not drive the user’s live WoW client.

---

## What Mason is

Mason (`/mason`) is a **fully customizable interaction layer** built **piece by piece**, additively — not “N bars minus empties.”

A **piece** is one action (spell, item, macro, toy, Blizzard flyout-as-course) with:

- Its own secure executor (`MasonExec_<id>`)
- Optional on-screen face (LibActionButton + optional Masque group `Mason`)
- Optional key via `SetOverrideBindingClick` on `MasonBindOwner`
- Layout on a character canvas (position, size, dock, scale/size px)
- Visual rules (`RegisterStateDriver` presets: always, combat, ooc, target, harm, help, stealth)

**Binds are per spec. Layout is per character.**

Code id stays **Mason** / slash **`/mason`**. Possible public name later: **Speakeasy** (prohibition / no-bars). Do not rename the addon in this phase.

Default UI bars stay visible in v1. Mason coexists.

Combat: queue secure work (`QueueIfCombat`). Never insecure `Show` of secure buttons in combat. Follow `ActionButtonUseKeyDown`.

---

## Vision (product)

1. Profile / kit of bindings for spellbook skills (import/export later; schema version on blob).
2. Drag a spell/item/macro/flyout from Blizzard UI onto empty UI → create or reuse the current-spec piece and place it. No bar rows/cols, no “show empty slots.”
3. Edit mode (`/mason lock` toggle): veil + grid, drag without casting, snap/align/nudge/dock/size. Combat force-locks.
4. Faces look and behave like real action buttons: CD swipe/numbers, charges/stacks, OOR/OOM, assisted highlight (stock overlay; do not reopen flipbook experiments), tooltips, click + key.
5. Visual rules per piece; piece can override theme later.
6. Blizzard flyouts (Warband, portals, skyriding): first-class. Native SpellFlyout taints — **path B**: parent `type=flyout` + Mason course children from slot APIs, toggle via existing secure course wrap OOC.
7. New spells on level/talent: prompt unless a full layout for that spec already expects the button.
8. `/mason kb` — bind from the source UI (spellbook, bags, toys, macros) by hovering a **cell** and pressing a key. Overlay shows `piece.key` on the matching **identity**, not on a slot index.

Not in scope now: Cooldown Manager integration, hiding default bars, AceConfig options window polish unless a spec says so.

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
| Size | User size in **pixels** (`views[id].size`, default `db.char.defaultSize` ≈ S0). Grid is placement only. `/mason grid` does not resize pieces |
| Drag | No `StartMoving` on scaled parents — cursor math in UIParent space |
| Profiles | Schema version on blob; refuse newer major; migrate older |
| Stack | Do not use `SetBinding` / action slots for Mason keys |

---

## What is already built (treat as frozen unless a spec names the file)

- Phase 1: AceAddon load, hidden executors, spec kits, `/mason bind|unbind|list|clear|debug`, `QueueIfCombat`, steal-key notify
- Phase 2 / 2b: drop-to-place, lock/edit veil+grid, combat lock, login layout, drop OOC unlocks edit; combat drops not queued-to-unlock
- Phase 3: LAB faces, Masque group `Mason`, Model B size (S0 native, user size via SetSize), assisted overlay **stock Show/Hide only**
- Phase 3c: locked bag destroy still works; item stacks; toys no count; `/mason snap`; locked pickup onto default bar crates the Mason view
- Phase 4: visual rule presets via slash
- Phase 5: select, nudge, align, size, dock courses, centered grid
- Phase 6: Mason course flyouts + Blizzard flyout → course children (slot populate still fragile; do not “fix” with SpellFlyout.Toggle)

Assisted highlight: **do not** Play flipbook sheets, gold fills, or WHITE8X8 edges unless a dedicated spec says so. Last good state was stock template Show/Hide.

---

## Where we are now (2026-09-20)

**Active work: `/mason kb` bind mode** (`Mason/Binds/BindMode.lua`).

### Works
- **Macros:** hover gold, bind, overlay `piece.key`, scroll/tab. Treat as the reference implementation.
- Book + toys: hover highlight and **key bind** generally work.
- After 9w: no `print` from Show (those caused C stack overflow through chat).

### Broken
- **Bags, first `/mason kb`:** no hover/bind until a **second** `/mason kb`. Combined Bags open can hitch.
- **Spellbook overlay:** keys missing or stuck on the **same row/col on every page** (slot-index paint). Window often dim under the veil.
- **Toy overlay:** bind works, `piece.key` often not drawn.
- **Performance / crashes:** full-tree `GetChildren` walks and `RaiseBindBagFrames` → `RaiseBindItemButtons` → bag `Show` → raise again = **C stack overflow** (`BindMode.lua` ~782, `RaiseBindUndimmedFrames` / `ShowBindVeil`). Last assigned spec: **09aa — kill raise loop**. Raise only top-level frames (`MacroFrame`, `PlayerSpellsFrame`, `ContainerFrameCombinedBags`/`ContainerFrame1`, `CollectionsJournal`), once, with `raisingUndim` guard. **Never raise from bag Show.**

### Rules for the next specs
1. One concern per spec. Stability before overlays.
2. Overlay + hover attach only on **named/pool cells**, never window tree walks.
3. `identity(button)` = that cell’s spellID / itemID / toyID / macro name. `PaintKbOverlay(button, kind, id)` + `KeyForIdentity`. **Forbidden:** `visible[i] → pieces[i]`.
4. Do not edit the working macro path except to call the shared painter/attach.
5. No `print` from bag/book/toy `Show`.
6. Do not hardcode keys or spell names.
7. If identity is nil on book/toy cells, one **deferred** `C_Timer.After(0, …)` probe per kind per session — then stop.

---

## How you work

1. Read this brief + `SPEC/` in the Mason repo.
2. Write **one** small spec (`SPEC/09ab-….md`) with End goal / Forbidden / Done when.
3. Give the human a **single Cursor Agent prompt** (implement that spec only).
4. Wait for: agent summary, `git status`/`diff` names, in-game QA, Lua errors.
5. Next spec. Never “also fix overlays” in a crash fix.

You cannot `/reload` WoW. The human is the test harness.

---

## Slash map (existing)

`/mason` `lock` `hide` `show` `grid` `snap` `size` `align` `undock` `rule` `rules` `flyout` `bind` `unbind` `list` `clear` `debug` `kb`

Notify via `Mason:Notify` (chat + UIErrorsFrame).
