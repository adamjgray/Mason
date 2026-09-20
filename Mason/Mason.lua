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
  "/mason debug ghosts",
  "/mason edit",
  "/mason lock",
  "/mason hide <key|id|spell>",
  "/mason show <key|id|spell>",
  "/mason grid <8-128>",
  "/mason snap",
  "/mason rule <key|id|spell> <preset|clear>",
  "/mason rules",
  "/mason align left|right|top|bottom|hcenter|vcenter",
  "/mason scale <key|id|spell> <factor>",
  "/mason size [token] <px|reset>",
  "/mason undock [key|id|spell]",
  "/mason flyout <parent> add|remove|side|cols|clear",
  "/mason flyout close",
  "/mason kb",
  "/mason export kit|layout|full",
  "/mason import",
  "/mason config",
}

function Mason:OnInitialize()
  self.executors = {}
  self:InitDB()
  if self.RegisterOptions then
    self:RegisterOptions()
  end
  self:RegisterChatCommand("mason", "OnChatCommand")
end

function Mason:OnEnable()
  self:CreateBindOwner()
  self:CreateDropCatcher()
  self:CreateEditMode()
  self:RegisterRuntimeEvents()
  if self.EnsureRules then
    self:EnsureRules()
  end
  if self.InstallFlyoutHooks then
    self:InstallFlyoutHooks()
  end
  if self.EnsureBindCatcher then
    self:EnsureBindCatcher()
  end
  if self.ResetFlyoutsClosed then
    self:ResetFlyoutsClosed()
  end
  self:QueueIfCombat(function()
    self:ApplyOverrides()
    self:ApplyLayout()
    if self.InstallBindBagHooks then
      self:InstallBindBagHooks()
    end
    if self.InstallHotkeyFrameHooks then
      self:InstallHotkeyFrameHooks()
    end
    if self.ScheduleSpellbookHotkeys then
      self:ScheduleSpellbookHotkeys()
    elseif self.RefreshBlizzardHotkeys then
      self:RefreshBlizzardHotkeys()
    end
  end)
end

function Mason:RegisterRuntimeEvents()
  if self.eventFrame then
    return
  end
  local frame = CreateFrame("Frame", "MasonEventFrame", UIParent)
  self.eventFrame = frame
  frame:SetFrameStrata("BACKGROUND")
  frame:EnableMouse(false)
  frame:SetSize(1, 1)
  frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
  frame:Show()
  frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_SPECIALIZATION_CHANGED" then
      local unit = ...
      if unit and unit ~= "player" then
        return
      end
      self:QueueIfCombat(function()
        self:ApplyOverrides()
        self:ApplyLayout()
        if self.RefreshBlizzardHotkeys then
          self:RefreshBlizzardHotkeys()
        end
      end)
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
      if self.InstallBindBagHooks then
        self:InstallBindBagHooks()
      end
      if self.InstallHotkeyFrameHooks then
        self:InstallHotkeyFrameHooks()
      end
      if self.ScheduleSpellbookHotkeys then
        self:ScheduleSpellbookHotkeys()
      elseif self.RequestBlizzardHotkeys then
        self:RequestBlizzardHotkeys()
      elseif self.RefreshBlizzardHotkeys then
        self:QueueIfCombat(function()
          Mason:RefreshBlizzardHotkeys()
        end)
      end
    elseif event == "SPELLS_CHANGED" then
      if self.ScheduleSpellbookHotkeys then
        self:ScheduleSpellbookHotkeys()
      elseif self.RequestBlizzardHotkeys then
        self:RequestBlizzardHotkeys()
      elseif self.RefreshBlizzardHotkeys then
        self:RefreshBlizzardHotkeys()
      end
    elseif event == "PLAYER_REGEN_ENABLED" then
      self:FlushCombatQueue()
      if self.PaintRules then
        self:PaintRules()
      end
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_ENTERING_COMBAT" then
      if self.ExitBindMode then
        self:ExitBindMode()
      end
      self:OnCombatLock()
      if self.PaintRules then
        self:PaintRules()
      end
    elseif event == "PLAYER_TARGET_CHANGED" then
      if self.PaintRules then
        self:PaintRules()
      end
    elseif event == "CURSOR_CHANGED" then
      if self.SyncDropCatcher then
        self:SyncDropCatcher()
      end
    elseif event == "ACTIONBAR_SLOT_CHANGED" then
      if self.OnMasonPickupSlotChanged then
        self:OnMasonPickupSlotChanged()
      end
    elseif event == "BAG_UPDATE_DELAYED" or event == "BAG_CONTAINER_UPDATE" then
      if event == "BAG_UPDATE_DELAYED" and self.RefreshItemCounts then
        self:RefreshItemCounts()
      end
      if self.KbWantsRaise and self:KbWantsRaise() then
        -- 09ab: schedule paint/attach only — never raise from bag events.
        if self.ScheduleBagFollowup then
          self:ScheduleBagFollowup()
        elseif self.RepaintSourceHotkeys then
          self:RepaintSourceHotkeys()
        elseif self.PassBagsRaiseAndPaint then
          self:PassBagsRaiseAndPaint(true)
        end
        if self.HookLateFrameOnShow then
          self:HookLateFrameOnShow(_G.ContainerFrameCombinedBags, "bags")
        end
      end
      if self.RepaintSourceHotkeys then
        self:RepaintSourceHotkeys()
      elseif self.RefreshBlizzardHotkeys then
        self:RefreshBlizzardHotkeys()
      end
    elseif event == "ASSISTED_COMBAT_ACTION_SPELL_CAST" then
      if self.OnAssistedSpellSignal then
        self:OnAssistedSpellSignal()
      end
    elseif event == "CVAR_UPDATE" then
      local name = ...
      if name == "ActionButtonUseKeyDown" then
        self:QueueIfCombat(function()
          self:RefreshExecutorClicks()
        end)
      end
    end
  end)
  frame:SetScript("OnUpdate", function(_, elapsed)
    if InCombatLockdown() then
      if self.ExitBindMode then
        self:ExitBindMode()
      end
      if not self:IsLocked() then
        self:OnCombatLock()
      end
    end
    if self.PollMasonPickup then
      self:PollMasonPickup()
    end
    if self.PollAssistedHighlight then
      self:PollAssistedHighlight(elapsed)
    end
    if self.PaintRules and self.HasVisibleView and self:HasVisibleView() then
      self.rulePaintElapsed = (self.rulePaintElapsed or 0) + elapsed
      if self.rulePaintElapsed >= 0.1 then
        self.rulePaintElapsed = 0
        self:PaintRules()
      end
    else
      self.rulePaintElapsed = 0
    end
  end)
  frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
  frame:RegisterEvent("PLAYER_LOGIN")
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  frame:RegisterEvent("SPELLS_CHANGED")
  frame:RegisterEvent("PLAYER_TARGET_CHANGED")
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  frame:RegisterEvent("PLAYER_REGEN_DISABLED")
  frame:RegisterEvent("CVAR_UPDATE")
  frame:RegisterEvent("CURSOR_CHANGED")
  frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
  frame:RegisterEvent("BAG_UPDATE_DELAYED")
  pcall(frame.RegisterEvent, frame, "BAG_CONTAINER_UPDATE")
  pcall(frame.RegisterEvent, frame, "PLAYER_ENTERING_COMBAT")
  pcall(frame.RegisterEvent, frame, "ASSISTED_COMBAT_ACTION_SPELL_CAST")
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

function Mason:OnChatCommand(input)
  input = strtrim(input or "")
  if input == "" then
    if self.OpenOptions then
      self:OpenOptions()
    else
      self:PrintUsage()
    end
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
      piece = self:FindPieceByKey(token, specID)
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
      print(string.format("Mason: %s %s %s %s", piece.id, piece.type or "spell", self:PieceLabel(piece), piece.key or "-"))
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
    local token = strtrim(rest)
    if string.lower(token) == "ghosts" then
      if self.DebugDockGhosts then
        self:DebugDockGhosts()
      end
      return
    end
    if token ~= "" then
      local piece = self:ResolvePieceToken(token)
      if not piece then
        print("Mason: no piece for " .. token)
        return
      end
      local exec = self.executors and self.executors[piece.id]
      if not exec then
        print("Mason: no executor for " .. piece.id)
        return
      end
      print(string.format(
        "Mason: type=%s flyout=%s spellAttr=%s",
        tostring(exec:GetAttribute("type")),
        tostring(exec:GetAttribute("flyout")),
        tostring(exec:GetAttribute("spell"))
      ))
      return
    end
    local specID = self:GetCurrentSpecID()
    local count = 0
    for _ in pairs(self:GetKit(specID)) do
      count = count + 1
    end
    print(string.format(
      "Mason: specID=%s pieces=%d keyDown=%s combat=%s locked=%s masque=%s lab=%s",
      tostring(specID),
      count,
      tostring(not not GetCVarBool("ActionButtonUseKeyDown")),
      tostring(not not InCombatLockdown()),
      tostring(self:IsLocked()),
      (LibStub("Masque", true) and "yes" or "no"),
      (LibStub("LibActionButton-1.0", true) and "yes" or "no")
    ))
    for id, view in pairs(self:GetViews()) do
      if view.visible then
        local exec = self.executors and self.executors[id]
        if exec then
          local s0 = self.GetFaceNativeSize and self:GetFaceNativeSize() or 45
          local scale = self.GetFaceScale and self:GetFaceScale(exec) or (view.scale or 1)
          print(string.format(
            "Mason: debug face %s S0=%.1f scale=%.3f buttonW=%.1f effectiveScale=%.3f",
            tostring(id),
            s0,
            scale,
            exec:GetWidth() or 0,
            exec:GetEffectiveScale() or 0
          ))
          break
        end
      end
    end
    for id, view in pairs(self:GetViews()) do
      if view.visible then
        local piece = self:FindPiece(id)
        local exec = self.executors and self.executors[id]
        if piece and piece.type == "flyout" and exec then
          print(string.format(
            "Mason: type=%s flyout=%s spellAttr=%s",
            tostring(exec:GetAttribute("type")),
            tostring(exec:GetAttribute("flyout")),
            tostring(exec:GetAttribute("spell"))
          ))
        end
      end
    end
    return
  end

  if cmd == "config" or cmd == "options" then
    if self.OpenOptions then
      self:OpenOptions()
    end
    return
  end

  if cmd == "kb" then
    if self.ToggleBindMode then
      self:ToggleBindMode()
    end
    return
  end

  if cmd == "export" then
    local kind = string.lower(strtrim(rest))
    if self.ExportShare then
      self:ExportShare(kind)
    end
    return
  end

  if cmd == "import" then
    local payload = strtrim(rest)
    if payload == "" then
      if self.ShowShareDialog then
        self:ShowShareDialog("", true)
      end
      return
    end
    if self.ImportShare then
      self:ImportShare(payload)
    end
    return
  end

  if cmd == "edit" or cmd == "lock" then
    if self.ToggleEditMode then
      self:ToggleEditMode()
    end
    return
  end

  if cmd == "hide" then
    local token = strtrim(rest)
    if token == "" then
      print("Mason: usage: /mason hide <key|id|spell>")
      return
    end
    local piece = self:ResolvePieceToken(token)
    if not piece then
      print("Mason: no piece for " .. token)
      return
    end
    local deferred = self:ClearView(piece.id)
    if deferred then
      print("Mason: queued until combat ends")
    end
    return
  end

  if cmd == "show" then
    local token = strtrim(rest)
    if token == "" then
      print("Mason: usage: /mason show <key|id|spell>")
      return
    end
    local piece = self:ResolvePieceToken(token)
    if not piece then
      print("Mason: no piece for " .. token)
      return
    end
    local deferred = self:ShowView(piece.id)
    if deferred then
      print("Mason: queued until combat ends")
    end
    return
  end

  if cmd == "grid" then
    local pixels = tonumber(strtrim(rest))
    if not pixels or not self:SetGridSize(pixels) then
      print("Mason: usage: /mason grid <8-128>")
      return
    end
    print("Mason: grid " .. tostring(self:GetGridSize()))
    return
  end

  if cmd == "snap" then
    local on = not self:IsSnapEnabled()
    self:SetSnapEnabled(on)
    self:Notify(on and "snap on" or "snap off")
    return
  end

  if cmd == "rules" then
    if self.ListRulePresets then
      self:ListRulePresets()
    end
    return
  end

  if cmd == "rule" then
    local preset = string.match(rest, "(%S+)$")
    local token = rest
    if preset then
      token = strtrim(rest:sub(1, #rest - #preset))
    end
    if not preset or token == "" then
      print("Mason: usage: /mason rule <key|id|spell> <preset|clear>")
      return
    end
    preset = string.lower(preset)
    local piece = self:ResolvePieceToken(token)
    if not piece then
      print("Mason: no piece for " .. token)
      return
    end
    if preset ~= "clear" then
      local allowed = {
        always = true,
        combat = true,
        ooc = true,
        target = true,
        harm = true,
        help = true,
        stealth = true,
      }
      if not allowed[preset] then
        print("Mason: invalid condition")
        return
      end
    end
    if self:SetPieceRule(piece.id, preset) then
      self:Notify(self:PieceLabel(piece) .. " rule " .. preset)
    end
    return
  end

  if cmd == "align" then
    local mode = string.lower(strtrim(rest))
    local allowed = {
      left = true,
      right = true,
      top = true,
      bottom = true,
      hcenter = true,
      vcenter = true,
    }
    if not allowed[mode] or not self.AlignSelection then
      print("Mason: usage: /mason align left|right|top|bottom|hcenter|vcenter")
      return
    end
    self:AlignSelection(mode)
    return
  end

  if cmd == "scale" then
    local factor = string.match(rest, "(%S+)$")
    local token = rest
    if factor then
      token = strtrim(rest:sub(1, #rest - #factor))
    end
    factor = tonumber(factor)
    if not token or token == "" or not factor then
      print("Mason: usage: /mason scale <key|id|spell> <factor>")
      return
    end
    local piece = self:ResolvePieceToken(token)
    if not piece then
      print("Mason: no piece for " .. token)
      return
    end
    if not self:SetViewScale(piece.id, factor) then
      print("Mason: usage: /mason scale <key|id|spell> <factor>")
    end
    return
  end

  if cmd == "size" then
    local restTrim = strtrim(rest)
    if restTrim == "" then
      print("Mason: usage: /mason size [token] <px|reset>")
      return
    end
    if restTrim == "reset" then
      local ids = self.SelectedList and self:SelectedList() or {}
      if #ids == 0 then
        print("Mason: usage: /mason size reset")
        return
      end
      self:SizeIdsToDefault(ids)
      return
    end
    local last = string.match(restTrim, "(%S+)$")
    local head = strtrim(restTrim:sub(1, #restTrim - #last))
    if head == "" and tonumber(last) then
      local px = self:SetDefaultSize(last)
      if not px then
        print("Mason: usage: /mason size [token] <px|reset>")
        return
      end
      self:Notify("default size " .. tostring(px))
      return
    end
    if head == "" then
      print("Mason: usage: /mason size [token] <px|reset>")
      return
    end
    local piece = self:ResolvePieceToken(head)
    if not piece then
      print("Mason: no piece for " .. head)
      return
    end
    if string.lower(last) == "reset" then
      self:SetViewSize(piece.id, self:GetDefaultSize())
      return
    end
    local px = tonumber(last)
    if not px then
      print("Mason: usage: /mason size [token] <px|reset>")
      return
    end
    self:SetViewSize(piece.id, px)
    return
  end

  if cmd == "flyout" then
    if self.HandleFlyoutSlash then
      self:HandleFlyoutSlash(rest)
    end
    return
  end

  if cmd == "undock" then
    local token = strtrim(rest)
    if token ~= "" then
      local piece = self:ResolvePieceToken(token)
      if not piece then
        print("Mason: no piece for " .. token)
        return
      end
      self:UndockView(piece.id)
      if not InCombatLockdown() then
        self:PlaceView(piece.id)
      else
        self:QueueIfCombat(function()
          self:PlaceView(piece.id)
        end)
      end
      return
    end
    local selected = self.SelectedList and self:SelectedList() or {}
    if #selected == 0 then
      print("Mason: usage: /mason undock <key|id|spell>")
      return
    end
    for i = 1, #selected do
      local id = selected[i]
      self:UndockView(id)
      if not InCombatLockdown() then
        self:PlaceView(id)
      else
        self:QueueIfCombat(function()
          self:PlaceView(id)
        end)
      end
    end
    return
  end

  self:PrintUsage()
end
