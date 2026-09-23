local Mason = LibStub("AceAddon-3.0"):GetAddon("Mason")

local defaults = {
  profile = {
    nextPieceIndex = 1,
    specKits = {},
    rules = {},
    views = {},
    snap = true,
    gridSize = 32,
    defaultSize = nil,
    debug = false,
    -- Assisted combat highlight ring on recommended faces (Blizzard-like). Default on.
    assistedHighlightRing = true,
  },
  char = {
    locked = true,
  },
}

local function TableEmpty(t)
  if type(t) ~= "table" then
    return true
  end
  return next(t) == nil
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

function Mason:IsDebug()
  return self.db and self.db.profile and self.db.profile.debug and true or false
end

function Mason:DebugPrint(...)
  if self:IsDebug() then
    print(...)
  end
end

function Mason:MigrateCharLayoutToProfile()
  local profile = self.db and self.db.profile
  local char = self.db and self.db.char
  if not profile or not char then
    return
  end
  profile.views = profile.views or {}
  if TableEmpty(profile.views) and type(char.views) == "table" and not TableEmpty(char.views) then
    profile.views = CopyValue(char.views)
  end
  if profile.snap == nil and char.snap ~= nil then
    profile.snap = not not char.snap
  end
  if profile.gridSize == nil and char.gridSize ~= nil then
    profile.gridSize = char.gridSize
  end
  if profile.defaultSize == nil and char.defaultSize ~= nil then
    profile.defaultSize = char.defaultSize
  end
  if profile.debug == nil and char.debug ~= nil then
    profile.debug = not not char.debug
  end
  char.views = nil
end

function Mason:OnAceProfileChanged()
  self:QueueIfCombat(function()
    local kit = Mason:GetKit()
    for id in pairs(Mason.executors or {}) do
      if not kit[id] then
        Mason:ParkExecutor(id)
        if Mason.HideEditHandle then
          Mason:HideEditHandle(id)
        end
      end
    end
    Mason:ApplyOverrides()
    if Mason.ApplyLayout then
      Mason:ApplyLayout()
    end
    if Mason.RepaintSourceHotkeys then
      Mason:RepaintSourceHotkeys()
    end
    if Mason.RefreshPiecesTable then
      Mason:RefreshPiecesTable()
    end
  end)
end

function Mason:InitDB()
  self.db = LibStub("AceDB-3.0"):New("MasonDB", defaults, true)
  self:MigrateCharLayoutToProfile()
  if self.db.RegisterCallback then
    self.db.RegisterCallback(self, "OnProfileChanged", "OnAceProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnAceProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "OnAceProfileChanged")
  end
  if self.EnsureRules then
    self:EnsureRules()
  end
  if self.GetDefaultSize then
    self:GetDefaultSize()
  end
end

function Mason:GetCurrentSpecID()
  local index
  if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
    index = C_SpecializationInfo.GetSpecialization()
  elseif GetSpecialization then
    index = GetSpecialization()
  end
  if not index then
    return nil
  end
  local specID
  if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
    specID = C_SpecializationInfo.GetSpecializationInfo(index)
  elseif GetSpecializationInfo then
    specID = GetSpecializationInfo(index)
  end
  if not specID or specID == 0 then
    return nil
  end
  return specID
end

function Mason:GetSpecKit(specID)
  specID = specID or self:GetCurrentSpecID()
  if not specID then
    return nil
  end
  local kits = self.db.profile.specKits
  local kit = kits[specID]
  if not kit then
    kit = kits[tostring(specID)]
  end
  if not kit then
    kit = { pieces = {} }
    kits[specID] = kit
  end
  kit.pieces = kit.pieces or {}
  return kit
end

function Mason:GetKit(specID)
  local kit = self:GetSpecKit(specID)
  if not kit then
    return {}
  end
  return kit.pieces
end

function Mason:AllocPieceID()
  local index = self.db.profile.nextPieceIndex or 1
  self.db.profile.nextPieceIndex = index + 1
  return "p_" .. index
end

function Mason:FindPiece(id)
  local kits = self.db.profile.specKits
  if not kits then
    return nil
  end
  local currentID = self:GetCurrentSpecID()
  if currentID then
    local kit = self:GetSpecKit(currentID)
    if kit.pieces[id] then
      return kit.pieces[id], currentID
    end
  end
  for specID, kit in pairs(kits) do
    if kit.pieces and kit.pieces[id] then
      return kit.pieces[id], specID
    end
  end
  return nil
end

function Mason:PieceLabel(piece)
  if not piece then
    return "?"
  end
  if piece.type == "flyout" then
    if piece.spellName and piece.spellName ~= "" then
      return piece.spellName
    end
    if self.FlyoutLabel then
      return self:FlyoutLabel(piece.flyoutId) or ("flyout " .. tostring(piece.flyoutId))
    end
    return "flyout " .. tostring(piece.flyoutId)
  end
  return piece.spellName or piece.macroName or (piece.itemID and tostring(piece.itemID)) or piece.id
end

function Mason:FindPieceByKey(key, specID)
  if not key then
    return nil
  end
  local want = string.upper(key)
  for _, piece in pairs(self:GetKit(specID)) do
    if piece.key and string.upper(piece.key) == want then
      return piece
    end
  end
  return nil
end

function Mason:FindPieceBySpellToken(token, specID)
  if not token or token == "" then
    return nil
  end
  local numeric = tonumber(token)
  local want = string.lower(token)
  for _, piece in pairs(self:GetKit(specID)) do
    if piece.type == "spell" then
      if numeric and piece.spellID == numeric then
        return piece
      end
      if piece.spellName and string.lower(piece.spellName) == want then
        return piece
      end
    end
  end
  return nil
end

function Mason:ResolvePieceToken(token, specID)
  token = strtrim(token or "")
  if token == "" then
    return nil
  end
  local pieces = self:GetKit(specID)
  if string.match(token, "^p_%d+$") then
    return pieces[token]
  end
  return self:FindPieceByKey(token, specID) or self:FindPieceBySpellToken(token, specID)
end

-- Shared talent/override matcher for pickup reuse, faces, and assisted highlight.
-- Union related IDs from every Retail API (do not elseif — APIs disagree per spell).
function Mason:SpellIDsMatch(a, b)
  if not a or not b then
    return false
  end
  a, b = tonumber(a), tonumber(b)
  if not a or not b then
    return false
  end
  if a == b then
    return true
  end
  local function related(id)
    local ids = { [id] = true }
    local function add(v)
      v = tonumber(v)
      if v and v > 0 then
        ids[v] = true
      end
    end
    local function try(fn, ...)
      if not fn then
        return
      end
      local ok, v = pcall(fn, ...)
      if ok then
        add(v)
      end
    end
    if C_Spell then
      try(C_Spell.GetOverrideSpell, id)
      try(C_Spell.GetBaseSpell, id)
    end
    try(FindSpellOverrideBySpellID, id)
    try(GetOverrideSpell, id)
    if C_SpellBook then
      try(C_SpellBook.FindBaseSpellByID, id)
    end
    try(FindBaseSpellByID, id)
    try(FindBaseSpellBySpellID, id)
    return ids
  end
  local left, right = related(a), related(b)
  for id in pairs(left) do
    if right[id] then
      return true
    end
  end
  return false
end

function Mason:FindPieceByAction(ptype, fields)
  fields = fields or {}
  for _, piece in pairs(self:GetKit()) do
    if ptype == "spell" and piece.type == "spell" and self:SpellIDsMatch(piece.spellID, fields.spellID) then
      return piece
    elseif (ptype == "item" or ptype == "toy") and (piece.type == "item" or piece.type == "toy")
      and tonumber(piece.itemID) and tonumber(fields.itemID)
      and tonumber(piece.itemID) == tonumber(fields.itemID) then
      return piece
    elseif ptype == "macro" and piece.type == "macro" and piece.macroName == fields.macroName then
      return piece
    elseif ptype == "flyout" and piece.type == "flyout" and piece.flyoutId == fields.flyoutId then
      return piece
    end
  end
  return nil
end

function Mason:GetViews()
  local profile = self.db.profile
  profile.views = profile.views or {}
  return profile.views
end
