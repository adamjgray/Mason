# Mason 9o — Restore bags/toys; no nil methods

Do not redesign bind mode. Do not change scale host, flyouts, or profiles.

## End goal

Bags and toys work again as they did before 9n (hotkeys + first/second kb open without Lua errors). Spellbook/macros must not crash `/mason kb`. Spellbook chords can stay missing this pass if needed — **no crash is the bar**.

## Why this failed

`PassBagsRaiseAndPaint` / `PassMacroRaiseAndPaint` / the Collections OnShow helper are called as methods and are **nil**. Opening bags, `/macro`, or the toy box while kb is on throws and aborts the old working raise.

9n also rewired bag/toy paint. That is why “do not touch bags/toys” broke.

## 1. No nil calls

Every `self:Foo()` in BindMode OnShow / Pass* / Raise* must exist on Mason.

If a helper is missing: define it as a thin wrapper around the **pre-9n** function that already worked (`RaiseBindUndimFrame`, bag paint, toy paint), or delete the call.

pcall the raise so one bad frame cannot 79× error.

## 2. Restore bags and toys

Revert bag and toy **paint + hover-bind** to the last working version (post-9l / pre-9n). That includes Combined Bags first-open retry if it worked on second open before 9n.

Do not walk bags through the new ScrollBox spellbook path.

## 3. Macros / Collections OnShow

OnMacroOpened / CollectionsJournal hook must not call nil. If hover-bind for macros is not ready, Show the panel and return — no error. Same for ToysTab.

## 4. Spellbook

Do not block this pass on Polymorph `9`. If the painter is unsafe, skip it rather than crash. A follow-up can paint the book after bags/toys are green again.

## Done when

1. `/mason kb` then bags — no Lua error; items hover-bind; hotkeys look like pre-9n.
2. `/mason kb` then toy box — no Lua error; toys hover-bind.
3. `/mason kb` then `/macro` — no Lua error (grid/bind can still be wrong).
4. Texture undim guard still in place.
