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

function Mason:SnapToGrid(x, y)
  local g = self:GetGridSize()
  return math.floor(x / g + 0.5) * g, math.floor(y / g + 0.5) * g
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
  for x = 0, w, size do
    local tex = line()
    tex:ClearAllPoints()
    tex:SetPoint("BOTTOMLEFT", veil, "BOTTOMLEFT", x, 0)
    tex:SetSize(1, h)
  end
  for y = 0, h, size do
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
  local scale = (view and view.scale) or 1
  handle:SetScale(1)
  handle:SetSize(s0 * scale, s0 * scale)
  handle:ClearAllPoints()
  handle:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
end

function Mason:DragExecutorToCursor(id)
  if InCombatLockdown() then
    return
  end
  local x, y = self:GetCursorUIPosition()
  self.dragX, self.dragY = x, y
  local exec = self.executors and self.executors[id]
  if exec then
    exec:ClearAllPoints()
    exec:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
  end
  self:LayoutEditHandle(id, x, y)
end

function Mason:EnsureEditHandle(id, exec)
  self.editHandles = self.editHandles or {}
  local sanitized = tostring(id):gsub("[^%w_]", "_")
  local name = "MasonEdit_" .. sanitized
  local handle = self.editHandles[id] or _G[name]
  if not handle then
    handle = CreateFrame("Button", name, UIParent)
    handle:RegisterForClicks("AnyDown", "AnyUp")
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
        Mason:ClearView(handle.pieceId)
      end
    end)
    handle.xbtn = xbtn
    local function stopDrag(h)
      h.masonDragging = false
      local dragId = h.pieceId
      Mason.dragId = nil
      if dragId then
        Mason:CommitViewPosition(dragId)
      end
    end
    handle:SetScript("OnMouseDown", function(h, button)
      if button ~= "LeftButton" or not Mason:InEditMode() or InCombatLockdown() then
        return
      end
      if not h.executor then
        return
      end
      Mason.dragId = h.pieceId
      h.masonDragging = true
      Mason:DragExecutorToCursor(h.pieceId)
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
    handle:SetScript("OnHide", function(h)
      if h.masonDragging then
        stopDrag(h)
      end
    end)
    handle:SetScript("OnUpdate", function(h)
      if h.masonDragging and h.pieceId then
        Mason:DragExecutorToCursor(h.pieceId)
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
  if self.editVeil then
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
  else
    self:HideEditChrome()
  end
end
