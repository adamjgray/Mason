local Mason = LibStub("AceAddon-3.0"):GetAddon("Mason")

local function Label(piece)
  return piece.spellName or piece.macroName or (piece.itemID and tostring(piece.itemID)) or piece.id
end

local function NormalizeKey(key)
  return string.upper(tostring(key))
end

local function IsMasonClickAction(action)
  return type(action) == "string" and string.find(action, "^CLICK MasonExec_", 1, false)
end

function Mason:CreatePiece(fields)
  fields = fields or {}
  local specID = fields.specID or self:GetCurrentSpecID()
  local kit = self:GetSpecKit(specID)
  if not kit then
    return nil
  end
  local id = self:AllocPieceID()
  local piece = {
    id = id,
    type = fields.type or "spell",
    spellID = fields.spellID,
    spellName = fields.spellName,
    itemID = fields.itemID,
    macroName = fields.macroName,
    key = nil,
    specID = specID,
  }
  kit.pieces[id] = piece
  if fields.key then
    self:SetPieceKey(id, fields.key)
  else
    self:QueueIfCombat(function()
      self:EnsureExecutor(piece)
      self:ApplyOverrides()
    end)
  end
  return piece
end

function Mason:SetPieceKey(id, key)
  local piece, specID = self:FindPiece(id)
  if not piece then
    return false
  end
  local pieces = self:GetKit(specID)
  key = NormalizeKey(key)
  local messages = {}
  for otherId, other in pairs(pieces) do
    if otherId ~= id and other.key and NormalizeKey(other.key) == key then
      messages[#messages + 1] = key .. " moved from " .. Label(other)
      other.key = nil
    end
  end
  local previous = GetBindingAction(key, true)
  piece.key = key
  local line = key .. " → " .. Label(piece)
  if previous and previous ~= "" and not IsMasonClickAction(previous) then
    line = line .. " (was " .. previous .. ")"
  end
  messages[#messages + 1] = line
  return self:ApplyOverridesAndNotify(messages)
end

function Mason:ClearPieceKey(id)
  local piece = self:FindPiece(id)
  if not piece then
    return false
  end
  piece.key = nil
  return self:ApplyOverridesAndNotify()
end

function Mason:DeletePiece(id)
  local piece, specID = self:FindPiece(id)
  if not piece then
    return false
  end
  local kit = self:GetSpecKit(specID)
  kit.pieces[id] = nil
  return self:QueueIfCombat(function()
    self:ParkExecutor(id)
    self:ApplyOverrides()
  end)
end

function Mason:ClearCurrentKit()
  local kit = self:GetSpecKit()
  if not kit then
    return false
  end
  local ids = {}
  for id in pairs(kit.pieces) do
    ids[#ids + 1] = id
    kit.pieces[id] = nil
  end
  return self:QueueIfCombat(function()
    for i = 1, #ids do
      self:ParkExecutor(ids[i])
    end
    self:ApplyOverrides()
  end)
end

function Mason:ApplyOverrides()
  if InCombatLockdown() then
    return self:QueueIfCombat(function()
      self:ApplyOverrides()
    end)
  end
  local owner = self:CreateBindOwner()
  ClearOverrideBindings(owner)
  local pieces = self:GetKit()
  for _, piece in pairs(pieces) do
    self:EnsureExecutor(piece)
    if piece.key and piece.key ~= "" then
      SetOverrideBindingClick(owner, false, piece.key, self:ExecutorName(piece.id), "LeftButton")
    end
  end
end
