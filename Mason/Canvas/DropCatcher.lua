local Mason = LibStub("AceAddon-3.0"):GetAddon("Mason")

local function FormatPayload(a, b, c, d)
  return table.concat({
    tostring(a),
    tostring(b),
    tostring(c),
    tostring(d),
  }, ", ")
end

function Mason:ParseCursorAction()
  if not GetCursorInfo then
    return nil
  end
  local infoType, a, b, c, d = GetCursorInfo()
  if not infoType then
    return nil
  end
  if infoType == "spell" then
    local spellID
    if type(c) == "number" then
      spellID = c
    elseif type(a) == "number" and type(b) ~= "string" then
      spellID = a
    else
      Mason:DebugPrint("Mason: GetCursorInfo spell payload: " .. FormatPayload(a, b, c, d))
      return nil, "ambiguous"
    end
    local spellName
    if C_Spell and C_Spell.GetSpellName then
      spellName = C_Spell.GetSpellName(spellID)
    elseif C_Spell and C_Spell.GetSpellInfo then
      local info = C_Spell.GetSpellInfo(spellID)
      spellName = info and info.name
    end
    if not spellName and not (C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)) then
      return nil, "unknown"
    end
    local looks = Mason.SpellLooksLikeFlyout and Mason:SpellLooksLikeFlyout(spellID)
    if looks then
      Mason:DebugPrint("Mason: GetCursorInfo spell payload: " .. FormatPayload(a, b, c, d) .. " spellID=" .. tostring(spellID))
      return nil, "ambiguous"
    end
    return {
      type = "spell",
      spellID = spellID,
      spellName = spellName,
    }
  end
  if infoType == "item" then
    local itemID = a
    if type(itemID) ~= "number" then
      return nil, "unknown"
    end
    local name
    if C_Item and C_Item.GetItemNameByID then
      name = C_Item.GetItemNameByID(itemID)
    end
    return {
      type = "item",
      itemID = itemID,
      spellName = name,
    }
  end
  if infoType == "toy" then
    local itemID = a
    if type(itemID) ~= "number" then
      return nil, "unknown"
    end
    local name
    if C_ToyBox and C_ToyBox.GetToyInfo then
      name = C_ToyBox.GetToyInfo(itemID)
    end
    return {
      type = "toy",
      itemID = itemID,
      spellName = name,
    }
  end
  if infoType == "macro" then
    local index = a
    if not GetMacroInfo then
      return nil, "unknown"
    end
    local name = GetMacroInfo(index)
    if not name then
      return nil, "unknown"
    end
    return {
      type = "macro",
      macroName = name,
    }
  end
  if infoType == "flyout" then
    local flyoutId = tonumber(a)
    local infoOk = false
    if flyoutId and GetFlyoutInfo then
      infoOk = pcall(GetFlyoutInfo, flyoutId)
    elseif flyoutId and C_SpellBook and C_SpellBook.GetFlyoutInfo then
      infoOk = pcall(C_SpellBook.GetFlyoutInfo, flyoutId)
    end
    if not flyoutId or not infoOk then
      Mason:DebugPrint("Mason: bad flyoutId " .. tostring(a) .. " " .. tostring(infoType) .. " " .. FormatPayload(a, b, c, d))
      return nil, "ambiguous"
    end
    local spellName = Mason.FlyoutLabel and Mason:FlyoutLabel(flyoutId) or nil
    return {
      type = "flyout",
      flyoutId = flyoutId,
      spellName = spellName,
    }
  end
  Mason:DebugPrint("Mason: GetCursorInfo payload: " .. tostring(infoType) .. " " .. FormatPayload(a, b, c, d))
  return nil
end

function Mason:CursorHoldsAcceptedType()
  if not GetCursorInfo then
    return false
  end
  local infoType = GetCursorInfo()
  return infoType == "spell" or infoType == "item" or infoType == "macro" or infoType == "toy" or infoType == "flyout"
end

function Mason:CursorShouldArmCatcher()
  if self.masonPickupId then
    return false
  end
  if not GetCursorInfo then
    return false
  end
  local infoType = GetCursorInfo()
  if infoType == "spell" or infoType == "macro" or infoType == "flyout" then
    return true
  end
  if infoType == "item" or infoType == "toy" then
    return not self:IsLocked()
  end
  return false
end

function Mason:SyncDropCatcher()
  local catcher = self.dropCatcher
  if not catcher then
    return
  end
  if self:CursorShouldArmCatcher() then
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:Show()
    if not catcher:IsMouseEnabled() then
      Mason:DebugPrint("Mason: drop catcher mouse on")
    end
    catcher:EnableMouse(true)
    if self.SetEditHandlesMouse then
      self:SetEditHandlesMouse(false)
    end
  else
    catcher:EnableMouse(false)
    catcher:Show()
    catcher:SetFrameStrata("BACKGROUND")
    catcher:SetFrameLevel(0)
    if self.InEditMode and self:InEditMode() and self.SetEditHandlesMouse then
      self:SetEditHandlesMouse(true)
    end
  end
end

function Mason:PlaceCursorAction(action, x, y)
  if action.type == "flyout" then
    local flyoutId = tonumber(action.flyoutId)
    local infoOk = false
    if flyoutId and GetFlyoutInfo then
      infoOk = pcall(GetFlyoutInfo, flyoutId)
    end
    if not flyoutId or not infoOk then
      local infoType, a, b, c, d = GetCursorInfo()
      Mason:DebugPrint("Mason: bad flyoutId " .. tostring(action.flyoutId) .. " " .. tostring(infoType) .. " " .. FormatPayload(a, b, c, d))
      return false
    end
    action.flyoutId = flyoutId
    action.spellID = nil
  end
  local piece = self:FindPieceByAction(action.type, action)
  if not piece then
    piece = self:CreatePiece({
      type = action.type,
      spellID = action.type ~= "flyout" and action.spellID or nil,
      spellName = action.spellName,
      itemID = action.itemID,
      macroName = action.macroName,
      flyoutId = action.flyoutId,
    })
  else
    if action.spellName then
      piece.spellName = action.spellName
    end
    if action.flyoutId then
      piece.type = "flyout"
      piece.flyoutId = tonumber(action.flyoutId)
      piece.spellID = nil
    end
  end
  if not piece then
    print("Mason: could not create piece")
    return false
  end
  if self.SnapToGrid then
    local view = self:GetViews()[piece.id]
    local size = (self.GetViewSize and self:GetViewSize(view)) or 45
    x, y = self:SnapToGrid(x, y, size)
  end
  self:WriteViewLayout(piece.id, x, y)
  local msg = "placed " .. self:PieceLabel(piece)
  self:PlaceView(piece.id, x, y)
  if action.type == "flyout" and self.PopulateBlizzardFlyoutSlots then
    self:PopulateBlizzardFlyoutSlots(piece.id, action.flyoutId)
  end
  self:Notify(msg)
  if self:IsLocked() then
    self:SetLocked(false)
    self:DebugPrint("Mason: edit on")
  end
end

function Mason:HandleCanvasDrop()
  if InCombatLockdown() then
    self:Notify("cannot place in combat")
    return
  end
  local action, err = self:ParseCursorAction()
  if err == "ambiguous" then
    return
  end
  if not action then
    if err == "unknown" then
      print("Mason: unknown cursor action")
      ClearCursor()
    end
    return
  end
  if action.type == "spell" and action.spellID then
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(action.spellID)
    if not info then
      print("Mason: unknown spell")
      ClearCursor()
      return
    end
    if not action.spellName then
      action.spellName = info.name
    end
  end
  if (action.type == "item" or action.type == "toy") and self:IsLocked() then
    return
  end
  local x, y = self:GetCursorUIPosition()
  self:PlaceCursorAction(action, x, y)
  ClearCursor()
  self:SyncDropCatcher()
end

function Mason:CreateDropCatcher()
  if self.dropCatcher then
    return self.dropCatcher
  end
  local catcher = CreateFrame("Frame", "MasonDropCatcher", UIParent)
  catcher:SetAllPoints(UIParent)
  catcher:SetFrameStrata("HIGH")
  catcher:SetFrameLevel(0)
  catcher:EnableMouse(false)
  catcher:Show()
  catcher:SetScript("OnReceiveDrag", function()
    Mason:HandleCanvasDrop()
  end)
  catcher:SetScript("OnMouseUp", function()
    if Mason:CursorShouldArmCatcher() then
      Mason:HandleCanvasDrop()
    end
  end)
  catcher:SetScript("OnUpdate", function()
    Mason:SyncDropCatcher()
  end)
  self.dropCatcher = catcher
  self:SyncDropCatcher()
  return catcher
end
