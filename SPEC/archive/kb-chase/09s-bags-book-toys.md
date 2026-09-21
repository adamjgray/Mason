# Mason 9s — Bag hover-bind; book veil+ID; toy hotkeys

Do **not** change macro paint, hover, scroll, or bind. Macros work.

Do not change scale host, flyouts, or profiles.

## End goal

First `/mason kb` after reload: bag items hover-gold and accept a key (Escape on a hovered item clears that bind, does not leave kb unless nothing is hovered). Spellbook undimmed; highlight on the **icon**; `9` on Polymorph regardless of which page was open. Toys show `9` on the toy icon again; bind stays as it is now.

## Why this failed

Bags: hotkey FontString is on the item, but OnEnter/bind-target never attached on first open. Escape is the global kb-exit, not “clear this piece.”

Spellbook: veil still covers PlayerSpellsFrame. Highlight is the full spell row. Paint still keys off visible-page **order**, so the opening page gets a different mapping than page 2.

Toys: 9q/9r reparent or recycle cleared `masonHotkey` and never SetText again. Bind path still finds the toyID.

## 1. Bags = copy macro hover-bind

Reuse the **macro** attach (OnEnter glow + bind catcher on the button). Call it when Combined Bags `buttons>0` while kb is on, and on each item OnShow.

Escape: if the cursor is over a Mason-bound bag item in kb, clear that piece key only. If not over a bind target, exit kb and restore bag levels (current Escape).

## 2. Spellbook

- Raise/undim `PlayerSpellsFrame` on book OnShow while kb is on (same raise macros use).
- Hover glow on the spell **icon button**, not the name row.
- Match **spellID** from that button’s element data every paint, including the page already visible at open. Paging only SetTexts; it must not shift keys to other spells.

## 3. Toys

Restore FontString on `button` TOPRIGHT of `icon`, SetText from current toyID when the cell has a piece. Recycle = SetText or `""`. Do not rewrite toy bind; it works.

## Done when

1. Reload → kb → first bags — hover gold, key sticks, Escape-on-item clears bind.
2. Book — undimmed; icon-only highlight; `9` on Polymorph on whatever page is showing.
3. Toys — `9` visible on the bound toy; bind unchanged.
4. Macros still perfect.
