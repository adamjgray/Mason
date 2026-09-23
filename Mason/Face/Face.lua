local Mason = LibStub("AceAddon-3.0"):GetAddon("Mason")

local SHOW_CD_TEXT = true
local SHOW_HOTKEY = true
local SHOW_COUNT = true

-- LAB-1.0 has no wrap API. CreateButton(id, name, header, config) always
-- CreateFrame("CheckButton", name, header, "ActionButtonTemplate, SecureActionButtonTemplate").
-- Architect-allowed path: that name is MasonExec_<id>, the bind target. One frame per piece.

local FACE_CONFIG = {
  outOfRangeColoring = "button",
  tooltip = "enabled",
  showGrid = true,
  cooldownCount = SHOW_CD_TEXT,
  assistedHighlight = false,
  actionButtonUI = false,
  hideElements = {
    macro = false,
    hotkey = not SHOW_HOTKEY,
    equipped = false,
    border = false,
    borderIfEmpty = false,
  },
}

function Mason:GetLAB()
  return LibStub("LibActionButton-1.0", true)
end

function Mason:GetMasqueGroup()
  if self.masqueGroup == false then
    return nil
  end
  if self.masqueGroup then
    return self.masqueGroup
  end
  local MSQ = LibStub("Masque", true)
  if not MSQ then
    self.masqueGroup = false
    return nil
  end
  self.masqueGroup = MSQ:Group("Mason")
  return self.masqueGroup
end

function Mason:GetLABHeader()
  if self.labHeader then
    return self.labHeader
  end
  local header = CreateFrame("Frame", "MasonLABHeader", UIParent, "SecureHandlerBaseTemplate")
  header:SetSize(1, 1)
  header:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
  header:EnableMouse(false)
  header:Show()
  self.labHeader = header
  return header
end

function Mason:GetFaceNativeSize()
  local ab = _G.ActionButton1
  local w = ab and ab.GetWidth and ab:GetWidth()
  if w and w > 0 then
    return w
  end
  return 45
end

function Mason:GetFaceScale(exec)
  local id = exec and exec.masonPieceId
  if id and self.GetViews then
    local view = self:GetViews()[id]
    if view then
      local s0 = self:GetFaceNativeSize()
      if s0 > 0 then
        return self:GetViewSize(view) / s0
      end
    end
  end
  return 1
end

function Mason:GetDefaultSize()
  local s0 = self:GetFaceNativeSize()
  if not self.db or not self.db.profile then
    return s0
  end
  local n = tonumber(self.db.profile.defaultSize)
  if not n then
    return s0
  end
  return n
end

function Mason:SetDefaultSize(px)
  px = self:ClampViewSize(px)
  if not px then
    return false
  end
  self.db.profile.defaultSize = px
  return px
end

function Mason:ClampViewSize(px)
  px = tonumber(px)
  if not px then
    return nil
  end
  if px < 16 then
    px = 16
  elseif px > 128 then
    px = 128
  end
  return math.floor(px + 0.5)
end

function Mason:GetViewSize(view)
  if view and tonumber(view.size) then
    return view.size
  end
  local s0 = self:GetFaceNativeSize()
  if view and tonumber(view.scale) then
    return s0 * view.scale
  end
  return self:GetDefaultSize()
end

function Mason:SyncViewSize(view, size)
  size = self:ClampViewSize(size) or self:GetDefaultSize()
  view.size = size
  local s0 = self:GetFaceNativeSize()
  if s0 > 0 then
    view.scale = size / s0
  end
  return size
end

function Mason:EnsureViewSize(view)
  if not view then
    return self:GetDefaultSize()
  end
  return self:SyncViewSize(view, self:GetViewSize(view))
end

function Mason:StripSlotArt(exec)
  if not exec or self:GetMasqueGroup() then
    return
  end
end

function Mason:FitFace(exec)
  if not exec or InCombatLockdown() then
    return
  end
  local s0 = self:GetFaceNativeSize()
  exec:SetScale(1)
  exec:SetSize(s0, s0)
end

function Mason:FitFaceIcon(exec)
  self:FitFace(exec)
end

function Mason:FitHoverChrome(exec)
end

function Mason:HookFaceRange(exec)
  if not exec then
    return
  end
  exec.IsUnitInRange = function(self, unit)
    if unit == "" then
      unit = nil
    end
    unit = unit or "target"
    -- Item: do not call IsItemInRange / C_Item.IsItemInRange — protected in LAB
    -- poll context (upstream LAB leaves Item.IsUnitInRange unset for the same reason).
    if self._state_type == "spell" and self._state_action then
      if C_Spell and C_Spell.IsSpellInRange then
        local ok, inRange = pcall(C_Spell.IsSpellInRange, self._state_action, unit)
        if ok then
          return inRange
        end
      end
    end
    return nil
  end
end

function Mason:PieceIsToy(piece)
  if not piece then
    return false
  end
  if piece.type == "toy" then
    return true
  end
  local id = piece.itemID
  if not id then
    return false
  end
  if PlayerHasToy and PlayerHasToy(id) then
    return true
  end
  if C_ToyBox then
    if C_ToyBox.GetToyFromItemID then
      local toyID = C_ToyBox.GetToyFromItemID(id)
      if toyID and toyID ~= 0 then
        return true
      end
    end
    if C_ToyBox.GetToyInfo then
      local info = C_ToyBox.GetToyInfo(id)
      if info then
        return true
      end
    end
  end
  return false
end

function Mason:ItemStackCount(itemID)
  if not itemID then
    return 0
  end
  if C_Item and C_Item.GetItemCount then
    return C_Item.GetItemCount(itemID) or 0
  end
  if GetItemCount then
    return GetItemCount(itemID) or 0
  end
  return 0
end

function Mason:ToyIsUsable(itemID)
  if not itemID then
    return false
  end
  if PlayerHasToy and not PlayerHasToy(itemID) then
    return false
  end
  if C_ToyBox and C_ToyBox.IsToyUsable then
    return not not C_ToyBox.IsToyUsable(itemID)
  end
  return true
end

function Mason:ApplyFaceTypeOverrides(exec, piece)
  if not exec then
    return
  end
  piece = piece or (exec.masonPieceId and self:FindPiece(exec.masonPieceId))
  if not piece then
    return
  end
  local ptype = piece.type or "spell"
  if ptype == "flyout" then
    if self.ConfigureFlyoutParent and not self.masonPopulatingFlyout and not exec.masonFlyoutConfigured then
      self:ConfigureFlyoutParent(exec, piece)
    end
    exec.IsUsable = function()
      return true, false
    end
    exec.IsUnitInRange = function()
      return nil
    end
    exec.outOfRange = false
    exec.HasAction = function()
      return true
    end
    if exec.icon then
      exec.icon:SetVertexColor(1, 1, 1)
      if exec.icon.SetDesaturated then
        exec.icon:SetDesaturated(false)
      end
    end
    if self.UpdateFlyoutArrow then
      self:UpdateFlyoutArrow(exec, piece)
    end
    return
  end
  if self.HideFlyoutArrow then
    self:HideFlyoutArrow(exec)
  end
  if ptype == "macro" then
    exec.IsUsable = function()
      return true, false
    end
    exec.IsUnitInRange = function()
      return nil
    end
    exec.outOfRange = false
    if exec.icon then
      exec.icon:SetVertexColor(1, 1, 1)
      if exec.icon.SetDesaturated then
        exec.icon:SetDesaturated(false)
      end
    end
    return
  end
  if ptype == "item" or ptype == "toy" then
    local itemID = piece.itemID
    local isToy = ptype == "toy" or self:PieceIsToy(piece)
    if isToy then
      exec.GetCount = function()
        return 0
      end
      exec.IsConsumableOrStackable = function()
        return false
      end
      exec.GetDisplayCount = function()
        return ""
      end
      exec.IsUsable = function()
        return Mason:ToyIsUsable(itemID), false
      end
      exec.IsUnitInRange = function()
        return nil
      end
      exec.outOfRange = false
      if exec.icon then
        if self:ToyIsUsable(itemID) then
          exec.icon:SetVertexColor(1, 1, 1)
        else
          exec.icon:SetVertexColor(0.4, 0.4, 0.4)
        end
        if exec.icon.SetDesaturated then
          exec.icon:SetDesaturated(false)
        end
      end
    else
      exec.GetCount = function()
        return Mason:ItemStackCount(itemID)
      end
      exec.IsConsumableOrStackable = function()
        return true
      end
      exec.GetDisplayCount = function(self)
        local count = self:GetCount() or 0
        if count > (self.maxDisplayCount or 9999) then
          return "*"
        end
        return count
      end
    end
    self:UpdatePieceCount(exec, piece)
  end
end

function Mason:UpdatePieceCount(exec, piece)
  if not exec or not exec.Count then
    return
  end
  piece = piece or (exec.masonPieceId and self:FindPiece(exec.masonPieceId))
  if not piece then
    return
  end
  if piece.type == "toy" or self:PieceIsToy(piece) then
    exec.Count:SetText("")
    exec.Count:Hide()
    return
  end
  if piece.type ~= "item" then
    return
  end
  if not SHOW_COUNT then
    exec.Count:Hide()
    return
  end
  local count = self:ItemStackCount(piece.itemID)
  if count > (exec.maxDisplayCount or 9999) then
    exec.Count:SetText("*")
  else
    exec.Count:SetText(tostring(count))
  end
  exec.Count:Show()
end

function Mason:RefreshItemCounts()
  for _, exec in pairs(self.executors or {}) do
    self:UpdatePieceCount(exec)
  end
end


function Mason:SpellIDFromTraitEntry(configID, entryID)
  if not configID or not entryID or not C_Traits then
    return nil
  end
  if not C_Traits.GetEntryInfo or not C_Traits.GetDefinitionInfo then
    return nil
  end
  local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
  local defID = entryInfo and entryInfo.definitionID
  if not defID then
    return nil
  end
  local def = C_Traits.GetDefinitionInfo(defID)
  return def and tonumber(def.spellID) or nil
end

-- Active spell on a Selection/choice talent node that contains spellID (sibling swap).
function Mason:ActiveSpellOnSharedChoiceNode(spellID)
  spellID = tonumber(spellID)
  if not spellID or not C_Traits or not C_ClassTalents then
    return nil
  end
  if not C_ClassTalents.GetActiveConfigID or not C_Traits.GetConfigInfo
    or not C_Traits.GetTreeNodes or not C_Traits.GetNodeInfo then
    return nil
  end
  local configID = C_ClassTalents.GetActiveConfigID()
  if not configID then
    return nil
  end
  local configInfo = C_Traits.GetConfigInfo(configID)
  if not configInfo or not configInfo.treeIDs then
    return nil
  end
  local selectionType = Enum and Enum.TraitNodeType and Enum.TraitNodeType.Selection
  local subTreeType = Enum and Enum.TraitNodeType and Enum.TraitNodeType.SubTreeSelection
  for _, treeID in ipairs(configInfo.treeIDs) do
    local nodes = C_Traits.GetTreeNodes(treeID)
    if nodes then
      for _, nodeID in ipairs(nodes) do
        local node = C_Traits.GetNodeInfo(configID, nodeID)
        -- Choice nodes expose 2+ entryIDs; skip single-entry traits.
        if node and node.entryIDs and #node.entryIDs >= 2 then
          local ntype = node.type
          if not ntype
            or not selectionType
            or ntype == selectionType
            or (subTreeType and ntype == subTreeType) then
            local contains = false
            for _, entryID in ipairs(node.entryIDs) do
              local sid = self:SpellIDFromTraitEntry(configID, entryID)
              if sid and sid == spellID then
                contains = true
                break
              end
            end
            if contains then
              local activeEntryID = node.activeEntry and node.activeEntry.entryID
              if not activeEntryID and node.entryIDsWithCommittedRanks then
                activeEntryID = node.entryIDsWithCommittedRanks[1]
              end
              if activeEntryID then
                local activeSpell = self:SpellIDFromTraitEntry(configID, activeEntryID)
                if activeSpell and activeSpell > 0 then
                  return activeSpell
                end
              end
            end
          end
        end
      end
    end
  end
  return nil
end

-- Preferences: choice-node pieces follow the active talent (like default bars).
-- Mutates kit spellID only for Selection-node siblings — not every GetOverrideSpell
-- (avoids stance/temp override thrash into SavedVariables).
function Mason:SyncChoiceNodeSpells()
  if InCombatLockdown() then
    return self:QueueIfCombat(function()
      Mason:SyncChoiceNodeSpells()
    end)
  end
  local kit = self.GetKit and self:GetKit()
  if not kit then
    return
  end
  local changed = false
  for _, piece in pairs(kit) do
    if (piece.type or "spell") == "spell" and piece.spellID then
      local cur = tonumber(piece.spellID)
      local active = self:ActiveSpellOnSharedChoiceNode(cur)
      active = tonumber(active)
      local kitChanged = active and cur and active ~= cur
      if kitChanged then
        piece.spellID = active
        if C_Spell and C_Spell.GetSpellName then
          piece.spellName = C_Spell.GetSpellName(active) or piece.spellName
        elseif GetSpellInfo then
          piece.spellName = GetSpellInfo(active) or piece.spellName
        end
        changed = true
      end
      local exec = self.executors and self.executors[piece.id]
      if exec then
        local labId = self.ResolveSpellCastIdentity and select(1, self:ResolveSpellCastIdentity(piece))
        labId = tonumber(labId) or tonumber(piece.spellID)
        if kitChanged or exec.masonLastLabId ~= labId then
          if exec.__LAB_Version then
            self:ConfigureFace(exec, piece)
          else
            self:ConfigureExecutor(exec, piece)
          end
          if self.UpdateFace and exec.__LAB_Version then
            self:UpdateFace(exec, piece)
          elseif self.PaintView then
            self:PaintView(exec, piece)
          end
          exec.masonLastLabId = labId
          changed = true
        end
      end
    end
  end
  if changed then
    if self.OnAssistedSpellSignal then
      self:OnAssistedSpellSignal()
    end
    if self.RepaintSourceHotkeys then
      self:RepaintSourceHotkeys()
    end
  end
end

-- Talent / replacement spells (e.g. Greater Invisibility): CastSpellByID no-ops
-- while CastSpellByName works. LAB Spell handlers need a numeric _state_action
-- (FindSpellBookSlotBySpellID). Split: LAB SetState keeps override ID; secure
-- "spell" attribute gets the localized name for cast. Kit identity stays piece.spellID
-- except SyncChoiceNodeSpells (choice-node active entry).
function Mason:ResolveSpellCastIdentity(piece)
  if not piece then
    return nil, nil
  end
  local id = tonumber(piece.spellID)
  local name = piece.spellName
  local castId = id
  if id then
    if C_Spell and C_Spell.GetOverrideSpell then
      local ok, ov = pcall(C_Spell.GetOverrideSpell, id)
      ov = ok and tonumber(ov) or nil
      if ov and ov > 0 then
        castId = ov
      end
    elseif FindSpellOverrideBySpellID then
      local ok, ov = pcall(FindSpellOverrideBySpellID, id)
      ov = ok and tonumber(ov) or nil
      if ov and ov > 0 then
        castId = ov
      end
    end
    if C_Spell and C_Spell.GetSpellName then
      name = C_Spell.GetSpellName(castId) or name
    elseif GetSpellInfo then
      name = GetSpellInfo(castId) or name
    end
  end
  if type(name) ~= "string" or name == "" then
    name = nil
  end
  return castId, name
end

-- Localized name for SecureActionButton cast (CastSpellByName). Nil if unknown.
function Mason:SpellActionForSecure(piece)
  local _, name = self:ResolveSpellCastIdentity(piece)
  return name
end

function Mason:NormalizeAssistedSpellID(id)
  id = tonumber(id)
  if not id or id == 0 then
    return nil
  end
  return id
end

-- Exact ID only: SpellIDsMatch here skipped assisted refreshes when the next-cast
-- recommendation moved between related/talent IDs (C-08 smoke FAIL 2).
function Mason:AssistedSpellUnchanged(a, b)
  a = self:NormalizeAssistedSpellID(a)
  b = self:NormalizeAssistedSpellID(b)
  if not a and not b then
    return true
  end
  if not a or not b then
    return false
  end
  return a == b
end

function Mason:OnAssistedSpellSignal()
  self:SyncAssistedSpell()
end

function Mason:PollAssistedHighlight()
  self:SyncAssistedSpell()
end

function Mason:AssistedOverlayNeedsShow()
  for _, exec in pairs(self.executors or {}) do
    if exec.__LAB_Version and self:AssistedShouldShow(exec) then
      local frame = exec.AssistedCombatHighlightFrame
      if not frame or not frame:IsShown() then
        return true
      end
    end
  end
  return false
end

function Mason:SyncAssistedSpell()
  if not self:HasVisibleView() then
    return
  end
  local rec = self:NormalizeAssistedSpellID(self:GetAssistedSpellID())
  local unchanged = self:AssistedSpellUnchanged(rec, self.assistedLastSpell)
  self.assistedLastSpell = rec
  if unchanged and not self:AssistedOverlayNeedsShow() then
    -- Next-cast ID stable, but LAB UpdateAction may have restored the generic
    -- assisted-action icon — repaint recommended texture on the rotation button.
    for _, exec in pairs(self.executors or {}) do
      if exec.__LAB_Version then
        self:UpdateAssistedCombatButtonIcon(exec)
        self:UpdateAssistedCombatRotationOverlay(exec)
      end
    end
    return
  end
  self:RefreshAssistedHighlights()
end

function Mason:IsAssistedHighlightRingEnabled()
  if not self.db or not self.db.profile then
    return true
  end
  if self.db.profile.assistedHighlightRing == nil then
    return true
  end
  return not not self.db.profile.assistedHighlightRing
end

function Mason:SetAssistedHighlightRingEnabled(enabled)
  if not self.db or not self.db.profile then
    return
  end
  self.db.profile.assistedHighlightRing = not not enabled
  if self.RefreshAssistedHighlights then
    self:RefreshAssistedHighlights()
  end
end

function Mason:IsAssistedRotationArrowEnabled()
  if not self.db or not self.db.profile then
    return true
  end
  if self.db.profile.assistedRotationArrow == nil then
    return true
  end
  return not not self.db.profile.assistedRotationArrow
end

function Mason:SetAssistedRotationArrowEnabled(enabled)
  if not self.db or not self.db.profile then
    return
  end
  self.db.profile.assistedRotationArrow = not not enabled
  if self.RefreshAssistedHighlights then
    self:RefreshAssistedHighlights()
  end
end

-- Live next-cast, sticky last recommend, or first rotation spell — never the
-- generic assisted-action spell (including when the recommend is on cooldown).
function Mason:GetAssistedRecommendedSpellID(piece)
  local actionId = self:GetAssistedActionSpellID()
  local function live(id)
    id = tonumber(id)
    if not id or id == 0 then
      return nil
    end
    -- API sometimes returns the action spell itself before a real recommendation.
    if actionId and id == actionId then
      return nil
    end
    return id
  end
  if AssistedCombatManager and AssistedCombatManager.lastNextCastSpellID then
    local id = live(AssistedCombatManager.lastNextCastSpellID)
    if id then
      return id
    end
  end
  if C_AssistedCombat and C_AssistedCombat.GetNextCastSpell then
    local id = live(C_AssistedCombat.GetNextCastSpell(false))
    if id then
      return id
    end
    id = live(C_AssistedCombat.GetNextCastSpell(true))
    if id then
      return id
    end
  end
  if C_AssistedCombat and C_AssistedCombat.GetRotationSpells then
    local ok, spells = pcall(C_AssistedCombat.GetRotationSpells)
    if ok and type(spells) == "table" then
      for i = 1, #spells do
        local id = live(spells[i])
        if id then
          return id
        end
      end
    end
  end
  -- Sticky through CD / OOC gaps when the API briefly returns nil or action spell.
  if piece and piece.assistedLastSpellID then
    local sticky = tonumber(piece.assistedLastSpellID)
    if sticky and sticky ~= 0 and sticky ~= actionId then
      return sticky
    end
  end
  return nil
end

function Mason:GetAssistedNextCastSpellID()
  return self:GetAssistedRecommendedSpellID()
end

function Mason:GetAssistedActionSpellID()
  if AssistedCombatManager and AssistedCombatManager.GetActionSpellID then
    local id = AssistedCombatManager:GetActionSpellID()
    if id and id ~= 0 then
      return tonumber(id)
    end
  end
  if C_AssistedCombat and C_AssistedCombat.GetActionSpell then
    local id = C_AssistedCombat.GetActionSpell()
    if id and id ~= 0 then
      return tonumber(id)
    end
  end
  return nil
end

function Mason:GetAssistedSpellID()
  return self:GetAssistedRecommendedSpellID() or self:GetAssistedActionSpellID()
end

-- Copy displayed texture from a Blizzard assisted-combat action slot (OOC-safe).
function Mason:GetAssistedCombatSlotTexture()
  if not (C_ActionBar and C_ActionBar.IsAssistedCombatAction and GetActionTexture) then
    return nil
  end
  local actionId = self:GetAssistedActionSpellID()
  local generic
  if actionId and C_Spell and C_Spell.GetSpellTexture then
    generic = C_Spell.GetSpellTexture(actionId)
  end
  for slot = 1, 180 do
    local ok, assisted = pcall(C_ActionBar.IsAssistedCombatAction, slot)
    if ok and assisted then
      if C_ActionBar.ForceUpdateAction then
        pcall(C_ActionBar.ForceUpdateAction, slot, true)
      end
      local tex = GetActionTexture(slot)
      if tex and tex ~= 0 and tex ~= generic then
        return tex
      end
    end
  end
  return nil
end

-- Single-button assistant: sticky kit flag + action-spell ID match.
function Mason:IsAssistedCombatPiece(piece)
  if not piece or (piece.type or "spell") ~= "spell" then
    return false
  end
  if piece.assistedCombat then
    return true
  end
  local actionId = self:GetAssistedActionSpellID()
  local sid = tonumber(piece.spellID)
  if actionId and sid and sid == actionId then
    piece.assistedCombat = true
    return true
  end
  return false
end

function Mason:StampAssistedCombatPieces()
  local actionId = self:GetAssistedActionSpellID()
  if not actionId then
    return
  end
  for _, piece in pairs(self:GetKit() or {}) do
    if (piece.type or "spell") == "spell" and tonumber(piece.spellID) == actionId then
      piece.assistedCombat = true
    end
  end
end

function Mason:ScheduleAssistedCombatIconRetry(exec)
  if not exec or exec.masonAssistedIconRetry then
    return
  end
  exec.masonAssistedIconRetry = true
  if AssistedCombatManager and AssistedCombatManager.ForceUpdateAtEndOfFrame then
    pcall(function()
      AssistedCombatManager:ForceUpdateAtEndOfFrame()
    end)
  end
  local delays = { 0, 0, 0.05, 0.15, 0.35, 1.0, 2.0 }
  for i = 1, #delays do
    local last = i == #delays
    C_Timer.After(delays[i], function()
      if last then
        exec.masonAssistedIconRetry = nil
      end
      if exec and exec.masonPieceId and Mason.UpdateAssistedCombatButtonIcon then
        Mason:UpdateAssistedCombatButtonIcon(exec)
      end
    end)
  end
end

-- Always re-apply recommended texture (LAB UpdateAction restores the generic glyph
-- on cooldown / state updates). Sticky last recommend across CD / OOC gaps.
function Mason:UpdateAssistedCombatButtonIcon(exec)
  if not exec or not exec.icon then
    return
  end
  local piece = exec.masonPieceId and self:FindPiece(exec.masonPieceId)
  if not self:IsAssistedCombatPiece(piece) then
    return
  end
  local texId = self:GetAssistedRecommendedSpellID(piece)
  if texId then
    if piece then
      piece.assistedLastSpellID = texId
    end
    exec.masonAssistedLastRecommend = texId
  else
    texId = exec.masonAssistedLastRecommend
      or (piece and tonumber(piece.assistedLastSpellID))
      or nil
  end
  if texId then
    local tex
    if C_Spell and C_Spell.GetSpellTexture then
      tex = C_Spell.GetSpellTexture(texId)
    elseif GetSpellTexture then
      tex = GetSpellTexture(texId)
    end
    if tex then
      -- Do not early-return on same spell ID: LAB may have wiped the texture.
      exec.icon:SetTexture(tex)
      exec.masonAssistedIconSpell = texId
      return
    end
  end
  local slotTex = self:GetAssistedCombatSlotTexture()
  if slotTex then
    exec.icon:SetTexture(slotTex)
    exec.masonAssistedIconSpell = slotTex
    return
  end
  if not exec.masonAssistedIconSpell then
    exec.icon:SetTexture(0)
  end
  self:ScheduleAssistedCombatIconRetry(exec)
end

-- Gold clockwise arrow (UI-HUD-RotationHelper-*) around the single-button assistant.
-- Exactly one Inactive (OOC) or Active (combat) layer — never both (double arrow).
function Mason:EnsureAssistedCombatRotationOverlay(exec)
  if not exec then
    return nil
  end
  if exec.masonAssistedRotationFrame then
    exec.AssistedCombatRotationFrame = exec.masonAssistedRotationFrame
    return exec.masonAssistedRotationFrame
  end
  -- Drop stray duplicates parented to this face (prior double-create).
  if exec.GetChildren then
    local children = { exec:GetChildren() }
    for i = 1, #children do
      local child = children[i]
      if child and child.InactiveTexture and child.ActiveFrame then
        child:Hide()
        child:SetParent(nil)
      end
    end
  end
  local ok, frame = pcall(CreateFrame, "Frame", nil, exec, "ActionBarButtonAssistedCombatRotationTemplate")
  if not ok or not frame then
    return nil
  end
  exec.masonAssistedRotationFrame = frame
  exec.AssistedCombatRotationFrame = frame
  local w = exec.GetWidth and exec:GetWidth() or 0
  local h = exec.GetHeight and exec:GetHeight() or 0
  if not w or w <= 0 then
    w = 45
  end
  if not h or h <= 0 then
    h = 45
  end
  frame:SetSize(w * 1.4, h * 1.4)
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", exec, "CENTER", -2, 1)
  frame:SetFrameLevel((exec.GetFrameLevel and exec:GetFrameLevel() or 0) + 8)
  -- Mixin OnUpdate ForceUpdateAction's parent.action — Mason faces have none.
  frame:SetScript("OnUpdate", nil)
  -- Start exclusive: inactive only (OOC default).
  if frame.InactiveTexture then
    frame.InactiveTexture:Show()
  end
  if frame.ActiveFrame then
    frame.ActiveFrame:Hide()
  end
  return frame
end

function Mason:SyncAssistedCombatRotationLayers(frame)
  if not frame then
    return
  end
  local inCombat = UnitAffectingCombat and UnitAffectingCombat("player")
  if frame.InactiveTexture then
    frame.InactiveTexture:SetShown(not inCombat)
  end
  if frame.ActiveFrame then
    frame.ActiveFrame:SetShown(not not inCombat)
    if inCombat then
      if frame.ActiveFrame.GlowAnim then
        pcall(function()
          frame.ActiveFrame.GlowAnim:Play()
        end)
      end
    elseif frame.ActiveFrame.GlowAnim then
      pcall(function()
        frame.ActiveFrame.GlowAnim:Stop()
      end)
    end
  end
end

function Mason:UpdateAssistedCombatRotationOverlay(exec)
  if not exec then
    return
  end
  local piece = exec.masonPieceId and self:FindPiece(exec.masonPieceId)
  local show = self:IsAssistedRotationArrowEnabled() and self:IsAssistedCombatPiece(piece)
  local frame = exec.masonAssistedRotationFrame or exec.AssistedCombatRotationFrame
  if show then
    frame = self:EnsureAssistedCombatRotationOverlay(exec)
    if not frame then
      return
    end
    frame:Show()
    self:SyncAssistedCombatRotationLayers(frame)
  elseif frame then
    frame:Hide()
  end
end

function Mason:AssistedShouldShow(exec)
  if not self:IsAssistedHighlightRingEnabled() then
    return false
  end
  if not exec or not exec.masonPieceId then
    return false
  end
  local rec = self.assistedLastSpell
  if not rec then
    return false
  end
  local views = self.GetViews and self:GetViews()
  local view = views and views[exec.masonPieceId]
  if not view or not view.visible then
    return false
  end
  local piece = self:FindPiece(exec.masonPieceId)
  -- Rotation button shows next-cast icon; do not also paint the highlight overlay.
  if self:IsAssistedCombatPiece(piece) then
    return false
  end
  local buttonSpell = exec.GetSpellId and exec:GetSpellId()
  return self:SpellIDsMatch(buttonSpell, rec)
    or (piece and self:SpellIDsMatch(piece.spellID, rec))
end

function Mason:EnsureAssistedOverlay(exec)
  if not exec then
    return nil
  end
  if exec.masonAssisted then
    exec.masonAssisted:Hide()
  end
  if exec.masonAssistedBackdrop then
    exec.masonAssistedBackdrop:Hide()
  end
  local frame = exec.AssistedCombatHighlightFrame
  if not frame then
    local ok, created = pcall(CreateFrame, "Frame", nil, exec, "ActionBarButtonAssistedCombatHighlightTemplate")
    if not ok or not created then
      return nil
    end
    frame = created
    exec.AssistedCombatHighlightFrame = frame
    frame:SetParent(exec)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", exec, "CENTER")
  end
  return frame
end

function Mason:UpdateAssistedHighlight(exec)
  if not exec then
    return
  end
  local frame = exec.AssistedCombatHighlightFrame
  if self:AssistedShouldShow(exec) then
    frame = self:EnsureAssistedOverlay(exec)
    if not frame then
      return
    end
    frame:Show()
    if frame.Flipbook and frame.Flipbook.Anim then
      frame.Flipbook.Anim:Play()
    end
  elseif frame then
    frame:Hide()
  end
end

function Mason:RefreshAssistedHighlights()
  for _, exec in pairs(self.executors or {}) do
    if exec.__LAB_Version then
      self:UpdateAssistedHighlight(exec)
      self:UpdateAssistedCombatButtonIcon(exec)
      self:UpdateAssistedCombatRotationOverlay(exec)
    end
  end
end

function Mason:HasVisibleView()
  local kit = self:GetKit()
  for id, view in pairs(self:GetViews()) do
    if view.visible and kit[id] then
      return true
    end
  end
  return false
end

function Mason:RegisterFaceCallbacks()
  if self.masonFaceCallbacks then
    return
  end
  self.masonFaceCallbacks = true
  if EventRegistry then
    local function refresh()
      Mason:OnAssistedSpellSignal()
    end
    pcall(function()
      EventRegistry:RegisterCallback("AssistedCombatManager.OnAssistedHighlightSpellChange", refresh)
    end)
    pcall(function()
      EventRegistry:RegisterCallback("AssistedCombatManager.OnSetActionSpell", refresh)
    end)
    pcall(function()
      EventRegistry:RegisterCallback("AssistedCombatManager.OnSetUseAssistedHighlight", refresh)
    end)
  end
  local LAB = self:GetLAB()
  if LAB and LAB.RegisterCallback then
    local function afterLAB(button)
      if not button or not button.masonPieceId then
        return
      end
      local view = Mason.GetViews and Mason:GetViews()[button.masonPieceId]
      if view and view.visible then
        if Mason.InEditMode and Mason:InEditMode() then
          button:Show()
        end
        if Mason.PaintRule then
          Mason:PaintRule(button)
        else
          button:SetAlpha(1)
        end
      end
      Mason:StripSlotArt(button)
      Mason:FitFace(button)
      Mason:HookFaceRange(button)
      Mason:ApplyFaceTypeOverrides(button)
      -- LAB UpdateState may rewrite spell=labaction (numeric); keep CastSpellByName arm.
      if button.masonSpellCastName and not InCombatLockdown() then
        button:SetAttribute("spell", button.masonSpellCastName)
      end
      local afterPiece = button.masonPieceId and Mason:FindPiece(button.masonPieceId)
      if afterPiece and afterPiece.type == "flyout" and not Mason.masonPopulatingFlyout and not button.masonFlyoutConfigured then
        if Mason.ConfigureFlyoutParent then
          Mason:ConfigureFlyoutParent(button, afterPiece)
        end
      end
      if Mason.ShowFlyoutArrow then
        Mason:ShowFlyoutArrow(button, afterPiece)
      end
      Mason:UpdateAssistedHighlight(button)
      Mason:UpdateAssistedCombatButtonIcon(button)
      Mason:UpdateAssistedCombatRotationOverlay(button)
      if Mason.ApplyCenteredScale then
        Mason:ApplyCenteredScale(button.masonPieceId)
      elseif Mason.AnchorViewCenter then
        Mason:AnchorViewCenter(button)
      end
      if Mason.ApplyViewPixelBox then
        Mason:ApplyViewPixelBox(button.masonPieceId)
      end
    end
    LAB.RegisterCallback(self, "OnButtonUpdate", function(_, button)
      afterLAB(button)
    end)
    LAB.RegisterCallback(self, "OnButtonContentsChanged", function(_, button)
      afterLAB(button)
    end)
  end
  local MSQ = LibStub("Masque", true)
  if MSQ and MSQ.Register then
    pcall(function()
      MSQ:Register("Mason", function()
        for _, exec in pairs(Mason.executors or {}) do
          if exec.__LAB_Version then
            Mason:FitFace(exec)
            Mason:UpdateAssistedHighlight(exec)
            if Mason.ApplyCenteredScale then
              Mason:ApplyCenteredScale(exec.masonPieceId)
            elseif Mason.AnchorViewCenter then
              Mason:AnchorViewCenter(exec)
            end
          end
        end
      end)
    end)
  end
end

function Mason:ConfigureFace(exec, piece)
  if not exec or not piece or not exec.SetState then
    return
  end
  -- C-05 / SAFE-01: never SetState/SetAttribute in lockdown; queue for regen.
  if InCombatLockdown() then
    self:QueueIfCombat(function()
      Mason:ConfigureFace(exec, piece)
    end)
    return
  end
  local ptype = piece.type or "spell"
  if ptype == "flyout" then
    if not self.masonPopulatingFlyout and not exec.masonFlyoutConfigured then
      if self.ConfigureFlyoutParent then
        self:ConfigureFlyoutParent(exec, piece)
      end
    end
    exec:SetAttribute("type", "")
    exec:SetAttribute("type2", "")
    exec:SetAttribute("spell", nil)
    exec:SetAttribute("flyout", nil)
    exec:SetAttribute("LABUseCustomFlyout", false)
    exec.masonSpellCastName = nil
  elseif ptype == "spell" then
    -- LAB _state_action must be numeric; cast attribute overridden to name below.
    local labId, castName = self:ResolveSpellCastIdentity(piece)
    exec:SetState("0", "spell", labId or piece.spellID or piece.spellName)
    exec.masonSpellCastName = castName
    exec.masonLastLabId = tonumber(labId) or tonumber(piece.spellID)
  elseif ptype == "item" or ptype == "toy" then
    exec:SetState("0", "item", piece.itemID)
    exec.masonSpellCastName = nil
  elseif ptype == "macro" then
    exec:SetState("0", "macro", piece.macroName)
    exec.masonSpellCastName = nil
  else
    exec:SetState("0", "empty")
    exec.masonSpellCastName = nil
  end
  exec:SetAttribute("type2", "")
  if exec.DisableDragNDrop then
    exec:DisableDragNDrop(true)
  end
  self:HonorExecutorClicks(exec)
  exec.GetHotkey = function()
    if not SHOW_HOTKEY then
      return nil
    end
    local p = Mason:FindPiece(exec.masonPieceId)
    if p and p.key and p.key ~= "" then
      return p.key
    end
    return nil
  end
  if exec.HotKey then
    exec.HotKey:ClearAllPoints()
    exec.HotKey:SetPoint("TOPRIGHT", exec, "TOPRIGHT", -2, -1)
    local key = exec:GetHotkey()
    if key then
      exec.HotKey:SetText(key)
      exec.HotKey:Show()
    else
      exec.HotKey:SetText("")
      exec.HotKey:Hide()
    end
  end
  if exec.Count then
    if SHOW_COUNT then
      exec.Count:Show()
    else
      exec.Count:Hide()
    end
  end
  if exec.UpdateAction then
    exec:UpdateAction(true)
  end
  -- SetState copies labaction → spell (numeric). Prefer CastSpellByName for talent spells.
  if ptype == "spell" and exec.masonSpellCastName then
    exec:SetAttribute("spell", exec.masonSpellCastName)
  end
  self:HookFaceRange(exec)
  self:ApplyFaceTypeOverrides(exec, piece)
  if self.WireLockedPickup then
    self:WireLockedPickup(exec)
  end
  self:StripSlotArt(exec)
  self:UpdateAssistedHighlight(exec)
  exec.masonAssistedIconSpell = nil
  self:UpdateAssistedCombatButtonIcon(exec)
  self:UpdateAssistedCombatRotationOverlay(exec)
  if self.ShowFlyoutArrow then
    self:ShowFlyoutArrow(exec, piece)
  end
  self:FitFace(exec)
  if self.ApplyCenteredScale then
    self:ApplyCenteredScale(exec.masonPieceId)
  elseif self.AnchorViewCenter then
    self:AnchorViewCenter(exec)
  end
end

function Mason:SkinFace(exec)
  local group = self:GetMasqueGroup()
  if not group or not exec then
    return
  end
  if not exec.masonMasque then
    if exec.AddToMasque then
      exec:AddToMasque(group)
    else
      group:AddButton(exec)
    end
    exec.masonMasque = true
  elseif group.ReSkin then
    group:ReSkin()
  end
  self:FitFace(exec)
  self:UpdateAssistedHighlight(exec)
end

function Mason:UpdateFace(exec, piece)
  if not exec then
    return
  end
  if exec.masonIcon then
    exec.masonIcon:Hide()
  end
  if exec.masonHotkey then
    exec.masonHotkey:Hide()
  end
  self:ConfigureFace(exec, piece)
  self:SkinFace(exec)
  self:StripSlotArt(exec)
  self:UpdateAssistedHighlight(exec)
  exec.masonAssistedIconSpell = nil
  self:UpdateAssistedCombatButtonIcon(exec)
  self:UpdateAssistedCombatRotationOverlay(exec)
  self:FitFace(exec)
  if self.ApplyCenteredScale then
    self:ApplyCenteredScale(exec.masonPieceId)
  elseif self.AnchorViewCenter then
    self:AnchorViewCenter(exec)
  end
end

function Mason:EnsureExecutor(piece)
  self:RegisterFaceCallbacks()
  if not piece or not piece.id then
    return nil
  end
  local name = self:ExecutorName(piece.id)
  local exec = self.executors[piece.id] or _G[name]
  -- C-05 / SAFE-01: never CreateFrame / SetAttribute / SetState in lockdown.
  -- Return an existing exec if present; queue full ensure+configure for regen.
  if InCombatLockdown() then
    self:QueueIfCombat(function()
      Mason:EnsureExecutor(piece)
    end)
    if exec then
      exec.masonPieceId = piece.id
      self.executors[piece.id] = exec
    end
    return exec
  end
  if exec then
    exec.masonPieceId = piece.id
    self.executors[piece.id] = exec
    if exec.__LAB_Version then
      self:ConfigureFace(exec, piece)
    else
      self:ConfigureExecutor(exec, piece)
      if self.WireLockedPickup then
        self:WireLockedPickup(exec)
      end
    end
    return exec
  end
  local LAB = self:GetLAB()
  if not LAB then
    exec = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    exec:SetSize(1, 1)
    exec:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -2000, -2000)
    exec:EnableMouse(false)
    exec:Hide()
    exec:SetAlpha(0)
    exec.masonPieceId = piece.id
    self.executors[piece.id] = exec
    self:ConfigureExecutor(exec, piece)
    if self.WireLockedPickup then
      self:WireLockedPickup(exec)
    end
    return exec
  end
  local numericId = tonumber((tostring(piece.id):match("%d+"))) or 1
  exec = LAB:CreateButton(numericId, name, self:GetLABHeader(), FACE_CONFIG)
  exec:SetParent(UIParent)
  exec:SetSize(1, 1)
  exec:ClearAllPoints()
  exec:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -2000, -2000)
  exec:EnableMouse(false)
  exec:Hide()
  exec:SetAlpha(0)
  exec.masonPieceId = piece.id
  self.executors[piece.id] = exec
  self:ConfigureFace(exec, piece)
  self:SkinFace(exec)
  return exec
end

function Mason:PaintView(exec, piece)
  if exec and exec.__LAB_Version then
    self:UpdateFace(exec, piece)
    return
  end
  if not exec or not piece then
    return
  end
  local icon = exec.masonIcon
  if not icon then
    local frameName = exec:GetName()
    icon = exec:CreateTexture(frameName and (frameName .. "Icon") or nil, "BACKGROUND")
    icon:SetAllPoints(exec)
    exec.masonIcon = icon
  end
  local ptype = piece.type or "spell"
  local tex = 134400
  if ptype == "spell" and C_Spell and C_Spell.GetSpellTexture then
    tex = C_Spell.GetSpellTexture(piece.spellID or piece.spellName) or tex
  elseif ptype == "flyout" then
    if self.FlyoutTexture then
      tex = self:FlyoutTexture(piece.flyoutId) or tex
    end
  elseif (ptype == "item" or ptype == "toy") and piece.itemID and C_Item and C_Item.GetItemIconByID then
    tex = C_Item.GetItemIconByID(piece.itemID) or tex
  elseif ptype == "macro" and piece.macroName and GetMacroInfo then
    tex = select(2, GetMacroInfo(piece.macroName)) or tex
  end
  icon:SetTexture(tex)
  local hotkey = exec.masonHotkey
  if not hotkey then
    local frameName = exec:GetName()
    hotkey = exec:CreateFontString(frameName and (frameName .. "HotKey") or nil, "OVERLAY", "NumberFontNormal")
    hotkey:SetPoint("TOPRIGHT", exec, "TOPRIGHT", -2, -1)
    exec.masonHotkey = hotkey
  end
  if piece.key and piece.key ~= "" then
    hotkey:SetText(piece.key)
  else
    hotkey:SetText("")
  end
end
