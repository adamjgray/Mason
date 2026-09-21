local Mason = LibStub("AceAddon-3.0"):GetAddon("Mason")

function Mason:ExecutorName(id)
  local sanitized = tostring(id):gsub("[^%w_]", "_")
  return "MasonExec_" .. sanitized
end

function Mason:CreateBindOwner()
  if self.bindOwner then
    return self.bindOwner
  end
  local owner = CreateFrame("Frame", "MasonBindOwner", UIParent)
  self.bindOwner = owner
  return owner
end

local function HonorKeyDownClicks(exec)
  if GetCVarBool("ActionButtonUseKeyDown") then
    exec:RegisterForClicks("AnyDown")
  else
    exec:RegisterForClicks("AnyUp")
  end
end

function Mason:ConfigureExecutor(exec, piece)
  local ptype = piece.type or "spell"
  exec:SetAttribute("type", ptype)
  exec:SetAttribute("type2", "")
  if ptype == "spell" then
    -- Non-LAB path: name for CastSpellByName; fall back to ID if name unknown.
    local spell = (self.SpellActionForSecure and self:SpellActionForSecure(piece))
      or piece.spellID
      or piece.spellName
    exec:SetAttribute("spell", spell)
  elseif ptype == "item" or ptype == "toy" then
    exec:SetAttribute("item", piece.itemID)
  elseif ptype == "macro" then
    exec:SetAttribute("macro", piece.macroName)
  elseif ptype == "flyout" then
    exec:SetAttribute("type", "")
    exec:SetAttribute("flyout", nil)
    exec:SetAttribute("spell", nil)
    exec:SetAttribute("LABUseCustomFlyout", false)
  end
  HonorKeyDownClicks(exec)
end

function Mason:EnsureExecutor(piece)
  local name = self:ExecutorName(piece.id)
  local exec = self.executors[piece.id] or _G[name]
  if not exec then
    exec = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    exec:SetSize(1, 1)
    exec:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -2000, -2000)
    exec:EnableMouse(false)
    exec:Hide()
    exec:SetAlpha(0)
  end
  exec.masonPieceId = piece.id
  self.executors[piece.id] = exec
  self:ConfigureExecutor(exec, piece)
  if self.WireExecutorView then
    self:WireExecutorView(exec)
  end
  return exec
end

function Mason:CrateExecutorVisual(id)
  local exec = self.executors[id] or _G[self:ExecutorName(id)]
  if not exec then
    return
  end
  if self.ClearVisibilityDriver then
    self:ClearVisibilityDriver(exec)
  end
  if not InCombatLockdown() then
    exec:SetParent(UIParent)
  end
  exec:EnableMouse(false)
  exec:Hide()
  exec:SetAlpha(0)
  exec:ClearAllPoints()
  exec:SetSize(1, 1)
  exec:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -2000, -2000)
  local host = self.scaleHosts and self.scaleHosts[id]
  if host then
    host:Hide()
  end
  if self.HideFlyoutArrow then
    self:HideFlyoutArrow(exec)
  end
  if self.HideEditHandle then
    self:HideEditHandle(id)
  end
end

function Mason:ParkExecutor(id)
  local exec = self.executors[id] or _G[self:ExecutorName(id)]
  if not exec then
    return
  end
  exec:SetAttribute("type", nil)
  exec:SetAttribute("spell", nil)
  exec:SetAttribute("item", nil)
  exec:SetAttribute("macro", nil)
  exec:SetAttribute("flyout", nil)
  self:CrateExecutorVisual(id)
end

function Mason:RefreshExecutorClicks()
  if InCombatLockdown() then
    return
  end
  for id in pairs(self:GetKit()) do
    local exec = self.executors[id] or _G[self:ExecutorName(id)]
    if exec then
      HonorKeyDownClicks(exec)
    end
  end
end
