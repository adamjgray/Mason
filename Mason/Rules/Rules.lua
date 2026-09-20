local Mason = LibStub("AceAddon-3.0"):GetAddon("Mason")

local DEFAULT_ALPHA = 1

local PRESETS = {
  always = { id = "r_always", name = "Always", visibility = "show" },
  combat = { id = "r_combat", name = "Combat", visibility = "[combat] show; hide" },
  ooc = { id = "r_ooc", name = "Out of combat", visibility = "[nocombat] show; hide" },
  target = { id = "r_target", name = "Target", visibility = "[@target,exists] show; hide" },
  harm = { id = "r_harm", name = "Harm", visibility = "[@target,harm] show; hide" },
  help = { id = "r_help", name = "Help", visibility = "[@target,help] show; hide" },
  stealth = { id = "r_stealth", name = "Stealth", visibility = "[stealth] show; hide" },
}

local PRESET_ORDER = { "always", "combat", "ooc", "target", "harm", "help", "stealth" }

function Mason:EnsureRules()
  local rules = self.db.profile.rules
  if not rules then
    rules = {}
    self.db.profile.rules = rules
  end
  for i = 1, #PRESET_ORDER do
    local key = PRESET_ORDER[i]
    local spec = PRESETS[key]
    local row = rules[spec.id]
    if not row then
      row = {
        id = spec.id,
        name = spec.name,
        visibility = spec.visibility,
        alphaCombat = 1,
        alphaOOC = 1,
        desatUnusable = true,
      }
      rules[spec.id] = row
    else
      row.id = spec.id
      row.name = row.name or spec.name
      row.visibility = spec.visibility
      if row.alphaCombat == nil then
        row.alphaCombat = 1
      end
      if row.alphaOOC == nil then
        row.alphaOOC = 1
      end
      if row.desatUnusable == nil then
        row.desatUnusable = true
      end
    end
  end
  return rules
end

function Mason:GetRule(ruleId)
  if not ruleId then
    return nil
  end
  local rules = self.db.profile.rules or self:EnsureRules()
  return rules[ruleId] or rules[tostring(ruleId)]
end

function Mason:PresetNameForRuleId(ruleId)
  for i = 1, #PRESET_ORDER do
    local key = PRESET_ORDER[i]
    if PRESETS[key].id == ruleId then
      return key
    end
  end
  return nil
end

function Mason:ListRulePresets()
  for i = 1, #PRESET_ORDER do
    local key = PRESET_ORDER[i]
    local spec = PRESETS[key]
    print(string.format("Mason: %s %s %s", key, spec.id, spec.visibility))
  end
end

function Mason:ValidateVisibility(cond)
  if type(cond) ~= "string" then
    return false, "invalid condition"
  end
  cond = strtrim(cond)
  if cond == "" then
    return false, "invalid condition"
  end
  for clause in string.gmatch(cond .. ";", "([^;]*);") do
    clause = strtrim(clause)
    if clause ~= "" then
      local state = clause:match("(%S+)$")
      if not state then
        return false, "invalid condition"
      end
      state = string.lower(state)
      if state ~= "show" and state ~= "hide" then
        return false, "invalid condition"
      end
      local options = clause:match("^(%b[])")
      if options and SecureCmdOptionParse then
        local ok, err = pcall(SecureCmdOptionParse, options)
        if not ok then
          return false, tostring(err or "invalid condition")
        end
      end
    end
  end
  return true
end

function Mason:GetPieceRuleIds(id)
  local view = self:GetViews()[id]
  if not view then
    return {}
  end
  if type(view.ruleIds) == "table" then
    local out = {}
    for i = 1, #view.ruleIds do
      out[#out + 1] = view.ruleIds[i]
    end
    return out
  end
  if view.ruleId then
    return { view.ruleId }
  end
  return {}
end

function Mason:PieceHasRules(id)
  return #self:GetPieceRuleIds(id) > 0
end

function Mason:CombineRuleVisibility(ruleIds)
  if not ruleIds or #ruleIds == 0 then
    return "show"
  end
  local opts = {}
  for i = 1, #ruleIds do
    local rule = self:GetRule(ruleIds[i])
    if rule and rule.visibility then
      if rule.visibility ~= "show" then
        local opt = string.match(rule.visibility, "^(%b[])")
        if opt then
          opts[#opts + 1] = opt
        end
      end
    end
  end
  if #opts == 0 then
    return "show"
  end
  return table.concat(opts, "") .. " show; hide"
end

function Mason:GetViewVisibility(view)
  local vis = "show"
  if view then
    local ids = view.ruleIds
    if type(ids) ~= "table" and view.ruleId then
      ids = { view.ruleId }
    end
    if type(ids) == "table" and #ids > 0 then
      vis = self:CombineRuleVisibility(ids)
    elseif view.ruleId then
      local rule = self:GetRule(view.ruleId)
      if rule and rule.visibility then
        vis = rule.visibility
      end
    end
    if view.override and view.override.visibility then
      vis = view.override.visibility
    end
  end
  return vis
end

function Mason:GetViewPaint(view)
  local alpha = DEFAULT_ALPHA
  local desatUnusable = true
  if not view then
    return alpha, desatUnusable
  end
  local ruleId = view.ruleId
  if (not ruleId) and type(view.ruleIds) == "table" then
    ruleId = view.ruleIds[1]
  end
  if ruleId then
    local rule = self:GetRule(ruleId)
    if rule then
      if InCombatLockdown() then
        if rule.alphaCombat ~= nil then
          alpha = rule.alphaCombat
        end
      elseif rule.alphaOOC ~= nil then
        alpha = rule.alphaOOC
      end
      if rule.desatUnusable ~= nil then
        desatUnusable = rule.desatUnusable
      end
    end
  end
  if view and view.override and view.override.alpha ~= nil then
    alpha = view.override.alpha
  end
  return alpha, desatUnusable
end

function Mason:PaintRule(exec)
  if not exec then
    return
  end
  local id = exec.masonPieceId
  if not id or not self.GetViews then
    return
  end
  local view = self:GetViews()[id]
  if not view or not view.visible then
    return
  end
  local alpha, desatUnusable = self:GetViewPaint(view)
  pcall(function()
    exec:SetAlpha(alpha)
  end)
  local icon = exec.icon
  if icon and desatUnusable then
    pcall(function()
      local usable = true
      if exec.IsUsable then
        usable = exec:IsUsable()
      end
      if usable == false then
        if icon.SetDesaturated then
          icon:SetDesaturated(true)
        end
      end
    end)
  end
end

function Mason:PaintRules()
  if not self.HasVisibleView or not self:HasVisibleView() then
    return
  end
  for id, view in pairs(self:GetViews()) do
    if view.visible then
      local exec = self.executors and self.executors[id]
      if exec then
        self:PaintRule(exec)
      end
    end
  end
end

function Mason:ClearVisibilityDriver(exec)
  if not exec or InCombatLockdown() then
    return
  end
  if UnregisterStateDriver then
    UnregisterStateDriver(exec, "visibility")
  end
end

function Mason:ApplyRule(exec, piece)
  if not exec or not piece then
    return
  end
  if InCombatLockdown() then
    return self:QueueIfCombat(function()
      self:ApplyRule(exec, piece)
    end)
  end
  local view = self:GetViews()[piece.id]
  if not view or not view.visible then
    self:ClearVisibilityDriver(exec)
    return
  end
  if self:InEditMode() then
    self:ClearVisibilityDriver(exec)
    exec:Show()
    self:PaintRule(exec)
    return
  end
  local vis = self:GetViewVisibility(view)
  local ok, err = self:ValidateVisibility(vis)
  if not ok then
    print("Mason: " .. (err or "invalid condition"))
    return
  end
  self:ClearVisibilityDriver(exec)
  RegisterStateDriver(exec, "visibility", vis)
  self:PaintRule(exec)
end

function Mason:ApplyRules()
  if InCombatLockdown() then
    return self:QueueIfCombat(function()
      self:ApplyRules()
    end)
  end
  self:EnsureRules()
  local kit = self:GetKit()
  for id, view in pairs(self:GetViews()) do
    if view.visible and kit[id] then
      local exec = self.executors and self.executors[id]
      if exec then
        self:ApplyRule(exec, kit[id])
      end
    end
  end
end

function Mason:SetPieceRuleIds(id, ruleIds)
  local piece = self:FindPiece(id)
  if not piece then
    return false
  end
  local views = self:GetViews()
  local view = views[id] or {}
  views[id] = view
  if not ruleIds or #ruleIds == 0 then
    view.ruleId = nil
    view.ruleIds = nil
    if view.override then
      view.override.visibility = nil
    end
  else
    local vis = self:CombineRuleVisibility(ruleIds)
    local ok, err = self:ValidateVisibility(vis)
    if not ok then
      print("Mason: " .. (err or "invalid condition"))
      return false
    end
    view.ruleIds = ruleIds
    view.ruleId = ruleIds[1]
  end
  local exec = self.executors and self.executors[id]
  if exec and view.visible then
    self:ApplyRule(exec, piece)
  end
  return true
end

function Mason:SetPieceRule(id, preset)
  local piece = self:FindPiece(id)
  if not piece then
    return false
  end
  if preset == "clear" then
    return self:SetPieceRuleIds(id, nil)
  end
  local spec = PRESETS[preset]
  if not spec then
    print("Mason: invalid condition")
    return false
  end
  return self:SetPieceRuleIds(id, { spec.id })
end
