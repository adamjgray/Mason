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
    flyoutId = fields.flyoutId,
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

function Mason:SetPieceKey(id, key, overwrite)
  local piece, specID = self:FindPiece(id)
  if not piece then
    return false
  end
  key = NormalizeKey(key)
  if piece.key and NormalizeKey(piece.key) == key then
    return false
  end
  local other = self:FindPieceByKey(key, specID)
  if other and other.id ~= id and not overwrite then
    if self.ShowBindOverwriteDialog then
      if InCombatLockdown() then
        return self:QueueIfCombat(function()
          Mason:ShowBindOverwriteDialog(id, key, other)
        end)
      end
      self:ShowBindOverwriteDialog(id, key, other)
      return false
    end
  end
  local messages = {}
  if other and other.id ~= id then
    messages[#messages + 1] = key .. " moved from " .. Label(other)
    other.key = nil
  end
  local previous = GetBindingAction(key, true)
  piece.key = key
  local line = key .. " → " .. Label(piece)
  if previous and previous ~= "" and not IsMasonClickAction(previous) then
    line = line .. " (was " .. previous .. ")"
  end
  messages[#messages + 1] = line
  local deferred
  if self:IsDebug() then
    deferred = self:ApplyOverridesAndNotify(messages)
  else
    deferred = self:QueueIfCombat(function()
      self:ApplyOverrides()
    end)
  end
  if self.AfterBindChange then
    self:AfterBindChange()
  end
  return deferred
end

function Mason:ClearPieceKey(id)
  local piece = self:FindPiece(id)
  if not piece then
    return false
  end
  local messages = {}
  if piece.key and piece.key ~= "" then
    messages[#messages + 1] = "unbound " .. Label(piece)
  end
  piece.key = nil
  local deferred
  if self:IsDebug() and #messages > 0 then
    deferred = self:ApplyOverridesAndNotify(messages)
  else
    deferred = self:QueueIfCombat(function()
      self:ApplyOverrides()
    end)
  end
  if self.AfterBindChange then
    self:AfterBindChange()
  end
  return deferred
end

function Mason:AfterBindChange()
  if self.RefreshPiecesTable then
    self:RefreshPiecesTable()
  end
  -- 09ab / B-02: store-driven clear+paint via sole painter — never RefreshBlizzard fallback.
  self:QueueIfCombat(function()
    Mason:RepaintSourceHotkeys()
  end)
end

function Mason:DeletePiece(id)
  local piece, specID = self:FindPiece(id)
  if not piece then
    return false
  end
  local kit = self:GetSpecKit(specID)
  kit.pieces[id] = nil
  local views = self:GetViews()
  if views then
    views[id] = nil
  end
  local deferred = self:QueueIfCombat(function()
    self:ParkExecutor(id)
    self:ApplyOverrides()
  end)
  -- B-03 / BM-13: paint≡bind — source chords must clear+repaint when a keyed piece goes.
  if self.AfterBindChange then
    self:AfterBindChange()
  end
  return deferred
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
    local views = self:GetViews()
    if views then
      views[id] = nil
    end
  end
  local deferred = self:QueueIfCombat(function()
    for i = 1, #ids do
      self:ParkExecutor(ids[i])
    end
    self:ApplyOverrides()
  end)
  -- B-03 / BM-13: kit clear removes keyed pieces — same store-driven clear+paint path.
  if self.AfterBindChange then
    self:AfterBindChange()
  end
  return deferred
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
  if self.ApplyLayout then
    self:ApplyLayout()
  end
end
