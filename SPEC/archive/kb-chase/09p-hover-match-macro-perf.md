# Mason 9p — Bag hover; spell match; macro perf

Do **not** change toy-box paint, hover, or raise. Toys work.

Do not change scale host, flyouts, profiles, or the Texture undim guard.

## End goal

First `/mason kb` after `/reload`: bags hover-bind. Spellbook is undimmed, `9` on Polymorph only. `/macro` shows chords without hitching on tab/scroll.

## Why this failed

Bags: first-open raise paints hotkeys but never attaches the hover glow / bind target to item buttons. Second session worked because attach ran at kb enter when bags already existed.

Spellbook: paint walks buttons by index, not by spellID. Fireball is the first cell; Polymorph’s piece key is written there. Veil covers PlayerSpellsFrame (`masonSpellBookFrame`) so the book stays dim until Collections Show raises it and moves it.

Macros: every OnUpdate / acquire / scroll / tab re-walks the whole selector and creates FontStrings. That tanks tab and scroll.

## 1. Bags hover (first kb)

When Combined Bags `buttons>0` while kb is on, run the **same hover-bind attach** toys use (glow + catcher on item buttons). Paint already works — do not rewrite bag paint.

## 2. Spellbook

- Undim `PlayerSpellsFrame` / `masonSpellBookFrame` on book OnShow while kb is on. Do not wait for Collections.
- Map chord by **spellID** (and override/base id), not button index. Polymorph’s piece → the button whose data is Polymorph. No Fireball `9`.
- One FontString per spell button; TOPRIGHT of that button’s icon.

## 3. Macros perf + chords

- Paint only when selector **content** changes (Show, tab, data refresh), not every OnUpdate.
- Reuse FontStrings; do not CreateFontString on scroll.
- Show the piece key when `piece.type == "macro"` and names match (exact macro name).
- Cap work per pass (visible buttons only if ScrollBox exposes them).

## Done when

1. `/reload` → kb → first bags — hover gold + bind (toys still perfect).
2. kb → spellbook — window undimmed; `9` on Polymorph, not Fireball.
3. `/macro` — chords on bound macros; tab/scroll usable (no multi-second hitch).
4. Toy box unchanged. No new nil-method errors.
