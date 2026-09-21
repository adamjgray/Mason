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
local BIND_VEIL_STRATA = "BACKGROUND"
local BIND_VEIL_LEVEL = 0
-- 09ab: no Blizzard undim raise; UNDIM_LEVEL unused

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
  local function idFromSpellInfo(info)
    if type(info) ~= "table" then
      return nil
    end
    local id = fromValue(info.spellID or info.spellId)
    if id then
      return id
    end
    -- actionID is the spellID only for Spell items (not flyouts/PvpTalents/etc).
    if Enum and Enum.SpellBookItemType and info.itemType ~= nil then
      if info.itemType ~= Enum.SpellBookItemType.Spell then
        return nil
      end
    end
    return fromValue(info.actionID)
  end
  local function fromTable(t, depth)
    if type(t) ~= "table" or (depth or 0) > 2 then
      return nil
    end
    local id = fromValue(t.spellID or t.spellId) or idFromSpellInfo(t)
    if id then
      return id
    end
    if type(t.spellBookItemInfo) == "table" then
      id = idFromSpellInfo(t.spellBookItemInfo)
      if id then
        return id
      end
    end
    return nil
  end
  local function fromSlotBank(slot, bank)
    slot = tonumber(slot)
    if not slot or not C_SpellBook or not C_SpellBook.GetSpellBookItemInfo then
      return nil
    end
    if bank == nil and Enum and Enum.SpellBookSpellBank then
      bank = Enum.SpellBookSpellBank.Player
    end
    -- Retail API: GetSpellBookItemInfo(slotIndex, spellBank)
    local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, slot, bank)
    if ok and type(info) == "table" then
      return idFromSpellInfo(info)
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
  -- Frame fields (SpellBookItemMixin) — required after /reload with no session stamps.
  id = fromSlotBank(
    f.slotIndex or f.spellBookItemSlotIndex or f.spellBookItemIndex or f.index or f.slot,
    f.spellBank or f.bank or f.spellBookSpellBank
  )
  if id then
    return id
  end
  if C_SpellBook and C_SpellBook.GetSpellBookItemType then
    local slot = tonumber(f.slotIndex or f.spellBookItemSlotIndex or f.spellBookItemIndex or f.index or f.slot)
    local bank = f.spellBank or f.bank or f.spellBookSpellBank
    if bank == nil and Enum and Enum.SpellBookSpellBank then
      bank = Enum.SpellBookSpellBank.Player
    end
    if slot then
      local ok, itemType, actionID = pcall(C_SpellBook.GetSpellBookItemType, slot, bank)
      if ok and actionID then
        if not Enum or not Enum.SpellBookItemType or itemType == Enum.SpellBookItemType.Spell or itemType == nil then
          id = fromValue(actionID)
          if id then
            return id
          end
        end
      end
    end
  end
  if f.GetElementData then
    local ok, data = pcall(f.GetElementData, f)
    if ok then
      if type(data) == "table" then
        id = fromTable(data, 0) or fromTable(data.elementData, 1)
          or fromTable(data.spellBookItemInfo, 0)
          or fromValue(data.spellID or data.spellId)
        if id then
          return id
        end
        local slot = data.slotIndex or data.index or data.spellBookItemIndex or data.spellBookItemID
        local bank = data.spellBank or data.bank
        if type(data.elementData) == "table" then
          slot = slot or data.elementData.slotIndex or data.elementData.index or data.elementData.spellBookItemIndex
          bank = bank or data.elementData.spellBank or data.elementData.bank
        end
        id = fromSlotBank(slot, bank)
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
      id = idFromSpellInfo(info)
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
    id = idFromSpellInfo(f.spellBookItemInfo)
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
  local function acceptToyId(id)
    id = tonumber(id)
    if not id or id <= 0 then
      return nil
    end
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
    -- Still return: store KeyForIdentity needs the raw itemID after /reload.
    return id
  end
  local id = acceptToyId(f.toyID or f.toyId or f.itemID or f.itemId)
  if id then
    return id
  end
  local index = tonumber(f.index or f.itemIndex or f.toyIndex)
  if index and C_ToyBox and C_ToyBox.GetToyFromIndex then
    local ok, toyId = pcall(C_ToyBox.GetToyFromIndex, index)
    if ok then
      id = acceptToyId(toyId)
      if id then
        return id
      end
    end
  end
  if f.GetElementData then
    local ok, data = pcall(f.GetElementData, f)
    if ok and type(data) == "table" then
      id = acceptToyId(data.toyID or data.toyId or data.itemID or data.itemId)
      if id then
        return id
      end
      if type(data.elementData) == "table" then
        id = acceptToyId(data.elementData.toyID or data.elementData.toyId or data.elementData.itemID or data.elementData.itemId)
        if id then
          return id
        end
      end
      index = tonumber(data.index or data.itemIndex or data.toyIndex)
      if index and C_ToyBox and C_ToyBox.GetToyFromIndex then
        local ok2, toyId = pcall(C_ToyBox.GetToyFromIndex, index)
        if ok2 then
          id = acceptToyId(toyId)
          if id then
            return id
          end
        end
      end
    end
  end
  local name = FrameName(f)
  if name and string.find(string.lower(name), "toy", 1, true) then
    id = acceptToyId(f.itemID or f.itemId)
    if id then
      return id
    end
  end
  if f.GetParent then
    local p = f:GetParent()
    if p and p ~= f then
      id = acceptToyId(p.toyID or p.toyId or p.itemID or p.itemId)
      if id then
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
  if not toyID and f.masonKbKind == "toy" and f.masonKbId then
    toyID = tonumber(f.masonKbId) or f.masonKbId
  end
  if toyID then
    return { kind = "toy", itemID = toyID }
  end
  local spellID = SpellIdFromFrame(f)
  if not spellID and f.masonKbKind == "spell" and f.masonKbId then
    spellID = tonumber(f.masonKbId) or f.masonKbId
  end
  spellID = spellID or f.masonSpellId
  if spellID then
    return { kind = "spell", spellID = spellID }
  end
  local itemID = ItemIdFromFrame(f)
  if not itemID and f.masonKbKind == "item" and f.masonKbId then
    itemID = tonumber(f.masonKbId) or f.masonKbId
  end
  if itemID then
    return { kind = "item", itemID = itemID }
  end
  local macroName = MacroNameFromFrame(f)
  if not macroName and f.masonKbKind == "macro" and f.masonKbId then
    macroName = f.masonKbId
  end
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

local kbCellRegistry = {
  spell = {},
  item = {},
  toy = {},
  macro = {},
}

local function RememberKbCell(kind, btn)
  if not kind or not btn then
    return
  end
  local bucket = kbCellRegistry[kind]
  if not bucket then
    kbCellRegistry[kind] = {}
    bucket = kbCellRegistry[kind]
  end
  bucket[btn] = true
end

local function EachRegistryCell(kind, fn)
  local bucket = kbCellRegistry[kind]
  if not bucket then
    return
  end
  for btn in pairs(bucket) do
    if btn then
      fn(btn)
    end
  end
end

local function StampKbIdentity(btn, kind, id)
  if not btn or id == nil or id == "" then
    return
  end
  RememberKbCell(kind, btn)
  btn.masonKbKind = kind
  btn.masonKbId = id
  if kind == "spell" then
    btn.masonSpellId = id
  end
end

local function ClearKbIdentity(btn)
  if not btn then
    return
  end
  btn.masonKbKind = nil
  btn.masonKbId = nil
  btn.masonSpellId = nil
end

local function ClearHotkeyVisual(btn)
  if not btn then
    return
  end
  local fs = btn.masonHotkey
  if fs then
    if fs.SetText then
      fs:SetText("")
    end
    if fs.Hide then
      fs:Hide()
    end
  end
end

local ClearMacroHotkeyVisual = ClearHotkeyVisual

local function IsBagItemButton(btn)
  if not btn then
    return false
  end
  if btn.GetBagID or btn.bagID ~= nil or btn.BagID ~= nil then
    return true
  end
  if btn.GetBagAndSlot or btn.GetItemLocation then
    return true
  end
  local n = FrameName(btn) or ""
  if n ~= "" and string.find(n, "ContainerFrame", 1, true) and string.find(n, "Item", 1, true) then
    return true
  end
  return false
end

-- Forward declare: PaintKbAdapter paints macros onto the icon host.
local MacroHotkeyHost

local function HitKindId(hit)
  if not hit then
    return nil, nil
  end
  if hit.kind == "spell" then
    return "spell", hit.spellID
  end
  if hit.kind == "toy" then
    return "toy", hit.itemID
  end
  if hit.kind == "item" then
    return "item", hit.itemID
  end
  if hit.kind == "macro" then
    return "macro", hit.macroName
  end
  return nil, nil
end

local function KindMatchesWant(kind, wantKind)
  if not wantKind then
    return true
  end
  if kind == wantKind then
    return true
  end
  if wantKind == "item" and kind == "toy" then
    return true
  end
  if wantKind == "toy" and kind == "item" then
    return true
  end
  return false
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
  -- Stamp durable id on bind owner AND paint cell (icon) before AfterBindChange clear+paint.
  local owner = self.bindHoverOwner or self.bindHoverEnterFrame
  if owner and target.kind and target.kind ~= "piece" then
    local kind, id = HitKindId(target)
    if kind and id then
      StampKbIdentity(owner, kind, id)
      local paintCell = owner
      if kind == "spell" then
        local icon = owner.Button or owner.IconButton or owner.SpellButton or owner.iconButton
        if icon then
          paintCell = icon
        end
      end
      if paintCell ~= owner then
        StampKbIdentity(paintCell, kind, id)
      end
    end
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
  if identityKind then
    RememberKbCell(identityKind, button)
    if identity then
      StampKbIdentity(button, identityKind, identity)
    end
  end
  local fs
  if self.EnsureBlizzardHotkeyFont then
    fs = self:EnsureBlizzardHotkeyFont(button, identityKind)
  end
  if not fs then
    fs = button.masonHotkey
  end
  -- Macros: never CreateFontString on the ScrollBox row — require icon host.
  if not fs and identityKind == "macro" then
    return
  end
  if not fs then
    if not button.CreateFontString or InCombatLockdown() then
      return
    end
    fs = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    local icon = button.icon or button.Icon or button
    fs:SetPoint("TOPRIGHT", icon, "TOPRIGHT", -2, -2)
    button.masonHotkey = fs
  end
  if fs.SetIgnoreParentAlpha then
    fs:SetIgnoreParentAlpha(true)
  end
  if fs.SetDrawLayer then
    fs:SetDrawLayer("OVERLAY", 7)
  end
  if fs.Show then
    fs:Show()
  end
  self.blizzardHotkeyButtons = self.blizzardHotkeyButtons or {}
  self.blizzardHotkeyButtons[button] = true
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
  local function stampedSpellId(f)
    if not f then
      return nil
    end
    if f.masonKbKind == "spell" and f.masonKbId then
      return f.masonKbId
    end
    return f.masonSpellId
  end
  local function add(btn)
    if not btn or not IsShownCell(btn) then
      return
    end
    if seen[btn] then
      return
    end
    local cell = SpellIconFromRow(btn) or btn
    local sid = stampedSpellId(btn) or stampedSpellId(cell)
      or SpellIdFromFrame(btn) or SpellIdFromFrame(cell)
    if not sid and btn.GetParent then
      local p = btn:GetParent()
      local depth = 0
      while p and depth < 5 and not sid do
        sid = stampedSpellId(p) or SpellIdFromFrame(p)
        p = p.GetParent and p:GetParent()
        depth = depth + 1
      end
    end
    -- Propagate stamp onto the paint cell even if cell was already emitted.
    if sid then
      StampKbIdentity(cell, "spell", sid)
      StampKbIdentity(btn, "spell", sid)
    end
    if seen[cell] then
      seen[btn] = true
      return
    end
    if not sid and not LooksSpellCell(cell) and not LooksSpellCell(btn) then
      return
    end
    seen[btn] = true
    seen[cell] = true
    if sid then
      RememberKbCell("spell", cell)
    end
    out[#out + 1] = cell
  end
  for i = 1, 32 do
    add(_G["SpellBookItemButton" .. i])
    add(_G["SpellButton" .. i])
  end
  EachRegistryCell("spell", add)
  local ps = _G.PlayerSpellsFrame
  local sb = (ps and (ps.SpellBookFrame or ps.SpellBook)) or _G.SpellBookFrame
  local paged = sb and (sb.PagedSpellsFrame or sb.SpellBookPagedSpellsFrame)
  local holders = { paged, sb, ps and ps.SpellBookFrame, ps }
  for h = 1, #holders do
    local frame = holders[h]
    if frame then
      EachScrollBoxFrame(frame.ScrollBox, add)
      EachPoolActive(frame.framePool or frame.buttonPool or frame.itemButtonPool or frame.pool or frame.spellBookItemPool, add)
      local namedList = frame.spellBookItems or frame.itemButtons or frame.buttons or frame.contents
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
    local tid = ToyIdFromFrame(btn)
    if tid then
      StampKbIdentity(btn, "toy", tid)
    end
    RememberKbCell("toy", btn)
    out[#out + 1] = btn
  end
  EachRegistryCell("toy", add)
  local box = _G.ToyBox or (_G.CollectionsJournal and _G.CollectionsJournal.ToyBox)
  if box then
    EachScrollBoxFrame(box.ScrollBox, add)
    EachPoolActive(box.spellButtonPool or box.buttonPool or box.pool or box.toyButtonPool, add)
    local namedList = box.buttons or box.toyButtons or box.spellButtons
    if type(namedList) == "table" then
      for _, b in pairs(namedList) do
        add(b)
      end
    end
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
      local sid = SpellIdFromFrame(button) or button.masonSpellId
      if not sid then
        local cell = SpellIconFromRow(button)
        if cell and cell ~= button then
          sid = SpellIdFromFrame(cell)
        end
      end
      if not sid and button.GetParent then
        sid = SpellIdFromFrame(button:GetParent())
      end
      return sid
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

function Mason:ResolveKbIdentity(btn, wantKind)
  -- Live frame identity first (ScrollBox recycle-safe), then stamps, then bind Resolve walk.
  if not btn then
    return nil, nil
  end
  local function stampPaint(kind, id)
    StampKbIdentity(btn, kind, id)
    if kind == "spell" then
      local paintCell = btn.Button or btn.IconButton or btn.SpellButton or btn.iconButton
      if paintCell and paintCell ~= btn then
        StampKbIdentity(paintCell, kind, id)
      end
    end
  end
  local function liveIdentity()
    if not wantKind or wantKind == "macro" then
      local n = MacroNameFromFrame(btn)
      if (not n or n == "") and btn.GetParent then
        n = MacroNameFromFrame(btn:GetParent())
      end
      if (not n or n == "") then
        local icon = btn.Button or btn.IconButton or btn.iconButton
        if icon then
          n = MacroNameFromFrame(icon)
        end
      end
      if n and n ~= "" then
        return "macro", n
      end
    end
    if not wantKind or wantKind == "spell" then
      local sid = SpellIdFromFrame(btn)
      if not sid then
        local icon = btn.Button or btn.IconButton or btn.SpellButton or btn.iconButton
        sid = SpellIdFromFrame(icon)
      end
      if not sid and btn.GetParent then
        sid = SpellIdFromFrame(btn:GetParent())
      end
      if sid then
        return "spell", sid
      end
    end
    if not wantKind or wantKind == "toy" then
      local tid = ToyIdFromFrame(btn)
      if tid then
        return "toy", tid
      end
    end
    if not wantKind or wantKind == "item" then
      local iid = ItemIdFromFrame(btn)
      if iid then
        return "item", iid
      end
    end
    return nil, nil
  end
  local kind, id = liveIdentity()
  if id and KindMatchesWant(kind, wantKind) then
    stampPaint(kind, id)
    return kind, id
  end
  -- Bag ScrollBox recycle: empty (or unknown) cells must not keep stale masonKb*.
  if (not wantKind or wantKind == "item") and IsBagItemButton(btn) then
    ClearKbIdentity(btn)
    ClearHotkeyVisual(btn)
    if wantKind == "item" then
      return nil, nil
    end
  end
  local function readStamp(f)
    if not f then
      return nil, nil
    end
    if f.masonKbId ~= nil and f.masonKbId ~= "" then
      local stampedKind = f.masonKbKind
      if not stampedKind and f.masonSpellId and f.masonKbId == f.masonSpellId then
        stampedKind = "spell"
      end
      if stampedKind and KindMatchesWant(stampedKind, wantKind) then
        return stampedKind, f.masonKbId
      end
    end
    if wantKind == "spell" and f.masonSpellId then
      return "spell", f.masonSpellId
    end
    return nil, nil
  end
  kind, id = readStamp(btn)
  if not id then
    local p = btn.GetParent and btn:GetParent()
    local depth = 0
    while p and depth < 6 and not id do
      kind, id = readStamp(p)
      p = p.GetParent and p:GetParent()
      depth = depth + 1
    end
  end
  if id then
    stampPaint(kind, id)
    return kind, id
  end
  local hit, owner = self:ResolveBindTargetFromFrame(btn)
  kind, id = HitKindId(hit)
  if kind and id and KindMatchesWant(kind, wantKind) then
    local host = owner or btn
    StampKbIdentity(host, kind, id)
    stampPaint(kind, id)
    return kind, id
  end
  local a = wantKind and KB_ADAPTERS[wantKind]
  if a and a.identity then
    id = a.identity(btn)
    if id then
      stampPaint(wantKind, id)
      return wantKind, id
    end
  end
  return nil, nil
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
    local resolvedKind, id
    if a.name == "item" then
      -- Bags: live itemID only — never paint empty / stale-stamp ghosts.
      id = ItemIdFromFrame(btn)
      if id then
        resolvedKind = "item"
      else
        ClearKbIdentity(btn)
        ClearHotkeyVisual(btn)
      end
    else
      resolvedKind, id = self:ResolveKbIdentity(btn, a.name)
      if not id and a.name == "macro" and btn.GetParent then
        -- Icon host may lack element data; resolve from ScrollBox row parent.
        resolvedKind, id = self:ResolveKbIdentity(btn:GetParent(), a.name)
      end
    end
    local paintBtn = btn
    if a.name == "macro" then
      local host = MacroHotkeyHost(btn)
      if not host and btn.GetParent then
        host = MacroHotkeyHost(btn:GetParent())
      end
      if host then
        paintBtn = host
      end
      if paintBtn ~= btn then
        ClearHotkeyVisual(btn)
      end
      if btn.Button and btn.Button ~= paintBtn then
        ClearHotkeyVisual(btn.Button)
      end
    end
    if id then
      StampKbIdentity(btn, resolvedKind or a.name, id)
      StampKbIdentity(paintBtn, resolvedKind or a.name, id)
    else
      ClearKbIdentity(btn)
      if paintBtn ~= btn then
        ClearKbIdentity(paintBtn)
      end
      ClearHotkeyVisual(paintBtn)
      ClearHotkeyVisual(btn)
    end
    if self.bindMode then
      self:AttachKbHover(paintBtn, a.name, id)
      if paintBtn ~= btn then
        self:AttachKbHover(btn, a.name, id)
      end
    end
    if id then
      -- Store chord only when live identity is known (KeyForIdentity may be "").
      painted = painted + 1
      self:PaintKbOverlay(paintBtn, a.name, id)
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
      -- Always-on store paint; never walk/raise from bag UI callbacks.
      Mason:ScheduleBagFollowup()
    end)
  end
end

function Mason:RaiseBindBagFrames()
  -- 09ab: CombinedBags hooks/paint schedule only — never Raise bag frames.
  local function hookBag(frame)
    if not frame then
      return
    end
    pcall(function()
      self:HookBagSearchBox(frame)
      self:HookBagItemParents(frame)
      if frame.ScrollBox and not frame.ScrollBox.masonBagUpdateHook and frame.ScrollBox.Update then
        frame.ScrollBox.masonBagUpdateHook = true
        hooksecurefunc(frame.ScrollBox, "Update", function(box)
          if Mason.masonBagUpdateRepainting then
            return
          end
          Mason.masonBagUpdateRepainting = true
          EachScrollBoxFrame(box or frame.ScrollBox, function(btn)
            if not btn then
              return
            end
            local id = ItemIdFromFrame(btn)
            if not id or (btn.masonKbId and btn.masonKbId ~= id) then
              ClearKbIdentity(btn)
              ClearHotkeyVisual(btn)
            end
          end)
          -- B-02: bag ScrollBox → ScheduleBagFollowup only (never dual paint).
          Mason:ScheduleBagFollowup()
          Mason.masonBagUpdateRepainting = nil
        end)
      end
    end)
  end
  local combined = _G.ContainerFrameCombinedBags
  hookBag(combined)
  if not combined then
    local n = NUM_CONTAINER_FRAMES or 13
    for i = 1, n do
      local frame = _G["ContainerFrame" .. i]
      if frame and frame.IsShown and frame:IsShown() then
        hookBag(frame)
      end
    end
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
        if not btn then
          return
        end
        local id = ItemIdFromFrame(btn)
        local prev = btn.masonKbId
        if prev ~= nil and (not id or prev ~= id) then
          ClearKbIdentity(btn)
          ClearHotkeyVisual(btn)
        end
        if not id then
          ClearKbIdentity(btn)
          ClearHotkeyVisual(btn)
          if Mason.bindMode and Mason.AttachBagButtonHover then
            Mason:AttachBagButtonHover(btn)
          end
          return
        end
        StampKbIdentity(btn, "item", id)
        if Mason.PaintKbOverlay then
          Mason:PaintKbOverlay(btn, "item", id)
        end
        if Mason.bindMode and Mason.AttachBagButtonHover then
          Mason:AttachBagButtonHover(btn)
        end
      end)
    end
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

function Mason:InstallSourceHoverMixins()
  -- 09ab: one mixin install per source kind; gold glow only; no per-open Raise.
  -- Retry when mixins were nil at first kb (load-on-demand frames).
  self.masonSourceHoverMixinSeen = self.masonSourceHoverMixinSeen or {}
  local function hookEnter(mixin, kind, idFn)
    if not mixin or self.masonSourceHoverMixinSeen[mixin] then
      return false
    end
    if not mixin.OnEnter then
      return false
    end
    self.masonSourceHoverMixinSeen[mixin] = true
    hooksecurefunc(mixin, "OnEnter", function(btn)
      if not Mason.bindMode or not btn then
        return
      end
      local useKind = kind
      local id
      local resolvedKind, resolvedId = Mason:ResolveKbIdentity(btn, kind)
      if resolvedId then
        id = resolvedId
        useKind = resolvedKind or kind
      elseif idFn then
        id = idFn(btn)
        if id then
          StampKbIdentity(btn, useKind, id)
        end
      end
      if Mason.AttachKbHover then
        Mason:AttachKbHover(btn, useKind, id)
      end
      Mason:ShowBindHoverOnFrame(btn)
    end)
    if mixin.OnLeave then
      hooksecurefunc(mixin, "OnLeave", function(btn)
        if Mason.bindHoverEnterFrame == btn then
          Mason.bindHoverEnterFrame = nil
          Mason:HideBindHoverHighlight()
        end
      end)
    end
    return true
  end
  local hookedItem = hookEnter(_G.ContainerFrameItemButtonMixin, "item", ItemIdFromFrame)
  hookedItem = hookEnter(_G.ContainerFrameItemElementMixin, "item", ItemIdFromFrame) or hookedItem
  hookEnter(_G.SpellBookItemMixin, "spell", SpellIdFromFrame)
  hookEnter(_G.SpellBookItemButtonMixin, "spell", SpellIdFromFrame)
  hookEnter(_G.ToySpellButtonMixin, "toy", ToyIdFromFrame)
  hookEnter(_G.MacroButtonMixin, "macro", MacroNameFromFrame)
  if hookedItem then
    self.masonBagHoverMixins = true
  end
end

function Mason:InstallBagHoverMixins()
  self:InstallSourceHoverMixins()
end

function Mason:AttachKbBagHover()
  if not self.bindMode then
    return
  end
  if self.InstallSourceHoverMixins then
    pcall(self.InstallSourceHoverMixins, self)
  elseif self.InstallBagHoverMixins then
    pcall(self.InstallBagHoverMixins, self)
  end
  -- 09aa: do not ReassertBindCatcher (was ShowBindVeil → raise from bag paint).
  local a = KB_ADAPTERS.item
  local buttons = a.buttons()
  for i = 1, #buttons do
    local btn = buttons[i]
    local _, id = self:ResolveKbIdentity(btn, "item")
    if not id then
      id = a.identity(btn)
      if id then
        StampKbIdentity(btn, "item", id)
      end
    end
    self:AttachKbHover(btn, "item", id)
    if id then
      self:PaintKbOverlay(btn, "item", id)
    end
  end
end

function Mason:PassBagsRaiseAndPaint(fromRetry)
  -- Always-on store paint; attach hover only in kb. Never raise / ShowBindVeil.
  -- B-02: single painter — RepaintSourceHotkeys only (no PaintBagHotkeys fallback).
  if self.InstallSourceHoverMixins then
    pcall(self.InstallSourceHoverMixins, self)
  end
  self:RepaintSourceHotkeys()
  if self.bindMode and self.AttachKbBagHover then
    pcall(self.AttachKbBagHover, self)
  end
end

function Mason:ScheduleBagFollowup()
  -- SPEC: deferred After(0) once per panel Show. No empty-retry waves.
  if self.masonBagFollowup then
    return
  end
  self.masonBagFollowup = true
  local function run()
    Mason.masonBagFollowup = nil
    -- Always-on store paint (QA r4): not gated on /mason kb.
    if Mason.InstallSourceHoverMixins then
      pcall(Mason.InstallSourceHoverMixins, Mason)
    end
    if Mason.RaiseBindBagFrames then
      pcall(Mason.RaiseBindBagFrames, Mason) -- hooks only (no Raise)
    end
    Mason:PassBagsRaiseAndPaint(true)
  end
  if not (C_Timer and C_Timer.After) then
    run()
    return
  end
  C_Timer.After(0, run)
end

function Mason:OnBagsOpened()
  -- Always-on store paint; never raise / never walk item pools from bag Show.
  self:ScheduleBagFollowup()
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

function Mason:PassMacroRaiseAndPaint()
  -- 09ab: never Raise MacroFrame/Selector (raise blanks grid). Paint from store only.
  -- B-02: single painter — RepaintSourceHotkeys only (PaintMacroHotkeys deleted).
  self:HookMacroSelectorFillSignals()
  if self.InstallSourceHoverMixins then
    pcall(self.InstallSourceHoverMixins, self)
  end
  self:RepaintSourceHotkeys()
  local n = self:CountMacroButtons()
  if n == 0 then
    self.masonMacroNeedButtons = true
  else
    self.masonMacroNeedButtons = nil
  end
  return n
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
        if sel.ScrollBox then
          EachScrollBoxFrame(sel.ScrollBox, function(btn)
            ClearKbIdentity(btn)
            ClearMacroHotkeyVisual(btn)
            local host = MacroHotkeyHost(btn)
            if host then
              ClearKbIdentity(host)
              ClearMacroHotkeyVisual(host)
            end
          end)
        end
        Mason:RepaintSourceHotkeys()
      end)
    end
    if sel.TabSystem and sel.TabSystem.SetTab then
      hooksecurefunc(sel.TabSystem, "SetTab", function()
        if sel.ScrollBox then
          EachScrollBoxFrame(sel.ScrollBox, function(btn)
            ClearKbIdentity(btn)
            ClearMacroHotkeyVisual(btn)
            local host = MacroHotkeyHost(btn)
            if host then
              ClearKbIdentity(host)
              ClearMacroHotkeyVisual(host)
            end
          end)
        end
        Mason:RepaintSourceHotkeys()
      end)
    end
  end
  if sel and sel.ScrollBox and not sel.ScrollBox.masonHotkeyRecycle then
    sel.ScrollBox.masonHotkeyRecycle = true
    local function clearMacroCellStamps(btn)
      if not btn then
        return
      end
      ClearKbIdentity(btn)
      ClearMacroHotkeyVisual(btn)
      local host = MacroHotkeyHost(btn)
      if host and host ~= btn then
        ClearKbIdentity(host)
        ClearMacroHotkeyVisual(host)
      end
      if btn.Button and btn.Button ~= host then
        ClearKbIdentity(btn.Button)
        ClearMacroHotkeyVisual(btn.Button)
      end
    end
    local function paintMacroCell(btn)
      if not btn then
        return
      end
      clearMacroCellStamps(btn)
      local _, id = Mason:ResolveKbIdentity(btn, "macro")
      if not id then
        id = MacroNameFromFrame(btn)
      end
      if id then
        StampKbIdentity(btn, "macro", id)
      end
      local host = MacroHotkeyHost(btn) or btn
      if id then
        StampKbIdentity(host, "macro", id)
        if Mason.PaintKbOverlay then
          Mason:PaintKbOverlay(host, "macro", id)
        end
      end
      if Mason.bindMode then
        Mason:AttachKbHover(host, "macro", id)
        if host ~= btn then
          Mason:AttachKbHover(btn, "macro", id)
        end
      end
    end
    if sel.ScrollBox.RegisterCallback then
      pcall(sel.ScrollBox.RegisterCallback, sel.ScrollBox, "OnAcquiredFrame", function(_, btn)
        paintMacroCell(btn)
      end)
      pcall(sel.ScrollBox.RegisterCallback, sel.ScrollBox, "OnScroll", function()
        Mason:RepaintSourceHotkeys()
      end)
    end
    if sel.ScrollBox.Update and not sel.ScrollBox.masonMacroUpdatePaint then
      sel.ScrollBox.masonMacroUpdatePaint = true
      hooksecurefunc(sel.ScrollBox, "Update", function(box)
        if Mason.masonMacroUpdateRepainting then
          return
        end
        Mason.masonMacroUpdateRepainting = true
        EachScrollBoxFrame(box or sel.ScrollBox, clearMacroCellStamps)
        Mason:RepaintSourceHotkeys()
        Mason.masonMacroUpdateRepainting = nil
      end)
    end
    if sel.ScrollBox.HookScript then
      pcall(function()
        sel.ScrollBox:HookScript("OnMouseWheel", function()
          Mason:RepaintSourceHotkeys()
        end)
      end)
    end
  end
  if not self.masonMacroTabHook then
    self.masonMacroTabHook = true
    if type(_G.MacroFrame_SetAccountMacros) == "function" then
      hooksecurefunc("MacroFrame_SetAccountMacros", function()
        Mason:RepaintSourceHotkeys()
      end)
    end
    if type(_G.MacroFrame_SetCharacterMacros) == "function" then
      hooksecurefunc("MacroFrame_SetCharacterMacros", function()
        Mason:RepaintSourceHotkeys()
      end)
    end
  end
end

function Mason:ScheduleMacroFollowup()
  -- Paint only when MacroUI is loaded and selector already has cells.
  -- Cold first Show: HookMacroSelectorFillSignals OnAcquiredFrame/SetTab paints when data arrives.
  -- Never SoftFill / Rebuild / Raise.
  if self.masonMacroFollowup then
    return
  end
  self.masonMacroFollowup = true
  local function run()
    Mason.masonMacroFollowup = nil
    -- Always-on store paint: not gated on /mason kb.
    if not _G.MacroFrame then
      return
    end
    if Mason.InstallSourceHoverMixins then
      pcall(Mason.InstallSourceHoverMixins, Mason)
    end
    Mason:HookMacroSelectorFillSignals()
    if Mason:CountMacroButtons() > 0 then
      Mason:PassMacroRaiseAndPaint()
    end
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(0, run)
  else
    run()
  end
end

function Mason:OnMacroOpened()
  -- Always-on store paint; never raise MacroFrame. Hook fill signals; paint when cells exist.
  -- B-02: ScheduleMacroFollowup → PassMacroRaiseAndPaint → RepaintSourceHotkeys only.
  if self.HookMacroSelectorFillSignals then
    pcall(self.HookMacroSelectorFillSignals, self)
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
        -- Deferred store paint (RequestBlizzardHotkeys → RepaintSourceHotkeys).
        Mason:RequestBlizzardHotkeys()
      elseif kind == "spell" then
        Mason:ScheduleSpellbookHotkeys()
      end
    end)
  end
end

function Mason:EnsureSourcePaintMixins()
  -- Retry when Blizzard LoD addons define mixins after first login install.
  self.masonSourcePaintMixinSeen = self.masonSourcePaintMixinSeen or {}
  local seen = self.masonSourcePaintMixinSeen
  local function hookMixinOnShow(mixin, kind)
    if not mixin or not mixin.OnShow or seen[mixin] then
      return
    end
    seen[mixin] = true
    hooksecurefunc(mixin, "OnShow", function(selfBtn)
      if kind == "paint" then
        local cell = SpellIconFromRow(selfBtn) or selfBtn
        local _, sid = Mason:ResolveKbIdentity(cell, "spell")
        if not sid then
          _, sid = Mason:ResolveKbIdentity(selfBtn, "spell")
        end
        sid = sid or SpellIdFromFrame(selfBtn) or SpellIdFromFrame(cell)
        if sid then
          StampKbIdentity(cell, "spell", sid)
          Mason:PaintKbOverlay(cell, "spell", sid)
        else
          local _, tid = Mason:ResolveKbIdentity(cell, "toy")
          tid = tid or ToyIdFromFrame(selfBtn)
          if tid then
            StampKbIdentity(cell, "toy", tid)
            Mason:PaintKbOverlay(cell, "toy", tid)
          end
        end
      else
        -- Book/collections chrome show → deferred store painter.
        Mason:RequestBlizzardHotkeys()
      end
    end)
  end
  hookMixinOnShow(SpellBookItemMixin, "paint")
  hookMixinOnShow(SpellBookItemButtonMixin, "paint")
  hookMixinOnShow(ToySpellButtonMixin, "paint")
  hookMixinOnShow(SpellBookFrameMixin, "book")
  if PlayerSpellsFrameMixin and PlayerSpellsFrameMixin.OnShow and not seen.PlayerSpellsFrameMixin then
    seen.PlayerSpellsFrameMixin = true
    hooksecurefunc(PlayerSpellsFrameMixin, "OnShow", function()
      if Mason.InstallHotkeyFrameHooks then
        pcall(Mason.InstallHotkeyFrameHooks, Mason)
      end
      if Mason.ScheduleSpellbookHotkeys then
        pcall(Mason.ScheduleSpellbookHotkeys, Mason)
      end
    end)
  end
  if MacroFrameMixin and MacroFrameMixin.OnShow and not seen.MacroFrameMixin then
    seen.MacroFrameMixin = true
    hooksecurefunc(MacroFrameMixin, "OnShow", function()
      if Mason.OnMacroOpened then
        pcall(Mason.OnMacroOpened, Mason)
      end
    end)
  end
  if CollectionsJournalMixin and CollectionsJournalMixin.OnShow and not seen.CollectionsJournalMixin then
    seen.CollectionsJournalMixin = true
    hooksecurefunc(CollectionsJournalMixin, "OnShow", function()
      if Mason.InstallHotkeyFrameHooks then
        pcall(Mason.InstallHotkeyFrameHooks, Mason)
      end
      if Mason.RequestBlizzardHotkeys then
        pcall(Mason.RequestBlizzardHotkeys, Mason)
      end
    end)
  end
end

function Mason:InstallBindBagHooks()
  if self.InstallSourceHoverMixins then
    pcall(self.InstallSourceHoverMixins, self)
  elseif self.InstallBagHoverMixins then
    pcall(self.InstallBagHoverMixins, self)
  end
  if self.EnsureSourcePaintMixins then
    pcall(self.EnsureSourcePaintMixins, self)
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
    if self.HookMacroSelectorFillSignals then
      pcall(self.HookMacroSelectorFillSignals, self)
    end
    if self.HookHotkeyRecycle then
      pcall(self.HookHotkeyRecycle, self)
    end
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
  -- MacroFrameMixin / PlayerSpellsFrameMixin OnShow: EnsureSourcePaintMixins (LoD-safe).
  if type(_G.TogglePlayerSpells) == "function" then
    hooksecurefunc("TogglePlayerSpells", function()
      if Mason.ScheduleSpellbookHotkeys then
        pcall(Mason.ScheduleSpellbookHotkeys, Mason)
      end
    end)
  end
  if type(_G.ToggleSpellBook) == "function" then
    hooksecurefunc("ToggleSpellBook", function()
      if Mason.ScheduleSpellbookHotkeys then
        pcall(Mason.ScheduleSpellbookHotkeys, Mason)
      end
    end)
  end
  if type(_G.ToggleCollectionsJournal) == "function" then
    hooksecurefunc("ToggleCollectionsJournal", function()
      if Mason.RequestBlizzardHotkeys then
        pcall(Mason.RequestBlizzardHotkeys, Mason)
      end
    end)
  end
  if self.EnsureSourcePaintMixins then
    pcall(self.EnsureSourcePaintMixins, self)
  end
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
        if Mason.RequestBlizzardHotkeys then
          pcall(Mason.RequestBlizzardHotkeys, Mason)
        end
      elseif name == "PlayerSpellsFrame" or name == "SpellBookFrame" then
        if Mason.RememberSpellBookFrame then
          pcall(Mason.RememberSpellBookFrame, Mason, frame)
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

function Mason:HookToyKbShow(frame)
  if not frame or frame.masonKbToyShowAlways then
    return
  end
  frame.masonKbToyShowAlways = true
  if frame.HookScript then
    frame:HookScript("OnShow", function()
      -- B-02: deferred schedule → RepaintSourceHotkeys (no RefreshBlizzard fallback).
      Mason:RequestBlizzardHotkeys()
    end)
  end
end

function Mason:ShowBindVeil()
  -- 09ab: veil dim only — never Raise Blizzard frames to "undim".
  if self.showingBindVeil then
    return
  end
  self.showingBindVeil = true
  pcall(function()
    local veil = self:EnsureBindVeil()
    if not veil then
      return
    end
    veil:EnableMouse(false)
    veil:SetFrameStrata(BIND_VEIL_STRATA)
    veil:SetFrameLevel(BIND_VEIL_LEVEL)
    veil:Show()
    if self.InstallBindBagHooks then
      self:InstallBindBagHooks()
    end
  end)
  self.showingBindVeil = nil
end

function Mason:HideBindVeil()
  if self.bindVeil then
    self.bindVeil:EnableMouse(false)
    self.bindVeil:Hide()
  end
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
    local target = Mason:GetBindHoverTarget()
    if target then
      local wheel = (delta or 0) > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"
      Mason:OnBindCatcherKey(self, wheel)
      return
    end
    -- No bind cell under cursor: forward wheel so macro/book/toy grids can scroll.
    local foci = Mason.GetMouseFocusList and Mason:GetMouseFocusList() or {}
    for i = 1, #foci do
      local f = foci[i]
      if f and f ~= self and f ~= Mason.bindVeil and f.GetScript then
        local script = f:GetScript("OnMouseWheel")
        if script then
          script(f, delta)
          return
        end
      end
    end
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
    if self.InstallSourceHoverMixins then
      pcall(self.InstallSourceHoverMixins, self)
    end
    -- Hooks only (no Raise). Sync bag attach if cells already exist; else OnAcquiredFrame/Update.
    if self.RaiseBindBagFrames then
      pcall(self.RaiseBindBagFrames, self)
    end
    local itemButtons = KB_ADAPTERS.item and KB_ADAPTERS.item.buttons and KB_ADAPTERS.item.buttons() or {}
    if self.bindMode and #itemButtons > 0 and self.AttachKbBagHover then
      pcall(self.AttachKbBagHover, self)
    end
    local function afterKbOn()
      if not Mason.bindMode then
        return
      end
      -- B-02: one store painter entry; panel-specific schedule only for hooks/fill.
      Mason:RepaintSourceHotkeys()
      local mf = _G.MacroFrame
      if mf and Mason.HookMacroSelectorFillSignals then
        pcall(Mason.HookMacroSelectorFillSignals, Mason)
      end
      local ps = _G.PlayerSpellsFrame
      if ps and ps.IsShown and ps:IsShown() and Mason.ScheduleSpellbookHotkeys then
        Mason:ScheduleSpellbookHotkeys()
      end
      local toy = _G.ToyBox
      if toy and toy.IsShown and toy:IsShown() then
        Mason:RequestBlizzardHotkeys()
      end
    end
    if C_Timer and C_Timer.After then
      C_Timer.After(0, afterKbOn)
    else
      afterKbOn()
    end
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

function MacroHotkeyHost(btn)
  -- Paint host = icon button (not the tall grid row/col container).
  if not CanUndimFrame(btn) then
    return nil
  end
  local iconBtn = btn.Button or btn.IconButton or btn.iconButton or btn.SpellButton
  if iconBtn and CanUndimFrame(iconBtn) then
    return iconBtn
  end
  local iconTex = FindButtonIconTexture(btn)
  if iconTex and iconTex.GetParent then
    local p = iconTex:GetParent()
    if p and CanUndimFrame(p) and p ~= btn then
      local ph = p.GetHeight and p:GetHeight() or 0
      local pw = p.GetWidth and p:GetWidth() or 0
      if ph > 0 and ph <= 50 and pw > 0 and pw <= 50 then
        return p
      end
    end
  end
  local h = btn.GetHeight and btn:GetHeight() or 0
  local w = btn.GetWidth and btn:GetWidth() or 0
  if h > 50 or (w > 0 and h > 0 and w > (h * 1.6)) then
    if btn.GetChildren then
      local children = { btn:GetChildren() }
      for i = 1, #children do
        local c = children[i]
        if CanUndimFrame(c) and c.IsObjectType and (c:IsObjectType("Button") or c:IsObjectType("CheckButton")) then
          local ch = c.GetHeight and c:GetHeight() or 0
          local cw = c.GetWidth and c:GetWidth() or 0
          if ch >= 24 and ch <= 50 and cw >= 24 and cw <= 50 then
            return c
          end
        end
      end
    end
    -- Wide ScrollBox row: parent FontString to the icon texture's frame, never row chrome.
    local iconTex = FindButtonIconTexture(btn)
    if iconTex and iconTex.GetParent then
      local p = iconTex:GetParent()
      if p and CanUndimFrame(p) then
        return p
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

function Mason:EnsureBlizzardHotkeyFont(btn, identityKind)
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
  local isMacro = (identityKind == "macro")
    or (btn.masonKbKind == "macro")
    or (HotkeyKind(btn) == "macro")
  local cell = btn
  if isMacro then
    cell = MacroHotkeyHost(btn)
    if not cell then
      local iconTex = FindButtonIconTexture(btn) or FindIconRegion(btn)
      if iconTex and iconTex.GetParent then
        local p = iconTex:GetParent()
        if p and CanUndimFrame(p) and not IsHotkeyHostWindow(p) then
          cell = p
        end
      end
    end
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
  -- Parent to icon button; anchor to icon texture (not the grid row).
  local parent = cell
  if icon and icon.GetParent then
    local ip = icon:GetParent()
    if ip and CanUndimFrame(ip) then
      parent = ip
    end
  end
  if fs.SetParent then
    fs:SetParent(parent)
  end
  local look = self:GetPieceHotkeyLook()
  fs:SetFont(look.font, look.size, look.flags)
  fs:SetTextColor(look.r, look.g, look.b, look.a)
  fs:SetJustifyH("RIGHT")
  fs:ClearAllPoints()
  if icon then
    fs:SetPoint("TOPRIGHT", icon, "TOPRIGHT", -2, -2)
  else
    fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -2, -2)
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

function Mason:ScheduleSpellbookHotkeys()
  -- SPEC: one deferred After(0) paint from store — no empty-retry waves.
  -- B-02: RepaintSourceHotkeys only (no PaintSpellbook / RefreshBlizzard fallbacks).
  if self.masonSpellPaintQueued then
    return
  end
  self.masonSpellPaintQueued = true
  local function paint()
    Mason.masonSpellPaintQueued = nil
    -- Always-on store paint: not gated on /mason kb.
    if Mason.EnsureSourcePaintMixins then
      pcall(Mason.EnsureSourcePaintMixins, Mason)
    end
    if Mason.InstallHotkeyFrameHooks then
      pcall(Mason.InstallHotkeyFrameHooks, Mason)
    end
    if Mason.InstallSourceHoverMixins then
      pcall(Mason.InstallSourceHoverMixins, Mason)
    end
    Mason:RepaintSourceHotkeys()
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(0, paint)
  else
    paint()
  end
end

function Mason:RequestBlizzardHotkeys()
  -- Deferred After(0) coalesce into the single store painter (toys / collections).
  if self.masonHotkeyQueued then
    return
  end
  self.masonHotkeyQueued = true
  local run = function()
    Mason.masonHotkeyQueued = nil
    if Mason.EnsureSourcePaintMixins then
      pcall(Mason.EnsureSourcePaintMixins, Mason)
    end
    if Mason.InstallHotkeyFrameHooks then
      pcall(Mason.InstallHotkeyFrameHooks, Mason)
    end
    Mason:RepaintSourceHotkeys()
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(0, run)
  else
    run()
  end
end

function Mason:ClearSourceHotkeys()
  local tracked = self.blizzardHotkeyButtons
  if not tracked then
    return
  end
  for btn in pairs(tracked) do
    if btn then
      local fs = btn.masonHotkey
      if fs then
        fs:SetText("")
        fs:Hide()
      end
      -- Drop durable stamps so recycle/empty cells cannot repaint ghosts.
      if btn.masonKbKind == "item" or IsBagItemButton(btn) then
        ClearKbIdentity(btn)
      end
    end
  end
  self.blizzardHotkeyButtons = {}
end

function Mason:RepaintSourceHotkeys()
  -- 09ab / B-02: sole public store painter — clear tracked hosts, then paint from KeyForIdentity.
  if InCombatLockdown() then
    return self:QueueIfCombat(function()
      Mason:RepaintSourceHotkeys()
    end)
  end
  if self.InstallHotkeyFrameHooks then
    self:InstallHotkeyFrameHooks()
  end
  if self.InstallSourceHoverMixins then
    pcall(self.InstallSourceHoverMixins, self)
  end
  self:ClearSourceHotkeys()
  self:PaintKbAdapter("spell")
  self:PaintKbAdapter("item")
  self:PaintKbAdapter("toy")
  self:PaintKbAdapter("macro")
end

function Mason:PaintToyCellHotkey(btn)
  if not btn then
    return
  end
  local id = ToyIdFromFrame(btn)
  if not id then
    local _, resolved = self:ResolveKbIdentity(btn, "toy")
    id = resolved
  end
  if id then
    StampKbIdentity(btn, "toy", id)
    self:PaintKbOverlay(btn, "toy", id)
  else
    ClearKbIdentity(btn)
    ClearHotkeyVisual(btn)
  end
end

function Mason:HookHotkeyRecycle()
  -- LoD-safe: Blizzard_Collections / PlayerSpells may load after first login install.
  -- B-02: page/scroll/wheel → RepaintSourceHotkeys only (no PaintToy / PaintSpellbook aliases).
  self.masonHotkeyRecycleHooks = self.masonHotkeyRecycleHooks or {}
  local seen = self.masonHotkeyRecycleHooks
  if not seen["ToyBox_OnMouseWheel"] and type(_G.ToyBox_OnMouseWheel) == "function" then
    seen["ToyBox_OnMouseWheel"] = true
    hooksecurefunc("ToyBox_OnMouseWheel", function()
      Mason:RepaintSourceHotkeys()
    end)
  end
  if not seen["ToyBox_UpdateButtons"] and type(_G.ToyBox_UpdateButtons) == "function" then
    seen["ToyBox_UpdateButtons"] = true
    hooksecurefunc("ToyBox_UpdateButtons", function()
      Mason:RepaintSourceHotkeys()
    end)
  end
  if not seen["ToySpellButton_UpdateButton"] and type(_G.ToySpellButton_UpdateButton) == "function" then
    seen["ToySpellButton_UpdateButton"] = true
    hooksecurefunc("ToySpellButton_UpdateButton", function(btn)
      if Mason.PaintToyCellHotkey then
        Mason:PaintToyCellHotkey(btn)
      end
    end)
  end
  if ToySpellButtonMixin and ToySpellButtonMixin.UpdateButton and not seen[ToySpellButtonMixin] then
    seen[ToySpellButtonMixin] = true
    hooksecurefunc(ToySpellButtonMixin, "UpdateButton", function(btn)
      if btn then
        local id = ToyIdFromFrame(btn)
        if id then
          StampKbIdentity(btn, "toy", id)
        else
          ClearKbIdentity(btn)
          ClearHotkeyVisual(btn)
        end
      end
      if Mason.PaintToyCellHotkey then
        Mason:PaintToyCellHotkey(btn)
      end
    end)
  end
  local box = _G.ToyBox
  if box then
    if box.PagingFrame and box.PagingFrame.SetCurrentPage and not box.PagingFrame.masonHotkeyPage then
      box.PagingFrame.masonHotkeyPage = true
      hooksecurefunc(box.PagingFrame, "SetCurrentPage", function()
        Mason:RepaintSourceHotkeys()
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
          Mason:RepaintSourceHotkeys()
        end)
      end
    end
    if box.HookScript and not box.masonHotkeyWheel then
      box.masonHotkeyWheel = true
      pcall(function()
        box:HookScript("OnMouseWheel", function()
          Mason:RepaintSourceHotkeys()
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
        Mason:RepaintSourceHotkeys()
      end)
    end
    if frame.GoToPage then
      hooksecurefunc(frame, "GoToPage", function()
        Mason:RepaintSourceHotkeys()
      end)
    end
    if frame.PagingFrame and frame.PagingFrame.SetCurrentPage then
      hooksecurefunc(frame.PagingFrame, "SetCurrentPage", function()
        Mason:RepaintSourceHotkeys()
      end)
    end
    if frame.ScrollBox and frame.ScrollBox.RegisterCallback and not frame.ScrollBox.masonSpellAcquire then
      frame.ScrollBox.masonSpellAcquire = true
      pcall(frame.ScrollBox.RegisterCallback, frame.ScrollBox, "OnAcquiredFrame", function(_, btn)
        local cell = SpellIconFromRow(btn) or btn
        local id = SpellIdFromFrame(btn) or SpellIdFromFrame(cell)
        if not id and btn.GetParent then
          id = SpellIdFromFrame(btn:GetParent())
        end
        if id then
          StampKbIdentity(cell, "spell", id)
          Mason:PaintKbOverlay(cell, "spell", id)
        else
          ClearKbIdentity(cell)
          ClearHotkeyVisual(cell)
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
      if not id then
        local _, resolved = Mason:ResolveKbIdentity(cell, "spell")
        id = resolved
      end
      if not id then
        local _, resolved = Mason:ResolveKbIdentity(selfBtn, "spell")
        id = resolved
      end
      if id then
        StampKbIdentity(cell, "spell", id)
        StampKbIdentity(selfBtn, "spell", id)
        Mason:PaintKbOverlay(cell, "spell", id)
      else
        ClearKbIdentity(cell)
        ClearKbIdentity(selfBtn)
        ClearHotkeyVisual(cell)
        ClearHotkeyVisual(selfBtn)
      end
    end)
  end
  if SpellBookItemButtonMixin and SpellBookItemButtonMixin.Update and not self.masonSpellBtnUpdateHook then
    self.masonSpellBtnUpdateHook = true
    hooksecurefunc(SpellBookItemButtonMixin, "Update", function(selfBtn)
      local cell = SpellIconFromRow(selfBtn) or selfBtn
      local id = SpellIdFromFrame(selfBtn) or SpellIdFromFrame(cell)
      if not id then
        local _, resolved = Mason:ResolveKbIdentity(cell, "spell")
        id = resolved
      end
      if not id then
        local _, resolved = Mason:ResolveKbIdentity(selfBtn, "spell")
        id = resolved
      end
      if id then
        StampKbIdentity(cell, "spell", id)
        StampKbIdentity(selfBtn, "spell", id)
        Mason:PaintKbOverlay(cell, "spell", id)
      else
        ClearKbIdentity(cell)
        ClearKbIdentity(selfBtn)
        ClearHotkeyVisual(cell)
        ClearHotkeyVisual(selfBtn)
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
        Mason:RepaintSourceHotkeys()
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
        Mason:ScheduleSpellbookHotkeys()
      elseif frame == _G.ContainerFrameCombinedBags or name == "ContainerFrameCombinedBags" or (name and string.find(name, "ContainerFrame", 1, true)) then
        -- B-02: bags → ScheduleBagFollowup via OnBagsOpened only.
        if Mason.OnBagsOpened then
          pcall(Mason.OnBagsOpened, Mason)
        end
      else
        Mason:RepaintSourceHotkeys()
      end
    end)
  end
end
