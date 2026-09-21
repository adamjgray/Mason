# Mason 9m — Spellbook paint back; second-open bags/macros

Do not change scale host, flyouts, profile layout, or the Texture undim guard.

## End goal

Spellbook icons show Mason chords after `/reload` with kb off. `/mason kb` then the **first** bag open and the **first** `/macro` show a usable grid and accept hover-bind.

## Why this failed

9l skipped Textures and retried bags on `buttons=0`. That retry either never undims the **item buttons** that exist later, or hover-bind still walks Combined Bags before ScrollBox children exist.

Macros: first Show looks like screenshot 1 — tabs + selected name + edit box, **selector body empty**. The `?` grid is built on a later layout pass. Mason raises/paints that empty body and does not run again when the selector fills. Second `/macro` already has buttons, so it works.

Spellbook: 9h–9j painter was not called from login/OnShow after 9l, or it now parents to a skipped Texture and never SetTexts. Result: no `9` on Polymorph until something else binds.

## 1. Spellbook

Restore the 9j painter:

- PLAYER_ENTERING_WORLD, SPELLS_CHANGED, SpellBook/PlayerSpells OnShow, tab change, after ApplyOverrides
- One FontString, TOPRIGHT of the **spell icon**
- Works with kb off

Do not require RaiseBindUndimFrame. Paint is independent of the veil.

## 2. Macros first fill

Treat “selector has zero icon buttons” as not done.

After Show:

- After(0), After(0.15), After(0.4)
- Hook the 12.x selector `OnUpdate` / data provider callback / tab click (`General` vs character) to raise+paint when button count becomes > 0
- Call stock `MacroFrame_Update` if it exists

Screenshot 1 = fail. Screenshot 2 = success. Stay on the retry until the second layout exists **in this same first open**.

Hover-bind attaches when buttons appear, not only at kb enter.

## 3. Bags first fill

Same: `buttons==0` is not success. Retry until `buttons>0` or 1s elapsed. Also hook Combined Bags ScrollBox / container OnShow on the **item button parent**, not only the outer frame.

## Done when

1. `/reload`, book open, kb off — Polymorph shows `9` on the icon.
2. `/reload`, kb, first `/macro` — grid like screenshot 2, hover-bind works.
3. `/reload`, kb, first bags — hover-bind on items.
4. `/mason kb` still does not error on Textures.
