# Mason 9n — Spellbook/macro chords; first kb + bags/macros

Do not change bag-item or toy-box hotkey paint. Those work. Do not change scale host, flyouts, profile layout, or the Texture undim guard.

## End goal

Spellbook and macro **icons** always show the same Mason chord as the piece (kb on or off). `/mason kb` then the first bag open is full bind mode. `/mason kb` then the first `/macro` shows the `?` grid **and** hover-bind.

## Why this failed

Spellbook/macro FontStrings never appear — painter is not finding 12.x PlayerSpells / MacroSelector icon frames, or it parents to a region that is hidden. Bags/toys work because those buttons are a known walk.

First kb + bags: veil is up before Combined Bags exists. First open raises an empty tree; bind catcher never re-attaches to the 140 buttons. Second kb session works because bags already exist when ShowBindVeil runs.

First kb + macros: same empty first Show (no selector). Second session draws the grid but hover-bind was only registered at kb enter, so the new buttons have no bind target.

## 1. Spellbook paint (kb off)

Copy the **toy/bag** pattern: walk the visible spell buttons, parent one FontString to the **button**, `SetPoint("TOPRIGHT", icon, "TOPRIGHT", -2, -2)`.

Hook PlayerSpellsFrame / SpellBookFrame OnShow, tab change, SPELLS_CHANGED, login after ApplyOverrides. If the Midnight frame name is not SpellBookFrame, find it from `PlayerSpellsFrame` / `TogglePlayerSpells` and store it.

Never require kb mode.

## 2. Macro paint (kb off)

Same as bags: after the selector has buttons, one FontString per **macro button**, TOPRIGHT of that button’s icon. Not the tall cell.

Paint on Show, tab switch, and when button count becomes > 0.

## 3. First kb + bags

When Combined Bags first reports buttons>0 **while kb is on**, run the **full** bind-mode raise used on the second open: undim bags, attach hover-bind to item buttons, catcher mouse. Do not only paint hotkeys.

Do not change how bag hotkeys look.

## 4. First kb + macros

When selector button count becomes > 0 while kb is on:

- raise selector + buttons (Frames only)
- force stock update if the body is still empty
- attach hover-bind to those buttons (same walk as second session)

Empty body (name + edit box, no `?` grid) is not done. Keep retrying this open until buttons>0 or 2s.

## Done when

1. `/reload`, book, kb off — Polymorph `9` on the icon.
2. Placed macro — `9` on that cell’s icon in `/macro` (kb off).
3. `/reload` → kb → first bags — bind-mode gold + hover-bind (same as today’s second open).
4. `/reload` → kb → first `/macro` — filled grid + hover highlight + key capture.
5. Bag/toy hotkey look unchanged. `/mason kb` no Texture error.
