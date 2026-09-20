# Mason 9l — Undim only Frames; bags 0→N; macro icon; quiet debug

Do not change scale host, flyouts, or profile layout.

## End goal

`/mason kb` does not error. First bag open binds. First `/macro` shows the grid and binds. Macro `9` sits on the icon. Raise/button-count lines only print when Debug is on.

## Why this failed

`RaiseBindUndimFrame` walks children and calls `SetFrameStrata` / `SetFrameLevel` / `EnableMouse` on whatever it gets. Macro selector children include **Texture** regions (`Blizzard_SelectorUI.xml:22`). Textures are not frames → `attempt to call a nil value` at BindMode.lua:611. That abort also stops the rest of the macro raise, so the grid never undims and hover-bind never attaches.

Bags: first Show reports `buttons=0`, later `buttons=140`. Raise ran on the empty tree and did not run again when buttons appeared (or the second pass still dies on a Texture).

Macro hotkey still parented to the tall selector cell / a texture offset, so `9` floats midair.

Debug `Mason: bags raise` / `macro raise` print even when Debug is off.

## 1. RaiseBindUndimFrame

At the top:

```
if not frame or type(frame) ~= "table" or not frame.GetObjectType then return end
local ot = frame:GetObjectType()
if ot == "Texture" or ot == "FontString" or ot == "AnimationGroup" or ot == "Animation" then
  return
end
if not frame.SetFrameLevel then return end
```

pcall every SetFrameStrata / SetFrameLevel / EnableMouse / Raise.

Never treat a Texture as an undim target. Walk `GetChildren()` (frames) only — not `GetRegions()`.

## 2. Bags 0 → 140

If a raise pass sees `buttons==0` while kb is on, schedule another pass at 0.1s and 0.3s, and on the next `BAG_CONTAINER_UPDATE`. When `buttons` becomes > 0, raise **those buttons** (Frames/Buttons only).

Hover-bind walks item buttons, not the Combined Bags backdrop.

## 3. Macros

Same undim guard. After selector refresh, undim `MacroButton*` / scroll-box **buttons**, not their textures.

Hotkey: find the icon on that button (`button.Icon` or first Texture named Icon). `SetParent(button)` + `SetPoint("TOPRIGHT", icon, "TOPRIGHT", -2, -2)`. If no icon, TOPRIGHT of the **button** (the 36–45px cell), never the selector row.

## 4. Debug

`Mason: bags raise` and `Mason: macro raise` only if `db.profile.debug`. The Lua error must not return; do not keep those prints as a substitute for the guard.

## Done when

1. `/mason kb` — no Lua error.
2. Reload → kb → first bags — hover-bind (after buttons=140).
3. Reload → kb → first `/macro` — grid visible, hover-bind, `9` on the icon.
4. Debug off — no raise lines in chat.
