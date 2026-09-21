# Mason 9u — Bag perf + attach; book undim + ID paint; toy SetText

Do **not** edit macro functions. Macros work. Copy from them; do not invent a third path.

Do not change scale host, flyouts, or profiles.

## End goal

First `/mason kb` after reload: bags open at normal speed and hover-bind immediately. Spellbook is undimmed; each visible spell button shows `piece.key` only when that button’s **current spellID** matches the piece. Toys show `piece.key` on the matching toyID.

No hardcoded keys or spell names.

## Why this failed

Bags: first Show walks the whole bag tree, hooks every descendant, and still returns before bind-owner attach. That hitch + second-kb-only bind is the same bug as 9t with extra work.

Spellbook: veil still covers PlayerSpellsFrame. Paint still assigns keys by visible index.

Toys: bind uses toyID; FontString is created or leftover empty / hidden / wrong parent.

## 1. Bags — less work, same attach as second kb

- Do not recurse every bag child on Show.
- Walk only `ItemButton` / container item frames (same set hotkeys already paint).
- One HookScript per button (`masonBagKbHook`); never stack hooks.
- After that walk, while `bindMode`, call the **exact** function a later `/mason kb` uses for hover + bind owner. If that function is only inside `ShowBindVeil`, extract it and call it from bag Show too.
- No OnUpdate bag scan.

## 2. Spellbook

- On book OnShow while kb: raise PlayerSpellsFrame above the veil (same raise as MacroFrame).
- Paint: `button.masonHotkey:SetText(piece.key or "")` iff `ButtonSpellID(button) == piece.spellID` (or override/base). Never `visibleButtons[i]` → `pieces[i]`.
- Page change: clear every visible hotkey, then the same ID pass.

## 3. Toys — SetText only

Find the function that paints toy hotkeys. After identity is known:

```
fs = button.masonHotkey
if not fs then create on button, TOPRIGHT icon end
fs:SetText(key or "")
fs:Show()
fs:SetAlpha(1)
```

`key` = piece.key when toyID matches. Do not touch toy hover/bind.

## Done when

1. Reload → first kb → bags open quickly; hover gold + bind without a second kb.
2. Book undimmed; bound spell’s button shows that piece’s key on every page.
3. Bound toy shows that piece’s key.
4. Macros unchanged.
