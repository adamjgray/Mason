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
  local exec = self.executors[id] or _G[self:ExecutorName(id)]
  if not exec then
    return
  end
  local cx, cy = exec:GetCenter()
  if not cx then
    return
  end
  local uis = UIParent:GetEffectiveScale()
  local es = exec:GetEffectiveScale()
  local x, y = cx * es / uis, cy * es / uis
  if self.SnapToGrid then
    x, y = self:SnapToGrid(x, y)
  end
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
    exec:StopMovingOrSizing()
    exec:ClearAllPoints()
    exec:SetSize(36, 36)
    exec:SetScale(view.scale)
    exec:SetPoint(view.point, UIParent, view.relPoint, view.x, view.y)
    exec:SetAlpha(1)
    exec:Show()
    exec:EnableMouse(true)
    exec:SetMovable(false)
    self:PaintView(exec, piece)
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
end

function Mason:OnCombatLock()
  local id = self.dragId
  if id then
    local x, y = self:GetCursorUIPosition()
    self.dragId = nil
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
