# Mason 9j — Hotkeys persist; bags/macros after kb

Profiles and layout-on-profile stay as they are. Do not change scale host or flyout populate.

## End goal

After `/reload`, every bound spell/item/toy/macro shows **one** chord on its **icon**, without entering kb. `/mason kb` then opening bags, toys, or macros works the same as opening those windows first.

## Why the last pass failed

- Spellbook paint ran on bind and on kb enter, not on login / SpellBookFrame OnShow after reload. Polymorph is bound; the book is empty until something else retriggers paint.
- Toy box: we added a Mason FontString and never hid Blizzard’s (or we painted twice — icon + parent). Result: `0` stacked twice on Acolyte’s Guise.
- Bags and macros are created the first time they open. A hook on a nil frame at kb-enter does nothing. Combined Bags / MacroFrame OnShow must be hooked via event or `hooksecurefunc` on the open function, not only `frame:HookScript("OnShow")` when the frame already exists.

## 1. Spellbook after reload

Call the same icon painter from:

- PLAYER_ENTERING_WORLD / addon OnEnable after ApplyOverrides
- SPELLS_CHANGED
- SpellBookFrame OnShow and tab change

One FontString per icon. If it already exists, SetText only.

## 2. Toys: one label

Per toy button, one Mason hotkey region. Hide or reuse any previous Mason string. Do not also write the parent. If a `0` is Blizzard’s, hide that one while Mason owns the bind or don’t create a second.

## 3–4. Late frames

Do **not** require the frame to exist at `/mason kb`.

Register:

- `hooksecurefunc` on `ToggleAllBags` / `ToggleBag` / `ToggleBackpack` / combined-bags open (12.x names)
- event `BAG_CONTAINER_UPDATE` + OnShow on `ContainerFrameCombinedBags` when it first appears
- `hooksecurefunc("ShowMacroFrame", …)` or MacroFrame OnShow via event when the frame is created

On those: raise above veil, do not Disable/Hide children, paint hotkeys, enable hover-bind.

If Combined Bags / MacroFrame is still nil at kb enter, store `kbWantsRaise = true` and apply when the frame’s OnShow first fires.

## Done when

1. Bind Polymorph, `/reload`, open book — one `9` on the sheep icon.
2. Toy box — one chord per toy, not two `0`s.
3. Kb on, then `/macro` — `?` grid visible; hover-bind works.
4. Kb on, then open bags — items normal; hover-bind works.
5. Profiles still switch layout.
