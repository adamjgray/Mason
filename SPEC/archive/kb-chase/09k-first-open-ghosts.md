# Mason 9k — First-open bags/macros, Ghosts rows

Do not change scale host, flyout populate, or profile-owns-layout.

## End goal

`/mason kb` then the **first** bag open and the **first** `/macro` work. A bound macro’s `9` sits on that grid icon. Clear all Ghosts empties the pane in the same click.

## Why the last pass failed

Bags “work the second time” means the first OnShow ran before item buttons existed, Mason raised an empty frame, and never painted/raised again. Second Toggle rebuilds buttons and the existing OnShow hook finally sees them.

Macros: same lazy create. The `?` grid is `MacroFrame.MacroSelector` (or a scroll child) populated **after** Show. Raising MacroFrame on Show without a deferred refresh leaves a blank body. Hotkey is parented to the selector row / scroll child (tall cell) so `9` floats above the icon.

Ghosts: SavedVariables cleared, AceConfig `args` still hold the old `toggle`/`execute` rows until a full `NotifyChange` **after** the click.

## 1. Bags first open

On every Combined Bags / container Show **and** 0.05–0.15s later:

- raise frame + item buttons above veil
- paint hotkeys
- do not Disable slots

Also run that pass on `BAG_CONTAINER_UPDATE` while kb is on.

If debug: `Mason: bags raise <frameName> buttons=<n>` so `buttons=0` on first open is visible.

## 2. Macros first open + hotkey

On `ShowMacroFrame` / MacroFrame OnShow:

- raise MacroFrame + MacroSelector
- do not Hide children
- `C_Timer.After(0, …)` then `After(0.1, …)`: stock update (`MacroFrame_Update` or selector Refresh) + raise again + paint

Hotkey: walk to the **icon Texture or CheckButton** on that cell (usually `Name` + icon child). `SetPoint("TOPRIGHT", icon, "TOPRIGHT", …)`. Never parent to the selector button if that button is taller than the icon.

Debug: `Mason: macro raise shown=<bool> buttons=<n>`.

Hover-bind must resolve that same icon/button on first open.

## 3. Ghosts Clear all

After deleting leftover views:

```
C_Timer.After(0, function()
  -- rebuild ghosts args to empty placeholder only
  LibStub("AceConfigRegistry-3.0"):NotifyChange("Mason")
end)
```

Do not rebuild inside the button handler. Empty pane: one disabled `No leftover views.`

## Done when

1. Kb on, first `/macro` — `?` grid visible; hover-bind works; bound key on the icon, not above the cell.
2. Kb on, first bag open — hover-bind works (not only the second open).
3. Clear all Ghosts — rows gone immediately; no Lua error.
