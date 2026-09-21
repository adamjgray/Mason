# Mason public API

Architect-owned. Implementers add only what the current phase spec lists.

**Honesty / scope (Track A catch-up):** This file documents the **intentional** external and slash-facing surface through tip `df2d402` (phases 1–9ab). It is **not** a dump of every `function Mason:` in the tree (~hundreds of helpers). Methods used only inside their module, BindMode raise-era tombstones, and one-off UI Ensure* helpers are **internal** unless listed here.

AGENTS rule: public functions **added this phase** must match this file (or be marked internal in the phase SPEC).

---

## Phase 1 — kit / binds / combat queue

```
Mason:QueueIfCombat(fn)
Mason:GetCurrentSpecID()
Mason:GetKit(specID?)
Mason:CreatePiece(fields)
Mason:SetPieceKey(id, key, overwrite?)
Mason:ClearPieceKey(id)
Mason:DeletePiece(id)
Mason:ApplyOverrides()
Mason:Notify(msg)
Mason:AfterBindChange()          -- store hook; triggers source hotkey repaint
Mason:ClearCurrentKit()
Mason:IsDebug()
Mason:DebugPrint(...)
```

Slash: `/mason`, `/mason bind`, `/mason unbind`, `/mason list`, `/mason clear`, `/mason debug`.

---

## Phase 2 / 2b — canvas / edit

```
Mason:PlaceView(id, x, y, snap?)
Mason:ClearView(id, silent?)
Mason:ShowView(id)
Mason:ApplyLayout()
Mason:SetLocked(bool)
Mason:IsLocked()
Mason:ToggleEditMode()
Mason:GetViews()                 -- returns profile.views (09i)
```

Slash: `/mason lock`, `/mason edit` (alias), `/mason hide`, `/mason show`.

**Internal (not public contract):** drop-catcher Ensure*/Sync*, pickup poll helpers, view wire helpers.

---

## Phase 3 / 3c — face / size / pickup crate

```
Mason:EnsureExecutor(piece)
Mason:ConfigureFace(exec, piece)
Mason:UpdateFace(exec, piece)
Mason:GetDefaultSize()
Mason:SetDefaultSize(px)
Mason:SetViewSize(id, px)
Mason:RefreshItemCounts()
Mason:RefreshAssistedHighlights()
```

Slash: `/mason snap`, `/mason size`, `/mason scale` (legacy factor path may remain).

**Note (AGENTS):** no Blizzard action-slot writes **to build the kit**. Locked pickup → default-bar **crate detection** (`03c`) is intentional and allowed.

**Internal:** LAB/Masque getters, FitFace*, assisted overlay Ensure*, slot snapshot pollers.

---

## Phase 4 — visual rules

```
Mason:ListRulePresets()
Mason:SetPieceRule(id, preset)
Mason:SetPieceRuleIds(id, ruleIds)
Mason:ApplyRules()
Mason:PaintRules()
```

Slash: `/mason rule`, `/mason rules`.

`RegisterStateDriver` apply is OOC via `QueueIfCombat` (see `lockdown.md`).

---

## Phase 5 — layout tools

```
Mason:ClearSelection()
Mason:SelectOnly(id)
Mason:ToggleSelect(id)
Mason:NudgeSelection(dx, dy, snap?)
Mason:AlignSelection(mode)
Mason:UndockView(id)
Mason:HandleEscapeKey()
```

Slash: `/mason align`, `/mason undock`, `/mason grid`.

**Internal:** dock hint/match math, scale-host Ensure*, ghost list helpers used by Options.

---

## Phase 6 — flyouts

Public slash-driven course API (see phase 6 SPEC). Prefer slash + Options over ad-hoc external calls.

Slash: `/mason flyout …`, `/mason flyout close`.

**Internal:** secure child ensure/populate helpers.

---

## Phase 7 / 09 — bind mode (intentional)

```
Mason:IsBindMode()
Mason:ToggleBindMode()
Mason:SetBindMode(on)
Mason:ExitBindMode()
Mason:RepaintSourceHotkeys()     -- sole public store painter entry (09ab / 09x)
Mason:KeyForIdentity(kind, id)
Mason:PaintKbOverlay(button, kind, id)   -- cell overlay helper
Mason:AttachKbHover(button, kind, id)    -- cell hover helper
```

Slash: `/mason kb`.

### BindMode — internal / historical names

Treat as **internal** (may be renamed or deleted in Track B). Bodies must not Blizzard-Raise for undim (09ab):

- `RaiseBind*` / `Pass*RaiseAndPaint` / `KbWantsRaise` — paint/hook/schedule or no-op only
- `PaintBagHotkeys` / `PaintMacroHotkeys` / `PaintSpellbookHotkeys` / `PaintToyHotkeys` / `RefreshBlizzardHotkeys` — prefer callers go through `RepaintSourceHotkeys`
- `SoftFillMacroSelector` / `WatchLazyBindFrames` / `WalkBlizzardHotkeys` / `HookBindUndimShow` / `RaiseBindItemButtons` — permanent no-ops or delete candidates
- EnsureBindVeil / Catcher / Panel / EditBar / overwrite dialog — UI internals

---

## Phase 8 — import / export

```
Mason:ExportShare(kind)          -- kit | layout | full
Mason:ImportShare(str)
Mason:BuildExport(kind)
Mason:Migrate(data)
```

Slash: `/mason export`, `/mason import`.

---

## Phase 9 — AceConfig / profiles

Slash: `/mason config`.

Profile switch reloads binds + layout (`OnAceProfileChanged` / `MigrateCharLayoutToProfile` — internal migration helpers).

Layouts live at **`db.profile.views`** (09i). Older SPEC text saying `db.char.views` is historical.

---

## Slash map (tip)

`/mason` · `edit` · `lock` · `hide` · `show` · `grid` · `snap` · `size` · `scale` · `align` · `undock` · `rule` · `rules` · `flyout` · `bind` · `unbind` · `list` · `clear` · `debug` · `kb` · `export` · `import` · `config`
