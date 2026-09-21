# Mason 9q — Hotkey follows the icon; bag hover

Do not change scale host, flyouts, or profiles. Keep the Texture undim guard.

## End goal

Every Mason chord (bags, book, toys, macros) is parented to **that cell’s icon** and moves when the grid pages or scrolls. First kb after reload: bag items hover-gold. Escape does not leave bags stuck dim.

## Why this failed

FontStrings are parented to MacroFrame / ToyBox / SpellBook / Combined Bags (or a static overlay). ScrollBox reuses the same 12–40 buttons. Paint runs once by **visual index**, so:

- Toy/macro `9` stays in grid slot (1,1) while the toy/macro under it changes
- Book `9` lands on Fireball (first painted cell) and is missing on the page that was already visible at OnShow
- Bags show keys but never get the hover hook on first open; Escape / second kb leaves random items undimmed because raise ran on a stale child list

## 1. Own the FontString on the button

For every hotkey:

```
fs:SetParent(button)
fs:SetPoint("TOPRIGHT", icon, "TOPRIGHT", -2, -2)
```

`icon` = `button.icon` / `button.Icon` / first Texture. If the button is recycled, **reuse** `button.masonHotkey` and SetText for the **current** spellID / toyID / macro name / itemID. Empty text when that cell has no Mason piece.

Never parent to the journal, selector, or UIParent.

## 2. Repaint on recycle

Hook the ScrollBox/paging path each UI already uses:

- Toys: page buttons / `ToyBox_OnMouseWheel` / acquire
- Macros: selector scroll + tab
- Spellbook: page flip / spec tab
- Bags: container generate / item button OnShow

On each event: walk **visible** buttons only, read **current** identity, SetText. No CreateFontString per scroll tick.

## 3. Spellbook identity

`spellID` from element data / `C_SpellBook` / button API. Match piece.spellID or override/base. Do not use `GetID()` as a slot index. Paint the **already visible** page on OnShow (not only after a page flip).

## 4. Bags hover + veil

First kb: attach the same OnEnter/OnLeave glow toys use to each **item button** when `buttons>0`.

Escape: if it exits kb, restore bag frame levels/alpha like leaving kb normally. Do not leave Combined Bags under the veil.

Second kb: undim from a fresh button walk, not the first-open snapshot.

## Done when

1. Reload → kb → first bags — hover gold + bind; Escape leaves bags normal.
2. Book — `9` on Polymorph on the page that is open **and** after paging; never on Fireball unless Fireball is bound.
3. Toys — page/scroll: `9` stays on the **same toy**, not the same grid hole.
4. Macros — scroll/tab: `9` stays on that macro’s icon.
5. No hitch from OnUpdate full-grid create.
