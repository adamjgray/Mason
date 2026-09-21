# Mason 9r — PaintSpellbookHotkeys nil `ps`

One-line crash on `/reload`. Do not change bag/toy/macro paint, scale host, flyouts, or profiles.

## End goal

`/reload` has no `PaintSpellbookHotkeys` error. Book paint still runs when the book exists.

## Fix

`BindMode.lua:2970` indexes `ps` while it is nil (PLAYER_LOGIN / addon Enable, book not loaded).

At the top of `PaintSpellbookHotkeys` (and `ScheduleSpellbookHotkeys` if it assumes the same):

```
local ps = PlayerSpellsFrame or self.masonSpellBookFrame or _G.SpellBookFrame
if not ps then return end
```

pcall the rest. Do not create frames. Do not skip later OnShow paint.

## Done when

`/reload` — 0× that error. Opening the book still paints as in 9q.
