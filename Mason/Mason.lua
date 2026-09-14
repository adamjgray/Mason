local Mason = LibStub("AceAddon-3.0"):NewAddon("Mason", "AceConsole-3.0")
_G.Mason = Mason

function Mason:Notify(msg)
  print("Mason: " .. msg)
  if UIErrorsFrame and UIErrorsFrame.AddMessage then
    UIErrorsFrame:AddMessage(msg, 1.0, 0.82, 0.0)
  elseif RaidNotice_AddMessage and RaidWarningFrame then
    RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo and ChatTypeInfo["RAID_WARNING"])
  end
end

local USAGE = {
  "/mason bind <spell> <key>",
  "/mason unbind <key|pieceId>",
  "/mason list",
  "/mason clear",
  "/mason debug",
}

function Mason:OnInitialize()
  self.executors = {}
  self:InitDB()
  self:RegisterChatCommand("mason", "OnChatCommand")
end

function Mason:OnEnable()
  self:CreateBindOwner()
  self:RegisterRuntimeEvents()
  self:QueueIfCombat(function()
    self:ApplyOverrides()
  end)
end

function Mason:RegisterRuntimeEvents()
  if self.eventFrame then
    return
  end
  local frame = CreateFrame("Frame")
  self.eventFrame = frame
  frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  frame:RegisterEvent("CVAR_UPDATE")
  frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_SPECIALIZATION_CHANGED" then
      local unit = ...
      if unit and unit ~= "player" then
        return
      end
      self:QueueIfCombat(function()
        self:ApplyOverrides()
      end)
    elseif event == "PLAYER_REGEN_ENABLED" then
      self:FlushCombatQueue()
    elseif event == "CVAR_UPDATE" then
      local name = ...
      if name == "ActionButtonUseKeyDown" then
        self:QueueIfCombat(function()
          self:RefreshExecutorClicks()
        end)
      end
    end
  end)
end

function Mason:PrintUsage()
  for i = 1, #USAGE do
    print("Mason: " .. USAGE[i])
  end
end

local function SpellInfo(token)
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(token)
    if info and info.spellID then
      return info.spellID, info.name
    end
  end
  if GetSpellInfo then
    local name, _, _, _, _, _, spellID = GetSpellInfo(token)
    if spellID then
      return spellID, name
    end
    if name then
      return token, name
    end
  end
  return nil
end

local function SpellInBook(spellID)
  if C_SpellBook and C_SpellBook.IsSpellInSpellBook then
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if bank ~= nil then
      if C_SpellBook.IsSpellInSpellBook(spellID, bank, true) then
        return true
      end
      if C_SpellBook.IsSpellInSpellBook(spellID, bank, false) then
        return true
      end
    end
  end
  if IsPlayerSpell and IsPlayerSpell(spellID) then
    return true
  end
  if IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(spellID) then
    return true
  end
  if IsSpellKnown and IsSpellKnown(spellID) then
    return true
  end
  return false
end

local function ResolveSpell(token)
  local numeric = tonumber(token)
  local spellID, spellName = SpellInfo(numeric or token)
  if not spellID then
    return nil
  end
  if not SpellInBook(spellID) then
    return nil
  end
  if not spellName and C_Spell and C_Spell.GetSpellName then
    spellName = C_Spell.GetSpellName(spellID)
  end
  return spellID, spellName
end

local function FindPieceBySpell(pieces, spellID)
  for _, piece in pairs(pieces) do
    if piece.type == "spell" and piece.spellID == spellID then
      return piece
    end
  end
  return nil
end

local function FindPieceByKey(pieces, key)
  local want = string.upper(key)
  for _, piece in pairs(pieces) do
    if piece.key and string.upper(piece.key) == want then
      return piece
    end
  end
  return nil
end

local function PieceLabel(piece)
  return piece.spellName or piece.macroName or (piece.itemID and tostring(piece.itemID)) or piece.id
end

function Mason:OnChatCommand(input)
  input = strtrim(input or "")
  if input == "" then
    self:PrintUsage()
    return
  end
  local cmd, rest = string.match(input, "^(%S+)%s*(.*)$")
  cmd = string.lower(cmd)
  rest = rest or ""

  if cmd == "bind" then
    local key = string.match(rest, "(%S+)$")
    local spellToken = rest:sub(1, #rest - (key and #key or 0))
    spellToken = strtrim(spellToken)
    if not key or spellToken == "" then
      print("Mason: usage: /mason bind <spell> <key>")
      return
    end
    local spellID, spellName = ResolveSpell(spellToken)
    if not spellID then
      print("Mason: unknown spell: " .. spellToken)
      return
    end
    local specID = self:GetCurrentSpecID()
    if not specID then
      print("Mason: no specialization")
      return
    end
    local piece = FindPieceBySpell(self:GetKit(specID), spellID)
    if not piece then
      piece = self:CreatePiece({
        type = "spell",
        spellID = spellID,
        spellName = spellName,
        specID = specID,
      })
    else
      piece.spellName = spellName or piece.spellName
    end
    local deferred = self:SetPieceKey(piece.id, key)
    if deferred then
      print("Mason: queued until combat ends")
    end
    return
  end

  if cmd == "unbind" then
    local token = strtrim(rest)
    if token == "" then
      print("Mason: usage: /mason unbind <key|pieceId>")
      return
    end
    local specID = self:GetCurrentSpecID()
    local pieces = self:GetKit(specID)
    local piece
    if string.match(token, "^p_%d+$") then
      piece = pieces[token]
    else
      piece = FindPieceByKey(pieces, token)
    end
    if not piece then
      print("Mason: no piece for " .. token)
      return
    end
    local deferred = self:ClearPieceKey(piece.id)
    if deferred then
      print("Mason: queued until combat ends")
    end
    return
  end

  if cmd == "list" then
    local pieces = self:GetKit()
    local rows = {}
    for id, piece in pairs(pieces) do
      rows[#rows + 1] = { id = id, piece = piece }
    end
    table.sort(rows, function(a, b)
      return a.id < b.id
    end)
    if #rows == 0 then
      print("Mason: no pieces")
      return
    end
    for i = 1, #rows do
      local piece = rows[i].piece
      print(string.format("Mason: %s %s %s %s", piece.id, piece.type or "spell", PieceLabel(piece), piece.key or "-"))
    end
    return
  end

  if cmd == "clear" then
    local deferred = self:ClearCurrentKit()
    if deferred then
      print("Mason: queued until combat ends")
    end
    return
  end

  if cmd == "debug" then
    local specID = self:GetCurrentSpecID()
    local count = 0
    for _ in pairs(self:GetKit(specID)) do
      count = count + 1
    end
    print(string.format(
      "Mason: specID=%s pieces=%d keyDown=%s combat=%s",
      tostring(specID),
      count,
      tostring(not not GetCVarBool("ActionButtonUseKeyDown")),
      tostring(not not InCombatLockdown())
    ))
    return
  end

  self:PrintUsage()
end
