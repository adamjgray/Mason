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
  if ptype == "spell" then
    exec:SetAttribute("spell", piece.spellID or piece.spellName)
  elseif ptype == "item" then
    exec:SetAttribute("item", piece.itemID)
  elseif ptype == "macro" then
    exec:SetAttribute("macro", piece.macroName)
  end
  HonorKeyDownClicks(exec)
  exec:EnableMouse(false)
  exec:Hide()
  exec:SetAlpha(0)
end

function Mason:EnsureExecutor(piece)
  local name = self:ExecutorName(piece.id)
  local exec = self.executors[piece.id] or _G[name]
  if not exec then
    exec = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    exec:SetSize(1, 1)
    exec:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -2000, -2000)
  end
  self.executors[piece.id] = exec
  self:ConfigureExecutor(exec, piece)
  return exec
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
  exec:EnableMouse(false)
  exec:Hide()
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
