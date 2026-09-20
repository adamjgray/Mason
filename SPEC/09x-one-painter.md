# Mason 9x — One overlay painter (or park overlays)

Do **not** edit the working macro hover/bind/scroll path except to **call** its painter.

Do not change scale host, flyouts, or profiles.

## Decision baked in

Keep hover-bind on bags / book / toys. Overlay text (`piece.key` on the Blizzard cell) uses **one** function. Delete or no-op every other bag/book/toy SetText loop.

If you cannot find a single painter the macro path already uses, **stop** and list the function names. Do not write a fourth painter.

## Shared painter

```
function Mason:PaintKbOverlay(button, identityKind, identity)
  -- identityKind = "spell" | "item" | "macro" | "toy"
  -- identity = number or macro name
  local fs = button.masonHotkey
  if not fs then
    fs = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    fs:SetPoint("TOPRIGHT", button.icon or button, "TOPRIGHT", -2, -2)
    button.masonHotkey = fs
  end
  local key = self:KeyForIdentity(identityKind, identity) -- piece.key or ""
  fs:SetText(key)
  if key ~= "" then fs:Show(); fs:SetAlpha(1) else fs:SetText("") end
end
```

`KeyForIdentity` walks the current spec kit only. Match spellID / itemID / toyID / macro name. No page index.

Call it from:

- Macro scroll/tab (existing call site — keep)
- Each visible spell button after book page/show (pass that button’s spellID)
- Each visible toy button after toy page/show (pass toyID)
- Each bag item button after bag Show (pass itemID)

## Bags first-kb attach

`ShowBindVeil` must call `AttachKbBagHover` at the end, **and** Combined Bags / container OnShow must call it while `bindMode`. Same function as the second kb. Item buttons only. One hook flag.

## Book veil

Use the **same raise helper** as MacroFrame on `PlayerSpellsFrame` (and `PlayerSpellsFrame.SpellBookFrame` if that is the child). If macros are bright and the book is not, the book is not going through that helper.

## Forbidden

- `print` from Show
- OnUpdate scans
- Mapping `visible[i]` → `pieces[i]`
- Hardcoded key or spell names

## Done when

1. First kb + bags: hover + bind, no multi-second hitch.
2. Book undimmed; overlay on the button whose spellID matches the piece.
3. Toy overlay on the matching toyID.
4. Macros unchanged.
