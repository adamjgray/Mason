local Mason = LibStub("AceAddon-3.0"):GetAddon("Mason")

local DOCK_PX = 8
local GOLD = { 1, 0.82, 0, 1 }

function Mason:AnchorViewCenter(exec, id, x, y)
  if not exec or InCombatLockdown() then
    return
  end
  id = id or exec.masonPieceId
  local view = id and self:GetViews()[id]
  if not view or not view.visible then
    return
  end
  x = x or view.x
  y = y or view.y
  if x == nil or y == nil then
    return
  end
  exec:ClearAllPoints()
  exec:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
  if self.LayoutEditHandle then
    self:LayoutEditHandle(id, x, y)
  end
end

function Mason:ApplyCenteredScale(id)
  if InCombatLockdown() then
    return
  end
  local view = self:GetViews()[id]
  local exec = self.executors and self.executors[id]
  if not view or not view.visible or not exec then
    return
  end
  local x, y = view.x, view.y
  if x == nil or y == nil then
    return
  end
  if self.FitFace then
    self:FitFace(exec)
  else
    local size = self:GetViewSize(view)
    exec:SetScale(1)
    exec:SetSize(size, size)
  end
  exec:ClearAllPoints()
  exec:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
  if self.LayoutEditHandle then
    self:LayoutEditHandle(id, x, y)
  end
end

function Mason:GetViewHalf(view)
  return self:GetViewSize(view) / 2
end

function Mason:ViewBox(id, x, y)
  local view = self:GetViews()[id]
  if not view then
    return nil
  end
  x = x or view.x
  y = y or view.y
  if x == nil or y == nil then
    return nil
  end
  local half = self:GetViewHalf(view)
  return {
    x = x,
    y = y,
    half = half,
    left = x - half,
    right = x + half,
    bottom = y - half,
    top = y + half,
  }
end

function Mason:ClearSelection()
  self.selectedIds = {}
  self.selectionAnchor = nil
  self:RefreshSelectionChrome()
end

function Mason:IsSelected(id)
  return self.selectedIds and self.selectedIds[id]
end

function Mason:SelectedList()
  local list = {}
  for id in pairs(self.selectedIds or {}) do
    list[#list + 1] = id
  end
  table.sort(list)
  return list
end

function Mason:SelectOnly(id)
  self.selectedIds = { [id] = true }
  self.selectionAnchor = id
  self:RefreshSelectionChrome()
end

function Mason:ToggleSelect(id)
  self.selectedIds = self.selectedIds or {}
  if self.selectedIds[id] then
    self.selectedIds[id] = nil
    if self.selectionAnchor == id then
      self.selectionAnchor = nil
      for other in pairs(self.selectedIds) do
        self.selectionAnchor = other
        break
      end
    end
  else
    self.selectedIds[id] = true
    self.selectionAnchor = id
  end
  self:RefreshSelectionChrome()
end

function Mason:PaintHandleSelection(handle, selected)
  if not handle then
    return
  end
  if selected then
    if handle.SetBackdropBorderColor then
      handle:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
    end
  elseif handle.SetBackdropBorderColor then
    handle:SetBackdropBorderColor(0, 0, 0, 0)
  end
end

function Mason:RefreshSelectionChrome()
  for id, handle in pairs(self.editHandles or {}) do
    self:PaintHandleSelection(handle, self:IsSelected(id))
  end
end

function Mason:GetDockChildren(parentId)
  local kids = {}
  for id, view in pairs(self:GetViews()) do
    if view.visible and view.dock and view.dock.parent == parentId then
      kids[#kids + 1] = id
    end
  end
  return kids
end

function Mason:GetDockRoot(id)
  local views = self:GetViews()
  local seen = {}
  local cur = id
  while cur and views[cur] and views[cur].dock and views[cur].dock.parent do
    if seen[cur] then
      break
    end
    seen[cur] = true
    cur = views[cur].dock.parent
  end
  return cur or id
end

function Mason:CollectDockDescendants(id, into)
  into = into or {}
  into[id] = true
  local kids = self:GetDockChildren(id)
  for i = 1, #kids do
    self:CollectDockDescendants(kids[i], into)
  end
  return into
end

function Mason:GetCourseIds(id)
  local ids = {}
  if not id then
    return ids
  end
  return self:CollectDockDescendants(self:GetDockRoot(id), ids)
end

function Mason:MoveCourse(id, dx, dy)
  dx = dx or 0
  dy = dy or 0
  for mid in pairs(self:GetCourseIds(id)) do
    local view = self:GetViews()[mid]
    if view and view.x ~= nil and view.y ~= nil then
      local start = self.dragStart and self.dragStart[mid]
      local x, y
      if start then
        x, y = start.x + dx, start.y + dy
      else
        x, y = view.x + dx, view.y + dy
      end
      view.x, view.y = x, y
      local exec = self.executors and self.executors[mid]
      if exec and self.AnchorViewCenter then
        self:AnchorViewCenter(exec, mid, x, y)
      elseif self.LayoutEditHandle then
        self:LayoutEditHandle(mid, x, y)
      end
    end
  end
end

function Mason:PieceInCourse(id)
  local view = self:GetViews()[id]
  if not view or not view.visible then
    return false
  end
  if view.dock and view.dock.parent then
    return true
  end
  return #self:GetDockChildren(id) > 0
end

local DOCK_OPPOSITE = {
  left = "right",
  right = "left",
  top = "bottom",
  bottom = "top",
}

function Mason:EnsureDockHint(handle)
  if not handle or handle.dockHints then
    return
  end
  local hints = {}
  local function make()
    local t = handle:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(0.2, 0.85, 0.25, 1)
    t:Hide()
    hints[#hints + 1] = t
    return t
  end
  handle.dockHints = {
    left = make(),
    right = make(),
    top = make(),
    bottom = make(),
  }
end

function Mason:LayoutDockHint(handle, side)
  local t = handle.dockHints and handle.dockHints[side]
  if not t then
    return
  end
  t:ClearAllPoints()
  t:Show()
  if side == "left" then
    t:SetPoint("TOPLEFT", handle, "TOPLEFT", 0, 0)
    t:SetPoint("BOTTOMLEFT", handle, "BOTTOMLEFT", 0, 0)
    t:SetWidth(2)
  elseif side == "right" then
    t:SetPoint("TOPRIGHT", handle, "TOPRIGHT", 0, 0)
    t:SetPoint("BOTTOMRIGHT", handle, "BOTTOMRIGHT", 0, 0)
    t:SetWidth(2)
  elseif side == "top" then
    t:SetPoint("TOPLEFT", handle, "TOPLEFT", 0, 0)
    t:SetPoint("TOPRIGHT", handle, "TOPRIGHT", 0, 0)
    t:SetHeight(2)
  else
    t:SetPoint("BOTTOMLEFT", handle, "BOTTOMLEFT", 0, 0)
    t:SetPoint("BOTTOMRIGHT", handle, "BOTTOMRIGHT", 0, 0)
    t:SetHeight(2)
  end
end

function Mason:HideHandleDockHints(handle)
  if not handle or not handle.dockHints then
    return
  end
  for _, t in pairs(handle.dockHints) do
    t:Hide()
  end
end

function Mason:ClearDockHints()
  for _, handle in pairs(self.editHandles or {}) do
    self:HideHandleDockHints(handle)
  end
end

function Mason:ShowDockPairHint(childId, parentId, side)
  if not childId or not parentId or not side then
    return
  end
  local childHandle = self.editHandles and self.editHandles[childId]
  local parentHandle = self.editHandles and self.editHandles[parentId]
  local opp = DOCK_OPPOSITE[side]
  if parentHandle then
    self:EnsureDockHint(parentHandle)
    self:LayoutDockHint(parentHandle, side)
  end
  if childHandle and opp then
    self:EnsureDockHint(childHandle)
    self:LayoutDockHint(childHandle, opp)
  end
end

function Mason:RefreshDockHints(previewId, previewParent, previewSide)
  if not self:InEditMode() then
    self:ClearDockHints()
    return
  end
  self:ClearDockHints()
  for id, view in pairs(self:GetViews()) do
    if view.visible and view.dock and view.dock.parent and view.dock.side then
      self:ShowDockPairHint(id, view.dock.parent, view.dock.side)
    end
  end
  if previewId and previewParent and previewSide then
    self:ShowDockPairHint(previewId, previewParent, previewSide)
  end
end


function Mason:WouldDockCycle(id, parentId)
  if not id or not parentId or id == parentId then
    return true
  end
  local views = self:GetViews()
  local seen = {}
  local cur = parentId
  while cur do
    if cur == id then
      return true
    end
    if seen[cur] then
      return true
    end
    seen[cur] = true
    local view = views[cur]
    cur = view and view.dock and view.dock.parent
  end
  return false
end

function Mason:DockedCenter(id)
  local views = self:GetViews()
  local view = views[id]
  if not view or not view.dock or not view.dock.parent then
    return view and view.x, view and view.y
  end
  local parent = views[view.dock.parent]
  if not parent or parent.x == nil or parent.y == nil then
    return view.x, view.y
  end
  local ph = self:GetViewHalf(parent)
  local h = self:GetViewHalf(view)
  local side = view.dock.side
  local x, y = parent.x, parent.y
  if side == "right" then
    x = parent.x + ph + h
  elseif side == "left" then
    x = parent.x - ph - h
  elseif side == "top" then
    y = parent.y + ph + h
  elseif side == "bottom" then
    y = parent.y - ph - h
  end
  return x, y
end

function Mason:ResolveDockedPosition(id, visiting)
  local view = self:GetViews()[id]
  if not view then
    return
  end
  visiting = visiting or {}
  if visiting[id] then
    view.dock = nil
    return
  end
  visiting[id] = true
  if view.dock and view.dock.parent then
    if self:WouldDockCycle(id, view.dock.parent) then
      view.dock = nil
    else
      self:ResolveDockedPosition(view.dock.parent, visiting)
      local x, y = self:DockedCenter(id)
      if x ~= nil and y ~= nil then
        view.x, view.y = x, y
      end
    end
  end
end

function Mason:RelayoutDocked(id)
  local kids = self:GetDockChildren(id)
  for i = 1, #kids do
    local child = kids[i]
    self:ResolveDockedPosition(child)
    if not InCombatLockdown() then
      self:PlaceView(child)
    end
    self:RelayoutDocked(child)
  end
end

local function RangesOverlap(a0, a1, b0, b1, slack)
  return not (a1 < b0 - slack or b1 < a0 - slack)
end

function Mason:EdgeDockMatch(memberId, candidateId)
  local selfBox = self:ViewBox(memberId)
  local box = self:ViewBox(candidateId)
  if not selfBox or not box then
    return nil
  end
  local candidates = {
    { side = "right", dist = math.abs(selfBox.left - box.right), ok = RangesOverlap(selfBox.bottom, selfBox.top, box.bottom, box.top, DOCK_PX) },
    { side = "left", dist = math.abs(selfBox.right - box.left), ok = RangesOverlap(selfBox.bottom, selfBox.top, box.bottom, box.top, DOCK_PX) },
    { side = "top", dist = math.abs(selfBox.bottom - box.top), ok = RangesOverlap(selfBox.left, selfBox.right, box.left, box.right, DOCK_PX) },
    { side = "bottom", dist = math.abs(selfBox.top - box.bottom), ok = RangesOverlap(selfBox.left, selfBox.right, box.left, box.right, DOCK_PX) },
  }
  local bestDist, bestSide
  for i = 1, #candidates do
    local c = candidates[i]
    if c.ok and c.dist <= DOCK_PX and (not bestDist or c.dist < bestDist) then
      bestDist = c.dist
      bestSide = c.side
    end
  end
  if bestSide then
    return bestDist, bestSide
  end
  return nil
end

function Mason:FindBestDock(course)
  if not course then
    return nil
  end
  local bestDist, bestMember, bestParent, bestSide
  for memberId in pairs(course) do
    local memberView = self:GetViews()[memberId]
    if memberView and memberView.visible then
      for otherId, view in pairs(self:GetViews()) do
        if view.visible and not course[otherId] then
          if not self:WouldDockCycle(memberId, otherId) then
            local dist, side = self:EdgeDockMatch(memberId, otherId)
            if dist and (not bestDist or dist < bestDist) then
              bestDist = dist
              bestMember = memberId
              bestParent = otherId
              bestSide = side
            end
          end
        end
      end
    end
  end
  if bestMember then
    return bestMember, bestParent, bestSide
  end
  return nil
end

function Mason:FindDockTarget(id, ignore)
  local course = { [id] = true }
  for otherId in pairs(ignore or {}) do
    course[otherId] = true
  end
  local member, parent, side = self:FindBestDock(course)
  if member then
    return parent, side, member
  end
  return nil
end

function Mason:TryDockPair(memberId, parentId, side, course)
  if not memberId or not parentId or not side then
    return false
  end
  if self:WouldDockCycle(memberId, parentId) then
    print("Mason: dock cycle")
    return false
  end
  local view = self:GetViews()[memberId]
  if not view then
    return false
  end
  local ox, oy = view.x, view.y
  view.dock = { parent = parentId, side = side }
  local nx, ny = self:DockedCenter(memberId)
  if nx == nil or ny == nil then
    return true
  end
  local dx, dy = nx - (ox or nx), ny - (oy or ny)
  if course then
    for mid in pairs(course) do
      local v = self:GetViews()[mid]
      if v and v.x ~= nil then
        self:WriteViewLayout(mid, v.x + dx, v.y + dy)
      end
    end
  else
    self:WriteViewLayout(memberId, nx, ny)
  end
  return true
end

function Mason:TryDock(id, ignore)
  local course = { [id] = true }
  for otherId in pairs(ignore or {}) do
    course[otherId] = true
  end
  local member, parent, side = self:FindBestDock(course)
  if not member then
    return false
  end
  return self:TryDockPair(member, parent, side, course)
end

function Mason:TryDockCourse(course)
  if not course then
    return false
  end
  local member, parent, side = self:FindBestDock(course)
  if not member then
    return false
  end
  return self:TryDockPair(member, parent, side, course)
end

function Mason:UndockView(id)
  local view = self:GetViews()[id]
  if view then
    view.dock = nil
  end
  if self.RefreshDockHints then
    self:RefreshDockHints()
  end
end

function Mason:ApplyShiftUndock(id)
  local kids = self:GetDockChildren(id)
  self:UndockView(id)
  for i = 1, #kids do
    self:UndockView(kids[i])
  end
end

function Mason:BeginHandleDrag(id, shift)
  if InCombatLockdown() or not self:InEditMode() then
    return
  end
  local view = self:GetViews()[id]
  if not view or not view.visible then
    return
  end
  local cx, cy = self:GetCursorUIPosition()
  self.dragId = id
  self.dragShift = not not shift
  self.dragCursorX, self.dragCursorY = cx, cy
  self.dragUndock = not not shift
  self.dragUndockApplied = false
  local move = {}
  if shift then
    move[id] = true
  elseif self:PieceInCourse(id) then
    move = self:GetCourseIds(id)
  else
    move[id] = true
  end
  self.dragMoveIds = move
  self.dragStart = {}
  for mid in pairs(move) do
    local v = self:GetViews()[mid]
    if v and v.x ~= nil then
      self.dragStart[mid] = { x = v.x, y = v.y }
    end
  end
  self:UpdateHandleDrag()
end

function Mason:UpdateHandleDrag()
  if InCombatLockdown() or not self.dragId then
    return
  end
  local cx, cy = self:GetCursorUIPosition()
  local dx = cx - (self.dragCursorX or cx)
  local dy = cy - (self.dragCursorY or cy)
  self.dragX, self.dragY = cx, cy
  if self.dragUndock and not self.dragUndockApplied and (dx * dx + dy * dy) > 0.25 then
    self:ApplyShiftUndock(self.dragId)
    self.dragUndockApplied = true
  end
  if not self.dragUndockApplied and not self.dragShift and self:PieceInCourse(self.dragId) then
    self:MoveCourse(self.dragId, dx, dy)
  else
    for id, start in pairs(self.dragStart or {}) do
      local x, y = start.x + dx, start.y + dy
      local exec = self.executors and self.executors[id]
      if exec then
        self:AnchorViewCenter(exec, id, x, y)
      else
        self:LayoutEditHandle(id, x, y)
      end
      local view = self:GetViews()[id]
      if view then
        view.x, view.y = x, y
      end
    end
  end
  local course = self.dragMoveIds
  if not course or not next(course) then
    course = self:GetCourseIds(self.dragId)
  end
  local member, parent, side = self:FindBestDock(course)
  self:RefreshDockHints(member, parent, side)
end

function Mason:CommitDrag()
  local id = self.dragId
  local move = self.dragMoveIds or {}
  self.dragId = nil
  self.dragX, self.dragY = nil, nil
  self.dragMoveIds = nil
  self.dragStart = nil
  self.dragUndock = nil
  self.dragUndockApplied = nil
  if not id then
    return
  end
  local ignore = {}
  for mid in pairs(move) do
    ignore[mid] = true
    local view = self:GetViews()[mid]
    if view and view.x ~= nil then
      local x, y = view.x, view.y
      if self.SnapToGrid then
        x, y = self:SnapToGrid(x, y, self:GetViewSize(view))
      end
      self:WriteViewLayout(mid, x, y)
    end
  end
  self:TryDockCourse(move)
  self:RefreshDockHints()
  local function place(mid)
    if InCombatLockdown() then
      self:QueueIfCombat(function()
        self:PlaceView(mid)
        self:RelayoutDocked(mid)
      end)
    else
      self:PlaceView(mid)
      self:RelayoutDocked(mid)
    end
  end
  if move[id] then
    place(id)
  end
  for mid in pairs(move) do
    if mid ~= id then
      place(mid)
    end
  end
end

function Mason:NudgeSelection(dx, dy, snap)
  if not self:InEditMode() or self.dragId then
    return
  end
  local selected = self.selectedIds or {}
  local moved = {}
  for id in pairs(selected) do
    local view = self:GetViews()[id]
    if view and view.visible and view.x ~= nil then
      if view.dock and view.dock.parent and not selected[view.dock.parent] then
        self:UndockView(id)
      end
      moved[id] = true
      for desc in pairs(self:CollectDockDescendants(id)) do
        moved[desc] = true
      end
    end
  end
  for id in pairs(moved) do
    local view = self:GetViews()[id]
    if view and view.x ~= nil then
      local x, y = view.x + dx, view.y + dy
      if snap and self.SnapToGrid then
        x, y = self:SnapToGrid(x, y, self:GetViewSize(view))
      end
      self:WriteViewLayout(id, x, y)
    end
  end
  for id in pairs(moved) do
    self:ResolveDockedPosition(id)
    if not InCombatLockdown() then
      self:PlaceView(id)
    else
      self:QueueIfCombat(function()
        self:PlaceView(id)
      end)
    end
  end
end

function Mason:AlignSelection(mode)
  if not self:InEditMode() then
    return
  end
  local anchorId = self.selectionAnchor
  local selected = self:SelectedList()
  if #selected < 2 or not anchorId or not self:IsSelected(anchorId) then
    return
  end
  local abox = self:ViewBox(anchorId)
  if not abox then
    return
  end
  for i = 1, #selected do
    local id = selected[i]
    if id ~= anchorId then
      local view = self:GetViews()[id]
      local box = self:ViewBox(id)
      if view and box then
        if view.dock and view.dock.parent then
          self:UndockView(id)
        end
        local x, y = view.x, view.y
        if mode == "left" then
          x = abox.left + box.half
        elseif mode == "right" then
          x = abox.right - box.half
        elseif mode == "top" then
          y = abox.top - box.half
        elseif mode == "bottom" then
          y = abox.bottom + box.half
        elseif mode == "hcenter" then
          x = abox.x
        elseif mode == "vcenter" then
          y = abox.y
        else
          return
        end
        if self.SnapToGrid then
          x, y = self:SnapToGrid(x, y, self:GetViewSize(view))
        end
        self:WriteViewLayout(id, x, y)
        if not InCombatLockdown() then
          self:PlaceView(id)
        else
          self:QueueIfCombat(function()
            self:PlaceView(id)
          end)
        end
      end
    end
  end
end

function Mason:ClampScale(factor)
  factor = tonumber(factor)
  if not factor then
    return nil
  end
  if factor < 0.5 then
    factor = 0.5
  elseif factor > 2 then
    factor = 2
  end
  return math.floor(factor * 10 + 0.5) / 10
end

function Mason:SetViewSize(id, px)
  local view = self:GetViews()[id]
  if not view or not view.visible then
    return false
  end
  local size = self:SyncViewSize(view, px)
  local x, y = view.x, view.y
  local function finish()
    view.x, view.y = x, y
    local exec = self.executors and self.executors[id]
    if exec then
      exec:SetScale(1)
    end
    if self.ApplyCenteredScale then
      self:ApplyCenteredScale(id)
    elseif not InCombatLockdown() then
      self:PlaceView(id)
    end
    self:RelayoutDocked(id)
  end
  if InCombatLockdown() then
    self:QueueIfCombat(function()
      self:PlaceView(id)
      finish()
    end)
    return true
  end
  self:PlaceView(id)
  finish()
  return true
end

function Mason:SetViewScale(id, factor)
  factor = self:ClampScale(factor)
  if not factor then
    return false
  end
  local s0 = (self.GetFaceNativeSize and self:GetFaceNativeSize()) or 45
  return self:SetViewSize(id, s0 * factor)
end

function Mason:SizeIds(ids, wheelDelta)
  local step = wheelDelta > 0 and 2 or -2
  for i = 1, #ids do
    local id = ids[i]
    local view = self:GetViews()[id]
    if view and view.visible then
      self:SetViewSize(id, self:GetViewSize(view) + step)
    end
  end
end

function Mason:SizeIdsToDefault(ids)
  local size = self:GetDefaultSize()
  for i = 1, #ids do
    local id = ids[i]
    local view = self:GetViews()[id]
    if view and view.visible then
      self:SetViewSize(id, size)
    end
  end
end

function Mason:NudgeSelectionToGrid(dirx, diry)
  if not self:InEditMode() or self.dragId then
    return
  end
  local ox, oy = self:GetGridOrigin()
  local selected = self.selectedIds or {}
  local written = {}
  for id in pairs(selected) do
    local view = self:GetViews()[id]
    if view and view.visible and view.x ~= nil then
      if view.dock and view.dock.parent and not selected[view.dock.parent] then
        self:UndockView(id)
      end
      local nx, ny = view.x, view.y
      if dirx ~= 0 then
        nx = self:NextGridLine(view.x, ox, dirx)
      end
      if diry ~= 0 then
        ny = self:NextGridLine(view.y, oy, diry)
      end
      self:WriteViewLayout(id, nx, ny)
      written[id] = true
    end
  end
  for id in pairs(written) do
    self:RelayoutDocked(id)
    if not InCombatLockdown() then
      self:PlaceView(id)
    else
      self:QueueIfCombat(function()
        self:PlaceView(id)
      end)
    end
  end
end

function Mason:HandleNudgeKey(key)
  if not self:InEditMode() then
    return false
  end
  if key == "ESCAPE" then
    local had = false
    for _ in pairs(self.selectedIds or {}) do
      had = true
      break
    end
    if self.ClearSelection then
      self:ClearSelection()
    end
    return had
  end
  if self.dragId then
    return false
  end
  local selected = self.selectedIds or {}
  local empty = true
  for _ in pairs(selected) do
    empty = false
    break
  end
  if empty then
    return false
  end
  local dx, dy = 0, 0
  if key == "UP" then
    dy = 1
  elseif key == "DOWN" then
    dy = -1
  elseif key == "LEFT" then
    dx = -1
  elseif key == "RIGHT" then
    dx = 1
  else
    return false
  end
  if IsShiftKeyDown() then
    self:NudgeSelectionToGrid(dx, dy)
  else
    self:NudgeSelection(dx, dy, false)
  end
  return true
end
