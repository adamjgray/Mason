# Mason 9t — First-kb bags; book page keys; toy FontString

Do **not** edit macro functions. Macros work.

Do not change scale host, flyouts, or profiles.

## End goal

First `/mason kb` after `/reload`: bag hover + bind (same as today’s second open). Spellbook shows that piece’s **actual key** on the button for that piece’s **spell**, on every page. Toys show that piece’s key on the bound toy.

There is no special key and no special spell. Do not hardcode a key chord, a spell name, or a toy name.

## Why this failed

Bags: first Combined Bags Show paints hotkeys, then returns. Hover/bind attach runs only in `ShowBindVeil` when bags already exist. Second `/mason kb` works because bags are up.

Spellbook: highlight/bind read spellID correctly. **Paint** still writes by visible index or the page-open snapshot, so another page shows the wrong buttons’ keys.

Toys: bind resolves toyID; `masonHotkey` is missing or parented off-icon / alpha 0 / empty after recycle.

## 1. Bags first open

When `buttons>0` while `bindMode`, call the **same** function the second kb uses to hook item OnEnter/OnLeave and bind owner. Not paint-only.

Do not require closing kb. Item OnShow must attach if hooks were skipped at first Show.

## 2. Spellbook paint

Every paint pass: for each **visible** spell button, `SetText` to `piece.key` when that button’s **current spellID** (or override/base) equals `piece.spellID`. `SetText("")` if no piece.

Page flip = full visible pass, not “shift the old strings.”

Do not match by slot index, page index, or spell name.

## 3. Toys paint only

If `button.masonHotkey` is nil, create it on the **button**, TOPRIGHT of `icon`. `SetText` to `piece.key` when current toyID matches the piece. Recycle: SetText or `""`. Show/alpha 1.

Do not change toy hover/bind.

## Done when

1. Reload → first kb → bags hover gold + key capture (no second `/mason kb`).
2. Book — page to the bound spell: that spell’s button shows **its** piece key; other spells on that page do not steal it.
3. Toys — the bound toy’s icon shows **its** piece key.
4. Macros unchanged.
