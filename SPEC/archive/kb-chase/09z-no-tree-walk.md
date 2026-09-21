# Mason 9z — No tree walks; restore overlays

Do **not** recurse `GetChildren` / `GetRegions` on bags, PlayerSpellsFrame, MacroFrame, or CollectionsJournal.

That freeze is a full-frame walk (and likely HookScript on every descendant) when the window opens in kb mode.

Do not change scale host, flyouts, or profiles.

## End goal

Opening bags / book / macros / toys in `/mason kb` feels like opening them outside kb (no multi-second freeze).

Behavior target (same as before adapters froze things):

1. First kb + bags: hover + bind.
2. Book: bind + highlight + `piece.key` on the matching spell cell (not the same slot every page).
3. Toys: bind + highlight + `piece.key` on the matching toy.
4. Macros: same bind/paint as the last good macro pass, **without** the new hitch.

## What to delete

Any `buttons()` that starts at the window and walks children. Replace with **named / indexed cells only**.

Examples (use what exists on 12.x; do not invent a walker):

- Macros: the same button list the last good pass used (`MacroButton1..n` or the scroll frame’s item buttons). Do not start at MacroFrame.
- Bags: `ContainerFrameUtil_EnumerateContainerFrames` / combined bag `Items` / `itemButtonPool` active objects — item buttons only.
- Spellbook: the spellbook **paged button array** or pool (SpellBookItem buttons). If you cannot name it, do not walk PlayerSpellsFrame.
- Toys: ToyBox buttons array / pool. Not CollectionsJournal.

One `masonKbHook` flag. No extra HookScript on chrome.

## Overlays

`PaintKbOverlay` only if `identity(button)` is non-nil. If identity is nil, leave text empty — do not fall back to index.

If book/toy overlays stay blank, identity is nil on those cells. Then add **one** deferred probe (not from Show):

`C_Timer.After(0, function() print("Mason: id", kind, button:GetName(), id) end)`

once per kind per kb session. User pastes that. Do not print from Show.

## Bags first attach

`ShowBindVeil` **and** combined-bags OnShow call `AttachKbHover` on the **item button list above**, while `bindMode`. Not on the bag frame.

## Done when

No freeze. First-kb bags hover-bind. Book/toy keys visible on the matching id. Macros still work and open quickly.
