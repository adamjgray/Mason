# Mason 9v — Find the live painters (no new system)

Do **not** edit macro functions. Macros work.

Do not add a second bag attach, a second spellbook paint, or a second toy paint. Behavior did not change because the functions that run in-game were not the ones edited.

Do not change scale host, flyouts, or profiles.

## End goal

Know which functions run on first `/mason kb`. Then fix **those** three call sites only:

1. Bags: first Show must call the same hover/bind attach as the second kb (the one that already works).
2. Book: the paint that actually SetTexts must use button spellID == piece.spellID; PlayerSpellsFrame must raise above the veil.
3. Toys: the paint that actually runs must SetText(piece.key) on the visible toy button.

## Required first step (in code, not a comment)

Add **one** `print` at the start of every candidate:

- bag Show / AttachKbBagHover / RefreshBlizzardHotkeys bag branch
- PaintSpellbookHotkeys / ScheduleSpellbookHotkeys
- toy hotkey paint / RefreshBlizzardHotkeys toy branch

Text: `Mason: live <functionName>`.

After `/mason kb` the user will paste which names printed. **Only those functions may change.**

If two book paints print, delete or no-op the one that maps by index. Keep the ID match.

## Bags attach (only if AttachKbBagHover printed on first open and hover still fails)

The second kb already works. First bag Show must call **that exact function**, after items exist (`buttons>0`). Do not walk non-item frames. Do not add OnUpdate.

If AttachKbBagHover does **not** print on first bag open, wire bag OnShow to it. That is the whole bag bug.

## Book (only the function that printed)

If keys sit on the wrong icons, that function still uses `i`. Replace the loop body with: read this button’s spellID; SetText(piece.key) when it equals piece.spellID; else "".

Raise: same helper MacroFrame uses, on the frame that printed.

## Toys (only the function that printed)

SetText(piece.key or "") on `button.masonHotkey` for the button whose toyID matches. If that print never fires when the toy box is open, hook the Show that **does** fire (Collections / ToyBox) to that function.

## Done when

User paste shows `Mason: live …` for the paths that ran.

Then:

1. First kb bags — hover + bind.
2. Book undimmed; key on matching spellID.
3. Toy shows piece.key.
4. Macros unchanged.

If after wiring the printed functions nothing changes, stop and paste the print lines + function names. Do not write another painter.
