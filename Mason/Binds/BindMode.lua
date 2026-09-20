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

local PANEL_STRATA = "FULLSCREEN_DIALOG"
local CATCHER_LEVEL = 50
local PANEL_LEVEL = 200
local BIND_VEIL_ALPHA = 0.45
local BIND_VEIL_STRATA = "HIGH"
local BIND_VEIL_LEVEL = 20
local UNDIM_LEVEL = 30

local function SkinMasonPanel(frame)
  if not frame or not frame.SetBackdrop then
    return
  end
  frame:SetBackdrop(PANEL_BACKDROP)
  frame:SetBackdropColor(0.07, 0.07, 0.07, 0.94)
  frame:SetBackdropBorderColor(0.75, 0.62, 0.18, 1)
end

local function PanelButtons(panel)
  return { panel.doneBtn, panel.lockBtn, panel.cancelBtn, panel.kbBtn, panel.configBtn }
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
      btn:SetFrameLevel(level + 10)
    end
  end
  panel:Show()
  panel:Raise()
  if not panel.masonPrintedShowLevel then
    panel.masonPrintedShowLevel = true
    Mason:DebugPrint(string.format(
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
  self.db.profile.views = CopyValue(self.editViewsSnapshot)
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
  local function fromValue(v)
    local id = tonumber(v)
    if id and id > 0 then
      return id
    end
    return nil
  end
  local function fromTable(t, depth)
    if type(t) ~= "table" or (depth or 0) > 2 then
      return nil
    end
    local id = fromValue(t.spellID or t.spellId)
    if id then
      return id
    end
    if type(t.spellBookItemInfo) == "table" then
      id = fromValue(t.spellBookItemInfo.spellID or t.spellBookItemInfo.spellId)
      if id then
        return id
      end
    end
    return nil
  end
  local id = fromValue(f.spellID or f.spellId)
  if id then
    return id
  end
  id = fromTable(f.spellBookItemInfo, 0)
  if id then
    return id
  end
  if f.GetElementData then
    local ok, data = pcall(f.GetElementData, f)
    if ok then
      if type(data) == "table" then
        id = fromTable(data, 0) or fromTable(data.elementData, 1)
        if id then
          return id
        end
      else
        -- numeric element data is a slot/index, not a spellID
      end
    end
  end
  local bookItem = f.spellBookItemID or f.spellBookItemId
  if type(bookItem) == "table" then
    id = fromTable(bookItem, 0)
    if id then
      return id
    end
    bookItem = bookItem.spellBookItemID or bookItem.spellBookItemId
  end
  if bookItem and type(bookItem) ~= "number" and C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
    local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, bookItem)
    if ok and type(info) == "table" then
      id = fromValue(info.spellID or info.spellId)
      if id then
        return id
      end
    end
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
  if type(f.spellBookItemInfo) == "table" then
    id = tonumber(f.spellBookItemInfo.spellID or f.spellBookItemInfo.spellId)
    if id and id > 0 then
      return id
    end
  end
  return nil
end

local function MacroNameFromFrame(f)
  if not f then
    return nil
  end
  local index
  if type(f.macroName) == "string" and f.macroName ~= "" then
    return f.macroName
  end
  if f.GetElementData then
    local ok, data = pcall(f.GetElementData, f)
    if ok then
      if type(data) == "table" then
        if type(data.name) == "string" and data.name ~= "" then
          return data.name
        end
        if type(data.macroName) == "string" and data.macroName ~= "" then
          return data.macroName
        end
        if type(data.elementData) == "table" then
          if type(data.elementData.name) == "string" and data.elementData.name ~= "" then
            return data.elementData.name
          end
          index = tonumber(data.elementData.index or data.elementData.macroIndex or data.elementData.macroID)
        end
        index = index or tonumber(data.index or data.macroIndex or data.macroID or data.macroSlot)
      end
    end
  end
  if not index and f.Name and f.Name.GetText then
    local label = f.Name:GetText()
    if type(label) == "string" and label ~= "" and GetMacroIndexByName then
      local idx = GetMacroIndexByName(label)
      if idx and idx > 0 then
        return label
      end
    end
  end
  index = index or tonumber(f.macroID or f.macroIndex or f.macroSlot)
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
  if f.GetBagAndSlot then
    local ok, b, s = pcall(f.GetBagAndSlot, f)
    if ok then
      bag = bag or b
      slot = slot or s
    end
  end
  if (bag == nil or slot == nil) and f.GetItemLocation then
    local ok, loc = pcall(f.GetItemLocation, f)
    if ok and loc then
      if loc.GetBagAndSlot then
        local ok2, b, s = pcall(loc.GetBagAndSlot, loc)
        if ok2 then
          bag = bag or b
          slot = slot or s
        end
      end
      if loc.bagID ~= nil then
        bag = bag or loc.bagID
      end
      if loc.slotIndex ~= nil then
        slot = slot or loc.slotIndex
      end
    end
  end
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
  if name == "MasonBindCatcher" or name == "MasonBindPanel" or name == "MasonBindHoverGlow" or name == "MasonEditBar" or name == "MasonBindVeil" then
    return true
  end
  return false
end

local function IsHighlightOverlay(f)
  local name = FrameName(f)
  if not name then
    return false
  end
  name = string.lower(name)
  return string.find(name, "highlight", 1, true)
    or string.find(name, "overlay", 1, true)
    or string.find(name, "glow", 1, true)
    or string.find(name, "flash", 1, true)
end

local function IsCatcherOrVeil(f)
  local name = FrameName(f)
  return name == "MasonBindCatcher" or name == "MasonBindVeil" or name == "MasonBindHoverGlow"
end

local function ToyIdFromFrame(f)
  if not f then
    return nil
  end
  local id = tonumber(f.toyID or f.toyId or f.itemID or f.itemId)
  if id and id > 0 then
    if PlayerHasToy and PlayerHasToy(id) then
      return id
    end
    if C_ToyBox and C_ToyBox.GetToyFromItemID then
      local ok, toyFromItem = pcall(C_ToyBox.GetToyFromItemID, id)
      if ok and tonumber(toyFromItem) then
        return id
      end
    end
    if C_ToyBox and C_ToyBox.GetToyInfo then
      local ok, info = pcall(C_ToyBox.GetToyInfo, id)
      if ok and info then
        return id
      end
    end
  end
  if f.GetElementData then
    local ok, data = pcall(f.GetElementData, f)
    if ok and type(data) == "table" then
      id = tonumber(data.toyID or data.toyId or data.itemID or data.itemId)
      if id and id > 0 then
        return id
      end
    end
  end
  local name = FrameName(f)
  if name and string.find(string.lower(name), "toy", 1, true) then
    id = tonumber(f.itemID or f.itemId)
    if id and id > 0 then
      return id
    end
  end
  if f.GetParent then
    local p = f:GetParent()
    if p and p ~= f then
      id = tonumber(p.toyID or p.toyId or p.itemID or p.itemId)
      if id and id > 0 and PlayerHasToy and PlayerHasToy(id) then
        return id
      end
    end
  end
  return nil
end

function Mason:BindHitOnFrame(f)
  if not f or IsHighlightOverlay(f) then
    return nil
  end
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
  local toyID = ToyIdFromFrame(f)
  if toyID then
    return { kind = "toy", itemID = toyID }
  end
  local spellID = SpellIdFromFrame(f)
  if spellID then
    return { kind = "spell", spellID = spellID }
  end
  local itemID = ItemIdFromFrame(f)
  if itemID then
    return { kind = "item", itemID = itemID }
  end
  local macroName = MacroNameFromFrame(f)
  if macroName then
    return { kind = "macro", macroName = macroName }
  end
  return nil
end

function Mason:ResolveBindTargetFromFrame(f)
  while f and not IsSkipFrame(f) do
    local hit = self:BindHitOnFrame(f)
    if hit then
      return hit, f
    end
    f = f.GetParent and f:GetParent()
  end
  return nil
end

function Mason:GetBindHoverTarget()
  local foci = self:GetMouseFocusList()
  for i = 1, #foci do
    local f = foci[i]
    if f and not IsCatcherOrVeil(f) then
      local hit, owner = self:ResolveBindTargetFromFrame(f)
      if hit then
        self.bindHoverOwner = owner
        return hit
      end
    end
  end
  self.bindHoverOwner = nil
  local enter = self.bindHoverEnterFrame
  if enter and enter.IsMouseOver and enter:IsMouseOver() then
    local hit = self:BindHitOnFrame(enter)
    if hit then
      self.bindHoverOwner = enter
      return hit
    end
    local resolved = self:ResolveBindTargetFromFrame(enter)
    if resolved then
      self.bindHoverOwner = enter
      return resolved
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
  elseif target.kind == "toy" then
    piece = self:FindPieceByAction("toy", { itemID = target.itemID })
      or self:FindPieceByAction("item", { itemID = target.itemID })
    if not piece then
      local name
      if C_ToyBox and C_ToyBox.GetToyInfo then
        local _, toyName = C_ToyBox.GetToyInfo(target.itemID)
        name = toyName
      end
      if not name and C_Item and C_Item.GetItemNameByID then
        name = C_Item.GetItemNameByID(target.itemID)
      end
      piece = self:CreatePiece({
        type = "toy",
        itemID = target.itemID,
        spellName = name,
      })
    end
  elseif target.kind == "item" then
    local isToy = PlayerHasToy and PlayerHasToy(target.itemID)
    piece = self:FindPieceByAction("item", { itemID = target.itemID })
      or self:FindPieceByAction("toy", { itemID = target.itemID })
    if not piece then
      local name
      if C_Item and C_Item.GetItemNameByID then
        name = C_Item.GetItemNameByID(target.itemID)
      end
      piece = self:CreatePiece({
        type = isToy and "toy" or "item",
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
  elseif target.kind == "toy" then
    piece = self:FindPieceByAction("toy", { itemID = target.itemID })
      or self:FindPieceByAction("item", { itemID = target.itemID })
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

function Mason:EnsureBindVeil()
  if self.bindVeil then
    return self.bindVeil
  end
  if InCombatLockdown() then
    return nil
  end
  local veil = CreateFrame("Frame", "MasonBindVeil", UIParent)
  veil:SetAllPoints(UIParent)
  veil:SetFrameStrata(BIND_VEIL_STRATA)
  veil:SetFrameLevel(BIND_VEIL_LEVEL)
  veil:EnableMouse(false)
  veil:Hide()
  local dim = veil:CreateTexture(nil, "BACKGROUND")
  dim:SetAllPoints(veil)
  dim:SetColorTexture(0, 0, 0, BIND_VEIL_ALPHA)
  veil.dim = dim
  self.bindVeil = veil
  return veil
end

local function CanUndimFrame(frame)
  if not frame or type(frame) ~= "table" or not frame.GetObjectType then
    return false
  end
  local ot = frame:GetObjectType()
  if ot == "Texture" or ot == "FontString" or ot == "AnimationGroup" or ot == "Animation" then
    return false
  end
  if not frame.SetFrameLevel then
    return false
  end
  return true
end

function Mason:RaiseBindUndimFrame(frame)
  if not CanUndimFrame(frame) then
    return
  end
  self.bindUndimRestore = self.bindUndimRestore or {}
  if not self.bindUndimRestore[frame] then
    local strata, level
    if frame.GetFrameStrata then
      strata = frame:GetFrameStrata()
    end
    if frame.GetFrameLevel then
      level = frame:GetFrameLevel() or 0
    end
    self.bindUndimRestore[frame] = {
      strata = strata,
      level = level or 0,
    }
  end
  local veilLevel = (self.bindVeil and self.bindVeil:GetFrameLevel()) or BIND_VEIL_LEVEL
  local want = math.max(UNDIM_LEVEL, veilLevel + 10)
  if frame.GetFrameStrata and frame.SetFrameStrata and frame:GetFrameStrata() ~= PANEL_STRATA then
    pcall(frame.SetFrameStrata, frame, PANEL_STRATA)
  end
  local cur = (frame.GetFrameLevel and frame:GetFrameLevel()) or 0
  if cur < want and frame.SetFrameLevel then
    pcall(frame.SetFrameLevel, frame, want)
  end
  if frame.Raise then
    pcall(frame.Raise, frame)
  end
end

function Mason:RaiseBindUndimTree(frame, depth)
  -- 09aa: never tree-walk BindMode via GetChildren.
  return
end

local function EachScrollBoxFrame(box, fn)
  if not box then
    return
  end
  if box.GetFrames then
    local ok, frames = pcall(box.GetFrames, box)
    if ok and type(frames) == "table" then
      for i = 1, #frames do
        if frames[i] then
          fn(frames[i])
        end
      end
    end
  end
  if box.EnumerateFrames then
    pcall(function()
      for _, f in box:EnumerateFrames() do
        if f then
          fn(f)
        end
      end
    end)
  end
end

local function EachPoolActive(pool, fn)
  if not pool or not pool.EnumerateActive then
    return
  end
  pcall(function()
    for obj in pool:EnumerateActive() do
      if obj then
        fn(obj)
      end
    end
  end)
end

local function EachBagItemButton(frame, fn)
  if not frame then
    return
  end
  local seen = {}
  local function add(btn)
    if btn and not seen[btn] then
      seen[btn] = true
      fn(btn)
    end
  end
  if frame.Items then
    for _, btn in pairs(frame.Items) do
      add(btn)
    end
  end
  local name = FrameName(frame)
  if name then
    for i = 1, (MAX_CONTAINER_ITEMS or 36) do
      add(_G[name .. "Item" .. i])
    end
  end
  EachScrollBoxFrame(frame.ScrollBox, add)
  EachPoolActive(frame.itemButtonPool, add)
end

function Mason:KeyForIdentity(kind, identity)
  if identity == nil or identity == "" then
    return ""
  end
  local piece
  if kind == "spell" then
    piece = self:FindPieceByAction("spell", { spellID = identity })
  elseif kind == "item" then
    piece = self:FindPieceByAction("item", { itemID = identity })
      or self:FindPieceByAction("toy", { itemID = identity })
  elseif kind == "toy" then
    piece = self:FindPieceByAction("toy", { itemID = identity })
      or self:FindPieceByAction("item", { itemID = identity })
  elseif kind == "macro" then
    piece = self:FindPieceByAction("macro", { macroName = identity })
  end
  if piece and piece.key and piece.key ~= "" then
    return piece.key
  end
  return ""
end

function Mason:PaintKbOverlay(button, identityKind, identity)
  if not button then
    return
  end
  if button.masonPieceId then
    return
  end
  local name = button.GetName and button:GetName()
  if name and (string.find(name, "MasonExec_", 1, true) or string.find(name, "MasonEdit_", 1, true)) then
    return
  end
  if button.GetObjectType then
    local ot = button:GetObjectType()
    if ot == "Texture" or ot == "FontString" or ot == "AnimationGroup" or ot == "Animation" then
      return
    end
  end
  local fs = button.masonHotkey
  if not fs then
    if not button.CreateFontString or InCombatLockdown() then
      return
    end
    fs = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    local icon = button.icon or button.Icon or button
    fs:SetPoint("TOPRIGHT", icon, "TOPRIGHT", -2, -2)
    button.masonHotkey = fs
  end
  local key = self:KeyForIdentity(identityKind, identity)
  fs:SetText(key)
  if key ~= "" then
    fs:Show()
    if fs.SetAlpha then
      fs:SetAlpha(1)
    end
  else
    fs:SetText("")
  end
end

function Mason:RaiseBindKbFrame(frame)
  if not frame then
    return
  end
  pcall(function()
    self:RaiseBindUndimFrame(frame)
  end)
end

local function IsShownCell(btn)
  return btn and (not btn.IsShown or btn:IsShown())
end

local function IsSquareIconButton(btn)
  if not btn or not btn.IsObjectType then
    return false
  end
  if not (btn:IsObjectType("Button") or btn:IsObjectType("CheckButton")) then
    return false
  end
  local w = btn.GetWidth and btn:GetWidth() or 0
  local h = btn.GetHeight and btn:GetHeight() or 0
  if w > 80 and h > 0 and w > (h * 1.6) then
    return false
  end
  return true
end

local function SpellIconFromRow(btn)
  if not btn then
    return nil
  end
  if IsSquareIconButton(btn) then
    return btn
  end
  local icon = btn.Button or btn.IconButton or btn.SpellButton or btn.iconButton
  if icon and IsSquareIconButton(icon) then
    return icon
  end
  local named = btn.Icon or btn.icon
  if named and named.IsObjectType and (named:IsObjectType("Button") or named:IsObjectType("CheckButton")) then
    return named
  end
  return nil
end

local function LooksSpellCell(btn)
  if not btn then
    return false
  end
  local n = btn.GetName and btn:GetName() or ""
  if n ~= "" and string.find(n, "Paging", 1, true) then
    return false
  end
  if SpellIdFromFrame(btn) then
    return true
  end
  if btn.GetSpellID or btn.spellID or btn.spellId then
    return true
  end
  if n ~= "" and (string.find(n, "SpellBookItem", 1, true) or string.find(n, "SpellButton", 1, true)) then
    return true
  end
  return IsSquareIconButton(btn)
end

local function CollectSpellCells()
  local out, seen = {}, {}
  local function add(btn)
    if not btn or seen[btn] or not IsShownCell(btn) then
      return
    end
    local cell = SpellIconFromRow(btn) or btn
    if seen[cell] or not LooksSpellCell(cell) then
      return
    end
    local sid = SpellIdFromFrame(btn) or SpellIdFromFrame(cell)
    seen[btn] = true
    seen[cell] = true
    if sid then
      cell.masonSpellId = sid
    end
    out[#out + 1] = cell
  end
  for i = 1, 32 do
    add(_G["SpellBookItemButton" .. i])
    add(_G["SpellButton" .. i])
  end
  local ps = _G.PlayerSpellsFrame
  local sb = (ps and (ps.SpellBookFrame or ps.SpellBook)) or _G.SpellBookFrame
  local paged = sb and (sb.PagedSpellsFrame or sb.SpellBookPagedSpellsFrame)
  local holders = { paged, sb }
  for h = 1, #holders do
    local frame = holders[h]
    if frame then
      EachScrollBoxFrame(frame.ScrollBox, add)
      EachPoolActive(frame.framePool or frame.buttonPool or frame.itemButtonPool or frame.pool, add)
      local namedList = frame.spellBookItems or frame.itemButtons or frame.buttons
      if type(namedList) == "table" then
        for _, b in pairs(namedList) do
          add(b)
        end
      end
    end
  end
  return out
end

local function CollectItemCells()
  local out, seen = {}, {}
  local function add(btn)
    if btn and not seen[btn] and IsShownCell(btn) then
      seen[btn] = true
      out[#out + 1] = btn
    end
  end
  local function fromContainer(frame)
    EachBagItemButton(frame, add)
  end
  if type(ContainerFrameUtil_EnumerateContainerFrames) == "function" then
    pcall(function()
      for frame in ContainerFrameUtil_EnumerateContainerFrames() do
        fromContainer(frame)
      end
    end)
  end
  fromContainer(_G.ContainerFrameCombinedBags)
  if #out == 0 then
    local n = NUM_CONTAINER_FRAMES or 13
    for i = 1, n do
      local frame = _G["ContainerFrame" .. i]
      if frame and frame.IsShown and frame:IsShown() then
        fromContainer(frame)
      end
    end
  end
  return out
end

local function CollectToyCells()
  local out, seen = {}, {}
  local function add(btn)
    if not btn or seen[btn] or not IsShownCell(btn) then
      return
    end
    seen[btn] = true
    out[#out + 1] = btn
  end
  local box = _G.ToyBox
  if box then
    EachScrollBoxFrame(box.ScrollBox, add)
    EachPoolActive(box.spellButtonPool or box.buttonPool or box.pool, add)
  end
  for i = 1, 18 do
    add(_G["ToySpellButton" .. i])
  end
  return out
end

local function CollectMacroCells()
  local out = {}
  local cap = 40
  local mf = _G.MacroFrame
  local sel = mf and mf.MacroSelector
  if sel and sel.ScrollBox then
    EachScrollBoxFrame(sel.ScrollBox, function(btn)
      if #out >= cap then
        return
      end
      if IsShownCell(btn) then
        out[#out + 1] = btn
      end
    end)
  end
  if #out > 0 then
    return out
  end
  local maxMacro = (MAX_ACCOUNT_MACROS or 120) + (MAX_CHARACTER_MACROS or 18)
  for i = 1, maxMacro do
    if #out >= cap then
      break
    end
    local b = _G["MacroButton" .. i]
    if IsShownCell(b) then
      out[#out + 1] = b
    end
  end
  return out
end

local KB_ADAPTERS = {
  spell = {
    name = "spell",
    buttons = CollectSpellCells,
    identity = function(button)
      if not button then
        return nil
      end
      return SpellIdFromFrame(button) or button.masonSpellId
    end,
  },
  item = {
    name = "item",
    buttons = CollectItemCells,
    identity = function(button)
      return ItemIdFromFrame(button)
    end,
  },
  toy = {
    name = "toy",
    buttons = CollectToyCells,
    identity = function(button)
      if not button then
        return nil
      end
      local id = tonumber(button.itemID or button.itemId or button.toyID or button.toyId)
      if id and id > 0 then
        return id
      end
      return ToyIdFromFrame(button)
    end,
  },
  macro = {
    name = "macro",
    buttons = CollectMacroCells,
    identity = function(button)
      return MacroNameFromFrame(button)
    end,
  },
}

function Mason:ProbeKbIdentityOnce(kind, button, id)
  if kind ~= "spell" and kind ~= "toy" then
    return
  end
  if not self.bindMode then
    return
  end
  self.masonKbProbe = self.masonKbProbe or {}
  if self.masonKbProbe[kind] then
    return
  end
  self.masonKbProbe[kind] = true
  if not (C_Timer and C_Timer.After) then
    return
  end
  C_Timer.After(0, function()
    local a = KB_ADAPTERS[kind]
    local live = id
    if a and button then
      live = a.identity(button)
    end
    if live then
      return
    end
    local name = button and button.GetName and button:GetName()
    print("Mason: id", kind, name, live)
  end)
end

function Mason:PaintKbAdapter(kind)
  local a = KB_ADAPTERS[kind]
  if not a then
    return
  end
  local buttons = a.buttons()
  local painted = 0
  local probeBtn
  for i = 1, #buttons do
    local btn = buttons[i]
    local id = a.identity(btn)
    if self.bindMode then
      self:AttachKbHover(btn, a.name, id)
    end
    if id then
      painted = painted + 1
      self:PaintKbOverlay(btn, a.name, id)
    elseif not probeBtn then
      probeBtn = btn
    end
  end
  if painted == 0 and probeBtn then
    self:ProbeKbIdentityOnce(a.name, probeBtn, nil)
  end
end

function Mason:AttachKbHover(button, kind, id)
  if not button or not CanUndimFrame(button) then
    return
  end
  button.masonKbKind = kind
  button.masonKbId = id
  if button.masonKbHook or button.masonKbHoverHook or not button.HookScript then
    return
  end
  button.masonKbHook = true
  button.masonKbHoverHook = true
  button:HookScript("OnEnter", function(selfBtn)
    if Mason.bindMode then
      Mason:ShowBindHoverOnFrame(selfBtn)
    end
  end)
  button:HookScript("OnLeave", function(selfBtn)
    if Mason.bindHoverEnterFrame == selfBtn then
      Mason.bindHoverEnterFrame = nil
      Mason:HideBindHoverHighlight()
    end
  end)
end

function Mason:CountBagItemButtons(frame)
  local n = 0
  EachBagItemButton(frame, function(btn)
    if CanUndimFrame(btn) then
      n = n + 1
    end
  end)
  return n
end

function Mason:RaiseBindItemButtons(frame)
  if not frame then
    return
  end
  EachBagItemButton(frame, function(btn)
    if not btn then
      return
    end
    -- 09aa: never raise item buttons (Show→raise overflow).
    local id = ItemIdFromFrame(btn)
    self:AttachKbHover(btn, "item", id)
    if id then
      self:PaintKbOverlay(btn, "item", id)
    end
  end)
end

function Mason:HookBagSearchBox(frame)
  if not frame then
    return
  end
  local box = frame.SearchBox or frame.searchBox or frame.BagItemSearchBox
  if not box and FrameName(frame) then
    box = _G[FrameName(frame) .. "SearchBox"]
  end
  if not box or box.masonBindSearchHook then
    return
  end
  box.masonBindSearchHook = true
  if box.HookScript then
    box:HookScript("OnTextChanged", function()
      if Mason:KbWantsRaise() then
        Mason:RaiseBindBagFrames()
      end
    end)
  end
end

function Mason:RaiseBindBagFrames()
  local function raiseBag(frame, doPrint)
    if not frame then
      return
    end
    pcall(function()
    -- 09aa: raise top-level bag frame only; never HookBindUndimShow / item raise.
    self:RaiseBindUndimFrame(frame)
    self:HookBagSearchBox(frame)
    self:RaiseBindItemButtons(frame)
    self:HookBagItemParents(frame)
    if frame.ScrollBox then
      if not frame.ScrollBox.masonBagUpdateHook and frame.ScrollBox.Update then
        frame.ScrollBox.masonBagUpdateHook = true
        hooksecurefunc(frame.ScrollBox, "Update", function()
          if Mason:KbWantsRaise() then
            Mason:ScheduleBagFollowup()
          end
        end)
      end
    end
    if doPrint then
      self:DebugPrint(string.format(
        "Mason: bags raise %s buttons=%d",
        FrameName(frame) or "?",
        self:CountBagItemButtons(frame)
      ))
    end
    end)
  end
  local combined = _G.ContainerFrameCombinedBags
  raiseBag(combined, combined ~= nil)
  local n = NUM_CONTAINER_FRAMES or 13
  for i = 1, n do
    local frame = _G["ContainerFrame" .. i]
    local shown = frame and frame.IsShown and frame:IsShown()
    raiseBag(frame, shown and not combined)
  end
end

function Mason:KbWantsRaise()
  return not not (self.bindMode or self.kbWantsRaise)
end

function Mason:ReassertBindCatcher()
  if not self.bindMode then
    return
  end
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
  if self.ShowBindVeil then
    self:ShowBindVeil()
  end
end

function Mason:GetSpellBookRoot()
  if self.masonSpellBookFrame then
    return self.masonSpellBookFrame
  end
  local ps = _G.PlayerSpellsFrame
  if ps then
    local sb = ps.SpellBookFrame or ps.SpellBook or ps.Book
    if sb then
      self.masonSpellBookFrame = sb
      return sb
    end
    self.masonSpellBookFrame = ps
    return ps
  end
  return _G.SpellBookFrame
end

function Mason:RememberSpellBookFrame(frame)
  if not frame or not frame.GetObjectType then
    return
  end
  local ot = frame:GetObjectType()
  if ot == "Texture" or ot == "FontString" then
    return
  end
  local name = frame.GetName and frame:GetName() or ""
  if name == "PlayerSpellsFrame" or name == "SpellBookFrame" or string.find(name, "SpellBook", 1, true) then
    if name == "PlayerSpellsFrame" then
      local sb = frame.SpellBookFrame or frame.SpellBook
      self.masonSpellBookFrame = sb or frame
    else
      self.masonSpellBookFrame = frame
    end
  end
end

function Mason:PaintScrollBoxHotkeys(frame, depth)
  return
end

function Mason:CountAllBagButtons()
  local n = self:CountBagItemButtons(_G.ContainerFrameCombinedBags)
  if n > 0 then
    return n
  end
  local max = NUM_CONTAINER_FRAMES or 13
  for i = 1, max do
    n = n + self:CountBagItemButtons(_G["ContainerFrame" .. i])
  end
  return n
end

function Mason:HookBagItemParents(frame)
  if not frame then
    return
  end
  local function hookParent(parent)
    if parent and parent.HookScript then
      self:HookLateFrameOnShow(parent, "bags")
    end
  end
  hookParent(frame.ScrollBox)
  hookParent(frame.Items)
  hookParent(frame.ItemHolder)
  hookParent(frame.Contents)
  if frame.ScrollBox and not frame.ScrollBox.masonBagAcquireHook then
    frame.ScrollBox.masonBagAcquireHook = true
    if frame.ScrollBox.RegisterCallback then
      pcall(frame.ScrollBox.RegisterCallback, frame.ScrollBox, "OnAcquiredFrame", function(_, btn)
        local id = ItemIdFromFrame(btn)
        if id and Mason.PaintKbOverlay then
          Mason:PaintKbOverlay(btn, "item", id)
        end
        if Mason.bindMode and Mason.AttachBagButtonHover then
          Mason:AttachBagButtonHover(btn)
        end
      end)
    end
  end
end

function Mason:ScheduleBagFillWatch()
  if self.masonBagFillWatch or not (C_Timer and C_Timer.After) then
    return
  end
  self.masonBagFillWatch = true
  self.masonBagFillStart = (GetTime and GetTime()) or 0
  local delays = { 0.1, 0.2, 0.35, 0.5, 0.75, 1.0 }
  for i = 1, #delays do
    local d = delays[i]
    C_Timer.After(d, function()
      if not Mason:KbWantsRaise() then
        Mason.masonBagFillWatch = nil
        return
      end
      Mason:PassBagsRaiseAndPaint(true)
      local n = Mason:CountAllBagButtons()
      local elapsed = ((GetTime and GetTime()) or 0) - (Mason.masonBagFillStart or 0)
      if n > 0 or elapsed >= 1 then
        Mason.masonBagFillWatch = nil
      end
    end)
  end
end

local function BindHoverGlowFrame(frame)
  if not frame then
    return nil
  end
  local w = frame.GetWidth and frame:GetWidth() or 0
  local h = frame.GetHeight and frame:GetHeight() or 0
  if w > 0 and h > 0 and w > (h * 1.6) and w > 64 then
    local icon = frame.IconButton or frame.iconButton or frame.SpellButton or frame.Button
    if icon and icon.GetObjectType and icon:GetObjectType() ~= "Texture" then
      return icon
    end
    local named = frame.Icon or frame.icon
    if named and named.GetObjectType then
      local ot = named:GetObjectType()
      if ot == "Button" or ot == "CheckButton" or ot == "Frame" then
        return named
      end
    end
  end
  return frame
end

function Mason:ShowBindHoverOnFrame(frame)
  if not self.bindMode or not frame then
    return
  end
  self.bindHoverEnterFrame = frame
  local glow = self:EnsureBindHoverHighlight()
  if not glow then
    return
  end
  glow:ClearAllPoints()
  local glowFrame = BindHoverGlowFrame(frame) or frame
  glow:SetPoint("TOPLEFT", glowFrame, "TOPLEFT", -2, 2)
  glow:SetPoint("BOTTOMRIGHT", glowFrame, "BOTTOMRIGHT", 2, -2)
  glow:Show()
end

function Mason:AttachBagButtonHover(btn)
  self:AttachKbHover(btn, "item", ItemIdFromFrame(btn))
end

function Mason:InstallBagHoverMixins()
  if self.masonBagHoverMixins then
    return
  end
  self.masonBagHoverMixins = true
  local function hookEnter(mixin)
    if not mixin then
      return
    end
    if mixin.OnEnter then
      hooksecurefunc(mixin, "OnEnter", function(btn)
        if not Mason.bindMode or not btn then
          return
        end
        if Mason.AttachKbHover then
          Mason:AttachKbHover(btn, "item", ItemIdFromFrame(btn))
        end
        Mason:ShowBindHoverOnFrame(btn)
      end)
    end
    if mixin.OnLeave then
      hooksecurefunc(mixin, "OnLeave", function(btn)
        if Mason.bindHoverEnterFrame == btn then
          Mason.bindHoverEnterFrame = nil
          Mason:HideBindHoverHighlight()
        end
      end)
    end
  end
  hookEnter(_G.ContainerFrameItemButtonMixin)
  hookEnter(_G.ContainerFrameItemElementMixin)
end

function Mason:AttachKbBagHover()
  if not self.bindMode then
    return
  end
  if self.InstallBagHoverMixins then
    pcall(self.InstallBagHoverMixins, self)
  end
  if self.ReassertBindCatcher then
    pcall(self.ReassertBindCatcher, self)
  end
  local a = KB_ADAPTERS.item
  local buttons = a.buttons()
  for i = 1, #buttons do
    local btn = buttons[i]
    local id = a.identity(btn)
    -- 09aa: never raise item buttons.
    self:AttachKbHover(btn, "item", id)
    if id then
      self:PaintKbOverlay(btn, "item", id)
    end
  end
end

function Mason:PassBagsRaiseAndPaint(fromRetry)
  if self.PaintBagHotkeys then
    self:PaintBagHotkeys()
  end
  if self.bindMode then
    local n = self:CountAllBagButtons()
    if n == 0 then
      self.masonBagNeedButtons = true
      self:ScheduleBagFillWatch()
    else
      self.masonBagNeedButtons = nil
      self.masonBagFillWatch = nil
      if self.AttachKbBagHover then
        pcall(self.AttachKbBagHover, self)
      end
    end
  end
end

function Mason:ScheduleBagFollowup()
  if self.masonBagFollowup then
    return
  end
  self.masonBagFollowup = true
  if not (C_Timer and C_Timer.After) then
    self.masonBagFollowup = nil
    return
  end
  C_Timer.After(0.1, function()
    Mason.masonBagFollowup = nil
    Mason:PassBagsRaiseAndPaint(true)
  end)
end

function Mason:OnBagsOpened()
  if self.PassBagsRaiseAndPaint then
    pcall(self.PassBagsRaiseAndPaint, self)
  elseif self.RaiseBindBagFrames then
    pcall(self.RaiseBindBagFrames, self)
  end
  if self.bindMode and self.AttachKbBagHover then
    pcall(self.AttachKbBagHover, self)
  end
end

function Mason:CountMacroButtons()
  local n = 0
  local mf = _G.MacroFrame
  local sel = mf and mf.MacroSelector
  if sel and sel.ScrollBox then
    EachScrollBoxFrame(sel.ScrollBox, function(btn)
      if CanUndimFrame(btn) then
        n = n + 1
      end
    end)
  end
  if n > 0 then
    return n
  end
  local maxMacro = (MAX_ACCOUNT_MACROS or 120) + (MAX_CHARACTER_MACROS or 18)
  for i = 1, maxMacro do
    local b = _G["MacroButton" .. i]
    if b and b.IsShown and b:IsShown() then
      n = n + 1
    end
  end
  return n
end

function Mason:RefreshMacroSelector()
  local mf = _G.MacroFrame
  if not mf then
    return
  end
  if type(_G.MacroFrame_Update) == "function" then
    pcall(_G.MacroFrame_Update)
  elseif mf.Update then
    pcall(mf.Update, mf)
  end
  local sel = mf.MacroSelector
  if not sel then
    return
  end
  if sel.Update then
    pcall(sel.Update, sel)
  end
  if sel.RefreshScrollBox then
    pcall(sel.RefreshScrollBox, sel)
  end
  if sel.ScrollBox then
    if sel.ScrollBox.Rebuild then
      pcall(sel.ScrollBox.Rebuild, sel.ScrollBox)
    end
    if sel.ScrollBox.Update then
      pcall(sel.ScrollBox.Update, sel.ScrollBox)
    end
  end
end

function Mason:PassMacroRaiseAndPaint()
  self:HookMacroSelectorFillSignals()
  if self.KbWantsRaise and self:KbWantsRaise() then
    self:RefreshMacroSelector()
    self:RefreshMacroSelectorIfEmpty()
    self:RaiseBindMacroFrames()
  end
  self:PaintMacroHotkeys()
  local n = self:CountMacroButtons()
  if n == 0 then
    self.masonMacroNeedButtons = true
  else
    self.masonMacroNeedButtons = nil
    if self.KbWantsRaise and self:KbWantsRaise() then
      if self.ReassertBindCatcher then
        pcall(self.ReassertBindCatcher, self)
      end
      self:RaiseBindMacroFrames()
    end
  end
  local mf = _G.MacroFrame
  local shown = mf and mf.IsShown and mf:IsShown()
  if self.KbWantsRaise and self:KbWantsRaise() then
    self:DebugPrint(string.format(
      "Mason: macro raise shown=%s buttons=%d",
      tostring(not not shown),
      n
    ))
  end
  return n
end

function Mason:PaintMacroHotkeys()
  local a = KB_ADAPTERS.macro
  local buttons = a.buttons()
  for i = 1, #buttons do
    local btn = buttons[i]
    local id = a.identity(btn)
    if id then
      self:PaintKbOverlay(btn, "macro", id)
    end
    if self.bindMode then
      self:AttachKbHover(btn, "macro", id)
    end
  end
end

function Mason:HookMacroSelectorFillSignals()
  local mf = _G.MacroFrame
  if not mf then
    return
  end
  local sel = mf.MacroSelector
  if sel and not sel.masonFillSignals then
    sel.masonFillSignals = true
    if sel.SetTab then
      hooksecurefunc(sel, "SetTab", function()
        Mason:PaintMacroHotkeys()
        if Mason.KbWantsRaise and Mason:KbWantsRaise() then
          Mason:RaiseBindMacroFrames()
        end
      end)
    end
    if sel.TabSystem and sel.TabSystem.SetTab then
      hooksecurefunc(sel.TabSystem, "SetTab", function()
        Mason:PaintMacroHotkeys()
        if Mason.KbWantsRaise and Mason:KbWantsRaise() then
          Mason:RaiseBindMacroFrames()
        end
      end)
    end
  end
  if sel.ScrollBox and not sel.ScrollBox.masonHotkeyRecycle then
    sel.ScrollBox.masonHotkeyRecycle = true
    if sel.ScrollBox.RegisterCallback then
      pcall(sel.ScrollBox.RegisterCallback, sel.ScrollBox, "OnAcquiredFrame", function(_, btn)
        if Mason.PaintKbOverlay then
          local id = MacroNameFromFrame(btn)
          Mason:PaintKbOverlay(btn, "macro", id)
          if Mason.bindMode then
            Mason:AttachKbHover(btn, "macro", id)
          end
        end
      end)
      pcall(sel.ScrollBox.RegisterCallback, sel.ScrollBox, "OnScroll", function()
        Mason:PaintMacroHotkeys()
      end)
    end
    if sel.ScrollBox.HookScript then
      pcall(function()
        sel.ScrollBox:HookScript("OnMouseWheel", function()
          Mason:PaintMacroHotkeys()
        end)
      end)
    end
  end
  if not self.masonMacroTabHook then
    self.masonMacroTabHook = true
    if type(_G.MacroFrame_SetAccountMacros) == "function" then
      hooksecurefunc("MacroFrame_SetAccountMacros", function()
        Mason:PaintMacroHotkeys()
      end)
    end
    if type(_G.MacroFrame_SetCharacterMacros) == "function" then
      hooksecurefunc("MacroFrame_SetCharacterMacros", function()
        Mason:PaintMacroHotkeys()
      end)
    end
  end
end

function Mason:ScheduleMacroFollowup()
  if self.masonMacroFollowup or not (C_Timer and C_Timer.After) then
    return
  end
  self.masonMacroFollowup = true
  local t0 = (GetTime and GetTime()) or 0
  local delays = { 0, 0.15, 0.4, 0.8, 1.2, 1.6, 2.0 }
  for i = 1, #delays do
    local d = delays[i]
    C_Timer.After(d, function()
      local n = Mason:PassMacroRaiseAndPaint()
      local elapsed = ((GetTime and GetTime()) or 0) - t0
      if (n and n > 0) or elapsed >= 2 then
        Mason.masonMacroFollowup = nil
      end
    end)
  end
end

function Mason:RaiseBindSpellBook()
  if not (self.KbWantsRaise and self:KbWantsRaise()) then
    return
  end
  if self.ReassertBindCatcher then
    pcall(self.ReassertBindCatcher, self)
  end
  local ps = _G.PlayerSpellsFrame
  self:RaiseBindKbFrame(ps)
  self:RaiseBindKbFrame(ps and (ps.SpellBookFrame or ps.SpellBook))
  self:RaiseBindKbFrame(self.masonSpellBookFrame)
  self:RaiseBindKbFrame(_G.SpellBookFrame)
end

function Mason:OnMacroOpened()
  if self.PassMacroRaiseAndPaint then
    pcall(self.PassMacroRaiseAndPaint, self)
  end
  if self.ScheduleMacroFollowup then
    pcall(self.ScheduleMacroFollowup, self)
  end
end

function Mason:HookLateFrameOnShow(frame, kind)
  if not frame or frame.masonLateShowHook then
    return
  end
  frame.masonLateShowHook = true
  if frame.HookScript then
    frame:HookScript("OnShow", function()
      if kind == "bags" then
        Mason:OnBagsOpened()
      elseif kind == "macro" then
        Mason:OnMacroOpened()
      elseif kind == "toy" then
        if Mason.KbWantsRaise and Mason:KbWantsRaise() and Mason.RaiseBindToyFrames then
          pcall(Mason.RaiseBindToyFrames, Mason)
        end
        if Mason.RefreshBlizzardHotkeys then
          pcall(Mason.RefreshBlizzardHotkeys, Mason)
        end
      elseif kind == "spell" then
        if Mason.RaiseBindSpellBook then
          pcall(Mason.RaiseBindSpellBook, Mason)
        end
        if Mason.ScheduleSpellbookHotkeys then
          Mason:ScheduleSpellbookHotkeys()
        elseif Mason.RefreshBlizzardHotkeys then
          Mason:RefreshBlizzardHotkeys()
        end
      end
    end)
  end
end

function Mason:InstallBindBagHooks()
  if self.InstallBagHoverMixins then
    pcall(self.InstallBagHoverMixins, self)
  end
  if self.masonBindBagHooks then
    self:HookLateFrameOnShow(_G.ContainerFrameCombinedBags, "bags")
    self:HookLateFrameOnShow(_G.MacroFrame, "macro")
    if _G.MacroFrame and _G.MacroFrame.MacroSelector then
      self:HookLateFrameOnShow(_G.MacroFrame.MacroSelector, "macro")
    end
    self:HookLateFrameOnShow(_G.ToyBox, "toy")
    self:HookLateFrameOnShow(_G.PlayerSpellsFrame, "spell")
    local sb = _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.SpellBookFrame
    self:HookLateFrameOnShow(sb, "spell")
    self:HookLateFrameOnShow(_G.SpellBookFrame, "spell")
    return
  end
  self.masonBindBagHooks = true
  if ContainerFrameMixin and ContainerFrameMixin.OnShow then
    hooksecurefunc(ContainerFrameMixin, "OnShow", function()
      Mason:OnBagsOpened()
    end)
  end
  if ContainerFrameCombinedBagsMixin and ContainerFrameCombinedBagsMixin.OnShow then
    hooksecurefunc(ContainerFrameCombinedBagsMixin, "OnShow", function()
      Mason:OnBagsOpened()
    end)
  end
  if type(_G.OpenAllBags) == "function" then
    hooksecurefunc("OpenAllBags", function()
      Mason:OnBagsOpened()
    end)
  end
  if type(_G.ToggleAllBags) == "function" then
    hooksecurefunc("ToggleAllBags", function()
      Mason:OnBagsOpened()
    end)
  end
  if type(_G.ToggleBackpack) == "function" then
    hooksecurefunc("ToggleBackpack", function()
      Mason:OnBagsOpened()
    end)
  end
  if type(_G.ToggleBag) == "function" then
    hooksecurefunc("ToggleBag", function()
      Mason:OnBagsOpened()
    end)
  end
  if type(_G.OpenBag) == "function" then
    hooksecurefunc("OpenBag", function()
      Mason:OnBagsOpened()
    end)
  end
  if type(_G.ShowMacroFrame) == "function" then
    hooksecurefunc("ShowMacroFrame", function()
      Mason:OnMacroOpened()
    end)
  end
  if MacroFrameMixin and MacroFrameMixin.OnShow then
    hooksecurefunc(MacroFrameMixin, "OnShow", function()
      Mason:OnMacroOpened()
    end)
  end
  if PlayerSpellsFrameMixin and PlayerSpellsFrameMixin.OnShow then
    hooksecurefunc(PlayerSpellsFrameMixin, "OnShow", function()
      if Mason.RaiseBindSpellBook then
        pcall(Mason.RaiseBindSpellBook, Mason)
      end
      if Mason.ScheduleSpellbookHotkeys then
        pcall(Mason.ScheduleSpellbookHotkeys, Mason)
      end
    end)
  end
  if type(_G.TogglePlayerSpells) == "function" then
    hooksecurefunc("TogglePlayerSpells", function()
      if Mason.RaiseBindSpellBook then
        pcall(Mason.RaiseBindSpellBook, Mason)
      end
      if Mason.ScheduleSpellbookHotkeys then
        pcall(Mason.ScheduleSpellbookHotkeys, Mason)
      end
    end)
  end
  if type(_G.ToggleSpellBook) == "function" then
    hooksecurefunc("ToggleSpellBook", function()
      if Mason.RaiseBindSpellBook then
        pcall(Mason.RaiseBindSpellBook, Mason)
      end
      if Mason.ScheduleSpellbookHotkeys then
        pcall(Mason.ScheduleSpellbookHotkeys, Mason)
      end
    end)
  end
  if type(_G.ToggleCollectionsJournal) == "function" then
    hooksecurefunc("ToggleCollectionsJournal", function()
      if Mason.KbWantsRaise and Mason:KbWantsRaise() and Mason.RaiseBindToyFrames then
        pcall(Mason.RaiseBindToyFrames, Mason)
      end
      if Mason.RequestBlizzardHotkeys then
        pcall(Mason.RequestBlizzardHotkeys, Mason)
      end
    end)
  end
  local function hookMixinOnShow(mixin, kind)
    if mixin and mixin.OnShow then
      hooksecurefunc(mixin, "OnShow", function(self)
        if kind == "paint" then
          local cell = SpellIconFromRow(self) or self
          local sid = SpellIdFromFrame(self) or SpellIdFromFrame(cell)
          if sid then
            Mason:PaintKbOverlay(cell, "spell", sid)
          else
            local tid = ToyIdFromFrame(self)
            if tid then
              Mason:PaintKbOverlay(cell, "toy", tid)
            end
          end
        else
          Mason:RequestBlizzardHotkeys()
        end
      end)
    end
  end
  hookMixinOnShow(SpellBookItemMixin, "paint")
  hookMixinOnShow(SpellBookItemButtonMixin, "paint")
  hookMixinOnShow(ToySpellButtonMixin, "paint")
  hookMixinOnShow(SpellBookFrameMixin, "book")
  if type(_G.ShowUIPanel) == "function" then
    hooksecurefunc("ShowUIPanel", function(frame)
      if not frame then
        return
      end
      local name = frame.GetName and frame:GetName()
      if frame == _G.MacroFrame or name == "MacroFrame" then
        if Mason.OnMacroOpened then
          pcall(Mason.OnMacroOpened, Mason)
        end
      elseif frame == _G.ToyBox or name == "ToyBox" or frame == _G.CollectionsJournal or name == "CollectionsJournal" then
        if Mason.KbWantsRaise and Mason:KbWantsRaise() and Mason.RaiseBindToyFrames then
          pcall(Mason.RaiseBindToyFrames, Mason)
        end
        if Mason.RequestBlizzardHotkeys then
          pcall(Mason.RequestBlizzardHotkeys, Mason)
        end
      elseif name == "PlayerSpellsFrame" or name == "SpellBookFrame" then
        if Mason.RememberSpellBookFrame then
          pcall(Mason.RememberSpellBookFrame, Mason, frame)
        end
        if Mason.RaiseBindSpellBook then
          pcall(Mason.RaiseBindSpellBook, Mason)
        end
        if Mason.ScheduleSpellbookHotkeys then
          pcall(Mason.ScheduleSpellbookHotkeys, Mason)
        end
      elseif frame == _G.ContainerFrameCombinedBags or name == "ContainerFrameCombinedBags" then
        if Mason.OnBagsOpened then
          pcall(Mason.OnBagsOpened, Mason)
        end
      end
    end)
  end
  self:HookLateFrameOnShow(_G.ContainerFrameCombinedBags, "bags")
  self:HookLateFrameOnShow(_G.MacroFrame, "macro")
  self:HookLateFrameOnShow(_G.ToyBox, "toy")
  self:HookLateFrameOnShow(_G.PlayerSpellsFrame, "spell")
  self:HookLateFrameOnShow(_G.SpellBookFrame, "spell")
end

function Mason:RaiseBindMacroFrames()
  local mf = _G.MacroFrame
  self:RaiseBindKbFrame(mf)
  self:RaiseBindKbFrame(_G.MacroFrameScrollFrame)
  self:RaiseBindKbFrame(_G.MacroButtonScrollFrame)
  if mf then
    local sel = mf.MacroSelector
    self:RaiseBindKbFrame(sel)
    if sel then
      self:RaiseBindKbFrame(sel.ScrollBox)
      self:RaiseBindKbFrame(sel.ScrollBar)
      EachScrollBoxFrame(sel.ScrollBox, function(btn)
        Mason:RaiseBindKbFrame(btn)
      end)
      self:HookMacroKbShow(sel)
      if sel.ScrollBox then
        self:HookMacroKbShow(sel.ScrollBox)
      end
    end
    self:HookMacroKbShow(mf)
  end
  local maxMacro = (MAX_ACCOUNT_MACROS or 120) + (MAX_CHARACTER_MACROS or 18)
  for i = 1, maxMacro do
    self:RaiseBindKbFrame(_G["MacroButton" .. i])
  end
end

function Mason:HookMacroKbShow(frame)
  if not CanUndimFrame(frame) or frame.masonKbShowAlways then
    return
  end
  frame.masonKbShowAlways = true
  if frame.HookScript then
    frame:HookScript("OnShow", function()
      Mason:OnMacroOpened()
    end)
  end
end

function Mason:RaiseBindToyFrames()
  local box = _G.ToyBox
  pcall(function()
    self:RaiseBindUndimFrame(box)
  end)
  for i = 1, 18 do
    pcall(function()
      self:RaiseBindUndimFrame(_G["ToySpellButton" .. i])
    end)
  end
  local a = KB_ADAPTERS.toy
  local buttons = a.buttons()
  for i = 1, #buttons do
    local btn = buttons[i]
    self:RaiseBindUndimFrame(btn)
    local id = a.identity(btn)
    if self.bindMode then
      self:AttachKbHover(btn, "toy", id)
    end
    if id then
      self:PaintKbOverlay(btn, "toy", id)
    end
  end
end

function Mason:HookToyKbShow(frame)
  if not frame or frame.masonKbToyShowAlways then
    return
  end
  frame.masonKbToyShowAlways = true
  if frame.HookScript then
    frame:HookScript("OnShow", function()
      if Mason.bindMode then
        Mason:RaiseBindToyFrames()
      end
      if Mason.RefreshBlizzardHotkeys then
        Mason:RefreshBlizzardHotkeys()
      end
    end)
  end
end

function Mason:RefreshMacroSelectorIfEmpty()
  local mf = _G.MacroFrame
  if not mf or not mf.IsShown or not mf:IsShown() then
    return
  end
  local function hasButtons()
    local maxMacro = (MAX_ACCOUNT_MACROS or 120) + (MAX_CHARACTER_MACROS or 18)
    for i = 1, maxMacro do
      local b = _G["MacroButton" .. i]
      if b and b.IsShown and b:IsShown() then
        return true
      end
    end
    local sel = mf.MacroSelector
    if sel and sel.ScrollBox and sel.ScrollBox.GetFrames then
      local frames = sel.ScrollBox:GetFrames()
      if type(frames) == "table" then
        for i = 1, #frames do
          if frames[i] and frames[i].IsShown and frames[i]:IsShown() then
            return true
          end
        end
      end
    end
    return false
  end
  if hasButtons() then
    return
  end
  if type(_G.MacroFrame_Update) == "function" then
    pcall(_G.MacroFrame_Update)
  elseif mf.Update then
    pcall(mf.Update, mf)
  else
    local sel = mf.MacroSelector
    if sel then
      if sel.Update then
        pcall(sel.Update, sel)
      end
      if sel.RefreshScrollBox then
        pcall(sel.RefreshScrollBox, sel)
      end
      if sel.ScrollBox and sel.ScrollBox.Rebuild then
        pcall(sel.ScrollBox.Rebuild, sel.ScrollBox)
      end
    end
  end
end

function Mason:HookBindUndimShow(frame)
  -- 09aa: never raise from bag/frame Show (breaks Show→raise reentry).
  return
end

function Mason:RaiseBindUndimmedFrames()
  if self.raisingUndim then
    return
  end
  self.raisingUndim = true
  local function raise(frame)
    self:RaiseBindUndimFrame(frame)
  end
  pcall(function()
    -- 09aa: raise only named top-level frames once.
    raise(_G.PlayerSpellsFrame)
    raise(_G.MacroFrame)
    raise(_G.ContainerFrameCombinedBags or _G.ContainerFrame1)
    raise(_G.CollectionsJournal)
    self:InstallBindBagHooks()
    if self.bindPanel then
      self.bindUndimRestore = self.bindUndimRestore or {}
      if not self.bindUndimRestore[self.bindPanel] then
        self.bindUndimRestore[self.bindPanel] = {
          strata = self.bindPanel:GetFrameStrata(),
          level = self.bindPanel:GetFrameLevel() or PANEL_LEVEL,
        }
      end
      self.bindPanel:SetFrameStrata(PANEL_STRATA)
      self.bindPanel:SetFrameLevel(PANEL_LEVEL)
    end
    for id, exec in pairs(self.executors or {}) do
      if exec and exec.IsShown and exec:IsShown() then
        raise(exec)
        local host = self.scaleHosts and self.scaleHosts[id]
        if host then
          raise(host)
        end
        local handle = self.editHandles and self.editHandles[id]
        if handle then
          raise(handle)
        end
      end
    end
  end)
  self.raisingUndim = nil
end

function Mason:RestoreBindUndimmedFrames()
  local saved = self.bindUndimRestore
  if not saved then
    return
  end
  local function restoreOne(frame)
    local info = frame and saved[frame]
    if not info or not frame then
      return
    end
    if frame.SetFrameStrata then
      pcall(frame.SetFrameStrata, frame, info.strata or "MEDIUM")
    end
    if frame.SetFrameLevel then
      pcall(frame.SetFrameLevel, frame, info.level or 0)
    end
  end
  for frame in pairs(saved) do
    restoreOne(frame)
  end
  restoreOne(_G.ContainerFrameCombinedBags)
  restoreOne(_G.BagsBar)
  restoreOne(_G.MainMenuBarBackpackButton)
  local n = NUM_CONTAINER_FRAMES or 13
  for i = 1, n do
    local frame = _G["ContainerFrame" .. i]
    restoreOne(frame)
    if frame then
      if frame.Items then
        for _, btn in pairs(frame.Items) do
          restoreOne(btn)
        end
      end
      EachScrollBoxFrame(frame.ScrollBox, restoreOne)
    end
  end
  local bags = _G.ContainerFrameCombinedBags
  if bags then
    if bags.Items then
      for _, btn in pairs(bags.Items) do
        restoreOne(btn)
      end
    end
    EachScrollBoxFrame(bags.ScrollBox, restoreOne)
  end
  self.bindUndimRestore = nil
end

function Mason:ShowBindVeil()
  local veil = self:EnsureBindVeil()
  if not veil then
    return
  end
  veil:EnableMouse(false)
  veil:SetFrameStrata(BIND_VEIL_STRATA)
  veil:SetFrameLevel(BIND_VEIL_LEVEL)
  veil:Show()
  self:RaiseBindUndimmedFrames()
  if self.bindMode and self.AttachKbBagHover then
    pcall(self.AttachKbBagHover, self)
  end
end

function Mason:HideBindVeil()
  if self.bindVeil then
    self.bindVeil:EnableMouse(false)
    self.bindVeil:Hide()
  end
  self:RestoreBindUndimmedFrames()
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
  local function debugHover(target)
    if not self:IsDebug() then
      return
    end
    local overToy = (_G.ToyBox and _G.ToyBox.IsMouseOver and _G.ToyBox:IsMouseOver())
      or (_G.CollectionsJournal and _G.CollectionsJournal.IsMouseOver and _G.CollectionsJournal:IsMouseOver() and _G.ToyBox and _G.ToyBox.IsShown and _G.ToyBox:IsShown())
    if target and target.kind == "toy" then
      self:DebugPrint("Mason: kb hover toy " .. tostring(target.itemID or "?"))
      return
    end
    if not target and overToy then
      self:DebugPrint("Mason: kb hover toy none")
      return
    end
    if not target then
      self:DebugPrint("Mason: kb hover none")
      return
    end
    local id = target.pieceId or target.spellID or target.itemID or target.macroName or "?"
    self:DebugPrint("Mason: kb hover " .. tostring(target.kind) .. " " .. tostring(id))
  end
  if key == "ESCAPE" then
    if catcher.SetPropagateKeyboardInput then
      catcher:SetPropagateKeyboardInput(false)
    end
    local target = self:GetBindHoverTarget()
    debugHover(target)
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
  debugHover(target)
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

function Mason:WatchLazyBindFrames()
  if self.masonLazyBindWatch then
    return
  end
  local watch = CreateFrame("Frame")
  local elapsed = 0
  local pulse = 0
  self.masonLazyBindWatch = watch
  watch:SetScript("OnUpdate", function(self, dt)
    if not Mason.bindMode then
      self:SetScript("OnUpdate", nil)
      Mason.masonLazyBindWatch = nil
      return
    end
    dt = dt or 0
    elapsed = elapsed + dt
    pulse = pulse + dt
    if pulse < 0.1 and elapsed <= 8 then
      return
    end
    pulse = 0
    local bags = _G.ContainerFrameCombinedBags
    local macros = _G.MacroFrame
    Mason:HookLateFrameOnShow(bags, "bags")
    Mason:HookLateFrameOnShow(macros, "macro")
    if macros and macros.IsShown and macros:IsShown() then
      Mason:RaiseBindMacroFrames()
      if Mason.masonMacroNeedButtons then
        local n = Mason:CountMacroButtons()
        if n and n > 0 then
          Mason.masonMacroNeedButtons = nil
          Mason:PaintMacroHotkeys()
        end
      end
    elseif macros then
      Mason:RaiseBindMacroFrames()
      Mason:HookMacroKbShow(macros)
      if macros.MacroSelector then
        Mason:HookMacroKbShow(macros.MacroSelector)
      end
    end
    if _G.ToyBox then
      Mason:RaiseBindToyFrames()
    end
    Mason:HookLateFrameOnShow(_G.PlayerSpellsFrame, "spell")
    local ps = _G.PlayerSpellsFrame
    if ps and ps.SpellBookFrame then
      Mason:HookLateFrameOnShow(ps.SpellBookFrame, "spell")
    end
    if ps and ps.IsShown and ps:IsShown() and Mason.RaiseBindSpellBook then
      pcall(Mason.RaiseBindSpellBook, Mason)
    end
    if elapsed > 8 then
      self:SetScript("OnUpdate", nil)
      Mason.masonLazyBindWatch = nil
    end
  end)
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
  self.kbWantsRaise = on
  if on then
    self.masonKbProbe = {}
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
    self:ShowBindVeil()
    self:InstallBindBagHooks()
    self:RaiseBindBagFrames()
    if self.CountAllBagButtons and self:CountAllBagButtons() > 0 and self.AttachKbBagHover then
      pcall(self.AttachKbBagHover, self)
    end
    if not _G.ContainerFrameCombinedBags or not _G.MacroFrame then
      self.kbWantsRaise = true
    end
    self:WatchLazyBindFrames()
    self:DebugPrint("Mason: keybind on")
  else
    self.bindHoverEnterFrame = nil
    self.masonBagNeedButtons = nil
    self.masonBagFillWatch = nil
    self:HideBindCatcher()
    self:HideBindPanel()
    self:HideBindHoverHighlight()
    self:HideBindVeil()
    self:DebugPrint("Mason: keybind off")
  end
  self:SyncEditBarBindButton()
  if self.SyncOptionsRail then
    self:SyncOptionsRail()
  end
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
    self.kbWantsRaise = false
    self.bindHoverEnterFrame = nil
    self.masonBagNeedButtons = nil
    self.masonBagFillWatch = nil
    self:HideBindCatcher()
    self:HideBindPanel()
    self:HideBindHoverHighlight()
    self:HideBindVeil()
    self:DebugPrint("Mason: keybind off")
    self:SyncEditBarBindButton()
    if self.SyncOptionsRail then
      self:SyncOptionsRail()
    end
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
  panel:SetSize(360, 140)
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
  body:SetText("Hover a placed piece, a spellbook row, a macro, or a bag item, then press a key. This options list cannot be hovered to bind.")
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
    local hit, owner = self:ResolveBindTargetFromFrame(foci[i])
    if hit then
      targetFrame = owner
      break
    end
  end
  if not targetFrame and self.bindHoverEnterFrame then
    local enter = self.bindHoverEnterFrame
    if enter.IsMouseOver and enter:IsMouseOver() then
      targetFrame = enter
    end
  end
  if not targetFrame then
    glow:Hide()
    return
  end
  glow:ClearAllPoints()
  local glowFrame = BindHoverGlowFrame(targetFrame) or targetFrame
  glow:SetPoint("TOPLEFT", glowFrame, "TOPLEFT", -2, 2)
  glow:SetPoint("BOTTOMRIGHT", glowFrame, "BOTTOMRIGHT", 2, -2)
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
    if InCombatLockdown() then
      print("Mason: cannot edit in combat")
      return
    end
    Mason:SetLocked(true)
    Mason:DebugPrint("Mason: edit off")
  end)
  bar.cancelBtn = MakeBtn("Cancel", -46, function()
    if InCombatLockdown() then
      print("Mason: cannot cancel edit in combat")
      return
    end
    Mason:RestoreEditViewsSnapshot()
    Mason:SetLocked(true)
    Mason:DebugPrint("Mason: edit off")
  end)
  bar.kbBtn = MakeBtn("Keybind", 46, function()
    Mason:ToggleBindMode()
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

local function ChordLabel(key)
  if GetBindingText then
    local ok, text = pcall(GetBindingText, key)
    if ok and type(text) == "string" and text ~= "" then
      return text
    end
  end
  return key
end

local function IsMasonOwnedFrame(f)
  local name = FrameName(f)
  if f and f.masonPieceId then
    return true
  end
  if name and (string.find(name, "MasonExec_", 1, true) or string.find(name, "MasonEdit_", 1, true) or string.find(name, "MasonScaleHost_", 1, true)) then
    return true
  end
  return false
end

local function FindButtonIconTexture(btn)
  if not btn then
    return nil
  end
  local icon = btn.Icon or btn.icon
  if icon and icon.GetObjectType then
    local ot = icon:GetObjectType()
    if ot == "Texture" then
      return icon
    end
    if (ot == "Frame" or ot == "Button" or ot == "CheckButton") then
      local inner = icon.Icon or icon.icon
      if inner and inner.GetObjectType and inner:GetObjectType() == "Texture" then
        return inner
      end
    end
  end
  if btn.GetRegions then
    local regions = { btn:GetRegions() }
    for i = 1, #regions do
      local r = regions[i]
      if r and r.GetObjectType and r:GetObjectType() == "Texture" then
        local n = string.lower(r.GetName and r:GetName() or "")
        if n == "icon" or string.find(n, "icon", 1, true) then
          if not string.find(n, "border", 1, true) and not string.find(n, "highlight", 1, true) then
            return r
          end
        end
      end
    end
  end
  return nil
end

local function MacroHotkeyHost(btn)
  if not CanUndimFrame(btn) then
    return nil
  end
  local h = btn.GetHeight and btn:GetHeight() or 0
  if h > 50 then
    if FindButtonIconTexture(btn) then
      return btn
    end
    if btn.GetChildren then
      local children = { btn:GetChildren() }
      for i = 1, #children do
        local c = children[i]
        if CanUndimFrame(c) and c.IsObjectType and (c:IsObjectType("Button") or c:IsObjectType("CheckButton")) then
          local ch = c.GetHeight and c:GetHeight() or 0
          if ch >= 30 and ch <= 50 then
            return c
          end
        end
      end
    end
    return nil
  end
  return btn
end

local function FindIconRegion(btn)
  if not btn then
    return nil
  end
  local function squareish(r)
    if not r or not r.GetWidth then
      return false
    end
    local w, h = r:GetWidth(), r:GetHeight()
    if not w or not h or w < 8 or h < 8 then
      return false
    end
    return math.abs(w - h) <= (math.max(w, h) * 0.4)
  end
  local function asIcon(r)
    if not r then
      return nil
    end
    if r.GetObjectType and r:GetObjectType() == "Texture" then
      return r
    end
    if r.Icon then
      local inner = asIcon(r.Icon)
      if inner then
        return inner
      end
    end
    if r.icon then
      local inner = asIcon(r.icon)
      if inner then
        return inner
      end
    end
    if squareish(r) then
      return r
    end
    return nil
  end
  if btn.Name then
    local namedIcon = asIcon(btn.Icon or btn.icon)
    if namedIcon then
      return namedIcon
    end
  end
  local named = btn.Icon or btn.icon or btn.IconTexture or btn.iconTexture or btn.SpellIcon or btn.ItemTexture or btn.IconContainer
  if named then
    local icon = asIcon(named)
    if icon then
      return icon
    end
  end
  local best, bestLeft
  if btn.GetRegions then
    local regions = { btn:GetRegions() }
    for i = 1, #regions do
      local r = regions[i]
      if r and r.GetObjectType and r:GetObjectType() == "Texture" and squareish(r) then
        local name = string.lower(r.GetName and r:GetName() or "")
        if not string.find(name, "highlight", 1, true) and not string.find(name, "border", 1, true) and not string.find(name, "slot", 1, true) then
          local left = r.GetLeft and r:GetLeft()
          if not best or (left and bestLeft and left < bestLeft) or not bestLeft then
            best = r
            bestLeft = left
          end
        end
      end
    end
  end
  if best then
    return best
  end
  if btn.GetChildren then
    local children = { btn:GetChildren() }
    for i = 1, #children do
      local c = children[i]
      local n = string.lower(c.GetName and c:GetName() or "")
      local isCheck = c.IsObjectType and c:IsObjectType("CheckButton")
      if isCheck and squareish(c) then
        return asIcon(c.Icon or c.icon or c) or c
      end
      if c.Icon or c.icon or string.find(n, "icon", 1, true) then
        local icon = asIcon(c.Icon or c.icon or c)
        if icon then
          return icon
        end
      end
    end
  end
  return nil
end

local function HotkeyKind(btn)
  if not btn then
    return "other"
  end
  if btn.GetBagID or btn.bagID or btn.BagID then
    return "bag"
  end
  local name = FrameName(btn) or ""
  if string.find(name, "Macro", 1, true) then
    return "macro"
  end
  if string.find(name, "Toy", 1, true) then
    return "toy"
  end
  if btn.slotIndex or btn.spellBookItemIndex or string.find(name, "SpellBook", 1, true) or string.find(name, "PlayerSpells", 1, true) then
    return "spell"
  end
  return "other"
end

function Mason:GetPieceHotkeyLook()
  local look = {
    point = "TOPRIGHT",
    x = -2,
    y = -1,
    size = 12,
    flags = "",
    r = 1,
    g = 1,
    b = 1,
    a = 1,
    font = STANDARD_TEXT_FONT,
  }
  if NumberFontNormal and NumberFontNormal.GetFont then
    local font, size, flags = NumberFontNormal:GetFont()
    look.font = font or look.font
    look.size = size or look.size
    look.flags = flags or look.flags
  end
  for _, exec in pairs(self.executors or {}) do
    if exec and exec.IsShown and exec:IsShown() then
      local hk = exec.HotKey or exec.masonHotkey
      if hk and hk.GetPoint then
        local p, _, _, x, y = hk:GetPoint(1)
        if p then
          look.point = p
          look.x = x or look.x
          look.y = y or look.y
        end
        if hk.GetFont then
          local font, size, flags = hk:GetFont()
          if font then
            look.font = font
            look.size = size or look.size
            look.flags = flags or look.flags
          end
        end
        if hk.GetTextColor then
          look.r, look.g, look.b, look.a = hk:GetTextColor()
        end
        break
      end
    end
  end
  return look
end

local function IsHotkeyHostWindow(f)
  if not f or f == UIParent then
    return true
  end
  local name = FrameName(f) or ""
  if name == "ToyBox" or name == "MacroFrame" or name == "PlayerSpellsFrame" or name == "SpellBookFrame"
    or name == "ContainerFrameCombinedBags" or name == "CollectionsJournal" or name == "MacroSelector"
    or name == "UIParent" or name == "SpellBookPagedSpellsFrame" then
    return true
  end
  if _G.MacroFrame and f == _G.MacroFrame.MacroSelector then
    return true
  end
  if _G.PlayerSpellsFrame and (f == _G.PlayerSpellsFrame or f == _G.PlayerSpellsFrame.SpellBookFrame) then
    if not (f.IsObjectType and (f:IsObjectType("Button") or f:IsObjectType("CheckButton"))) then
      return true
    end
  end
  return false
end

function Mason:EnsureBlizzardHotkeyFont(btn)
  if not btn or IsMasonOwnedFrame(btn) or IsHotkeyHostWindow(btn) then
    return nil
  end
  if btn.GetObjectType then
    local ot = btn:GetObjectType()
    if ot == "Texture" or ot == "FontString" or ot == "AnimationGroup" or ot == "Animation" then
      return nil
    end
  end
  if not btn.CreateFontString then
    return nil
  end
  local cell = btn
  if HotkeyKind(btn) == "macro" then
    cell = MacroHotkeyHost(btn)
    if not cell then
      return nil
    end
  end
  if InCombatLockdown() and not cell.masonHotkey and not btn.masonHotkey then
    return nil
  end
  local icon = FindButtonIconTexture(cell) or FindIconRegion(cell) or FindButtonIconTexture(btn) or FindIconRegion(btn)
  if icon and icon.GetObjectType and icon:GetObjectType() ~= "Texture" then
    icon = FindButtonIconTexture(icon) or FindIconRegion(icon) or icon
    if icon.GetObjectType and icon:GetObjectType() ~= "Texture" then
      local inner = icon.Icon or icon.icon
      if inner and inner.GetObjectType and inner:GetObjectType() == "Texture" then
        icon = inner
      end
    end
  end
  if btn.masonHotkeyHolder then
    btn.masonHotkeyHolder:Hide()
  end
  if cell.masonHotkeyHolder then
    cell.masonHotkeyHolder:Hide()
  end
  local fs = cell.masonHotkey or btn.masonHotkey
  if not fs then
    if InCombatLockdown() then
      return nil
    end
    fs = cell:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  end
  cell.masonHotkey = fs
  btn.masonHotkey = fs
  if fs.SetParent then
    fs:SetParent(cell)
  end
  local look = self:GetPieceHotkeyLook()
  fs:SetFont(look.font, look.size, look.flags)
  fs:SetTextColor(look.r, look.g, look.b, look.a)
  fs:SetJustifyH("RIGHT")
  fs:ClearAllPoints()
  if icon then
    fs:SetPoint("TOPRIGHT", icon, "TOPRIGHT", -2, -2)
  else
    fs:SetPoint("TOPRIGHT", cell, "TOPRIGHT", -2, -2)
  end
  if fs.SetAlpha then
    fs:SetAlpha(1)
  end
  return fs
end

local function HitsMatch(a, b)
  if not a or not b or a.kind ~= b.kind then
    return false
  end
  if a.spellID and a.spellID == b.spellID then
    return true
  end
  if a.itemID and a.itemID == b.itemID then
    return true
  end
  if a.macroName and a.macroName == b.macroName then
    return true
  end
  if a.pieceId and a.pieceId == b.pieceId then
    return true
  end
  return false
end

local function ParentOwnsSameHit(btn, hit)
  local p = btn.GetParent and btn:GetParent()
  local n = 0
  while p and n < 5 do
    if not IsHotkeyHostWindow(p) then
      if HitsMatch(hit, Mason:BindHitOnFrame(p)) then
        return true
      end
    end
    p = p.GetParent and p:GetParent()
    n = n + 1
  end
  return false
end

local function BlizzardHotkeyRegion(btn)
  return btn.HotKey or btn.hotKey or btn.hotkey
end

local function SetBlizzardHotkeyHidden(btn, hidden)
  local hk = BlizzardHotkeyRegion(btn)
  if not hk then
    return
  end
  if hidden then
    btn.masonHidBlizzHotkey = true
    if hk.SetText then
      hk:SetText("")
    end
    if hk.Hide then
      hk:Hide()
    end
  elseif btn.masonHidBlizzHotkey then
    btn.masonHidBlizzHotkey = nil
    if hk.Show then
      hk:Show()
    end
  end
end

function Mason:PaintBlizzardHotkey(btn)
  if not btn then
    return
  end
  local hit = self:BindHitOnFrame(btn)
  if not hit then
    return
  end
  if hit.kind == "spell" then
    self:PaintKbOverlay(btn, "spell", hit.spellID)
  elseif hit.kind == "toy" then
    self:PaintKbOverlay(btn, "toy", hit.itemID)
  elseif hit.kind == "item" then
    self:PaintKbOverlay(btn, "item", hit.itemID)
  elseif hit.kind == "macro" then
    self:PaintKbOverlay(btn, "macro", hit.macroName)
  end
end

function Mason:WalkBlizzardHotkeys(frame, depth)
  return
end

function Mason:ScheduleSpellbookHotkeys()
  local function paint()
    if Mason.PaintSpellbookHotkeys then
      Mason:PaintSpellbookHotkeys()
    elseif Mason.RefreshBlizzardHotkeys then
      Mason:RefreshBlizzardHotkeys()
    end
  end
  paint()
  if C_Timer and C_Timer.After then
    C_Timer.After(0, paint)
    C_Timer.After(0.15, paint)
  end
end

function Mason:RequestBlizzardHotkeys()
  if self.masonHotkeyQueued then
    return
  end
  self.masonHotkeyQueued = true
  local run = function()
    Mason.masonHotkeyQueued = nil
    if Mason.RefreshBlizzardHotkeys then
      Mason:RefreshBlizzardHotkeys()
    end
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(0, run)
  else
    run()
  end
end

function Mason:PaintBagHotkeys()
  self:PaintKbAdapter("item")
end

function Mason:PaintToyCellHotkey(btn)
  local a = KB_ADAPTERS.toy
  self:PaintKbOverlay(btn, "toy", a.identity(btn))
end

function Mason:PaintToyHotkeys()
  self:PaintKbAdapter("toy")
end

function Mason:PaintSpellbookHotkeys()
  self:PaintKbAdapter("spell")
end

function Mason:HookHotkeyRecycle()
  if not self.masonToyHotkeyRecycle then
    self.masonToyHotkeyRecycle = true
    if type(_G.ToyBox_OnMouseWheel) == "function" then
      hooksecurefunc("ToyBox_OnMouseWheel", function()
        Mason:PaintToyHotkeys()
      end)
    end
    if type(_G.ToyBox_UpdateButtons) == "function" then
      hooksecurefunc("ToyBox_UpdateButtons", function()
        Mason:PaintToyHotkeys()
      end)
    end
    if type(_G.ToySpellButton_UpdateButton) == "function" then
      hooksecurefunc("ToySpellButton_UpdateButton", function(btn)
        if Mason.PaintToyCellHotkey then
          Mason:PaintToyCellHotkey(btn)
        end
      end)
    end
    if ToySpellButtonMixin and ToySpellButtonMixin.UpdateButton then
      hooksecurefunc(ToySpellButtonMixin, "UpdateButton", function(btn)
        if Mason.PaintToyCellHotkey then
          Mason:PaintToyCellHotkey(btn)
        end
      end)
    end
  end
  local box = _G.ToyBox
  if box then
    if box.PagingFrame and box.PagingFrame.SetCurrentPage and not box.PagingFrame.masonHotkeyPage then
      box.PagingFrame.masonHotkeyPage = true
      hooksecurefunc(box.PagingFrame, "SetCurrentPage", function()
        Mason:PaintToyHotkeys()
      end)
    end
    if box.ScrollBox and not box.ScrollBox.masonHotkeyRecycle then
      box.ScrollBox.masonHotkeyRecycle = true
      if box.ScrollBox.RegisterCallback then
        pcall(box.ScrollBox.RegisterCallback, box.ScrollBox, "OnAcquiredFrame", function(_, btn)
          if Mason.PaintToyCellHotkey then
            Mason:PaintToyCellHotkey(btn)
          end
        end)
        pcall(box.ScrollBox.RegisterCallback, box.ScrollBox, "OnScroll", function()
          Mason:PaintToyHotkeys()
        end)
      end
    end
    if box.HookScript and not box.masonHotkeyWheel then
      box.masonHotkeyWheel = true
      pcall(function()
        box:HookScript("OnMouseWheel", function()
          Mason:PaintToyHotkeys()
        end)
      end)
    end
  end
  local function hookSpellPages(frame)
    if not frame or frame.masonSpellPageHotkey then
      return
    end
    frame.masonSpellPageHotkey = true
    if frame.SetToPage then
      hooksecurefunc(frame, "SetToPage", function()
        Mason:PaintSpellbookHotkeys()
      end)
    end
    if frame.GoToPage then
      hooksecurefunc(frame, "GoToPage", function()
        Mason:PaintSpellbookHotkeys()
      end)
    end
    if frame.PagingFrame and frame.PagingFrame.SetCurrentPage then
      hooksecurefunc(frame.PagingFrame, "SetCurrentPage", function()
        Mason:PaintSpellbookHotkeys()
      end)
    end
    if frame.ScrollBox and frame.ScrollBox.RegisterCallback and not frame.ScrollBox.masonSpellAcquire then
      frame.ScrollBox.masonSpellAcquire = true
      pcall(frame.ScrollBox.RegisterCallback, frame.ScrollBox, "OnAcquiredFrame", function(_, btn)
        local cell = SpellIconFromRow(btn) or btn
        local id = SpellIdFromFrame(btn) or SpellIdFromFrame(cell)
        if id then
          Mason:PaintKbOverlay(cell, "spell", id)
        end
      end)
    end
  end
  local ps = _G.PlayerSpellsFrame
  local sb = ps and (ps.SpellBookFrame or ps.SpellBook) or _G.SpellBookFrame
  hookSpellPages(sb)
  if sb then
    hookSpellPages(sb.PagedSpellsFrame)
    hookSpellPages(sb.SpellBookPagedSpellsFrame)
  end
  if SpellBookItemMixin and SpellBookItemMixin.Update and not self.masonSpellItemUpdateHook then
    self.masonSpellItemUpdateHook = true
    hooksecurefunc(SpellBookItemMixin, "Update", function(selfBtn)
      local cell = SpellIconFromRow(selfBtn) or selfBtn
      local id = SpellIdFromFrame(selfBtn) or SpellIdFromFrame(cell)
      if id then
        Mason:PaintKbOverlay(cell, "spell", id)
      end
    end)
  end
  if SpellBookItemButtonMixin and SpellBookItemButtonMixin.Update and not self.masonSpellBtnUpdateHook then
    self.masonSpellBtnUpdateHook = true
    hooksecurefunc(SpellBookItemButtonMixin, "Update", function(selfBtn)
      local cell = SpellIconFromRow(selfBtn) or selfBtn
      local id = SpellIdFromFrame(selfBtn) or SpellIdFromFrame(cell)
      if id then
        Mason:PaintKbOverlay(cell, "spell", id)
      end
    end)
  end
  self:HookMacroSelectorFillSignals()
end

function Mason:InstallHotkeyFrameHooks()
  self:InstallBindBagHooks()
  self:HookHotkeyRecycle()
  self:HookBlizzardHotkeyShow(_G.PlayerSpellsFrame)
  local sb = _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.SpellBookFrame
  self:HookBlizzardHotkeyShow(sb)
  if sb then
    self:HookBlizzardHotkeyShow(sb.PagedSpellsFrame)
    self:HookBlizzardHotkeyShow(sb.SpellBookPagedSpellsFrame)
    if sb.TabSystem and sb.TabSystem.SetTab and not sb.masonTabHotkeyHook then
      sb.masonTabHotkeyHook = true
      hooksecurefunc(sb.TabSystem, "SetTab", function()
        Mason:PaintSpellbookHotkeys()
      end)
    end
  end
  self:HookBlizzardHotkeyShow(_G.SpellBookFrame)
  self:HookBlizzardHotkeyShow(_G.ToyBox)
  self:HookBlizzardHotkeyShow(_G.CollectionsJournal)
  if _G.CollectionsJournal then
    self:HookBlizzardHotkeyShow(_G.CollectionsJournal.ToyBox)
  end
  self:HookBlizzardHotkeyShow(_G.MacroFrame)
  self:HookBlizzardHotkeyShow(_G.ContainerFrameCombinedBags)
  self:HookLateFrameOnShow(_G.ContainerFrameCombinedBags, "bags")
  self:HookLateFrameOnShow(_G.MacroFrame, "macro")
end

function Mason:HookBlizzardHotkeyShow(frame)
  if not frame or frame.masonHotkeyShowHook then
    return
  end
  frame.masonHotkeyShowHook = true
  if frame.HookScript then
    frame:HookScript("OnShow", function()
      local name = frame.GetName and frame:GetName() or ""
      if frame == _G.PlayerSpellsFrame or frame == (_G.PlayerSpellsFrame and _G.PlayerSpellsFrame.SpellBookFrame) or name == "SpellBookFrame" or string.find(name, "SpellBook", 1, true) or string.find(name, "PlayerSpells", 1, true) then
        if Mason.RaiseBindSpellBook then
          pcall(Mason.RaiseBindSpellBook, Mason)
        end
        Mason:ScheduleSpellbookHotkeys()
      elseif frame == _G.ContainerFrameCombinedBags or name == "ContainerFrameCombinedBags" or (name and string.find(name, "ContainerFrame", 1, true)) then
        if Mason.OnBagsOpened then
          pcall(Mason.OnBagsOpened, Mason)
        else
          Mason:RefreshBlizzardHotkeys()
        end
      else
        Mason:RefreshBlizzardHotkeys()
      end
    end)
  end
end

function Mason:RefreshBlizzardHotkeys()
  if InCombatLockdown() then
    return self:QueueIfCombat(function()
      Mason:RefreshBlizzardHotkeys()
    end)
  end
  self:InstallHotkeyFrameHooks()
  local tracked = self.blizzardHotkeyButtons
  if tracked then
    for btn in pairs(tracked) do
      if btn.masonHotkey then
        btn.masonHotkey:SetText("")
        btn.masonHotkey:Hide()
      end
    end
  end
  local function visit(frame)
    self:HookBlizzardHotkeyShow(frame)
    self:WalkBlizzardHotkeys(frame, 0)
  end
  pcall(function()
    if Mason.PaintSpellbookHotkeys then
      Mason:PaintSpellbookHotkeys()
    else
      visit(_G.PlayerSpellsFrame)
      if _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.SpellBookFrame then
        local sb = _G.PlayerSpellsFrame.SpellBookFrame
        visit(sb)
        visit(sb.PagedSpellsFrame)
        visit(sb.SpellBookPagedSpellsFrame)
      end
      visit(_G.SpellBookFrame)
    end
  end)
  pcall(function()
    if Mason.PaintMacroHotkeys then
      Mason:PaintMacroHotkeys()
    end
  end)
  pcall(function()
    if Mason.PaintToyHotkeys then
      Mason:PaintToyHotkeys()
    else
      visit(_G.ToyBox)
      if _G.CollectionsJournal and _G.CollectionsJournal.ToyBox then
        visit(_G.CollectionsJournal.ToyBox)
      end
      for i = 1, 18 do
        local b = _G["ToySpellButton" .. i]
        Mason:PaintKbOverlay(b, "toy", b and (b.itemID or ToyIdFromFrame(b)))
      end
    end
  end)
  if Mason.PaintBagHotkeys then
    Mason:PaintBagHotkeys()
  else
    visit(_G.ContainerFrameCombinedBags)
    local n = NUM_CONTAINER_FRAMES or 13
    for i = 1, n do
      visit(_G["ContainerFrame" .. i])
    end
  end
  self:HookBlizzardHotkeyShow(_G.PlayerSpellsFrame)
  self:HookBlizzardHotkeyShow(_G.CollectionsJournal)
end
