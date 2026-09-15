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
  self.db.char.locked = locked
  if locked then
    self:HideEditChrome()
  elseif self.RefreshEditMode then
    self:RefreshEditMode()
  end
  return self:QueueIfCombat(function()
    self:ApplyLayout()
  end)
end

function Mason:WriteViewLayout(id, x, y)
  local views = self:GetViews()
  local view = views[id] or {}
  view.visible = true
  view.point = "CENTER"
  view.relPoint = "BOTTOMLEFT"
  view.x = x
  view.y = y
  view.scale = view.scale or 1
  views[id] = view
  return view
end

function Mason:CommitViewPosition(id)
  local x, y = self.dragX, self.dragY
  if x == nil or y == nil then
    x, y = self:GetCursorUIPosition()
  end
  if self.SnapToGrid then
    x, y = self:SnapToGrid(x, y)
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

function Mason:PlaceView(id, x, y)
  local piece = self:FindPiece(id)
  if not piece then
    return false
  end
  local views = self:GetViews()
  local view = views[id]
  if x ~= nil and y ~= nil then
    view = self:WriteViewLayout(id, x, y)
  else
    if not view then
      return false
    end
    view.visible = true
    views[id] = view
  end
  view.point = view.point or "CENTER"
  view.relPoint = view.relPoint or "BOTTOMLEFT"
  view.x = view.x or 0
  view.y = view.y or 0
  view.scale = view.scale or 1

  return self:QueueIfCombat(function()
    local exec = self:EnsureExecutor(piece)
    exec:SetParent(UIParent)
    exec:ClearAllPoints()
    local s0 = (self.GetFaceNativeSize and self:GetFaceNativeSize()) or 45
    exec:SetSize(s0, s0)
    exec:SetScale(view.scale or 1)
    exec:SetPoint(view.point, UIParent, view.relPoint, view.x, view.y)
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
    print("Mason: PlaceView", id, exec:IsShown(), exec:GetWidth())
    if self:InEditMode() then
      exec:SetMovable(true)
      if self.SyncEditHandle then
        self:SyncEditHandle(id)
      end
    elseif self.HideEditHandle then
      self:HideEditHandle(id)
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

function Mason:ClearView(id)
  local piece = self:FindPiece(id)
  local views = self:GetViews()
  if views[id] then
    views[id].visible = false
  end
  if piece then
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
  local id = self.dragId
  if id then
    local x, y = self.dragX, self.dragY
    if x == nil or y == nil then
      x, y = self:GetCursorUIPosition()
    end
    self.dragId = nil
    self.dragX, self.dragY = nil, nil
    if self.SnapToGrid then
      x, y = self:SnapToGrid(x, y)
    end
    self:WriteViewLayout(id, x, y)
  end
  if not self:IsLocked() then
    self:Notify("locked")
  end
  self:SetLocked(true)
end
