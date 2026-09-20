local Mason = LibStub("AceAddon-3.0"):GetAddon("Mason")

function Mason:GetCursorUIPosition()
  local scale = UIParent:GetEffectiveScale()
  local x, y = GetCursorPosition()
  return x / scale, y / scale
end

function Mason:IsLocked()
  if not self.db or not self.db.char then
    return true
  end
  if self.db.char.locked == nil then
    return true
  end
  return not not self.db.char.locked
end

function Mason:SetLocked(locked)
  locked = not not locked
  if not locked and self:IsLocked() and self.TakeEditViewsSnapshot then
    self:TakeEditViewsSnapshot()
  end
  self.db.char.locked = locked
  if locked then
    self:HideEditChrome()
  elseif self.RefreshEditMode then
    self:RefreshEditMode()
  end
  if self.SyncOptionsRail then
    self:SyncOptionsRail()
  end
  return self:QueueIfCombat(function()
    self:ApplyLayout()
  end)
end

function Mason:ToggleEditMode()
  if InCombatLockdown() and self:IsLocked() then
    print("Mason: cannot edit in combat")
    return false
  end
  local locked = not self:IsLocked()
  local deferred = self:SetLocked(locked)
  self:DebugPrint("Mason: " .. (locked and "edit off" or "edit on"))
  if deferred then
    print("Mason: queued until combat ends")
  end
  return true
end

function Mason:WriteViewLayout(id, x, y)
  local views = self:GetViews()
  local view = views[id] or {}
  view.visible = true
  view.point = "CENTER"
  view.relPoint = "BOTTOMLEFT"
  view.x = x
  view.y = y
  if view.size == nil then
    local size = (self.GetDefaultSize and self:GetDefaultSize()) or 45
    if self.SyncViewSize then
      self:SyncViewSize(view, size)
    else
      view.size = size
      view.scale = view.scale or 1
    end
  elseif self.SyncViewSize then
    self:SyncViewSize(view, view.size)
  else
    view.scale = view.scale or 1
  end
  views[id] = view
  return view
end

function Mason:CommitViewPosition(id)
  if self.dragId and self.CommitDrag then
    self:CommitDrag()
    return
  end
  local x, y = self.dragX, self.dragY
  if x == nil or y == nil then
    x, y = self:GetCursorUIPosition()
  end
  if self.SnapToGrid then
    local view = self:GetViews()[id]
    local size = (self.GetViewSize and self:GetViewSize(view)) or 45
    x, y = self:SnapToGrid(x, y, size)
  end
  self.dragX, self.dragY = nil, nil
  self:WriteViewLayout(id, x, y)
  if InCombatLockdown() then
    self:QueueIfCombat(function()
      self:PlaceView(id)
    end)
    return
  end
  self:PlaceView(id)
end

function Mason:PlaceView(id, x, y, snap)
  local piece = self:GetKit()[id]
  if not piece then
    return false
  end
  local views = self:GetViews()
  local view = views[id]
  if x ~= nil and y ~= nil then
    if snap ~= false and self.SnapToGrid and not (self.FindFlyoutParent and self:FindFlyoutParent(id)) then
      local size = (view and self.GetViewSize and self:GetViewSize(view)) or (self.GetDefaultSize and self:GetDefaultSize()) or 45
      x, y = self:SnapToGrid(x, y, size)
    end
    view = self:WriteViewLayout(id, x, y)
  else
    if not view then
      return false
    end
    view.visible = true
    views[id] = view
    if self.ResolveDockedPosition then
      self:ResolveDockedPosition(id)
    end
  end
  view.point = view.point or "CENTER"
  view.relPoint = view.relPoint or "BOTTOMLEFT"
  view.x = view.x or 0
  view.y = view.y or 0
  if self.EnsureViewSize then
    self:EnsureViewSize(view)
  elseif view.size == nil then
    local size = (self.GetDefaultSize and self:GetDefaultSize()) or 45
    view.size = size
    local s0 = (self.GetFaceNativeSize and self:GetFaceNativeSize()) or 45
    view.scale = size / s0
  end

  return self:QueueIfCombat(function()
    local exec = self:EnsureExecutor(piece)
    exec:SetParent(UIParent)
    if self.ApplyViewPixelBox then
      self:ApplyViewPixelBox(id)
    else
      exec:ClearAllPoints()
      local s0 = (self.GetFaceNativeSize and self:GetFaceNativeSize()) or 45
      local px = tonumber(view.size) or (self.GetDefaultSize and self:GetDefaultSize()) or s0
      local scale = s0 > 0 and (px / s0) or 1
      exec:SetSize(s0, s0)
      exec:SetScale(scale)
      local vis = s0 * scale
      exec:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", view.x - vis / 2, view.y + vis / 2)
    end
    exec:SetAlpha(1)
    exec:Show()
    exec:EnableMouse(true)
    exec:SetMovable(false)
    self:PaintView(exec, piece)
    exec:SetParent(UIParent)
    exec:SetAlpha(1)
    exec:Show()
    if self.FitFace then
      self:FitFace(exec)
    end
    if self.OnAssistedSpellSignal then
      self:OnAssistedSpellSignal()
    end
    if self.UpdateAssistedHighlight then
      self:UpdateAssistedHighlight(exec)
    end
    if self.ApplyRule then
      self:ApplyRule(exec, piece)
    end
    if self:InEditMode() then
      exec:SetMovable(true)
      if self.SyncEditHandle then
        self:SyncEditHandle(id)
      end
    elseif self.HideEditHandle then
      self:HideEditHandle(id)
    end
    if self.ApplyCenteredScale then
      self:ApplyCenteredScale(id)
    elseif self.AnchorViewCenter then
      self:AnchorViewCenter(exec, id, view.x, view.y)
    end
    if self.ApplyViewPixelBox then
      self:ApplyViewPixelBox(id)
    end
    if C_Timer and C_Timer.After then
      C_Timer.After(0, function()
        if InCombatLockdown() then
          return
        end
        if Mason.ApplyViewPixelBox then
          Mason:ApplyViewPixelBox(id)
        end
        if not Mason.masonPrintedPlaceFacts and Mason.ReportScaleFacts then
          Mason.masonPrintedPlaceFacts = true
          Mason:ReportScaleFacts(id)
        end
      end)
    elseif not self.masonPrintedPlaceFacts and self.ReportScaleFacts then
      self.masonPrintedPlaceFacts = true
      self:ReportScaleFacts(id)
    end
  end)
end

function Mason:ShowView(id)
  local piece = self:FindPiece(id)
  if not piece then
    return false
  end
  local view = self:GetViews()[id]
  if view and (view.x ~= nil) and (view.y ~= nil) then
    local deferred = self:PlaceView(id)
    self:Notify("shown " .. self:PieceLabel(piece))
    return deferred
  end
  local x, y
  if not InCombatLockdown() and self.GetCursorUIPosition then
    x, y = self:GetCursorUIPosition()
  else
    x = (UIParent:GetWidth() or 0) / 2
    y = (UIParent:GetHeight() or 0) / 2
  end
  local deferred = self:PlaceView(id, x, y)
  self:Notify("shown " .. self:PieceLabel(piece))
  return deferred
end

function Mason:ClearView(id, silent)
  local piece = self:FindPiece(id)
  local views = self:GetViews()
  if views[id] then
    views[id].visible = false
  end
  if piece and not silent then
    self:Notify("hidden " .. self:PieceLabel(piece))
  end
  return self:QueueIfCombat(function()
    self:CrateExecutorVisual(id)
    if self.HideEditHandle then
      self:HideEditHandle(id)
    end
  end)
end

function Mason:ApplyLayout()
  if InCombatLockdown() then
    return self:QueueIfCombat(function()
      self:ApplyLayout()
    end)
  end
  local current = self:GetKit()
  for id in pairs(self.executors) do
    if not current[id] then
      self:CrateExecutorVisual(id)
    end
  end
  for id, piece in pairs(current) do
    local view = self:GetViews()[id]
    if view and view.visible then
      self:PlaceView(id)
    else
      self:EnsureExecutor(piece)
      self:CrateExecutorVisual(id)
    end
  end
  if self.RefreshEditMode then
    self:RefreshEditMode()
  end
  if self.OnAssistedSpellSignal then
    self:OnAssistedSpellSignal()
  end
end

function Mason:OnCombatLock()
  if self.ExitBindMode then
    self:ExitBindMode()
  end
  if self.dragId and self.CommitDrag then
    self:CommitDrag()
  elseif self.dragId then
    local id = self.dragId
    local x, y = self.dragX, self.dragY
    if x == nil or y == nil then
      x, y = self:GetCursorUIPosition()
    end
    self.dragId = nil
    self.dragX, self.dragY = nil, nil
    if self.SnapToGrid then
      local view = self:GetViews()[id]
      local size = (self.GetViewSize and self:GetViewSize(view)) or 45
      x, y = self:SnapToGrid(x, y, size)
    end
    self:WriteViewLayout(id, x, y)
  end
  if self.ClearSelection then
    self:ClearSelection()
  end
  if not self:IsLocked() then
    self:DebugPrint("Mason: edit off")
  end
  self:SetLocked(true)
end

local ACTION_SLOT_MAX = 180

function Mason:SnapshotActionSlots()
  local snap = {}
  if not GetActionInfo then
    return snap
  end
  for slot = 1, ACTION_SLOT_MAX do
    local a, b, c = GetActionInfo(slot)
    snap[slot] = tostring(a) .. "\0" .. tostring(b) .. "\0" .. tostring(c)
  end
  return snap
end

function Mason:SlotHoldsPiece(slot, piece)
  if not GetActionInfo or not piece then
    return false
  end
  local atype, id, subType = GetActionInfo(slot)
  if not atype then
    return false
  end
  local ptype = piece.type or "spell"
  if ptype == "spell" and atype == "spell" then
    if self.SpellIDsMatch then
      return self:SpellIDsMatch(id, piece.spellID)
    end
    return id == piece.spellID
  end
  if ptype == "flyout" and atype == "flyout" then
    return id == piece.flyoutId
  end
  if (ptype == "item" or ptype == "toy") and (atype == "item" or atype == "toy") then
    return id == piece.itemID
  end
  if ptype == "macro" and atype == "macro" then
    if type(id) == "string" and piece.macroName then
      return id == piece.macroName
    end
    if GetMacroInfo and piece.macroName then
      local name = GetMacroInfo(id)
      return name == piece.macroName
    end
  end
  return false
end

function Mason:AnySlotHoldsPiece(piece)
  if not piece or not GetActionInfo then
    return false
  end
  for slot = 1, ACTION_SLOT_MAX do
    if self:SlotHoldsPiece(slot, piece) then
      return true
    end
  end
  return false
end

function Mason:ActionSlotsTookPiece(snapshot, piece)
  if not snapshot or not piece or not GetActionInfo then
    return false
  end
  for slot = 1, ACTION_SLOT_MAX do
    local a, b, c = GetActionInfo(slot)
    local cur = tostring(a) .. "\0" .. tostring(b) .. "\0" .. tostring(c)
    if snapshot[slot] ~= cur and self:SlotHoldsPiece(slot, piece) then
      return true
    end
  end
  return false
end

function Mason:ClearMasonPickup()
  self.masonPickupId = nil
  self.masonPickupSnapshot = nil
  self.masonPickupSlotChanged = nil
  self.masonPickupSawCursor = nil
  self.masonPickupEmptyArmed = nil
end

function Mason:AcceptMasonPickup()
  local id = self.masonPickupId
  self:ClearMasonPickup()
  if id then
    self:ClearView(id)
  end
end

function Mason:OnMasonPickupSlotChanged()
  if not self.masonPickupId then
    return
  end
  self.masonPickupSlotChanged = true
  if not GetCursorInfo() then
    self:AcceptMasonPickup()
  end
end

function Mason:PollMasonPickup()
  local id = self.masonPickupId
  if not id then
    return
  end
  if GetCursorInfo() then
    self.masonPickupSawCursor = true
    self.masonPickupEmptyArmed = nil
    return
  end
  if not self.masonPickupSawCursor then
    return
  end
  if self.masonPickupSlotChanged then
    self:AcceptMasonPickup()
    return
  end
  local piece = self:FindPiece(id)
  if piece and self:ActionSlotsTookPiece(self.masonPickupSnapshot, piece) then
    self:AcceptMasonPickup()
    return
  end
  if not self.masonPickupEmptyArmed then
    self.masonPickupEmptyArmed = true
    return
  end
  if piece and self:AnySlotHoldsPiece(piece) then
    self:AcceptMasonPickup()
    return
  end
  self:ClearMasonPickup()
end

function Mason:StartLockedPickup(id)
  if InCombatLockdown() or not self:IsLocked() then
    return
  end
  local piece = self:FindPiece(id)
  if not piece then
    return
  end
  local view = self:GetViews()[id]
  if not view or not view.visible then
    return
  end
  local ptype = piece.type or "spell"
  if ptype == "spell" then
    local spell = piece.spellID or piece.spellName
    if C_Spell and C_Spell.PickupSpell then
      C_Spell.PickupSpell(spell)
    elseif PickupSpell then
      PickupSpell(spell)
    end
  elseif ptype == "flyout" then
    local flyoutId = piece.flyoutId
    if PickupSpellFlyout then
      PickupSpellFlyout(flyoutId)
    elseif PickupFlyout then
      PickupFlyout(flyoutId)
    elseif piece.spellID and C_Spell and C_Spell.PickupSpell then
      C_Spell.PickupSpell(piece.spellID)
    elseif piece.spellID and PickupSpell then
      PickupSpell(piece.spellID)
    end
  elseif ptype == "macro" then
    local index = piece.macroName
    if GetMacroIndexByName and piece.macroName then
      local macroIndex = GetMacroIndexByName(piece.macroName)
      if macroIndex and macroIndex > 0 then
        index = macroIndex
      end
    end
    if PickupMacro then
      PickupMacro(index)
    end
  else
    local itemID = piece.itemID
    local isToy = ptype == "toy" or (self.PieceIsToy and self:PieceIsToy(piece))
    if isToy and C_ToyBox and C_ToyBox.PickupToyBoxItem and itemID then
      C_ToyBox.PickupToyBoxItem(itemID)
    elseif C_Item and C_Item.PickupItem and itemID then
      C_Item.PickupItem(itemID)
    elseif PickupItem and itemID then
      PickupItem(itemID)
    end
  end
  self.masonPickupId = id
  self.masonPickupSlotChanged = nil
  self.masonPickupEmptyArmed = nil
  self.masonPickupSawCursor = not not GetCursorInfo()
  self.masonPickupSnapshot = self:SnapshotActionSlots()
end

function Mason:WireLockedPickup(exec)
  if not exec or exec.masonPickupWired then
    return
  end
  exec.masonPickupWired = true
  if exec.RegisterForDrag then
    exec:RegisterForDrag("LeftButton")
  end
  exec:HookScript("OnDragStart", function(self)
    if Mason.StartLockedPickup then
      Mason:StartLockedPickup(self.masonPieceId)
    end
  end)
end

