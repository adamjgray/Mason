local Mason = LibStub("AceAddon-3.0"):GetAddon("Mason")

-- Mason course flyouts: kind mason (slash) and blizzard-slots (spellbook drop).
-- Parent click uses MasonFlyoutHeader WrapScript Show/Hide children. No SpellFlyout.

local MAX_CHILDREN = 12
local GAP = 2

local function FlyoutChildCap()
  return tonumber(MAX_CHILDREN) or 12
end

local function IsCourseKind(kind)
  return kind == "mason" or kind == "blizzard-slots"
end

local FLYOUT_WRAP = [[
  if self:GetAttribute("masonFlyout") then
    local onDown = self:GetAttribute("useOnKeyDown")
    if onDown ~= false then
      if down then
        owner:RunAttribute("masonToggle", self:GetName())
      end
    else
      if not down then
        owner:RunAttribute("masonToggle", self:GetName())
      end
    end
  end
]]

local HIDE_NAMED = [[
  local n = ...
  if not n then
    return
  end
  local ui = self:GetFrameRef("UIParent")
  for i = 1, 12 do
    local c = self:GetFrameRef(n .. "_FO" .. i)
    if c then
      c:Hide()
      c:EnableMouse(false)
      c:SetAlpha(0)
      c:ClearAllPoints()
      if ui then
        c:SetPoint("TOPLEFT", ui, "BOTTOMLEFT", -2000, -2000)
      end
    end
  end
]]

local HIDE_OPEN = [[
  local n = self:GetAttribute("masonOpen")
  if n then
    self:RunAttribute("masonHideNamed", n)
    self:SetAttribute("masonOpen", nil)
    self:CallMethod("MasonFlyoutState", n, "0")
  end
]]

local TOGGLE = [[
  local name = ...
  if not name then
    return
  end
  local open = self:GetAttribute("masonOpen")
  if open == name then
    self:RunAttribute("masonHideNamed", name)
    self:SetAttribute("masonOpen", nil)
    self:CallMethod("MasonFlyoutState", name, "0")
    return
  end
  if open then
    self:RunAttribute("masonHideNamed", open)
    self:CallMethod("MasonFlyoutState", open, "0")
  end
  local ui = self:GetFrameRef("UIParent")
  if not ui then
    return
  end
  for i = 1, 12 do
    local c = self:GetFrameRef(name .. "_FO" .. i)
    if c then
      local x = self:GetAttribute(name .. "_FOX" .. i)
      local y = self:GetAttribute(name .. "_FOY" .. i)
      local sz = self:GetAttribute(name .. "_FOS" .. i)
      if x and y then
        c:ClearAllPoints()
        c:SetPoint("CENTER", ui, "BOTTOMLEFT", x, y)
        if sz then
          c:SetSize(sz, sz)
        end
        c:SetParent(ui)
        c:SetAlpha(1)
        c:EnableMouse(true)
        c:Show()
      end
    end
  end
  self:SetAttribute("masonOpen", name)
  self:CallMethod("MasonFlyoutState", name, "1")
]]

local function PieceIdFromExecName(name)
  if not name then
    return nil
  end
  return string.match(name, "^MasonExec_(.+)$")
end

function Mason:IsBlizzardFlyoutPiece(id)
  local piece = self:FindPiece(id)
  return piece and piece.type == "flyout"
end

function Mason:FlyoutLabel(flyoutId)
  flyoutId = tonumber(flyoutId)
  if not flyoutId or not GetFlyoutInfo then
    return nil
  end
  local ok, name = pcall(GetFlyoutInfo, flyoutId)
  if ok and type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

function Mason:FlyoutTexture(flyoutId)
  flyoutId = tonumber(flyoutId)
  if not flyoutId then
    return 134400
  end
  if GetFlyoutInfo then
    local ok, _, _, _, _, icon = pcall(GetFlyoutInfo, flyoutId)
    if ok then
      icon = tonumber(icon)
      if icon and icon > 10 then
        return icon
      end
    end
  end
  local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
  local flyoutType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Flyout
  if bank and flyoutType and C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookSkillLineInfo then
    local n = C_SpellBook.GetNumSpellBookSkillLines() or 0
    for i = 1, n do
      local line = C_SpellBook.GetSpellBookSkillLineInfo(i)
      if line and line.numSpellBookItems then
        local offset = line.itemIndexOffset or 0
        for j = offset + 1, offset + line.numSpellBookItems do
          local itemType, actionID
          if C_SpellBook.GetSpellBookItemType then
            itemType, actionID = C_SpellBook.GetSpellBookItemType(j, bank)
          end
          if not itemType and C_SpellBook.GetSpellBookItemInfo then
            local item = C_SpellBook.GetSpellBookItemInfo(j, bank)
            if item then
              itemType = item.itemType
              actionID = item.actionID
              if itemType == flyoutType and tonumber(actionID) == flyoutId then
                if tonumber(item.iconID) then
                  return item.iconID
                end
              end
            end
          elseif itemType == flyoutType and tonumber(actionID) == flyoutId then
            if C_SpellBook.GetSpellBookItemTexture then
              local tex = C_SpellBook.GetSpellBookItemTexture(j, bank)
              if tex then
                return tex
              end
            end
            if C_SpellBook.GetSpellBookItemInfo then
              local item = C_SpellBook.GetSpellBookItemInfo(j, bank)
              if item and tonumber(item.iconID) then
                return item.iconID
              end
            end
          end
        end
      end
    end
  end
  return 134400
end

local function TableFlyoutId(info)
  if type(info) ~= "table" then
    return nil
  end
  local id = info.flyoutID or info.flyoutId or info.spellFlyoutID or info.actionID
  id = tonumber(id)
  if id and id > 0 then
    return id
  end
  return nil
end

function Mason:SpellLooksLikeFlyout(spellID)
  if not spellID then
    return false
  end
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(spellID)
    if type(info) == "table" and (info.isFlyout or info.flyoutID or info.flyoutId or info.spellFlyoutID) then
      return true
    end
  end
  return false
end

function Mason:ResolveFlyoutIDFromSpell(spellID)
  spellID = tonumber(spellID)
  if not spellID then
    return nil
  end
  if C_Spell then
    if C_Spell.GetSpellFlyoutID then
      local ok, id = pcall(C_Spell.GetSpellFlyoutID, spellID)
      id = ok and tonumber(id)
      if id and id > 0 then
        return id
      end
    end
    if C_Spell.GetSpellInfo then
      local info = C_Spell.GetSpellInfo(spellID)
      local id = TableFlyoutId(info)
      if id then
        return id
      end
    end
  end
  local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
  local flyoutType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Flyout
  if C_SpellBook then
    if C_SpellBook.FindSpellBookSlotForSpell then
      local ok, slot, foundBank = pcall(C_SpellBook.FindSpellBookSlotForSpell, spellID)
      if ok and slot and C_SpellBook.GetSpellBookItemInfo then
        local item = C_SpellBook.GetSpellBookItemInfo(slot, foundBank or bank)
        if item then
          local itype = item.itemType or item.spellBookItemType
          if flyoutType and itype == flyoutType then
            local id = TableFlyoutId(item)
            if id then
              return id
            end
          end
          local id = TableFlyoutId(item)
          if id and (itype == flyoutType or item.isFlyout) then
            return id
          end
        end
      end
    end
    if C_SpellBook.GetSpellBookItemType and C_SpellBook.FindSpellBookSlotForSpell then
      local ok, slot, foundBank = pcall(C_SpellBook.FindSpellBookSlotForSpell, spellID)
      if ok and slot then
        local tok, typeOrId, extra = pcall(C_SpellBook.GetSpellBookItemType, slot, foundBank or bank)
        if tok then
          if flyoutType and typeOrId == flyoutType then
            extra = tonumber(extra)
            if extra and extra > 0 then
              return extra
            end
          end
        end
      end
    end
    if bank and flyoutType and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookItemInfo then
      local n = C_SpellBook.GetNumSpellBookSkillLines() or 0
      local spellName
      if C_Spell and C_Spell.GetSpellName then
        spellName = C_Spell.GetSpellName(spellID)
      end
      spellName = spellName and string.lower(spellName)
      for i = 1, n do
        local line = C_SpellBook.GetSpellBookSkillLineInfo(i)
        if line and line.numSpellBookItems then
          local offset = line.itemIndexOffset or 0
          for j = offset + 1, offset + line.numSpellBookItems do
            local item = C_SpellBook.GetSpellBookItemInfo(j, bank)
            if item then
              local itype = item.itemType or item.spellBookItemType
              if itype == flyoutType then
                local fid = TableFlyoutId(item)
                if item.spellID == spellID and fid then
                  return fid
                end
                if spellName and item.name and string.lower(item.name) == spellName and fid then
                  return fid
                end
              end
            end
          end
        end
      end
    end
  end
  local spellName
  if C_Spell and C_Spell.GetSpellName then
    spellName = C_Spell.GetSpellName(spellID)
  end
  spellName = spellName and string.lower(spellName)
  if spellName and GetNumFlyouts and GetFlyoutID and GetFlyoutInfo then
    local n = GetNumFlyouts() or 0
    for i = 1, n do
      local fid = GetFlyoutID(i)
      local name = fid and self:FlyoutLabel(fid)
      if name and string.lower(name) == spellName then
        return fid
      end
    end
  end
  return nil
end

function Mason:PrintMissingFlyoutSlotAPI()
  print("Mason: GetFlyoutSlotInfo missing or usage-error")
  local function dump(tbl, prefix)
    if type(tbl) ~= "table" then
      return
    end
    for k, v in pairs(tbl) do
      local n = tostring(k)
      if string.find(string.lower(n), "flyout") then
        print("Mason: " .. prefix .. n .. " type=" .. type(v))
      end
    end
  end
  dump(_G.C_Spell, "C_Spell.")
  dump(_G.C_SpellBook, "C_SpellBook.")
end

function Mason:GetFlyoutSlotFns()
  local fns = {}
  if GetFlyoutSlotInfo then
    fns[#fns + 1] = { name = "GetFlyoutSlotInfo", fn = GetFlyoutSlotInfo }
  end
  if C_Spell and C_Spell.GetFlyoutSlotInfo then
    fns[#fns + 1] = { name = "C_Spell.GetFlyoutSlotInfo", fn = C_Spell.GetFlyoutSlotInfo }
  end
  if C_SpellBook and C_SpellBook.GetFlyoutSlotInfo then
    fns[#fns + 1] = { name = "C_SpellBook.GetFlyoutSlotInfo", fn = C_SpellBook.GetFlyoutSlotInfo }
  end
  return fns
end

function Mason:AcceptsSpellInfo(id)
  id = tonumber(id)
  if not id or id <= 0 then
    return false
  end
  if C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, id)
    if ok and info then
      return true
    end
  end
  if GetSpellInfo then
    local ok, name = pcall(GetSpellInfo, id)
    if ok and name then
      return true
    end
  end
  return false
end

function Mason:SpellIdFromFlyoutSlotValue(v, ids)
  ids = ids or {}
  local t = type(v)
  if t == "number" or t == "string" then
    local n = tonumber(v)
    if n and self:AcceptsSpellInfo(n) then
      ids[#ids + 1] = n
    end
  elseif t == "table" then
    local keys = { "overrideSpellID", "overrideSpellId", "spellID", "spellId", "spell" }
    for i = 1, #keys do
      self:SpellIdFromFlyoutSlotValue(v[keys[i]], ids)
    end
    for _, tv in pairs(v) do
      if type(tv) == "number" or type(tv) == "string" or type(tv) == "table" then
        self:SpellIdFromFlyoutSlotValue(tv, ids)
      end
    end
  end
  return ids
end

function Mason:PrintFlyoutSlotReturns(slot, src, ok, ...)
  local n = select("#", ...)
  if not ok then
    print("Mason: slot" .. tostring(slot) .. " type=error value=" .. tostring(select(1, ...)) .. " src=" .. tostring(src))
    return
  end
  local last = 0
  for i = 1, n do
    if select(i, ...) ~= nil then
      last = i
    end
  end
  if last < 1 then
    print("Mason: slot" .. tostring(slot) .. " type=nil value=nil src=" .. tostring(src))
    return
  end
  for i = 1, last do
    local v = select(i, ...)
    print("Mason: slot" .. tostring(slot) .. " type=" .. type(v) .. " value=" .. tostring(v))
    if type(v) == "table" then
      for k, tv in pairs(v) do
        print("Mason: slot" .. tostring(slot) .. " type=" .. type(tv) .. " value=" .. tostring(tv) .. " key=" .. tostring(k))
      end
    end
  end
end

function Mason:ReadFlyoutSlot(flyoutId, slot)
  local fns = self:GetFlyoutSlotFns()
  if #fns == 0 then
    return nil, nil, nil, "no slot API"
  end
  local spellID
  local known
  local name
  local err
  for i = 1, #fns do
    local r1, r2, r3, r4, r5, r6, r7, r8 = pcall(fns[i].fn, flyoutId, slot)
    if not r1 then
      err = tostring(r2)
    else
      local ids = {}
      self:SpellIdFromFlyoutSlotValue(r2, ids)
      self:SpellIdFromFlyoutSlotValue(r3, ids)
      self:SpellIdFromFlyoutSlotValue(r4, ids)
      self:SpellIdFromFlyoutSlotValue(r5, ids)
      self:SpellIdFromFlyoutSlotValue(r6, ids)
      self:SpellIdFromFlyoutSlotValue(r7, ids)
      self:SpellIdFromFlyoutSlotValue(r8, ids)
      if not spellID and ids[1] then
        spellID = ids[2] or ids[1]
      end
      if type(r4) == "boolean" then
        known = r4
      elseif type(r2) == "table" and type(r2.isKnown) == "boolean" then
        known = r2.isKnown
      elseif type(r3) == "boolean" then
        known = r3
      end
      if type(r5) == "string" then
        name = r5
      elseif type(r2) == "table" and type(r2.name) == "string" then
        name = r2.name
      elseif type(r4) == "string" then
        name = r4
      end
    end
  end
  if not spellID then
    return nil, known, name, err or "nil spellID"
  end
  return spellID, known, name, nil
end

function Mason:PopulateBlizzardFlyoutSlots(parentId, flyoutId)
  if self.masonPopulatingFlyout then
    return false
  end
  flyoutId = tonumber(flyoutId)
  if not parentId or not flyoutId then
    return false
  end
  self.masonPopulatingFlyout = true
  local function done(ret)
    self.masonPopulatingFlyout = false
    return ret
  end
  local fns = self:GetFlyoutSlotFns()
  if #fns == 0 then
    self:PrintMissingFlyoutSlotAPI()
    return done(false)
  end
  local okInfo, a, b, c, d = pcall(GetFlyoutInfo, flyoutId)
  local numSlots
  if okInfo then
    if type(a) == "table" then
      numSlots = tonumber(a.numSlots)
    end
    if type(c) == "number" then
      numSlots = tonumber(c)
    elseif type(b) == "number" and not numSlots then
      numSlots = tonumber(b)
    elseif type(d) == "number" and not numSlots then
      numSlots = tonumber(d)
    elseif type(a) == "number" and not numSlots then
      numSlots = tonumber(a)
    end
  end
  numSlots = tonumber(numSlots)
  if type(numSlots) ~= "number" then
    return done(false)
  end
  if numSlots < 1 then
    return done(true)
  end
  local fo = self:EnsureFlyout(parentId)
  fo.kind = "blizzard-slots"
  fo.blizzardId = flyoutId
  fo.side = fo.side or "top"
  fo.open = false
  fo.childIds = fo.childIds or {}
  local specID = self:GetCurrentSpecID()
  local skipped = {}
  local ok, err = pcall(function()
    for slot = 1, numSlots do
      local sid, _, spellName, why = self:ReadFlyoutSlot(flyoutId, slot)
      if not sid then
        skipped[#skipped + 1] = { slot = slot, why = why or "nil spellID" }
      else
        local name = spellName
        if (not name or name == "") and C_Spell and C_Spell.GetSpellName then
          name = C_Spell.GetSpellName(sid)
        end
        local child = self:FindPieceByAction("spell", { spellID = sid })
        if not child then
          child = self:CreatePiece({
            type = "spell",
            spellID = sid,
            spellName = name,
            specID = specID,
          })
        elseif name then
          child.spellName = child.spellName or name
        end
        if child then
          self:FlyoutAdd(parentId, child.id)
        else
          skipped[#skipped + 1] = { slot = slot, why = "CreatePiece failed" }
        end
      end
    end
    fo.kind = "blizzard-slots"
    fo.open = false
    local kids = fo.childIds or {}
    for i = 1, #kids do
      self:ClearView(kids[i])
    end
  end)
  if not ok then
    print("Mason: populate flyout " .. tostring(err))
    return done(false)
  end
  local piece = self:FindPiece(parentId)
  if piece then
    piece.flyoutBuilt = flyoutId
  end
  local n = fo.childIds and #fo.childIds or 0
  print("Mason: flyout " .. tostring(flyoutId) .. " slots=" .. tostring(numSlots) .. " children=" .. tostring(n))
  if n < numSlots then
    for i = 1, #skipped do
      print("Mason: flyout " .. tostring(flyoutId) .. " skip slot=" .. tostring(skipped[i].slot) .. " " .. tostring(skipped[i].why))
    end
  end
  return done(true)
end

local SIDE_DIR = { top = "UP", bottom = "DOWN", left = "LEFT", right = "RIGHT" }

local function RotateFlyoutArrowTex(tex, dir)
  if not tex then
    return
  end
  local deg
  if dir == "LEFT" then
    deg = 270
  elseif dir == "RIGHT" then
    deg = 90
  elseif dir == "DOWN" then
    deg = 180
  else
    deg = 0
  end
  if SetClampedTextureRotation then
    SetClampedTextureRotation(tex, deg)
  elseif tex.SetRotation then
    tex:SetRotation(math.rad(deg))
  end
end

local function PlaceFlyoutArrowTex(tex, exec, dir, dist)
  tex:ClearAllPoints()
  if dir == "LEFT" then
    tex:SetPoint("LEFT", exec, "LEFT", -dist, 0)
  elseif dir == "RIGHT" then
    tex:SetPoint("RIGHT", exec, "RIGHT", dist, 0)
  elseif dir == "DOWN" then
    tex:SetPoint("BOTTOM", exec, "BOTTOM", 0, -dist)
  else
    tex:SetPoint("TOP", exec, "TOP", 0, dist)
  end
end

local function ApplyFlyoutArrowArt(tex, exec)
  local art = exec.arrowNormalTexture or exec.arrowDownTexture
  if type(art) == "string" then
    if tex.SetAtlas then
      local ok = pcall(tex.SetAtlas, tex, art)
      if not ok then
        tex:SetTexture(art)
      end
    else
      tex:SetTexture(art)
    end
  elseif type(art) == "number" then
    tex:SetTexture(art)
  end
end

function Mason:FlyoutArrowRegions(exec)
  if not exec then
    return {}
  end
  local name = exec.GetName and exec:GetName()
  local named = name and _G[name .. "Arrow"]
  local list = {
    { region = exec.Arrow, label = "Arrow" },
    { region = exec.FlyoutArrow, label = "FlyoutArrow" },
    { region = exec.FlyoutArrowContainer, label = "FlyoutArrowContainer" },
    { region = named, label = name and (name .. "Arrow") or "NamedArrow" },
  }
  local out = {}
  local seen = {}
  for i = 1, #list do
    local r = list[i].region
    if r and not seen[r] then
      seen[r] = true
      out[#out + 1] = list[i]
    end
  end
  return out
end

function Mason:FlyoutParentStillPlaced(exec)
  if not exec then
    return false
  end
  local piece = exec.masonPieceId and self:FindPiece(exec.masonPieceId)
  local view = piece and self:GetViews() and self:GetViews()[piece.id]
  return piece and piece.type == "flyout" and view and view.visible
end

function Mason:AnyFlyoutViewVisible()
  if not self.GetViews then
    return false
  end
  for id, view in pairs(self:GetViews()) do
    if view and view.visible then
      local piece = self:FindPiece(id)
      if piece and piece.type == "flyout" then
        return true
      end
    end
  end
  return false
end

function Mason:EnsureFlyoutArrowTicker()
  if self.masonFlyoutArrowTicker then
    return
  end
  if not C_Timer or not C_Timer.NewTicker then
    return
  end
  self.masonFlyoutArrowTicker = C_Timer.NewTicker(0.1, function()
    if InCombatLockdown() then
      return
    end
    local any = false
    for id, view in pairs(Mason:GetViews()) do
      if view and view.visible then
        local piece = Mason:FindPiece(id)
        if piece and piece.type == "flyout" then
          any = true
          local exec = Mason:ExistingExecutor(id)
          if exec then
            Mason:ShowFlyoutArrow(exec, piece)
          end
        end
      end
    end
    if not any and Mason.masonFlyoutArrowTicker then
      Mason.masonFlyoutArrowTicker:Cancel()
      Mason.masonFlyoutArrowTicker = nil
    end
  end)
end

function Mason:HookArrowRegionHide(exec, region, label)
  if not region or region.masonArrowHideHook then
    return
  end
  region.masonArrowHideHook = true
  local function reshow()
    if region.masonArrowReshow then
      return
    end
    if InCombatLockdown() then
      return
    end
    if not Mason:FlyoutParentStillPlaced(exec) then
      return
    end
    local rname = (region.GetName and region:GetName() and region:GetName() ~= "") and region:GetName() or label or "?"
    print("Mason: arrow hide " .. tostring(rname))
    region.masonArrowReshow = true
    region:Show()
    region.masonArrowReshow = false
  end
  if region.HookScript then
    pcall(function()
      region:HookScript("OnHide", reshow)
    end)
  end
  if region.Hide then
    local orig = region.Hide
    region.Hide = function(self, ...)
      orig(self, ...)
      reshow()
    end
  end
end

function Mason:HideFlyoutArrow(exec)
  if not exec then
    return
  end
  local regions = self:FlyoutArrowRegions(exec)
  for i = 1, #regions do
    local region = regions[i].region
    region.masonArrowReshow = true
    region:Hide()
    region.masonArrowReshow = false
  end
end

function Mason:ShowFlyoutArrow(exec, piece)
  if not exec then
    return
  end
  piece = piece or (exec.masonPieceId and self:FindPiece(exec.masonPieceId))
  local view = piece and self:GetViews() and self:GetViews()[piece.id]
  if not piece or piece.type ~= "flyout" or not view or not view.visible then
    self:HideFlyoutArrow(exec)
    return
  end
  local fo = self:GetFlyout(piece.id)
  local dir = SIDE_DIR[(fo and fo.side) or "top"] or "UP"
  if not InCombatLockdown() then
    exec:SetAttribute("flyoutDirection", dir)
  end
  self:HookFlyoutArrow(exec)
  local regions = self:FlyoutArrowRegions(exec)
  for i = 1, #regions do
    local region = regions[i].region
    self:HookArrowRegionHide(exec, region, regions[i].label)
    region.masonArrowReshow = true
    region:Show()
    region.masonArrowReshow = false
    if region.SetAlpha then
      region:SetAlpha(1)
    end
    pcall(ApplyFlyoutArrowArt, region, exec)
    pcall(RotateFlyoutArrowTex, region, dir)
    pcall(PlaceFlyoutArrowTex, region, exec, dir, 4)
  end
  if exec.FlyoutArrowContainer then
    exec.FlyoutArrowContainer:Show()
    if exec.FlyoutArrowContainer.FlyoutArrowNormal then
      exec.FlyoutArrowContainer.FlyoutArrowNormal:Show()
    end
  end
  self:EnsureFlyoutArrowTicker()
end

function Mason:UpdateFlyoutArrow(exec, piece)
  self:ShowFlyoutArrow(exec, piece)
end

function Mason:HookFlyoutArrow(exec)
  if not exec or exec.masonFlyoutArrowHook then
    return
  end
  exec.masonFlyoutArrowHook = true
  local orig = exec.UpdateFlyout
  if orig then
    exec.UpdateFlyout = function(btn, ...)
      orig(btn, ...)
      Mason:ShowFlyoutArrow(btn)
    end
  end
  exec:HookScript("OnMouseUp", function(btn)
    Mason:ShowFlyoutArrow(btn)
  end)
  local regions = self:FlyoutArrowRegions(exec)
  for i = 1, #regions do
    self:HookArrowRegionHide(exec, regions[i].region, regions[i].label)
  end
end

function Mason:WatchSpellFlyout()
  local sf = _G.SpellFlyout
  if not sf or sf.masonMasonWatch then
    return sf
  end
  sf.masonMasonWatch = true
  sf:HookScript("OnShow", function()
    Mason.masonFlyoutShowCount = (Mason.masonFlyoutShowCount or 0) + 1
  end)
  sf:HookScript("OnHide", function()
    Mason.masonFlyoutHideCount = (Mason.masonFlyoutHideCount or 0) + 1
  end)
  return sf
end

function Mason:AnchorSpellFlyout(exec)
  local sf = _G.SpellFlyout
  if not sf or not exec or InCombatLockdown() then
    return
  end
  local parent = sf:GetParent()
  local parentName = parent and parent.GetName and parent:GetName() or ""
  local hiddenBar = parent and parent ~= exec and parent ~= UIParent and parent.IsShown and not parent:IsShown()
  local p1, rel, p2, x, y = sf:GetPoint(1)
  local offscreen = parent == UIParent and (not x or not y or (math.abs(x) < 1 and math.abs(y) < 1))
  if parent ~= exec or hiddenBar or offscreen then
    sf:SetParent(exec)
    sf:ClearAllPoints()
    local dir = exec:GetAttribute("flyoutDirection") or "UP"
    if dir == "LEFT" then
      sf:SetPoint("RIGHT", exec, "LEFT", 0, 0)
    elseif dir == "RIGHT" then
      sf:SetPoint("LEFT", exec, "RIGHT", 0, 0)
    elseif dir == "DOWN" then
      sf:SetPoint("TOP", exec, "BOTTOM", 0, 0)
    else
      sf:SetPoint("BOTTOM", exec, "TOP", 0, 0)
    end
  end
end

function Mason:ReportSpellFlyout(exec)
  local sf = self:WatchSpellFlyout()
  local flyoutId = exec and tonumber(exec:GetAttribute("flyout"))
  local numSlots, isKnown
  if flyoutId and GetFlyoutInfo then
    local ok, _, _, slots, known = pcall(GetFlyoutInfo, flyoutId)
    if ok then
      numSlots = slots
      isKnown = known
    end
  end
  if isKnown == false or numSlots == 0 then
    print("Mason: flyout isKnown=" .. tostring(isKnown) .. " numSlots=" .. tostring(numSlots) .. " cannot fake slots")
  end
  local shown = sf and sf:IsShown()
  local vis = sf and sf:IsVisible()
  local parent = sf and sf:GetParent()
  local pname = parent and parent.GetName and parent:GetName() or tostring(parent)
  local pointDump = "?"
  if sf then
    local p1, rel, p2, x, y = sf:GetPoint(1)
    local relName = rel and rel.GetName and rel:GetName() or tostring(rel)
    pointDump = table.concat({
      tostring(p1),
      tostring(relName),
      tostring(p2),
      tostring(x),
      tostring(y),
    }, ",")
  end
  print(string.format(
    "Mason: flyout popup shown=%s parent=%s slots=%s known=%s",
    tostring(not not shown),
    tostring(pname),
    tostring(numSlots),
    tostring(isKnown)
  ))
  print(string.format(
    "Mason: flyout vis=%s point=%s shows=%s hides=%s",
    tostring(not not vis),
    pointDump,
    tostring(self.masonFlyoutShowCount or 0),
    tostring(self.masonFlyoutHideCount or 0)
  ))
  if (self.masonFlyoutShowCount or 0) > 0 and (self.masonFlyoutHideCount or 0) > 0 then
    print("Mason: flyout toggled twice in one click")
  end
end

function Mason:DisableLABFlyoutClick(exec)
  if not exec then
    return
  end
  exec.LABUseCustomFlyout = false
  if InCombatLockdown() then
    return
  end
  exec:SetAttribute("LABUseCustomFlyout", false)
  if GetCVarBool("ActionButtonUseKeyDown") then
    exec:RegisterForClicks("AnyDown")
  else
    exec:RegisterForClicks("AnyUp")
  end
end

function Mason:CopyFlyoutButtonMixin(exec)
  local mixin = _G.FlyoutButtonMixin
  local ab = _G.ActionButton1
  if not exec then
    return mixin
  end
  if mixin and not exec.masonFlyoutMixinCopied then
    exec.masonFlyoutMixinCopied = true
    if Mixin then
      Mixin(exec, mixin)
    else
      for k, v in pairs(mixin) do
        if type(v) == "function" and exec[k] == nil then
          exec[k] = v
        end
      end
    end
  end
  if ab then
    local names = {
      "GetPopup",
      "SetPopup",
      "SetPopupDirection",
      "TogglePopup",
      "Flyout_OnClick",
      "UpdateFlyout",
      "IsPopupOpen",
    }
    for i = 1, #names do
      local name = names[i]
      if type(exec[name]) ~= "function" and type(ab[name]) == "function" then
        exec[name] = ab[name]
      end
    end
  end
  if not exec.GetSpellFlyoutDirection then
    exec.GetSpellFlyoutDirection = function()
      return exec:GetAttribute("flyoutDirection") or "UP"
    end
  end
  return mixin
end

function Mason:CloseBlizzardFlyoutPopup()
end

function Mason:EnsureSpellFlyoutEscape()
end

function Mason:OpenOfficialFlyout(exec)
  return false
end

function Mason:EnsureSpellFlyoutEscape()
  local sf = _G.SpellFlyout
  if not sf or not sf.GetName or not _G.UISpecialFrames then
    return
  end
  local name = sf:GetName()
  if not name then
    return
  end
  for i = 1, #UISpecialFrames do
    if UISpecialFrames[i] == name then
      return
    end
  end
  tinsert(UISpecialFrames, name)
end

function Mason:OpenOfficialFlyout(exec)
  if not exec then
    return false
  end
  local piece = exec.masonPieceId and self:FindPiece(exec.masonPieceId)
  if not piece or piece.type ~= "flyout" then
    return false
  end
  self:CopyFlyoutButtonMixin(exec)
  self:EnsureSpellFlyoutEscape()
  local ok, err = pcall(function()
    if self.masonOpenBlizzFlyout and self.masonOpenBlizzFlyout ~= exec then
      if self.masonOpenBlizzFlyout.ClosePopup then
        self.masonOpenBlizzFlyout:ClosePopup()
      end
      self.masonOpenBlizzFlyout = nil
    end
    if exec.IsPopupOpen and exec:IsPopupOpen() then
      if exec.ClosePopup then
        exec:ClosePopup()
      end
      self.masonOpenBlizzFlyout = nil
    else
      local ab = _G.ActionButton1
      local popup = (ab and ab.GetPopup and ab:GetPopup()) or _G.SpellFlyout
      if exec.SetPopup and popup then
        exec:SetPopup(popup)
      end
      if exec.SetPopupDirection then
        exec:SetPopupDirection("UP")
      end
      if exec.TogglePopup then
        exec:TogglePopup()
      elseif exec.Flyout_OnClick then
        exec:Flyout_OnClick(exec, "LeftButton")
      else
        error("no TogglePopup/Flyout_OnClick")
      end
      self.masonOpenBlizzFlyout = exec
    end
  end)
  if not ok then
    print("Mason: flyout " .. tostring(err))
    if InCombatLockdown() then
      print("Mason: cannot Toggle SpellFlyout in combat")
    end
  end
  return ok
end

function Mason:WireBlizzardFlyoutReport(exec)
end

function Mason:OpenOfficialFlyout(exec)
end

function Mason:CloseBlizzardFlyoutPopup()
end

function Mason:ExistingExecutor(id)
  if not id then
    return nil
  end
  return (self.executors and self.executors[id]) or _G[self:ExecutorName(id)]
end

function Mason:PointFlyoutChild(id, x, y)
  local view = self:GetViews()[id]
  if x ~= nil and y ~= nil then
    view = self:WriteViewLayout(id, x, y)
  end
  if not view then
    return
  end
  local exec = self:ExistingExecutor(id)
  if not exec or InCombatLockdown() then
    return
  end
  local size = (self.GetViewSize and self:GetViewSize(view)) or view.size or 45
  exec:SetParent(UIParent)
  exec:ClearAllPoints()
  exec:SetScale(1)
  exec:SetSize(size, size)
  exec:SetPoint("CENTER", UIParent, "BOTTOMLEFT", view.x or x or 0, view.y or y or 0)
  exec:SetAlpha(1)
  exec:Show()
  exec:EnableMouse(true)
end

function Mason:ConfigureFlyoutParent(exec, piece)
  if self.masonPopulatingFlyout then
    return
  end
  if not exec then
    return
  end
  piece = piece or (exec.masonPieceId and self:FindPiece(exec.masonPieceId))
  if not piece or piece.type ~= "flyout" then
    return
  end
  local flyoutId = tonumber(piece.flyoutId)
  if exec.masonFlyoutConfigured and exec.masonFlyoutConfiguredId == flyoutId then
    self:HookFlyoutArrow(exec)
    self:ShowFlyoutArrow(exec, piece)
    return
  end
  exec.masonFlyoutConfigured = true
  exec.masonFlyoutConfiguredId = flyoutId
  self:DisableLABFlyoutClick(exec)
  if not InCombatLockdown() then
    exec:SetAttribute("type", "")
    exec:SetAttribute("type2", "")
    exec:SetAttribute("flyout", nil)
    exec:SetAttribute("spell", nil)
    exec:SetAttribute("LABUseCustomFlyout", false)
  end
  exec.LABUseCustomFlyout = false
  local tex = self:FlyoutTexture(flyoutId)
  exec.HasAction = function()
    return true
  end
  exec.GetTexture = function()
    return tex
  end
  exec.IsUsable = function()
    return true, false
  end
  if exec.icon and tex then
    exec.icon:SetTexture(tex)
    exec.icon:Show()
    exec.icon:SetVertexColor(1, 1, 1)
  end
  if exec.SetAlpha then
    exec:SetAlpha(1)
  end
  self:ShowFlyoutArrow(exec, piece)
  self:HookFlyoutArrow(exec)
  self:HookFlyoutParentInsecure(exec)
  if piece.id then
    self:ApplyFlyoutSecure(piece.id)
  end
end

Mason.ApplyBlizzardFlyout = Mason.ConfigureFlyoutParent

function Mason:GetFlyout(id)
  local view = self:GetViews()[id]
  return view and view.flyout
end

function Mason:IsFlyoutParent(id)
  local fo = self:GetFlyout(id)
  return fo and IsCourseKind(fo.kind) and fo.childIds and #fo.childIds > 0
end

function Mason:FindFlyoutParent(id)
  if not id then
    return nil
  end
  for pid, view in pairs(self:GetViews()) do
    local fo = view.flyout
    if fo and IsCourseKind(fo.kind) and fo.childIds then
      for i = 1, #fo.childIds do
        if fo.childIds[i] == id then
          return pid
        end
      end
    end
  end
  return nil
end

function Mason:EnsureFlyout(id)
  local views = self:GetViews()
  local view = views[id]
  if not view then
    view = {}
    views[id] = view
  end
  local fo = view.flyout
  if not fo then
    fo = {
      kind = "mason",
      blizzardId = nil,
      side = "top",
      childIds = {},
      open = false,
    }
    view.flyout = fo
  end
  fo.childIds = fo.childIds or {}
  fo.side = fo.side or "top"
  fo.kind = fo.kind or "mason"
  if fo.open == nil then
    fo.open = false
  end
  return fo, view
end

function Mason:GetFlyoutHeader()
  if self.flyoutHeader then
    return self.flyoutHeader
  end
  local header = CreateFrame("Button", "MasonFlyoutHeader", UIParent, "SecureHandlerClickTemplate")
  header:Hide()
  header:EnableMouse(false)
  header:SetSize(1, 1)
  header:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
  header:SetFrameRef("UIParent", UIParent)
  if not header.SetFrameRef or not header.WrapScript then
    print("Mason: MasonFlyoutHeader missing SetFrameRef/WrapScript")
  end
  header:SetAttribute("masonHideNamed", HIDE_NAMED)
  header:SetAttribute("masonHideOpen", HIDE_OPEN)
  header:SetAttribute("masonToggle", TOGGLE)
  header.MasonFlyoutState = function(_, parentName, opened)
    Mason:OnFlyoutSecureState(parentName, opened == "1" or opened == true or opened == 1)
  end
  self.flyoutHeader = header
  return header
end

function Mason:OnFlyoutSecureState(parentName, opened)
  local id = PieceIdFromExecName(parentName)
  if not id then
    return
  end
  local fo = self:GetFlyout(id)
  if fo then
    fo.open = not not opened
  end
  if opened then
    for pid, view in pairs(self:GetViews()) do
      if pid ~= id and view.flyout then
        view.flyout.open = false
      end
    end
  end
  if InCombatLockdown() then
    return
  end
  if not self:IsLocked() then
    self:SyncFlyoutKeyCatcher()
    return
  end
  if opened then
    self:LayoutFlyoutChildren(id, true)
  else
    self:CrateFlyoutChildren(id)
  end
  self:SyncFlyoutKeyCatcher()
end

function Mason:ResetFlyoutsClosed()
  if not self.GetViews then
    return
  end
  for _, view in pairs(self:GetViews()) do
    if view.flyout then
      view.flyout.open = false
    end
  end
end

function Mason:FlyoutChildSize(parentView, childId)
  local cv = self:GetViews()[childId]
  if cv and self.GetViewSize then
    return self:GetViewSize(cv)
  end
  if parentView and self.GetViewSize then
    return self:GetViewSize(parentView)
  end
  return (self.GetDefaultSize and self:GetDefaultSize()) or 45
end

function Mason:FlyoutChildCenters(parentId)
  local views = self:GetViews()
  local parent = views[parentId]
  local fo = parent and parent.flyout
  if not parent or not fo or parent.x == nil or parent.y == nil then
    return {}
  end
  local n = fo.childIds and #fo.childIds or 0
  if n < 1 then
    return {}
  end
  local col
  local setCols = tonumber(fo.cols)
  if setCols then
    col = math.floor(setCols)
    if col < 1 then
      col = 1
    elseif col > 12 then
      col = 12
    end
  else
    col = math.ceil(math.sqrt(n))
    if col < 1 then
      col = 1
    end
  end
  local rows = math.ceil(n / col)
  local side = fo.side or "top"
  local psize = (self.GetViewSize and self:GetViewSize(parent)) or parent.size or 45
  local px, py = parent.x, parent.y
  local sizes = {}
  local rowH, colW = {}, {}
  for i = 1, n do
    local sz = self:FlyoutChildSize(parent, fo.childIds[i])
    sizes[i] = sz
    local r = math.floor((i - 1) / col) + 1
    local c = ((i - 1) % col) + 1
    if not rowH[r] or sz > rowH[r] then
      rowH[r] = sz
    end
    if not colW[c] or sz > colW[c] then
      colW[c] = sz
    end
  end
  local blockW, blockH = 0, 0
  for c = 1, col do
    blockW = blockW + (colW[c] or 0)
    if c > 1 then
      blockW = blockW + GAP
    end
  end
  for r = 1, rows do
    blockH = blockH + (rowH[r] or 0)
    if r > 1 then
      blockH = blockH + GAP
    end
  end
  local colX = {}
  local acc = 0
  for c = 1, col do
    colX[c] = acc
    acc = acc + (colW[c] or 0) + GAP
  end
  local rowY = {}
  acc = 0
  for r = 1, rows do
    rowY[r] = acc
    acc = acc + (rowH[r] or 0) + GAP
  end
  local out = {}
  for i = 1, n do
    local r = math.floor((i - 1) / col) + 1
    local c = ((i - 1) % col) + 1
    local sz = sizes[i]
    local ox = (colX[c] or 0) + (colW[c] or sz) / 2
    local oy = (rowY[r] or 0) + (rowH[r] or sz) / 2
    local x, y
    if side == "bottom" then
      x = px - blockW / 2 + ox
      y = py - psize / 2 - GAP - oy
    elseif side == "right" then
      x = px + psize / 2 + GAP + ox
      y = py - blockH / 2 + oy
    elseif side == "left" then
      x = px - psize / 2 - GAP - blockW + ox
      y = py - blockH / 2 + oy
    else
      x = px - blockW / 2 + ox
      y = py + psize / 2 + GAP + oy
    end
    out[i] = { id = fo.childIds[i], x = x, y = y, size = sz }
  end
  local minX, minY, maxX, maxY
  for i = 1, #out do
    local h = out[i].size / 2
    local L, R = out[i].x - h, out[i].x + h
    local B, T = out[i].y - h, out[i].y + h
    minX = minX and math.min(minX, L) or L
    maxX = maxX and math.max(maxX, R) or R
    minY = minY and math.min(minY, B) or B
    maxY = maxY and math.max(maxY, T) or T
  end
  local sw = UIParent:GetWidth() or 0
  local sh = UIParent:GetHeight() or 0
  local dx, dy = 0, 0
  if minX < 0 then
    dx = -minX
  end
  if maxX + dx > sw then
    dx = sw - maxX
  end
  if minX + dx < 0 then
    dx = px - (minX + maxX) / 2
  end
  if minY < 0 then
    dy = -minY
  end
  if maxY + dy > sh then
    dy = sh - maxY
  end
  if minY + dy < 0 then
    dy = py - (minY + maxY) / 2
  end
  for i = 1, #out do
    out[i].x = out[i].x + dx
    out[i].y = out[i].y + dy
  end
  return out
end

function Mason:EnsureChildView(parentId, childId)
  local views = self:GetViews()
  local parent = views[parentId]
  local view = views[childId]
  if not view then
    view = {
      visible = false,
      point = "CENTER",
      relPoint = "BOTTOMLEFT",
    }
    views[childId] = view
  end
  if view.size == nil then
    local size = self:FlyoutChildSize(parent, childId)
    if self.SyncViewSize then
      self:SyncViewSize(view, size)
    else
      view.size = size
    end
  elseif self.EnsureViewSize then
    self:EnsureViewSize(view)
  end
  return view
end

function Mason:LayoutFlyoutChildren(parentId, place)
  if self.masonLayingFlyout then
    return
  end
  local fo = self:GetFlyout(parentId)
  if not fo then
    return
  end
  self.masonLayingFlyout = true
  local centers = self:FlyoutChildCenters(parentId)
  for i = 1, #centers do
    local row = centers[i]
    local view = self:EnsureChildView(parentId, row.id)
    view.x = row.x
    view.y = row.y
    view.point = "CENTER"
    view.relPoint = "BOTTOMLEFT"
    if place and not InCombatLockdown() then
      self:PointFlyoutChild(row.id, row.x, row.y)
    end
  end
  if not InCombatLockdown() then
    self:ApplyFlyoutSecure(parentId)
  end
  self.masonLayingFlyout = false
end

function Mason:CrateFlyoutChildren(parentId)
  local fo = self:GetFlyout(parentId)
  if not fo then
    return
  end
  for i = 1, #fo.childIds do
    self:ClearView(fo.childIds[i])
  end
end

function Mason:ShouldShowFlyoutChildren(parentId)
  if not self:IsLocked() then
    return false
  end
  local fo = self:GetFlyout(parentId)
  return fo and fo.open
end

function Mason:WrapFlyoutParent(exec)
end

function Mason:ToggleFlyoutOOC(parentId)
  if InCombatLockdown() then
    print("Mason: cannot toggle flyout in combat")
    return
  end
  if not parentId or not self:IsLocked() or not self:IsFlyoutParent(parentId) then
    return
  end
  local fo = self:GetFlyout(parentId)
  if not fo then
    return
  end
  for pid, view in pairs(self:GetViews()) do
    if pid ~= parentId and view.flyout and view.flyout.open then
      view.flyout.open = false
      local kids = view.flyout.childIds or {}
      for i = 1, #kids do
        self:ClearView(kids[i])
      end
    end
  end
  if fo.open then
    fo.open = false
    local kids = fo.childIds or {}
    for i = 1, #kids do
      self:ClearView(kids[i])
    end
  else
    fo.open = true
    self:LayoutFlyoutChildren(parentId, true)
  end
  local parentExec = self:ExistingExecutor(parentId)
  if parentExec then
    self:ShowFlyoutArrow(parentExec, self:FindPiece(parentId))
  end
  self:EnsureFlyoutArrowTicker()
end

function Mason:HookFlyoutParentInsecure(exec)
  if not exec or exec.masonFlyoutInsecure then
    return
  end
  exec.masonFlyoutInsecure = true
  exec:HookScript("OnClick", function(btn, _, down)
    if not Mason:IsLocked() then
      return
    end
    local onDown = btn:GetAttribute("useOnKeyDown")
    if onDown ~= false then
      if not down then
        return
      end
    elseif down then
      return
    end
    if InCombatLockdown() then
      print("Mason: cannot toggle flyout in combat")
      return
    end
    Mason:ToggleFlyoutOOC(btn.masonPieceId)
    Mason:ShowFlyoutArrow(btn)
  end)
end

function Mason:ApplyFlyoutSecure(parentId)
  if InCombatLockdown() then
    return
  end
  local parent = self:ExistingExecutor(parentId)
  if not parent then
    return
  end
  local header = self:GetFlyoutHeader()
  if not header or not header.SetFrameRef then
    print("Mason: flyout header has no SetFrameRef")
    return
  end
  local name = parent:GetName()
  header:SetFrameRef(name, parent)
  self:HookFlyoutParentInsecure(parent)
  local fo = self:GetFlyout(parentId)
  local has = fo and IsCourseKind(fo.kind) and fo.childIds and #fo.childIds > 0
  parent:SetAttribute("masonFlyout", has and self:IsLocked() and true or false)
  local centers = has and self:FlyoutChildCenters(parentId) or {}
  for i = 1, FlyoutChildCap() do
    local row = centers[i]
    local ref = name .. "_FO" .. i
    if row then
      local child = self:ExistingExecutor(row.id)
      if child then
        header:SetFrameRef(ref, child)
        header:SetAttribute(name .. "_FOX" .. i, row.x)
        header:SetAttribute(name .. "_FOY" .. i, row.y)
        header:SetAttribute(name .. "_FOS" .. i, row.size)
      else
        header:SetAttribute(name .. "_FOX" .. i, nil)
        header:SetAttribute(name .. "_FOY" .. i, nil)
        header:SetAttribute(name .. "_FOS" .. i, nil)
      end
    else
      header:SetAttribute(name .. "_FOX" .. i, nil)
      header:SetAttribute(name .. "_FOY" .. i, nil)
      header:SetAttribute(name .. "_FOS" .. i, nil)
    end
  end
end

function Mason:ApplyFlyoutLayout()
  if InCombatLockdown() then
    return
  end
  local header = self.flyoutHeader
  if header then
    local openName = header:GetAttribute("masonOpen")
    local openId = PieceIdFromExecName(openName)
    for pid, view in pairs(self:GetViews()) do
      if view.flyout then
        view.flyout.open = (pid == openId)
      end
    end
  end
  for id, view in pairs(self:GetViews()) do
    local fo = view.flyout
    if fo and IsCourseKind(fo.kind) and fo.childIds then
      for i = 1, #fo.childIds do
        local cid = fo.childIds[i]
        local piece = self:FindPiece(cid)
        if piece then
          self:EnsureExecutor(piece)
        end
      end
      if self:IsFlyoutParent(id) then
        self:ApplyFlyoutSecure(id)
        if self:ShouldShowFlyoutChildren(id) then
          self:LayoutFlyoutChildren(id, true)
        else
          for i = 1, #fo.childIds do
            local cid = fo.childIds[i]
            local cv = self:GetViews()[cid]
            if cv then
              cv.visible = false
            end
            self:CrateExecutorVisual(cid)
          end
        end
      end
    end
  end
  self:SyncFlyoutKeyCatcher()
end

function Mason:CloseAllFlyouts()
  if self.CloseBlizzardFlyoutPopup then
    self:CloseBlizzardFlyoutPopup()
  end
  local any = false
  for _, view in pairs(self:GetViews()) do
    if view.flyout and view.flyout.open then
      any = true
    end
  end
  local header = self.flyoutHeader
  if InCombatLockdown() then
    if header and not self.flyoutWrapError then
      header:Execute([[ self:RunAttribute("masonHideOpen") ]])
    end
    return any
  end
  if header then
    header:Execute([[ self:RunAttribute("masonHideOpen") ]])
  end
  for id, view in pairs(self:GetViews()) do
    if view.flyout and (view.flyout.open or self:IsFlyoutParent(id)) then
      if view.flyout.open then
        any = true
      end
      view.flyout.open = false
      self:CrateFlyoutChildren(id)
    end
  end
  self:SyncFlyoutKeyCatcher()
  return any
end

function Mason:SyncFlyoutKeyCatcher()
  local f = self.flyoutKeyCatcher
  if not f then
    f = CreateFrame("Frame", "MasonFlyoutKeyCatcher", UIParent)
    f:SetSize(1, 1)
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    f:EnableMouse(false)
    f:SetScript("OnKeyDown", function(catcher, key)
      if key == "ESCAPE" and Mason:IsLocked() and not InCombatLockdown() then
        if Mason:CloseAllFlyouts() then
          if catcher.SetPropagateKeyboardInput then
            catcher:SetPropagateKeyboardInput(false)
          end
          return
        end
      end
      if catcher.SetPropagateKeyboardInput then
        catcher:SetPropagateKeyboardInput(true)
      end
    end)
    self.flyoutKeyCatcher = f
  end
  local open = false
  for _, view in pairs(self:GetViews()) do
    if view.flyout and view.flyout.open then
      open = true
      break
    end
  end
  if open and self:IsLocked() and not InCombatLockdown() then
    f:Show()
    f:EnableKeyboard(true)
    if f.SetPropagateKeyboardInput then
      f:SetPropagateKeyboardInput(true)
    end
  else
    f:EnableKeyboard(false)
    f:Hide()
  end
end

function Mason:WouldFlyoutCycle(parentId, childId)
  if parentId == childId then
    return true
  end
  if self:IsFlyoutParent(childId) then
    return true
  end
  if self:FindFlyoutParent(parentId) then
    return true
  end
  local seen = {}
  local function walk(id)
    if seen[id] then
      return true
    end
    seen[id] = true
    if id == parentId then
      return true
    end
    local fo = self:GetFlyout(id)
    if not fo or not fo.childIds then
      return false
    end
    for i = 1, #fo.childIds do
      if walk(fo.childIds[i]) then
        return true
      end
    end
    return false
  end
  return walk(childId)
end

function Mason:FlyoutAdd(parentId, childId)
  if InCombatLockdown() then
    print("Mason: cannot edit flyout in combat")
    return false
  end
  if not self:FindPiece(parentId) or not self:FindPiece(childId) then
    return false
  end
  if self:FindPiece(childId) and self:FindPiece(childId).type == "flyout" then
    print("Mason: cannot nest flyouts")
    return false
  end
  local other = self:FindFlyoutParent(childId)
  if other and other ~= parentId then
    print("Mason: cannot nest flyouts")
    return false
  end
  if self:WouldFlyoutCycle(parentId, childId) then
    if self:IsFlyoutParent(childId) then
      print("Mason: child is already a parent")
    else
      print("Mason: cannot nest flyouts")
    end
    return false
  end
  local fo = self:EnsureFlyout(parentId)
  for i = 1, #fo.childIds do
    if fo.childIds[i] == childId then
      return true
    end
  end
  local cap = FlyoutChildCap()
  local n = (fo.childIds and #fo.childIds) or 0
  if not self.masonPopulatingFlyout and n >= cap then
    print("Mason: flyout full")
    return false
  end
  fo.childIds[#fo.childIds + 1] = childId
  self:EnsureChildView(parentId, childId)
  local childPiece = self:FindPiece(childId)
  if childPiece then
    self:EnsureExecutor(childPiece)
  end
  if self.masonPopulatingFlyout then
    return true
  end
  if self:InEditMode() then
    self:LayoutFlyoutChildren(parentId, true)
  else
    self:ApplyFlyoutSecure(parentId)
    if not fo.open then
      self:ClearView(childId)
    else
      self:LayoutFlyoutChildren(parentId, true)
    end
  end
  return true
end

function Mason:FlyoutRemove(parentId, childId)
  if InCombatLockdown() then
    print("Mason: cannot edit flyout in combat")
    return false
  end
  local fo = self:GetFlyout(parentId)
  if not fo or not fo.childIds then
    return false
  end
  local nextIds = {}
  local found = false
  for i = 1, #fo.childIds do
    if fo.childIds[i] == childId then
      found = true
    else
      nextIds[#nextIds + 1] = fo.childIds[i]
    end
  end
  if not found then
    return false
  end
  fo.childIds = nextIds
  if self:InEditMode() then
    self:LayoutFlyoutChildren(parentId, true)
  else
    self:ApplyFlyoutSecure(parentId)
    if fo.open then
      self:LayoutFlyoutChildren(parentId, true)
    end
  end
  return true
end

function Mason:FlyoutSetSide(parentId, side)
  if InCombatLockdown() then
    print("Mason: cannot edit flyout in combat")
    return false
  end
  local allowed = { left = true, right = true, top = true, bottom = true }
  if not allowed[side] then
    return false
  end
  local fo = self:EnsureFlyout(parentId)
  fo.side = side
  local exec = self:ExistingExecutor(parentId)
  if exec then
    self:UpdateFlyoutArrow(exec, self:FindPiece(parentId))
  end
  if self:IsFlyoutParent(parentId) and self:ShouldShowFlyoutChildren(parentId) then
    self:LayoutFlyoutChildren(parentId, true)
  else
    self:ApplyFlyoutSecure(parentId)
  end
  return true
end

function Mason:FlyoutSetCols(parentId, cols)
  if InCombatLockdown() then
    print("Mason: cannot edit flyout in combat")
    return false
  end
  local n = tonumber(cols)
  if not n then
    return false
  end
  n = math.floor(n)
  if n < 1 then
    n = 1
  elseif n > 12 then
    n = 12
  end
  local fo = self:EnsureFlyout(parentId)
  fo.cols = n
  self:Notify("flyout cols " .. n)
  if self:ShouldShowFlyoutChildren(parentId) then
    self:LayoutFlyoutChildren(parentId, true)
  end
  return true
end

function Mason:FlyoutClear(parentId)
  if InCombatLockdown() then
    print("Mason: cannot edit flyout in combat")
    return false
  end
  local view = self:GetViews()[parentId]
  if not view or not view.flyout then
    return false
  end
  local fo = view.flyout
  local ids = fo.childIds or {}
  view.flyout = nil
  local header = self.flyoutHeader
  if header then
    local name = self:ExecutorName(parentId)
    if header:GetAttribute("masonOpen") == name then
      header:Execute([[ self:RunAttribute("masonHideOpen") ]])
    end
  end
  local exec = self.executors and self.executors[parentId]
  if exec then
    exec:SetAttribute("masonFlyout", false)
  end
  for i = 1, #ids do
    self:ClearView(ids[i])
  end
  return true
end

function Mason:HandleFlyoutSlash(rest)
  rest = strtrim(rest or "")
  if rest == "" then
    print("Mason: usage: /mason flyout <parent> add|remove|side|cols|clear")
    print("Mason: usage: /mason flyout close")
    return
  end
  if string.lower(rest) == "close" then
    self:CloseAllFlyouts()
    return
  end
  local parentToken, more = string.match(rest, "^(%S+)%s*(.*)$")
  more = strtrim(more or "")
  local parent = self:ResolvePieceToken(parentToken)
  if not parent then
    print("Mason: no piece for " .. parentToken)
    return
  end
  if more == "" then
    local fo = self:GetFlyout(parent.id) or self:EnsureFlyout(parent.id)
    local cols = fo.cols
    if cols == nil then
      cols = "auto"
    end
    print("Mason: flyout side=" .. tostring(fo.side or "top") .. " cols=" .. tostring(cols))
    return
  end
  local action, arg = string.match(more, "^(%S+)%s*(.*)$")
  action = string.lower(action or "")
  arg = strtrim(arg or "")
  if action == "clear" then
    self:FlyoutClear(parent.id)
    return
  end
  if action == "side" then
    local side = string.lower(arg)
    if not self:FlyoutSetSide(parent.id, side) then
      print("Mason: usage: /mason flyout <parent> side top|bottom|left|right")
    end
    return
  end
  if action == "cols" then
    if not self:FlyoutSetCols(parent.id, arg) then
      print("Mason: usage: /mason flyout <parent> cols <n>")
    end
    return
  end
  if action == "add" or action == "remove" then
    if arg == "" then
      print("Mason: usage: /mason flyout <parent> " .. action .. " <child>")
      return
    end
    local child = self:ResolvePieceToken(arg)
    if not child then
      print("Mason: no piece for " .. arg)
      return
    end
    if action == "add" then
      self:FlyoutAdd(parent.id, child.id)
    else
      self:FlyoutRemove(parent.id, child.id)
    end
    return
  end
  print("Mason: usage: /mason flyout <parent> add|remove|side|cols|clear")
end

function Mason:InstallFlyoutHooks()
  if self.masonFlyoutHooks then
    return
  end
  self.masonFlyoutHooks = true

  local origApply = self.ApplyLayout
  function Mason:ApplyLayout()
    origApply(self)
    if not InCombatLockdown() then
      self:ApplyFlyoutLayout()
    end
  end

  local origPlace = self.PlaceView
  function Mason:PlaceView(id, x, y, snap)
    if self:FindFlyoutParent(id) then
      snap = false
    end
    local result = origPlace(self, id, x, y, snap)
    local piece = self:FindPiece(id)
    local exec = self:ExistingExecutor(id)
    if exec then
      self:UpdateFlyoutArrow(exec, piece)
    end
    if self:FindFlyoutParent(id) then
      return result
    end
    if not InCombatLockdown() and self:IsFlyoutParent(id) and self:ShouldShowFlyoutChildren(id) then
      self:LayoutFlyoutChildren(id, true)
    elseif not InCombatLockdown() and self:IsFlyoutParent(id) then
      self:ApplyFlyoutSecure(id)
    end
    return result
  end

  local origCourse = self.GetCourseIds
  function Mason:GetCourseIds(id)
    local ids = origCourse(self, id)
    if self:ShouldShowFlyoutChildren(id) then
      ids[id] = true
      local fo = self:GetFlyout(id)
      for i = 1, #fo.childIds do
        ids[fo.childIds[i]] = true
      end
    end
    return ids
  end

  local origInCourse = self.PieceInCourse
  function Mason:PieceInCourse(id)
    if origInCourse(self, id) then
      return true
    end
    if self:ShouldShowFlyoutChildren(id) then
      return true
    end
    local parent = self:FindFlyoutParent(id)
    return parent ~= nil and self:ShouldShowFlyoutChildren(parent)
  end

  local origLock = self.SetLocked
  function Mason:SetLocked(locked)
    locked = not not locked
    if not InCombatLockdown() and not locked then
      if self.CloseBlizzardFlyoutPopup then
        self:CloseBlizzardFlyoutPopup()
      end
      if self.CloseAllFlyouts then
        self:CloseAllFlyouts()
      end
    end
    return origLock(self, locked)
  end

  local origDelete = self.DeletePiece
  function Mason:DeletePiece(id)
    for pid, view in pairs(self:GetViews()) do
      local fo = view.flyout
      if fo and fo.childIds then
        local nextIds = {}
        for i = 1, #fo.childIds do
          if fo.childIds[i] ~= id then
            nextIds[#nextIds + 1] = fo.childIds[i]
          end
        end
        fo.childIds = nextIds
        if pid == id then
          view.flyout = nil
        end
      end
    end
    return origDelete(self, id)
  end
end
