# Mason — QA checklist (kb / source panels)

Living human `/reload` checklist for BindMode / source-panel work. Mirrors **09ab Done when** + always-on preferences + **09aa** crash guards.

Agents cannot drive the live client. The human pastes results (dated notes under Project `internal/` when used).

**SoT:** `09ab` + `09aa` + preferences. Do not fail QA for “panels still look dim under the veil” by demanding Raise undim — **product: accept current veil dim**.

---

## Baseline smoke (every BindMode / paint / hook PR)

After `/reload` (debug off unless testing debug paths):

1. **Always-on chords (no kb):** open bags / spellbook / toys / macros **without** `/mason kb` → chords match store on matching identity cells.
2. **Enter kb:** `/mason kb` → gold hover on cells; bind / steal / clear / delete piece → panels update (clear stale + current) via store paint.
3. **First open cold vs second open:** all four panels — no SoftFill/Rebuild theater; no Raise; macros no flash-then-blank.
4. **Combat:** cannot enter kb (or secure work queues); paint queues via `QueueIfCombat`; no CreateFrame / SetAttribute / override bind / RegisterStateDriver in lockdown.
5. **Crash guards:** no Show→raise overflow; no item-button raise; no window tree-walk; no ungated `print` from Show.
6. **Review gates:** PR did not reintroduce archived-SPEC raise/undim behavior (`review-gates-kb.md`).

---

## 09ab Done when (surface matrix)

| Surface | Expect |
|---------|--------|
| **Bags** | First Combined Bags open (with or without kb for hover/bind): usable under veil dim, gold hover in kb, bind, store hotkey on matching item cell |
| **Spellbook** | First open: gold hover in kb, bind, `piece.key` on matching spellID (not slot-index) |
| **Toys** | First open: gold hover in kb, bind, `piece.key` on matching toyID |
| **Macros** | Full selector grid visible (no flash-then-blank); hover; bind; store hotkeys; no hitch from raise/pulse |
| **Veil** | Dim-only; Blizzard chrome not Raise/strata-undimmed. Gray-but-usable under dim = **accepted product** |

---

## How to record results

- Paste pass/fail per row into a dated Project note (e.g. `internal/09ab-reload-qa-rN.md`).
- Open failures stay open until green **or** product waives (veil dim already waived for “undimmed enough” via accept-dim).
- Do not close a SPEC as Done on warm-only evidence if cold first-open was the failure mode.
