local Mason = LibStub("AceAddon-3.0"):GetAddon("Mason")

local defaults = {
  profile = {
    nextPieceIndex = 1,
    specKits = {},
  },
  char = {
    locked = true,
    gridSize = 32,
    views = {},
  },
}

function Mason:InitDB()
  self.db = LibStub("AceDB-3.0"):New("MasonDB", defaults, true)
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

function Mason:FindPieceByAction(ptype, fields)
  fields = fields or {}
  for _, piece in pairs(self:GetKit()) do
    if ptype == "spell" and piece.type == "spell" and piece.spellID == fields.spellID then
      return piece
    elseif ptype == "item" and piece.type == "item" and piece.itemID == fields.itemID then
      return piece
    elseif ptype == "macro" and piece.type == "macro" and piece.macroName == fields.macroName then
      return piece
    end
  end
  return nil
end

function Mason:GetViews()
  local char = self.db.char
  char.views = char.views or {}
  return char.views
end
