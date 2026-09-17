local Mason = LibStub("AceAddon-3.0"):GetAddon("Mason")

local MODIFIER_KEYS = {
  LSHIFT = true,
  RSHIFT = true,
  LCTRL = true,
  RCTRL = true,
  LALT = true,
  RALT = true,
  LMETA = true,
  RMETA = true,
}

local PANEL_BACKDROP = {
  bgFile = "Interface\\Buttons\\WHITE8X8",
  edgeFile = "Interface\\Buttons\\WHITE8X8",
  edgeSize = 1,
  insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

local PANEL_STRATA = "DIALOG"
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

local function PanelButtons(panel)
  return { panel.doneBtn, panel.lockBtn, panel.cancelBtn, panel.kbBtn }
end

local function CatcherFrameLevel()
  local catcher = Mason.bindCatcher
  if catcher then
    return catcher:GetFrameLevel() or 0
  end
  return 0
end

local function PrepareMasonPanelShow(panel)
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
  local buttons = PanelButtons(panel)
  for i = 1, #buttons do
    local btn = buttons[i]
    if btn then
      btn:EnableMouse(true)
    end
  end
  panel:Show()
  panel:Raise()
  if not panel.masonPrintedShowLevel then
    panel.masonPrintedShowLevel = true
    print(string.format(
      "Mason: panel %s level=%d catcherLevel=%d",
      panel:GetName() or "?",
      panel:GetFrameLevel() or 0,
      CatcherFrameLevel()
    ))
  end
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
  self.db.char.views = CopyValue(self.editViewsSnapshot)
  return true
end

function Mason:IsBindMode()
  return not not self.bindMode
end

local function FrameName(f)
  return f and f.GetName and f:GetName() or nil
end

local function PieceIdFromExecName(name)
  if not name then
    return nil
  end
  local id = string.match(name, "^MasonExec_(.+)$")
  if id then
    return id
  end
  return string.match(name, "^MasonEdit_(.+)$")
end

function Mason:GetMouseFocusList()
  local list = {}
  if GetMouseFoci then
    local foci = GetMouseFoci()
    if type(foci) == "table" then
      for i = 1, #foci do
        list[#list + 1] = foci[i]
      end
    end
  end
  if #list == 0 and GetMouseFocus then
    local f = GetMouseFocus()
    if f then
      list[1] = f
    end
  end
  return list
end

local function SpellIdFromFrame(f)
  if not f then
    return nil
  end
  local id = tonumber(f.spellID or f.spellId)
  if id and id > 0 then
    return id
  end
  if f.GetSpellID then
    local ok, v = pcall(f.GetSpellID, f)
    if ok then
      id = tonumber(v)
      if id and id > 0 then
        return id
      end
    end
  end
  if f.GetSpellId then
    local ok, v = pcall(f.GetSpellId, f)
    if ok then
      id = tonumber(v)
      if id and id > 0 then
        return id
      end
    end
  end
  if f.GetSpellBookItemInfo then
    local ok, info = pcall(f.GetSpellBookItemInfo, f)
    if ok and type(info) == "table" then
      id = tonumber(info.spellID or info.spellId)
      if id and id > 0 then
        return id
      end
    elseif ok then
      id = tonumber(info)
      if id and id > 0 then
        return id
      end
    end
  end
  local slot = tonumber(f.slotIndex or f.spellBookItemIndex or f.itemIndex)
  if not slot and f.GetID then
    slot = tonumber(f:GetID())
  end
  local bank = f.spellBank
  if bank == nil and Enum and Enum.SpellBookSpellBank then
    bank = Enum.SpellBookSpellBank.Player
  end
  if slot and C_SpellBook then
    if C_SpellBook.GetSpellBookItemInfo then
      local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, slot, bank)
      if ok and type(info) == "table" then
        id = tonumber(info.spellID or info.spellId)
        if id and id > 0 then
          return id
        end
      end
    end
    if C_SpellBook.GetSpellBookItemType then
      local ok, typeOrId, extra = pcall(C_SpellBook.GetSpellBookItemType, slot, bank)
      if ok then
        id = tonumber(extra) or tonumber(typeOrId)
        if id and id > 0 then
          return id
        end
      end
    end
  end
  return nil
end

local function MacroNameFromFrame(f)
  if not f then
    return nil
  end
  if type(f.macroName) == "string" and f.macroName ~= "" then
    return f.macroName
  end
  local index = tonumber(f.macroID or f.macroIndex or f.macroSlot)
  if not index and f.GetID then
    local name = FrameName(f)
    if name and string.find(string.lower(name), "macro", 1, true) then
      index = tonumber(f:GetID())
    end
  end
  if index and GetMacroInfo then
    local name = GetMacroInfo(index)
    if name and name ~= "" then
      return name
    end
  end
  return nil
end

local function ItemIdFromFrame(f)
  if not f then
    return nil
  end
  local id = tonumber(f.itemID or f.itemId)
  if id and id > 0 then
    return id
  end
  if f.GetItemID then
    local ok, v = pcall(f.GetItemID, f)
    if ok then
      id = tonumber(v)
      if id and id > 0 then
        return id
      end
    end
  end
  local bag, slot
  if f.GetBagID then
    local ok, v = pcall(f.GetBagID, f)
    if ok then
      bag = v
    end
  end
  bag = bag or f.bagID or f.BagID
  if f.GetSlot then
    local ok, v = pcall(f.GetSlot, f)
    if ok then
      slot = v
    end
  end
  if slot == nil and f.GetID then
    slot = f:GetID()
  end
  slot = slot or f.slot
  if bag ~= nil and slot ~= nil and C_Container and C_Container.GetContainerItemID then
    local ok, v = pcall(C_Container.GetContainerItemID, bag, slot)
    if ok then
      id = tonumber(v)
      if id and id > 0 then
        return id
      end
    end
  end
  return nil
end

local function IsSkipFrame(f)
  if not f or f == UIParent or f == WorldFrame then
    return true
  end
  local name = FrameName(f)
  if name == "MasonBindCatcher" or name == "MasonBindPanel" or name == "MasonBindHoverGlow" or name == "MasonEditBar" then
    return true
  end
  return false
end

function Mason:ResolveBindTargetFromFrame(f)
  while f and not IsSkipFrame(f) do
    if f.masonPieceId and self:FindPiece(f.masonPieceId) then
      return { kind = "piece", pieceId = f.masonPieceId }
    end
    if f.pieceId and self:FindPiece(f.pieceId) then
      return { kind = "piece", pieceId = f.pieceId }
    end
    local name = FrameName(f)
    local pid = PieceIdFromExecName(name)
    if pid and self:FindPiece(pid) then
      return { kind = "piece", pieceId = pid }
    end
    local spellID = SpellIdFromFrame(f)
    if spellID then
      return { kind = "spell", spellID = spellID }
    end
    local macroName = MacroNameFromFrame(f)
    if macroName then
      return { kind = "macro", macroName = macroName }
    end
    local itemID = ItemIdFromFrame(f)
    if itemID then
      return { kind = "item", itemID = itemID }
    end
    f = f.GetParent and f:GetParent()
  end
  return nil
end

function Mason:GetBindHoverTarget()
  local foci = self:GetMouseFocusList()
  for i = 1, #foci do
    local hit = self:ResolveBindTargetFromFrame(foci[i])
    if hit then
      return hit
    end
  end
  return nil
end

function Mason:BindChordFromKey(key)
  if not key or MODIFIER_KEYS[key] then
    return nil
  end
  if key == "LeftButton" then
    key = "BUTTON1"
  elseif key == "RightButton" then
    key = "BUTTON2"
  elseif key == "MiddleButton" then
    key = "BUTTON3"
  elseif GetBindingFromClick and (string.find(key, "BUTTON", 1, true) or string.find(key, "MOUSEWHEEL", 1, true)) then
    local ok, fromClick = pcall(GetBindingFromClick, key)
    if ok and type(fromClick) == "string" and fromClick ~= "" then
      key = fromClick
    end
  end
  key = tostring(key)
  if CreateKeyChordStringUsingMetaKeyState then
    local ok, chord = pcall(CreateKeyChordStringUsingMetaKeyState, key)
    if ok and type(chord) == "string" and chord ~= "" then
      return chord
    end
  end
  local parts = {}
  if IsControlKeyDown and IsControlKeyDown() then
    parts[#parts + 1] = "CTRL"
  end
  if IsShiftKeyDown and IsShiftKeyDown() then
    parts[#parts + 1] = "SHIFT"
  end
  if IsAltKeyDown and IsAltKeyDown() then
    parts[#parts + 1] = "ALT"
  end
  parts[#parts + 1] = string.upper(key)
  return table.concat(parts, "-")
end

function Mason:ApplyHoverBind(target, chord)
  if not target or not chord then
    return false
  end
  local piece
  if target.kind == "piece" then
    piece = self:FindPiece(target.pieceId)
  elseif target.kind == "spell" then
    piece = self:FindPieceByAction("spell", { spellID = target.spellID })
    if not piece then
      local name
      if C_Spell and C_Spell.GetSpellName then
        name = C_Spell.GetSpellName(target.spellID)
      end
      piece = self:CreatePiece({
        type = "spell",
        spellID = target.spellID,
        spellName = name,
      })
    end
  elseif target.kind == "macro" then
    piece = self:FindPieceByAction("macro", { macroName = target.macroName })
    if not piece then
      piece = self:CreatePiece({
        type = "macro",
        macroName = target.macroName,
      })
    end
  elseif target.kind == "item" then
    piece = self:FindPieceByAction("item", { itemID = target.itemID })
      or self:FindPieceByAction("toy", { itemID = target.itemID })
    if not piece then
      local name
      if C_Item and C_Item.GetItemNameByID then
        name = C_Item.GetItemNameByID(target.itemID)
      end
      piece = self:CreatePiece({
        type = "item",
        itemID = target.itemID,
        spellName = name,
      })
    end
  end
  if not piece then
    return false
  end
  self:SetPieceKey(piece.id, chord)
  return true
end

function Mason:ClearHoverBind(target)
  if not target then
    return false
  end
  local piece
  if target.kind == "piece" then
    piece = self:FindPiece(target.pieceId)
  elseif target.kind == "spell" then
    piece = self:FindPieceByAction("spell", { spellID = target.spellID })
  elseif target.kind == "macro" then
    piece = self:FindPieceByAction("macro", { macroName = target.macroName })
  elseif target.kind == "item" then
    piece = self:FindPieceByAction("item", { itemID = target.itemID })
      or self:FindPieceByAction("toy", { itemID = target.itemID })
  end
  if piece and piece.key and piece.key ~= "" then
    self:ClearPieceKey(piece.id)
    return true
  end
  return false
end

function Mason:EnsureBindCatcher()
  if self.bindCatcher then
    return self.bindCatcher
  end
  if InCombatLockdown() then
    return nil
  end
  local catcher = CreateFrame("Frame", "MasonBindCatcher", UIParent)
  catcher:Hide()
  catcher:SetAllPoints(UIParent)
  catcher:SetFrameStrata(PANEL_STRATA)
  catcher:SetFrameLevel(CATCHER_LEVEL)
  catcher:EnableMouse(false)
  catcher:EnableMouseWheel(true)
  catcher:EnableKeyboard(true)
  catcher:SetPropagateKeyboardInput(true)
  catcher:SetScript("OnKeyDown", function(self, key)
    Mason:OnBindCatcherKey(self, key)
  end)
  catcher:SetScript("OnMouseWheel", function(self, delta)
    local wheel = (delta or 0) > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"
    Mason:OnBindCatcherKey(self, wheel)
  end)
  catcher:SetScript("OnUpdate", function()
    if Mason.bindMode then
      Mason:UpdateBindHoverHighlight()
    end
  end)
  self.bindCatcher = catcher
  return catcher
end

function Mason:HideBindCatcher()
  local catcher = self.bindCatcher
  if not catcher then
    return
  end
  catcher:EnableKeyboard(false)
  catcher:Hide()
end

function Mason:OnBindCatcherKey(catcher, key)
  if not self.bindMode then
    if catcher.SetPropagateKeyboardInput then
      catcher:SetPropagateKeyboardInput(true)
    end
    return
  end
  if key == "ESCAPE" then
    if catcher.SetPropagateKeyboardInput then
      catcher:SetPropagateKeyboardInput(false)
    end
    local target = self:GetBindHoverTarget()
    if target then
      self:ClearHoverBind(target)
    else
      self:SetBindMode(false)
    end
    return
  end
  if MODIFIER_KEYS[key] then
    if catcher.SetPropagateKeyboardInput then
      catcher:SetPropagateKeyboardInput(true)
    end
    return
  end
  local target = self:GetBindHoverTarget()
  if not target then
    if catcher.SetPropagateKeyboardInput then
      catcher:SetPropagateKeyboardInput(true)
    end
    return
  end
  local chord = self:BindChordFromKey(key)
  if not chord then
    if catcher.SetPropagateKeyboardInput then
      catcher:SetPropagateKeyboardInput(true)
    end
    return
  end
  if catcher.SetPropagateKeyboardInput then
    catcher:SetPropagateKeyboardInput(false)
  end
  self:ApplyHoverBind(target, chord)
end

function Mason:SetBindMode(on)
  on = not not on
  if on and InCombatLockdown() then
    print("Mason: cannot bind in combat")
    return false
  end
  if on == self.bindMode then
    return true
  end
  self.bindMode = on
  if on then
    local catcher = self:EnsureBindCatcher()
    if catcher then
      catcher:EnableMouse(false)
      catcher:SetFrameStrata(PANEL_STRATA)
      catcher:SetFrameLevel(CATCHER_LEVEL)
      catcher:Show()
      catcher:EnableKeyboard(true)
      if catcher.SetPropagateKeyboardInput then
        catcher:SetPropagateKeyboardInput(true)
      end
    end
    self:ShowBindPanel()
    self:Notify("keybind on")
  else
    self:HideBindCatcher()
    self:HideBindPanel()
    self:HideBindHoverHighlight()
    self:Notify("keybind off")
  end
  self:SyncEditBarBindButton()
  return true
end

function Mason:ToggleBindMode()
  if InCombatLockdown() and not self.bindMode then
    print("Mason: cannot bind in combat")
    return false
  end
  return self:SetBindMode(not self.bindMode)
end

function Mason:ExitBindMode()
  if self.bindMode then
    self.bindMode = false
    self:HideBindCatcher()
    self:HideBindPanel()
    self:HideBindHoverHighlight()
    self:Notify("keybind off")
    self:SyncEditBarBindButton()
  end
end

function Mason:EnsureBindPanel()
  if self.bindPanel then
    return self.bindPanel
  end
  if InCombatLockdown() then
    return nil
  end
  local panel = CreateFrame("Frame", "MasonBindPanel", UIParent, "BackdropTemplate")
  panel:SetSize(360, 118)
  panel:SetPoint("TOP", UIParent, "TOP", 0, -210)
  panel:SetFrameStrata(PANEL_STRATA)
  panel:SetFrameLevel(PANEL_LEVEL)
  panel:EnableMouse(true)
  panel:Hide()
  SkinMasonPanel(panel)
  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", panel, "TOP", 0, -10)
  title:SetText("Mason keybind")
  local body = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  body:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -34)
  body:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -34)
  body:SetJustifyH("LEFT")
  body:SetJustifyV("TOP")
  body:SetWordWrap(true)
  body:SetText("Hover a piece, spell, macro, or item and press a key. Escape on it clears. Escape on empty or Done exits.")
  local done = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  done:SetSize(80, 22)
  done:SetPoint("BOTTOM", panel, "BOTTOM", 0, 10)
  done:SetText("Done")
  done:EnableMouse(true)
  done:SetScript("OnClick", function()
    Mason:SetBindMode(false)
  end)
  panel.doneBtn = done
  self.bindPanel = panel
  return panel
end

function Mason:ShowBindPanel()
  local panel = self:EnsureBindPanel()
  if panel then
    PrepareMasonPanelShow(panel)
  end
end

function Mason:HideBindPanel()
  if self.bindPanel then
    self.bindPanel:Hide()
    self.bindPanel:EnableMouse(false)
  end
end

function Mason:EnsureBindHoverHighlight()
  if self.bindHoverGlow then
    return self.bindHoverGlow
  end
  if InCombatLockdown() then
    return nil
  end
  local glow = CreateFrame("Frame", "MasonBindHoverGlow", UIParent, "BackdropTemplate")
  glow:SetFrameStrata("TOOLTIP")
  glow:SetFrameLevel(10002)
  glow:EnableMouse(false)
  glow:Hide()
  if glow.SetBackdrop then
    glow:SetBackdrop({
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 2,
    })
    glow:SetBackdropBorderColor(1, 0.82, 0, 1)
    glow:SetBackdropColor(0, 0, 0, 0)
  end
  self.bindHoverGlow = glow
  return glow
end

function Mason:HideBindHoverHighlight()
  if self.bindHoverGlow then
    self.bindHoverGlow:Hide()
    self.bindHoverGlow:ClearAllPoints()
  end
end

function Mason:UpdateBindHoverHighlight()
  if not self.bindMode then
    self:HideBindHoverHighlight()
    return
  end
  local glow = self:EnsureBindHoverHighlight()
  if not glow then
    return
  end
  local targetFrame
  local foci = self:GetMouseFocusList()
  for i = 1, #foci do
    local f = foci[i]
    while f and not IsSkipFrame(f) do
      local hit = self:ResolveBindTargetFromFrame(f)
      if hit then
        targetFrame = f
        break
      end
      f = f.GetParent and f:GetParent()
    end
    if targetFrame then
      break
    end
  end
  if not targetFrame then
    glow:Hide()
    return
  end
  glow:ClearAllPoints()
  glow:SetPoint("TOPLEFT", targetFrame, "TOPLEFT", -2, 2)
  glow:SetPoint("BOTTOMRIGHT", targetFrame, "BOTTOMRIGHT", 2, -2)
  glow:Show()
end

function Mason:SyncEditBarBindButton()
  local bar = self.editBar
  if bar and bar.kbBtn then
    bar.kbBtn:SetText(self.bindMode and "Binding…" or "Keybind")
  end
end

function Mason:EnsureEditBar()
  if self.editBar then
    return self.editBar
  end
  if InCombatLockdown() then
    return nil
  end
  local bar = CreateFrame("Frame", "MasonEditBar", UIParent, "BackdropTemplate")
  bar:SetSize(360, 118)
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
  bar.lockBtn = MakeBtn("Lock", -92, function()
    if InCombatLockdown() then
      print("Mason: cannot lock in combat")
      return
    end
    Mason:SetLocked(true)
    Mason:Notify("locked")
  end)
  bar.cancelBtn = MakeBtn("Cancel", 0, function()
    if InCombatLockdown() then
      print("Mason: cannot cancel edit in combat")
      return
    end
    Mason:RestoreEditViewsSnapshot()
    Mason:SetLocked(true)
    Mason:Notify("locked")
  end)
  bar.kbBtn = MakeBtn("Keybind", 92, function()
    Mason:ToggleBindMode()
  end)
  self.editBar = bar
  self:SyncEditBarBindButton()
  return bar
end

function Mason:ShowEditBar()
  local bar = self:EnsureEditBar()
  if bar and self:InEditMode() then
    PrepareMasonPanelShow(bar)
    self:SyncEditBarBindButton()
  end
end

function Mason:HideEditBar()
  if self.editBar then
    self.editBar:Hide()
    self.editBar:EnableMouse(false)
  end
end
