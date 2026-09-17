local Mason = LibStub("AceAddon-3.0"):GetAddon("Mason")

local VEIL_ALPHA = 0.35
local GRID_LINE_ALPHA = 0.14

function Mason:InEditMode()
  return not self:IsLocked()
end

function Mason:GetGridSize()
  local n = self.db and self.db.char and self.db.char.gridSize
  n = tonumber(n) or 32
  if n < 8 then
    n = 8
  elseif n > 128 then
    n = 128
  end
  return n
end

function Mason:SetGridSize(pixels)
  pixels = math.floor(tonumber(pixels) or 0)
  if pixels < 8 or pixels > 128 then
    return false
  end
  self.db.char.gridSize = pixels
  if self.editVeil and self.editVeil:IsShown() then
    self:RedrawEditGrid()
  end
  return true
end

function Mason:IsSnapEnabled()
  if not self.db or not self.db.char then
    return true
  end
  if self.db.char.snap == nil then
    return true
  end
  return not not self.db.char.snap
end

function Mason:SetSnapEnabled(enabled)
  self.db.char.snap = not not enabled
  return self.db.char.snap
end

function Mason:GetGridOrigin()
  local w = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 0
  local h = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 0
  return w / 2, h / 2
end

function Mason:SnapValueToGrid(p, origin)
  local g = self:GetGridSize()
  origin = origin or 0
  return origin + math.floor((p - origin) / g + 0.5) * g
end

function Mason:NextGridLine(p, origin, dir)
  local g = self:GetGridSize()
  origin = origin or 0
  dir = dir >= 0 and 1 or -1
  local nearest = self:SnapValueToGrid(p, origin)
  if math.abs(p - nearest) <= 0.5 then
    return nearest + dir * g
  end
  if dir > 0 then
    local n = math.floor((p - origin) / g) + 1
    return origin + n * g
  end
  local n = math.ceil((p - origin) / g) - 1
  return origin + n * g
end

function Mason:SnapToGrid(x, y, size)
  if not self:IsSnapEnabled() then
    return x, y
  end
  local ox, oy = self:GetGridOrigin()
  size = tonumber(size) or (self.GetDefaultSize and self:GetDefaultSize()) or 45
  local half = size / 2
  local offsets = {
    { 0, 0 },
    { 0, half },
    { 0, -half },
    { half, 0 },
    { -half, 0 },
    { half, half },
    { half, -half },
    { -half, half },
    { -half, -half },
  }
  local bestErr, bestX, bestY
  for i = 1, #offsets do
    local px, py = x + offsets[i][1], y + offsets[i][2]
    local gx = self:SnapValueToGrid(px, ox)
    local gy = self:SnapValueToGrid(py, oy)
    local dx, dy = gx - px, gy - py
    local err = dx * dx + dy * dy
    if not bestErr or err < bestErr then
      bestErr = err
      bestX = gx - offsets[i][1]
      bestY = gy - offsets[i][2]
    end
  end
  return bestX, bestY
end

function Mason:CreateEditMode()
  if self.editVeil then
    return self.editVeil
  end
  self.editHandles = self.editHandles or {}
  local veil = CreateFrame("Frame", "MasonEditVeil", UIParent)
  veil:SetAllPoints(UIParent)
  veil:SetFrameStrata("HIGH")
  veil:SetFrameLevel(1)
  veil:EnableMouse(false)
  veil:EnableKeyboard(true)
  veil:Hide()
  local dim = veil:CreateTexture(nil, "BACKGROUND")
  dim:SetAllPoints(veil)
  dim:SetColorTexture(0, 0, 0, VEIL_ALPHA)
  veil.dim = dim
  veil.lines = {}
  veil:SetScript("OnSizeChanged", function()
    if veil:IsShown() then
      Mason:RedrawEditGrid()
    end
  end)
  veil:SetScript("OnKeyDown", function(self, key)
    if Mason.HandleNudgeKey and Mason:HandleNudgeKey(key) then
      if self.SetPropagateKeyboardInput then
        self:SetPropagateKeyboardInput(false)
      end
      return
    end
    if self.SetPropagateKeyboardInput then
      self:SetPropagateKeyboardInput(true)
    end
  end)
  self.editVeil = veil
  return veil
end

function Mason:RedrawEditGrid()
  local veil = self.editVeil
  if not veil then
    return
  end
  local size = self:GetGridSize()
  local w, h = veil:GetWidth(), veil:GetHeight()
  if not w or w == 0 then
    return
  end
  local ox, oy = self:GetGridOrigin()
  local lines = veil.lines
  local used = 0
  local function line()
    used = used + 1
    local tex = lines[used]
    if not tex then
      tex = veil:CreateTexture(nil, "ARTWORK")
      lines[used] = tex
    end
    tex:Show()
    tex:SetColorTexture(1, 1, 1, GRID_LINE_ALPHA)
    return tex
  end
  local n0 = math.floor((0 - ox) / size) - 1
  local n1 = math.ceil((w - ox) / size) + 1
  for n = n0, n1 do
    local x = ox + n * size
    local tex = line()
    tex:ClearAllPoints()
    tex:SetPoint("BOTTOMLEFT", veil, "BOTTOMLEFT", x, 0)
    tex:SetSize(1, h)
  end
  local m0 = math.floor((0 - oy) / size) - 1
  local m1 = math.ceil((h - oy) / size) + 1
  for m = m0, m1 do
    local y = oy + m * size
    local tex = line()
    tex:ClearAllPoints()
    tex:SetPoint("BOTTOMLEFT", veil, "BOTTOMLEFT", 0, y)
    tex:SetSize(w, 1)
  end
  for i = used + 1, #lines do
    lines[i]:Hide()
  end
end

function Mason:LayoutEditHandle(id, x, y)
  local handle = self.editHandles and self.editHandles[id]
  if not handle then
    return
  end
  local view = self:GetViews()[id]
  if x == nil or y == nil then
    if view then
      x, y = view.x, view.y
    end
  end
  if x == nil or y == nil then
    return
  end
  local s0 = (self.GetFaceNativeSize and self:GetFaceNativeSize()) or 45
  local S = (view and tonumber(view.size)) or (self.GetDefaultSize and self:GetDefaultSize()) or s0
  handle:SetParent(UIParent)
  handle:SetScale(1)
  handle:SetSize(S, S)
  handle:ClearAllPoints()
  handle:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
end

function Mason:DragExecutorToCursor(id)
  if self.UpdateHandleDrag and self.dragId then
    self:UpdateHandleDrag()
    return
  end
  if InCombatLockdown() then
    return
  end
  local x, y = self:GetCursorUIPosition()
  self.dragX, self.dragY = x, y
  local view = self:GetViews()[id]
  if view then
    view.x, view.y = x, y
  end
  local host = self.scaleHosts and self.scaleHosts[id]
  if host then
    host:ClearAllPoints()
    host:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
  elseif self.ApplyViewPixelBox then
    self:ApplyViewPixelBox(id)
  end
  self:LayoutEditHandle(id, x, y)
end

function Mason:EnsureEditHandle(id, exec)
  self.editHandles = self.editHandles or {}
  local sanitized = tostring(id):gsub("[^%w_]", "_")
  local name = "MasonEdit_" .. sanitized
  local handle = self.editHandles[id] or _G[name]
  if not handle then
    handle = CreateFrame("Button", name, UIParent, "BackdropTemplate")
    handle:RegisterForClicks("AnyDown", "AnyUp")
    handle:EnableMouseWheel(true)
    handle:EnableKeyboard(true)
    if handle.SetBackdrop then
      handle:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
      })
      handle:SetBackdropColor(0, 0, 0, 0)
      handle:SetBackdropBorderColor(0, 0, 0, 0)
    end
    local overlay = handle:CreateTexture(nil, "BACKGROUND")
    overlay:SetAllPoints(handle)
    overlay:SetColorTexture(1, 1, 1, 0.12)
    handle.overlay = overlay
    local xbtn = CreateFrame("Button", nil, handle)
    xbtn:SetSize(16, 16)
    xbtn:SetPoint("TOPRIGHT", handle, "TOPRIGHT", 2, 2)
    local xt = xbtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    xt:SetAllPoints()
    xt:SetText("×")
    xbtn:SetScript("OnClick", function()
      if handle.pieceId then
        if Mason.selectedIds then
          Mason.selectedIds[handle.pieceId] = nil
        end
        Mason:ClearView(handle.pieceId)
      end
    end)
    handle.xbtn = xbtn
    local function stopDrag(h)
      h.masonDragging = false
      if Mason.CommitDrag then
        Mason:CommitDrag()
      else
        local dragId = h.pieceId
        Mason.dragId = nil
        if dragId then
          Mason:CommitViewPosition(dragId)
        end
      end
    end
    handle:SetScript("OnMouseDown", function(h, button)
      if button ~= "LeftButton" or not Mason:InEditMode() or InCombatLockdown() then
        return
      end
      if not h.executor or not h.pieceId then
        return
      end
      local shift = IsShiftKeyDown()
      if shift then
        Mason:ToggleSelect(h.pieceId)
      else
        Mason:SelectOnly(h.pieceId)
      end
      h.masonDragging = true
      Mason:BeginHandleDrag(h.pieceId, shift)
    end)
    handle:SetScript("OnMouseUp", function(h, button)
      if button == "RightButton" and h.pieceId and Mason:InEditMode() then
        Mason:ClearView(h.pieceId)
        return
      end
      if button == "LeftButton" and h.masonDragging then
        stopDrag(h)
      end
    end)
    handle:SetScript("OnMouseWheel", function(h, delta)
      if not Mason:InEditMode() or InCombatLockdown() or not h.pieceId then
        return
      end
      if not Mason:IsSelected(h.pieceId) then
        return
      end
      if IsShiftKeyDown() then
        Mason:SizeIdsToDefault(Mason:SelectedList())
      else
        Mason:SizeIds(Mason:SelectedList(), delta)
      end
    end)
    handle:SetScript("OnKeyDown", function(self, key)
      if Mason.HandleNudgeKey and Mason:HandleNudgeKey(key) then
        if self.SetPropagateKeyboardInput then
          self:SetPropagateKeyboardInput(false)
        end
        return
      end
      if self.SetPropagateKeyboardInput then
        self:SetPropagateKeyboardInput(true)
      end
    end)
    handle:SetScript("OnHide", function(h)
      if h.masonDragging then
        stopDrag(h)
      end
    end)
    handle:SetScript("OnUpdate", function(h)
      if h.masonDragging and h.pieceId then
        Mason:UpdateHandleDrag()
        return
      end
      if h.pieceId and h:IsShown() then
        Mason:LayoutEditHandle(h.pieceId)
      end
    end)
    self.editHandles[id] = handle
  end
  handle.pieceId = id
  handle.executor = exec
  if self.PaintHandleSelection then
    self:PaintHandleSelection(handle, self:IsSelected(id))
  end
  return handle
end

function Mason:HideEditHandle(id)
  local handle = self.editHandles and self.editHandles[id]
  if not handle then
    handle = _G["MasonEdit_" .. tostring(id):gsub("[^%w_]", "_")]
  end
  if not handle then
    return
  end
  handle:EnableMouse(false)
  if handle.xbtn then
    handle.xbtn:EnableMouse(false)
  end
  if self.HideHandleDockHints then
    self:HideHandleDockHints(handle)
  end
  handle:Hide()
end

function Mason:SetEditHandlesMouse(enabled)
  if not self.editHandles then
    return
  end
  enabled = not not enabled
  for _, handle in pairs(self.editHandles) do
    if handle:IsShown() then
      handle:EnableMouse(enabled)
      if handle.xbtn then
        handle.xbtn:EnableMouse(enabled)
      end
    end
  end
end

function Mason:SyncEditHandle(id)
  local exec = self.executors and self.executors[id]
  local view = self:GetViews()[id]
  if not exec or not view or not view.visible or not self:InEditMode() then
    self:HideEditHandle(id)
    return
  end
  local handle = self:EnsureEditHandle(id, exec)
  self:LayoutEditHandle(id)
  handle:SetFrameStrata("DIALOG")
  local level = exec:GetFrameLevel()
  handle:SetFrameLevel((level or 0) + 20)
  handle:Show()
  local mouse = not self:CursorHoldsAcceptedType()
  handle:EnableMouse(mouse)
  if handle.xbtn then
    handle.xbtn:EnableMouse(mouse)
  end
end

function Mason:HideEditChrome()
  if self.ClearSelection then
    self:ClearSelection()
  end
  if self.HideEditBar then
    self:HideEditBar()
  end
  if self.editVeil then
    self.editVeil:EnableMouse(false)
    self.editVeil:Hide()
  end
  for id in pairs(self.editHandles or {}) do
    self:HideEditHandle(id)
  end
end

function Mason:RefreshEditMode()
  self:CreateEditMode()
  if self:InEditMode() then
    self.editVeil:Show()
    self.editVeil:EnableMouse(false)
    if self.editVeil.EnableKeyboard then
      self.editVeil:EnableKeyboard(true)
    end
    self:RedrawEditGrid()
    local current = self:GetKit()
    for id, handle in pairs(self.editHandles or {}) do
      if not current[id] then
        self:HideEditHandle(id)
      end
    end
    for id, view in pairs(self:GetViews()) do
      if view.visible and current[id] then
        self:SyncEditHandle(id)
      else
        self:HideEditHandle(id)
      end
    end
    if self.RefreshDockHints then
      self:RefreshDockHints()
    end
    if self.ShowEditBar then
      self:ShowEditBar()
    end
  else
    self:HideEditChrome()
  end
end
