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
      print("Mason: GetCursorInfo spell payload: " .. FormatPayload(a, b, c, d))
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
  return nil
end

function Mason:CursorHoldsAcceptedType()
  if not GetCursorInfo then
    return false
  end
  local infoType = GetCursorInfo()
  return infoType == "spell" or infoType == "item" or infoType == "macro"
end

function Mason:SyncDropCatcher()
  local catcher = self.dropCatcher
  if not catcher then
    return
  end
  if self:CursorHoldsAcceptedType() then
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:Show()
    catcher:EnableMouse(true)
    if self.SetEditHandlesMouse then
      self:SetEditHandlesMouse(false)
    end
  else
    catcher:EnableMouse(false)
    catcher:Hide()
    catcher:SetFrameStrata("HIGH")
    if self.InEditMode and self:InEditMode() and self.SetEditHandlesMouse then
      self:SetEditHandlesMouse(true)
    end
  end
end

function Mason:PlaceCursorAction(action, x, y)
  local piece = self:FindPieceByAction(action.type, action)
  if not piece then
    piece = self:CreatePiece({
      type = action.type,
      spellID = action.spellID,
      spellName = action.spellName,
      itemID = action.itemID,
      macroName = action.macroName,
    })
  else
    if action.spellName then
      piece.spellName = action.spellName
    end
  end
  if not piece then
    print("Mason: could not create piece")
    return false
  end
  self:WriteViewLayout(piece.id, x, y)
  local msg = "placed " .. self:PieceLabel(piece)
  self:PlaceView(piece.id, x, y)
  self:Notify(msg)
  if self:IsLocked() then
    self:SetLocked(false)
    self:Notify("unlocked")
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
  catcher:Hide()
  catcher:SetScript("OnReceiveDrag", function()
    Mason:HandleCanvasDrop()
  end)
  catcher:SetScript("OnMouseUp", function()
    if Mason:CursorHoldsAcceptedType() then
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
