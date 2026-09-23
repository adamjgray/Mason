-- C-07: edit bar, view snapshot, and bind-overwrite dialog live here (not BindMode).
-- BindMode remains kb catcher / veil / source-panel paint only.
local Mason = LibStub("AceAddon-3.0"):GetAddon("Mason")

local PANEL_BACKDROP = {
  bgFile = "Interface\\Buttons\\WHITE8X8",
  edgeFile = "Interface\\Buttons\\WHITE8X8",
  edgeSize = 1,
  insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

local PANEL_STRATA = "FULLSCREEN_DIALOG"
local CATCHER_LEVEL = 50
local PANEL_LEVEL = 200

local function SkinMasonPanel(frame)
  if not frame or not frame.SetBackdrop then
    return
  end
  frame:SetBackdrop(PANEL_BACKDROP)
  frame:SetBackdropColor(0.07, 0.07, 0.07, 0.94)
  frame:SetBackdropBorderColor(0.75, 0.62, 0.18, 1)
end

local function EditBarButtons(bar)
  return { bar.lockBtn, bar.cancelBtn, bar.kbBtn, bar.configBtn }
end

local function CatcherFrameLevel()
  local catcher = Mason.bindCatcher
  if catcher then
    return catcher:GetFrameLevel() or 0
  end
  return 0
end

-- Lift Mason-owned chrome above edit veil / optional kb catcher (09ab: Raise Mason frames only).
local function PrepareEditChromeShow(panel, buttons)
  if not panel then
    return
  end
  local catcher = Mason.bindCatcher
  if catcher then
    catcher:EnableMouse(false)
    catcher:SetFrameStrata(PANEL_STRATA)
    catcher:SetFrameLevel(CATCHER_LEVEL)
  end
  local veil = Mason.editVeil
  local veilLevel = 0
  if veil then
    veilLevel = veil:GetFrameLevel() or 0
  end
  local level = math.max(PANEL_LEVEL, CatcherFrameLevel() + 10, veilLevel + 10)
  panel:SetFrameStrata(PANEL_STRATA)
  panel:SetFrameLevel(level)
  panel:EnableMouse(true)
  buttons = buttons or {}
  for i = 1, #buttons do
    local btn = buttons[i]
    if btn then
      btn:EnableMouse(true)
      btn:SetFrameLevel(level + 10)
    end
  end
  panel:Show()
  panel:Raise()
end

local function CopyValue(v)
  if type(v) ~= "table" then
    return v
  end
  if CopyTable then
    return CopyTable(v)
  end
  local out = {}
  for k, val in pairs(v) do
    out[k] = CopyValue(val)
  end
  return out
end

function Mason:TakeEditViewsSnapshot()
  self.editViewsSnapshot = CopyValue(self:GetViews())
end

function Mason:RestoreEditViewsSnapshot()
  if not self.editViewsSnapshot then
    return false
  end
  self.db.profile.views = CopyValue(self.editViewsSnapshot)
  return true
end

function Mason:SyncEditBarBindButton()
  local bar = self.editBar
  if bar and bar.kbBtn then
    bar.kbBtn:SetText(self.bindMode and "Binding…" or "Keybind")
  end
end

-- Done: keep live layout writes, lock edit.
function Mason:ConfirmEditMode()
  if InCombatLockdown() then
    print("Mason: cannot edit in combat")
    return false
  end
  if not self:InEditMode() then
    return false
  end
  self:SetLocked(true)
  self:DebugPrint("Mason: edit off")
  return true
end

-- Cancel: restore unlock-time views snapshot, then lock.
function Mason:CancelEditMode()
  if InCombatLockdown() then
    print("Mason: cannot cancel edit in combat")
    return false
  end
  if not self:InEditMode() then
    return false
  end
  self:RestoreEditViewsSnapshot()
  self:SetLocked(true)
  self:DebugPrint("Mason: edit off")
  return true
end

-- Edit chrome keys: ESC = Cancel (or clear selection first); Enter = Done.
-- Kb mode leaves ESC to BindMode (unbind / exit kb).
function Mason:HandleEditChromeKey(key)
  if self.bindMode then
    return false
  end
  if key == "ESCAPE" then
    if self.optionsPanel and self.optionsPanel.IsShown and self.optionsPanel:IsShown() then
      self.optionsPanel:Hide()
      return true
    end
  end
  if not self:InEditMode() then
    return false
  end
  if key == "ESCAPE" then
    local had = false
    for _ in pairs(self.selectedIds or {}) do
      had = true
      break
    end
    if had then
      if self.ClearSelection then
        self:ClearSelection()
      end
      return true
    end
    return self:CancelEditMode()
  end
  if key == "ENTER" then
    return self:ConfirmEditMode()
  end
  return false
end

function Mason:EnsureEditBar()
  if self.editBar then
    return self.editBar
  end
  if InCombatLockdown() then
    return nil
  end
  local bar = CreateFrame("Frame", "MasonEditBar", UIParent, "BackdropTemplate")
  bar:SetSize(460, 118)
  bar:SetPoint("TOP", UIParent, "TOP", 0, -80)
  bar:SetFrameStrata(PANEL_STRATA)
  bar:SetFrameLevel(PANEL_LEVEL)
  bar:EnableMouse(true)
  bar:Hide()
  SkinMasonPanel(bar)
  local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", bar, "TOP", 0, -10)
  title:SetText("Mason edit")
  bar.title = title
  local body = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  body:SetPoint("TOPLEFT", bar, "TOPLEFT", 16, -34)
  body:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -16, -34)
  body:SetJustifyH("LEFT")
  body:SetJustifyV("TOP")
  body:SetWordWrap(true)
  body:SetText("Drag to move. Shift-click select. Wheel scale.")
  local function MakeBtn(text, x, onclick)
    local btn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    btn:SetSize(80, 22)
    btn:SetPoint("BOTTOM", bar, "BOTTOM", x, 10)
    btn:SetText(text)
    btn:EnableMouse(true)
    btn:SetScript("OnClick", onclick)
    return btn
  end
  bar.lockBtn = MakeBtn("Done", -138, function()
    Mason:ConfirmEditMode()
  end)
  bar.cancelBtn = MakeBtn("Cancel", -46, function()
    Mason:CancelEditMode()
  end)
  bar.kbBtn = MakeBtn("Keybind", 46, function()
    if Mason.ToggleBindMode then
      Mason:ToggleBindMode()
    end
  end)
  bar.configBtn = MakeBtn("Config", 138, function()
    if Mason.OpenOptions then
      Mason:OpenOptions()
    end
  end)
  self.editBar = bar
  self:SyncEditBarBindButton()
  return bar
end

function Mason:ShowEditBar()
  local bar = self:EnsureEditBar()
  if bar and self:InEditMode() then
    PrepareEditChromeShow(bar, EditBarButtons(bar))
    self:SyncEditBarBindButton()
  end
end

function Mason:HideEditBar()
  if self.editBar then
    self.editBar:Hide()
    self.editBar:EnableMouse(false)
  end
end

function Mason:EnsureBindOverwriteDialog()
  if self.bindOverwrite then
    return self.bindOverwrite
  end
  if InCombatLockdown() then
    return nil
  end
  local panel = CreateFrame("Frame", "MasonBindOverwrite", UIParent, "BackdropTemplate")
  panel:SetSize(420, 140)
  panel:SetPoint("CENTER")
  panel:SetFrameStrata("TOOLTIP")
  panel:SetFrameLevel(1)
  panel:EnableMouse(false)
  panel:Hide()
  SkinMasonPanel(panel)
  local body = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  body:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -20)
  body:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -20)
  body:SetJustifyH("LEFT")
  body:SetJustifyV("TOP")
  body:SetWordWrap(true)
  body:SetDrawLayer("OVERLAY", 2)
  panel.body = body
  local overwrite = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  overwrite:SetSize(100, 22)
  overwrite:SetFrameLevel(12)
  overwrite:EnableMouse(true)
  overwrite:SetPoint("BOTTOMLEFT", panel, "BOTTOM", -110, 16)
  overwrite:SetText("Overwrite")
  overwrite:SetScript("OnClick", function()
    local pending = Mason.bindOverwritePending
    panel:Hide()
    Mason.bindOverwritePending = nil
    if pending then
      Mason:SetPieceKey(pending.id, pending.key, true)
    end
  end)
  local cancel = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  cancel:SetSize(100, 22)
  cancel:SetFrameLevel(12)
  cancel:EnableMouse(true)
  cancel:SetPoint("BOTTOMRIGHT", panel, "BOTTOM", 110, 16)
  cancel:SetText("Cancel")
  cancel:SetScript("OnClick", function()
    Mason.bindOverwritePending = nil
    panel:Hide()
  end)
  panel.overwriteBtn = overwrite
  panel.cancelBtn = cancel
  self.bindOverwrite = panel
  return panel
end

function Mason:ShowBindOverwriteDialog(id, key, other)
  local piece = self:FindPiece(id)
  if not piece or not other or not key then
    return
  end
  local panel = self:EnsureBindOverwriteDialog()
  if not panel then
    return
  end
  self.bindOverwritePending = { id = id, key = key }
  panel.body:SetText(string.format(
    "%s is bound to %s. Bind it to %s instead?",
    key,
    self:PieceLabel(other),
    self:PieceLabel(piece)
  ))
  panel:SetFrameStrata("TOOLTIP")
  panel:SetFrameLevel(1)
  panel:EnableMouse(false)
  panel:Show()
  panel:Raise()
  if panel.overwriteBtn then
    panel.overwriteBtn:SetFrameLevel(12)
    panel.overwriteBtn:EnableMouse(true)
  end
  if panel.cancelBtn then
    panel.cancelBtn:SetFrameLevel(12)
    panel.cancelBtn:EnableMouse(true)
  end
end
