local Mason = LibStub("AceAddon-3.0"):GetAddon("Mason")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local AceGUI = LibStub("AceGUI-3.0")

local RULE_PRESETS = { always = true, combat = true, ooc = true, target = true, harm = true, help = true, stealth = true }
local RULE_ORDER = { "always", "combat", "ooc", "target", "harm", "help", "stealth" }
local RULE_VIS = {
  always = "show",
  combat = "[combat] show; hide",
  ooc = "[nocombat] show; hide",
  target = "[@target,exists] show; hide",
  harm = "[@target,harm] show; hide",
  help = "[@target,help] show; hide",
  stealth = "[stealth] show; hide",
}

local PANE_ORDER = { "general", "pieces", "layout", "rules", "flyouts", "ghosts", "profiles", "about" }
local PANE_LABEL = {
  general = "General",
  pieces = "Pieces",
  layout = "Layout",
  rules = "Rules",
  flyouts = "Flyouts",
  ghosts = "Ghosts",
  profiles = "Profiles",
  about = "About",
}

local PANEL_BACKDROP = {
  bgFile = "Interface\\Buttons\\WHITE8X8",
  edgeFile = "Interface\\Buttons\\WHITE8X8",
  edgeSize = 1,
  insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

local function SpecName(specID)
  if not specID then
    return "none"
  end
  if GetSpecializationInfoByID then
    local _, name = GetSpecializationInfoByID(specID)
    if name and name ~= "" then
      return name
    end
  end
  if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoByID then
    local info = C_SpecializationInfo.GetSpecializationInfoByID(specID)
    if type(info) == "table" and info.name then
      return info.name
    end
  end
  return "spec"
end

local function SortedPieces()
  local rows = {}
  for id, piece in pairs(Mason:GetKit()) do
    rows[#rows + 1] = { id = id, piece = piece }
  end
  table.sort(rows, function(a, b)
    return a.id < b.id
  end)
  return rows
end

local function PieceTokenValues()
  local values = {}
  local rows = SortedPieces()
  for i = 1, #rows do
    local piece = rows[i].piece
    values[piece.id] = string.format("%s  %s", piece.key or piece.id, Mason:PieceLabel(piece))
  end
  return values
end

local function FlyoutParentValues()
  local values = {}
  local rows = SortedPieces()
  for i = 1, #rows do
    local piece = rows[i].piece
    if piece.type == "flyout" then
      values[piece.id] = string.format("%s  %s", piece.key or piece.id, Mason:PieceLabel(piece))
    end
  end
  return values
end

local function RuleListText()
  local lines = {}
  for i = 1, #RULE_ORDER do
    local key = RULE_ORDER[i]
    lines[#lines + 1] = string.format("%s  %s", key, RULE_VIS[key])
  end
  return table.concat(lines, "\n")
end

local function State()
  Mason.optionsState = Mason.optionsState or {}
  local s = Mason.optionsState
  s.ruleChecks = s.ruleChecks or {}
  s.pane = s.pane or "general"
  return s
end

local function SkinPanel(frame)
  if not frame or not frame.SetBackdrop then
    return
  end
  frame:SetBackdrop(PANEL_BACKDROP)
  frame:SetBackdropColor(0.07, 0.07, 0.07, 0.94)
  frame:SetBackdropBorderColor(0.75, 0.62, 0.18, 1)
end

local function PieceIcon(piece)
  local tex = 134400
  if not piece then
    return tex
  end
  local ptype = piece.type or "spell"
  if ptype == "spell" and C_Spell and C_Spell.GetSpellTexture then
    tex = C_Spell.GetSpellTexture(piece.spellID or piece.spellName) or tex
  elseif ptype == "flyout" and Mason.FlyoutTexture then
    tex = Mason:FlyoutTexture(piece.flyoutId) or tex
  elseif (ptype == "item" or ptype == "toy") and piece.itemID and C_Item and C_Item.GetItemIconByID then
    tex = C_Item.GetItemIconByID(piece.itemID) or tex
  elseif ptype == "macro" and piece.macroName and GetMacroInfo then
    tex = select(2, GetMacroInfo(piece.macroName)) or tex
  end
  return tex
end

local function PieceRuleText(id)
  if not Mason.GetPieceRuleIds then
    return "-"
  end
  local ids = Mason:GetPieceRuleIds(id)
  local names = {}
  for n = 1, #ids do
    names[#names + 1] = Mason:PresetNameForRuleId(ids[n]) or ids[n]
  end
  if #names == 0 then
    return "-"
  end
  return table.concat(names, "+")
end

local COL = {
  icon = 24,
  id = 88,
  name = 140,
  type = 56,
  bind = 90,
}

local function LayoutPieceCols(row)
  local x = 4
  if row.icon then
    row.icon:ClearAllPoints()
    row.icon:SetPoint("LEFT", row, "LEFT", x, 0)
  end
  x = x + COL.icon + 6
  local function place(fs, width)
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", row, "LEFT", x, 0)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    x = x + width + 6
  end
  place(row.colId, COL.id)
  place(row.colName, COL.name)
  place(row.colType, COL.type)
  place(row.colBind, COL.bind)
  row.colRule:ClearAllPoints()
  row.colRule:SetPoint("LEFT", row, "LEFT", x, 0)
  row.colRule:SetPoint("RIGHT", row, "RIGHT", -4, 0)
  row.colRule:SetJustifyH("LEFT")
end

local function PaintPieceRow(row, selected)
  if not row.SetBackdropColor then
    return
  end
  if selected then
    row:SetBackdropColor(0.42, 0.34, 0.10, 0.95)
    row:SetBackdropBorderColor(0.75, 0.62, 0.18, 1)
  else
    row:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
    row:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
  end
end

local function MakePieceCol(parent, template)
  local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
  fs:SetJustifyH("LEFT")
  fs:SetWordWrap(false)
  return fs
end

local function BuildPieceArgs()
  return {}
end

local function EmptyGhostArgs()
  return {
    empty = {
      type = "execute",
      name = "No leftover views.",
      order = 0,
      disabled = true,
      func = function() end,
    },
  }
end

local function BuildGhostArgs()
  local ids = Mason.ListGhostViews and Mason:ListGhostViews() or {}
  if #ids == 0 then
    return EmptyGhostArgs()
  end
  local args = {
    clearAll = {
      type = "execute",
      name = "Clear all ghosts",
      order = 1,
      func = function()
        Mason:ClearAllGhostViews()
        if C_Timer and C_Timer.After then
          C_Timer.After(0, function()
            if Mason.options and Mason.options.args and Mason.options.args.ghosts then
              Mason.options.args.ghosts.args = EmptyGhostArgs()
            end
            LibStub("AceConfigRegistry-3.0"):NotifyChange("Mason")
          end)
        end
      end,
    },
  }
  for i = 1, #ids do
    local id = ids[i]
    local icon, ptype, name = Mason:GhostRowInfo(id)
    args["g_" .. id] = {
      type = "group",
      inline = true,
      name = "",
      order = 10 + i,
      args = {
        icon = {
          type = "description",
          name = " ",
          order = 1,
          width = 0.4,
          image = icon,
          imageWidth = 24,
          imageHeight = 24,
        },
        label = {
          type = "description",
          name = string.format("%s\n%s  %s", id, ptype, name),
          order = 2,
          width = 1.4,
        },
        clear = {
          type = "execute",
          name = "Clear view",
          order = 3,
          width = 0.7,
          func = function()
            Mason:ClearGhostView(id)
            if C_Timer and C_Timer.After then
              C_Timer.After(0, function()
                Mason:RefreshGhostOptions()
                AceConfigRegistry:NotifyChange("Mason")
              end)
            end
          end,
        },
      },
    }
  end
  return args
end

function Mason:RefreshGhostOptions()
  if not self.options or not self.options.args or not self.options.args.ghosts then
    return
  end
  self.options.args.ghosts.args = BuildGhostArgs()
end

function Mason:RefreshPiecesTable()
  if not self.optionsPanel or not self.optionsPanel:IsShown() then
    return
  end
  if self.piecesScroll then
    self:RefreshPiecesScroll()
  end
end

function Mason:RefreshPiecesOptions()
  if not self.options or not self.options.args or not self.options.args.pieces then
    return
  end
  self.options.args.pieces.args = BuildPieceArgs()
end

function Mason:LayoutPiecesScroll()
  local header = self.piecesHeader
  local scroll = self.piecesScroll
  local right = _G.MasonOptionsRight
  if not scroll or not right then
    return
  end
  if header then
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", right, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", right, "TOPRIGHT", -22, 0)
    header:SetHeight(22)
    LayoutPieceCols(header)
  end
  scroll:ClearAllPoints()
  if header then
    scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
  else
    scroll:SetPoint("TOPLEFT", right, "TOPLEFT", 0, 0)
  end
  scroll:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", -22, 0)
end

function Mason:SelectPiecesTableRow(id)
  local state = State()
  state.selectedPiece = id
  state.rulePiece = id
  self:LoadRuleChecks(id)
  local piece = id and self:FindPiece(id)
  if piece and piece.type == "flyout" then
    state.flyoutId = id
  end
  if self.RefreshPiecesScroll then
    self:RefreshPiecesScroll()
  end
  AceConfigRegistry:NotifyChange("Mason")
end

function Mason:RefreshPiecesScroll()
  local scroll = self.piecesScroll
  if not scroll then
    return
  end
  self:LayoutPiecesScroll()
  local header = self.piecesHeader
  if header and State().pane == "pieces" then
    header:Show()
    header.colId:SetText("id")
    header.colName:SetText("name")
    header.colType:SetText("type")
    header.colBind:SetText("bind")
    header.colRule:SetText("rule")
  end
  local child = scroll.child
  local rows = SortedPieces()
  local w = math.max((_G.MasonOptionsRight and _G.MasonOptionsRight:GetWidth() or 480) - 28, 200)
  local selected = State().selectedPiece
  local y = 0
  for i = 1, math.max(#rows, #scroll.rows) do
    local row = scroll.rows[i]
    if not row then
      row = CreateFrame("Button", nil, child, "BackdropTemplate")
      row:SetHeight(26)
      row:SetBackdrop(PANEL_BACKDROP)
      row:RegisterForClicks("LeftButtonUp")
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(20, 20)
      row.colId = MakePieceCol(row)
      row.colName = MakePieceCol(row)
      row.colType = MakePieceCol(row)
      row.colBind = MakePieceCol(row)
      row.colRule = MakePieceCol(row)
      row:SetScript("OnClick", function(btn)
        if btn.pieceId then
          Mason:SelectPiecesTableRow(btn.pieceId)
        end
      end)
      scroll.rows[i] = row
    end
    local data = rows[i]
    if data then
      local piece = data.piece
      row.pieceId = piece.id
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
      row:SetWidth(w)
      row:Show()
      LayoutPieceCols(row)
      row.icon:SetTexture(PieceIcon(piece))
      row.colId:SetText(piece.id)
      row.colName:SetText(Mason:PieceLabel(piece))
      row.colType:SetText(piece.type or "spell")
      row.colBind:SetText(piece.key or "-")
      row.colRule:SetText(PieceRuleText(piece.id))
      PaintPieceRow(row, selected == piece.id)
      y = y - 28
    else
      row.pieceId = nil
      row:Hide()
    end
  end
  child:SetSize(w, math.max(28, #rows * 28))
end

function Mason:ShowPiecesScroll(show)
  local scroll = self.piecesScroll
  if scroll then
    if show then
      if self.piecesHeader then
        self.piecesHeader:Show()
      end
      scroll:Show()
      self:RefreshPiecesScroll()
    else
      if self.piecesHeader then
        self.piecesHeader:Hide()
      end
      scroll:Hide()
    end
  end
end

function Mason:LoadRuleChecks(id)
  local state = State()
  state.ruleChecks = {}
  if not id or not self.GetPieceRuleIds then
    if self.SyncRulesChecks then
      self:SyncRulesChecks()
    end
    return
  end
  local ids = self:GetPieceRuleIds(id)
  for i = 1, #ids do
    local name = self:PresetNameForRuleId(ids[i])
    if name then
      state.ruleChecks[name] = true
    end
  end
  if self.SyncRulesChecks then
    self:SyncRulesChecks()
  end
end

function Mason:SyncOptionsRail()
  local panel = self.optionsPanel
  if not panel then
    return
  end
  if panel.editBtn then
    panel.editBtn:SetText(self:IsLocked() and "Edit mode" or "Editing…")
  end
  if panel.kbBtn then
    panel.kbBtn:SetText(self.bindMode and "Binding…" or "Keybind mode")
  end
end

function Mason:ApplyRulesPane()
  local state = State()
  local id = state.rulePiece
  if not id then
    print("Mason: usage: /mason rule <key|id|spell> <preset|clear>")
    return
  end
  local piece = self:GetKit()[id] or self:FindPiece(id)
  if not piece then
    print("Mason: no piece for " .. tostring(id))
    return
  end
  local ids = {}
  for i = 1, #RULE_ORDER do
    local key = RULE_ORDER[i]
    if state.ruleChecks[key] then
      ids[#ids + 1] = "r_" .. key
    end
  end
  self:QueueIfCombat(function()
    if Mason:SetPieceRuleIds(piece.id, ids) then
      Mason:Notify(Mason:PieceLabel(piece) .. " rules updated")
      if Mason.RefreshPiecesTable then
        Mason:RefreshPiecesTable()
      end
    end
  end)
end

function Mason:ClearRulesPane()
  local state = State()
  local id = state.rulePiece
  if not id then
    print("Mason: usage: /mason rule <key|id|spell> <preset|clear>")
    return
  end
  local piece = self:GetKit()[id] or self:FindPiece(id)
  if not piece then
    print("Mason: no piece for " .. tostring(id))
    return
  end
  self:QueueIfCombat(function()
    if Mason:SetPieceRuleIds(piece.id, nil) then
      state.ruleChecks = {}
      Mason:Notify(Mason:PieceLabel(piece) .. " rule clear")
      if Mason.SyncRulesPane then
        Mason:SyncRulesPane()
      end
      if Mason.RefreshPiecesTable then
        Mason:RefreshPiecesTable()
      end
    end
  end)
end

function Mason:SyncRulesChecks()
  local host = self.rulesPane
  if not host or not host.checks then
    return
  end
  local state = State()
  for i = 1, #RULE_ORDER do
    local key = RULE_ORDER[i]
    local cb = host.checks[key]
    if cb then
      cb:SetChecked(not not state.ruleChecks[key])
    end
  end
end

function Mason:ShouldShowRuleDrivers()
  local state = State()
  return self:IsDebug() or not not state.showRuleDrivers
end

function Mason:SyncRulesPane()
  local host = self.rulesPane
  if not host then
    return
  end
  local state = State()
  if host.drop then
    host.drop:SetList(PieceTokenValues())
    host.drop:SetValue(state.rulePiece)
  end
  if host.checks then
    for i = 1, #RULE_ORDER do
      local key = RULE_ORDER[i]
      local cb = host.checks[key]
      if cb then
        cb:SetChecked(not not state.ruleChecks[key])
      end
    end
  end
  if host.driverToggle then
    host.driverToggle:SetChecked(not not state.showRuleDrivers)
  end
  if host.driverText then
    if self:ShouldShowRuleDrivers() then
      host.driverText:SetText(RuleListText())
      host.driverText:Show()
    else
      host.driverText:SetText("")
      host.driverText:Hide()
    end
  end
end

function Mason:EnsureRulesPane()
  if self.rulesPane then
    return self.rulesPane
  end
  local right = _G.MasonOptionsRight
  if not right then
    return nil
  end
  local host = CreateFrame("Frame", "MasonRulesPane", right)
  host:Hide()
  host:SetAllPoints(right)
  local drop = AceGUI:Create("Dropdown")
  drop:SetLabel("Piece")
  drop:SetCallback("OnValueChanged", function(_, _, v)
    State().rulePiece = v
    State().selectedPiece = v
    Mason:LoadRuleChecks(v)
    if Mason.RefreshPiecesScroll and State().pane == "pieces" then
      Mason:RefreshPiecesScroll()
    end
  end)
  drop.frame:SetParent(host)
  drop.frame:ClearAllPoints()
  drop.frame:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -4)
  drop.frame:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, -4)
  drop.frame:Show()
  host.drop = drop

  local grid = CreateFrame("Frame", nil, host)
  grid:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -52)
  grid:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, -52)
  grid:SetHeight(64)
  host.grid = grid
  host.checks = {}
  for i = 1, #RULE_ORDER do
    local key = RULE_ORDER[i]
    local col = (i - 1) % 4
    local row = math.floor((i - 1) / 4)
    local cb = CreateFrame("CheckButton", nil, grid, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", grid, "TOPLEFT", col * 120, -row * 32)
    local label = cb.Text or cb.text
    if not label then
      label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      label:SetPoint("LEFT", cb, "RIGHT", 0, 0)
      cb.Text = label
    end
    label:SetText(key)
    cb:SetScript("OnClick", function(self)
      State().ruleChecks[key] = not not self:GetChecked()
    end)
    host.checks[key] = cb
  end

  local apply = CreateFrame("Button", nil, host, "UIPanelButtonTemplate")
  apply:SetSize(80, 22)
  apply:SetPoint("TOPLEFT", grid, "BOTTOMLEFT", 0, -10)
  apply:SetText("Apply")
  apply:SetScript("OnClick", function()
    Mason:ApplyRulesPane()
  end)
  local clear = CreateFrame("Button", nil, host, "UIPanelButtonTemplate")
  clear:SetSize(80, 22)
  clear:SetPoint("LEFT", apply, "RIGHT", 8, 0)
  clear:SetText("Clear")
  clear:SetScript("OnClick", function()
    Mason:ClearRulesPane()
  end)

  local toggle = CreateFrame("CheckButton", nil, host, "UICheckButtonTemplate")
  toggle:SetSize(24, 24)
  toggle:SetPoint("TOPLEFT", apply, "BOTTOMLEFT", -4, -12)
  local tlabel = toggle.Text or toggle.text
  if not tlabel then
    tlabel = toggle:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tlabel:SetPoint("LEFT", toggle, "RIGHT", 0, 0)
    toggle.Text = tlabel
  end
  tlabel:SetText("Show driver strings")
  toggle:SetScript("OnClick", function(self)
    State().showRuleDrivers = not not self:GetChecked()
    Mason:SyncRulesPane()
  end)
  host.driverToggle = toggle

  local driver = host:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  driver:SetPoint("TOPLEFT", toggle, "BOTTOMLEFT", 4, -8)
  driver:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, -8)
  driver:SetJustifyH("LEFT")
  driver:SetJustifyV("TOP")
  driver:Hide()
  host.driverText = driver

  self.rulesPane = host
  return host
end

function Mason:ShowRulesPane(show)
  local host = self:EnsureRulesPane()
  if not host then
    return
  end
  if show then
    host:Show()
    if host.drop and host.drop.frame then
      host.drop.frame:Show()
      local w = host:GetWidth() or 400
      if w > 1 then
        host.drop:SetWidth(w)
      end
    end
    self:SyncRulesPane()
  else
    host:Hide()
    if host.drop and host.drop.frame then
      host.drop.frame:Hide()
    end
  end
end

function Mason:FeedOptionsPane()
  local container = self.optionsContainer
  local pane = State().pane or "general"
  if not container then
    return
  end
  self:ShowPiecesScroll(pane == "pieces")
  self:ShowRulesPane(pane == "rules")
  if pane == "pieces" or pane == "rules" then
    if container.frame then
      container.frame:Hide()
    end
    return
  end
  if container.frame then
    container.frame:Show()
  end
  if pane == "ghosts" then
    self:RefreshGhostOptions()
  end
  AceConfigDialog:Open("Mason", container, pane)
end

function Mason:SelectOptionsPane(pane)
  State().pane = pane
  local panel = self.optionsPanel
  if panel and panel.menuBtns then
    for key, btn in pairs(panel.menuBtns) do
      if key == pane then
        btn:SetBackdropBorderColor(0.75, 0.62, 0.18, 1)
      else
        btn:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
      end
    end
  end
  self:FeedOptionsPane()
end

function Mason:EnsureOptionsFrame()
  if self.optionsPanel and self.optionsContainer then
    return self.optionsPanel
  end
  if InCombatLockdown() then
    return nil
  end
  local panel = CreateFrame("Frame", "MasonOptionsPanel", UIParent, "BackdropTemplate")
  panel:SetSize(720, 500)
  panel:SetPoint("CENTER")
  panel:SetFrameStrata("FULLSCREEN_DIALOG")
  panel:SetFrameLevel(220)
  panel:EnableMouse(true)
  panel:SetMovable(true)
  panel:Hide()
  SkinPanel(panel)
  panel:SetScript("OnMouseDown", function(self)
    self:StartMoving()
  end)
  panel:SetScript("OnMouseUp", function(self)
    self:StopMovingOrSizing()
  end)
  -- No EnableKeyboard / OnKeyDown. Product: Options is hidden in combat (see
  -- HideOptionsForCombat); ESC while shown uses UISpecialFrames below.
  panel:SetScript("OnShow", function(self)
    self:SetFrameStrata("FULLSCREEN_DIALOG")
    self:Raise()
  end)
  if UISpecialFrames then
    local found
    for i = 1, #UISpecialFrames do
      if UISpecialFrames[i] == "MasonOptionsPanel" then
        found = true
        break
      end
    end
    if not found then
      UISpecialFrames[#UISpecialFrames + 1] = "MasonOptionsPanel"
    end
  end

  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", panel, "TOP", 0, -10)
  title:SetText("Mason")

  local close = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  close:SetSize(80, 22)
  close:SetPoint("BOTTOM", panel, "BOTTOM", 0, 12)
  close:SetText("Close")
  close:SetScript("OnClick", function()
    panel:Hide()
  end)

  local rail = CreateFrame("Frame", nil, panel)
  rail:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -36)
  rail:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, 40)
  rail:SetWidth(160)

  local function MakeModeBtn(text, y, onclick)
    local btn = CreateFrame("Button", nil, rail, "UIPanelButtonTemplate")
    btn:SetSize(156, 24)
    btn:SetPoint("TOPLEFT", rail, "TOPLEFT", 2, y)
    btn:SetText(text)
    btn:SetScript("OnClick", onclick)
    return btn
  end

  panel.editBtn = MakeModeBtn("Edit mode", 0, function()
    Mason:ToggleEditMode()
    Mason:SyncOptionsRail()
  end)
  panel.kbBtn = MakeModeBtn("Keybind mode", -28, function()
    Mason:ToggleBindMode()
    Mason:SyncOptionsRail()
  end)

  panel.menuBtns = {}
  local menuY = -60
  for i = 1, #PANE_ORDER do
    local key = PANE_ORDER[i]
    local btn = CreateFrame("Button", nil, rail, "BackdropTemplate")
    btn:SetSize(156, 22)
    btn:SetPoint("TOPLEFT", rail, "TOPLEFT", 2, menuY)
    btn:SetBackdrop(PANEL_BACKDROP)
    btn:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
    btn:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", btn, "LEFT", 8, 0)
    label:SetText(PANE_LABEL[key])
    btn:SetScript("OnClick", function()
      Mason:SelectOptionsPane(key)
    end)
    panel.menuBtns[key] = btn
    menuY = menuY - 24
  end

  local right = CreateFrame("Frame", "MasonOptionsRight", panel)
  right:SetPoint("TOPLEFT", rail, "TOPRIGHT", 10, 0)
  right:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 40)

  local container = AceGUI:Create("SimpleGroup")
  container:SetLayout("Fill")
  container.frame:SetParent(right)
  container.frame:ClearAllPoints()
  container.frame:SetAllPoints(right)
  container.frame:Show()
  right:SetScript("OnSizeChanged", function(self, w, h)
    if w and h and w > 0 then
      container:SetWidth(w)
      container:SetHeight(h)
    end
    if Mason.piecesScroll and Mason.piecesScroll:IsShown() and Mason.RefreshPiecesScroll then
      Mason:RefreshPiecesScroll()
    elseif Mason.LayoutPiecesScroll then
      Mason:LayoutPiecesScroll()
    end
    if Mason.rulesPane and Mason.rulesPane:IsShown() and Mason.rulesPane.drop then
      local rw = self:GetWidth()
      if rw and rw > 1 then
        Mason.rulesPane.drop:SetWidth(rw)
      end
    end
  end)

  local header = CreateFrame("Frame", "MasonPiecesHeader", right, "BackdropTemplate")
  header:Hide()
  header:SetHeight(22)
  header:SetBackdrop(PANEL_BACKDROP)
  header:SetBackdropColor(0.09, 0.09, 0.09, 0.95)
  header:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
  header.icon = header:CreateTexture(nil, "ARTWORK")
  header.icon:SetSize(20, 20)
  header.icon:SetColorTexture(0, 0, 0, 0)
  header.colId = MakePieceCol(header, "GameFontNormalSmall")
  header.colName = MakePieceCol(header, "GameFontNormalSmall")
  header.colType = MakePieceCol(header, "GameFontNormalSmall")
  header.colBind = MakePieceCol(header, "GameFontNormalSmall")
  header.colRule = MakePieceCol(header, "GameFontNormalSmall")
  self.piecesHeader = header

  local scroll = CreateFrame("ScrollFrame", "MasonPiecesScroll", right, "UIPanelScrollFrameTemplate")
  scroll:Hide()
  local child = CreateFrame("Frame", "MasonPiecesScrollChild", scroll)
  scroll:SetScrollChild(child)
  scroll.child = child
  scroll.rows = {}
  self.piecesScroll = scroll

  self.optionsPanel = panel
  self.optionsContainer = container
  self:SyncOptionsRail()
  return panel
end

function Mason:HideOptionsForCombat()
  local panel = self.optionsPanel
  if panel and panel.IsShown and panel:IsShown() then
    self.optionsRestoreAfterCombat = true
    panel:Hide()
  end
end

function Mason:RestoreOptionsAfterCombat()
  if not self.optionsRestoreAfterCombat then
    return
  end
  self.optionsRestoreAfterCombat = false
  self:OpenOptions()
end

function Mason:OpenOptions()
  -- Product: Options stays closed during combat; reopen via RestoreUiAfterCombat
  -- if we hid it, or via QueueIfCombat if the user asked to open while locked down.
  if InCombatLockdown() then
    self:QueueIfCombat(function()
      Mason:OpenOptions()
    end)
    return
  end
  local panel = self:EnsureOptionsFrame()
  if not panel then
    return
  end
  self:RefreshGhostOptions()
  self:RefreshPiecesOptions()
  panel:Show()
  panel:SetFrameStrata("FULLSCREEN_DIALOG")
  panel:Raise()
  self:SyncOptionsRail()
  local right = _G.MasonOptionsRight
  if right and self.optionsContainer then
    local w, h = right:GetWidth(), right:GetHeight()
    if w and w > 1 then
      self.optionsContainer:SetWidth(w)
      self.optionsContainer:SetHeight(h)
    end
  end
  self:SelectOptionsPane(State().pane or "general")
end

function Mason:RegisterOptions()
  local state = State()
  self.options = {
    type = "group",
    name = "Mason",
    childGroups = "tab",
    args = {
      general = {
        type = "group",
        name = "General",
        order = 10,
        args = {
          defaultSize = {
            type = "range",
            name = "Default piece size",
            desc = "New drops only; does not resize existing pieces.",
            min = 16,
            max = 128,
            step = 2,
            order = 1,
            get = function()
              return Mason:GetDefaultSize()
            end,
            set = function(_, v)
              Mason:SetDefaultSize(v)
            end,
          },
          debug = {
            type = "toggle",
            name = "Debug",
            order = 2,
            get = function()
              return not not (Mason.db.profile.debug)
            end,
            set = function(_, v)
              Mason.db.profile.debug = not not v
            end,
          },
          notes = {
            type = "description",
            order = 3,
            name = "Binds follow ActionButtonUseKeyDown.\nDefault bars are not hidden.\nMasque group name is Mason.",
          },
        },
      },
      pieces = {
        type = "group",
        name = "Pieces",
        order = 20,
        args = {},
      },
      layout = {
        type = "group",
        name = "Layout",
        order = 30,
        args = {
          snap = {
            type = "toggle",
            name = "Snap to grid",
            order = 1,
            get = function()
              return Mason:IsSnapEnabled()
            end,
            set = function(_, v)
              Mason:SetSnapEnabled(v)
            end,
          },
          grid = {
            type = "range",
            name = "Grid size",
            min = 8,
            max = 128,
            step = 8,
            order = 2,
            get = function()
              return Mason:GetGridSize()
            end,
            set = function(_, v)
              Mason:SetGridSize(v)
            end,
          },
          howto = {
            type = "description",
            order = 3,
            name = "Shift+arrow snaps to next line; plain arrow is 1px; flyout children never snap.",
          },
        },
      },
      rules = {
        type = "group",
        name = "Rules",
        order = 40,
        args = {},
      },
      flyouts = {
        type = "group",
        name = "Flyouts",
        order = 50,
        args = {
          parent = {
            type = "select",
            name = "Flyout",
            order = 1,
            values = FlyoutParentValues,
            get = function()
              return state.flyoutId
            end,
            set = function(_, v)
              state.flyoutId = v
            end,
          },
          side = {
            type = "select",
            name = "Side",
            order = 2,
            values = {
              top = "Top",
              bottom = "Bottom",
              left = "Left",
              right = "Right",
            },
            get = function()
              local fo = state.flyoutId and Mason:GetFlyout(state.flyoutId)
              return (fo and fo.side) or "top"
            end,
            set = function(_, side)
              local id = state.flyoutId
              if not id then
                return
              end
              Mason:QueueIfCombat(function()
                Mason:FlyoutSetSide(id, side)
              end)
            end,
          },
          cols = {
            type = "range",
            name = "Columns",
            desc = "0 means auto (ceil(sqrt(n))).",
            min = 0,
            max = 12,
            step = 1,
            order = 10,
            get = function()
              local fo = state.flyoutId and Mason:GetFlyout(state.flyoutId)
              if not fo or fo.cols == nil then
                return 0
              end
              return fo.cols
            end,
            set = function(_, v)
              local id = state.flyoutId
              if not id then
                return
              end
              Mason:QueueIfCombat(function()
                if v == 0 then
                  local fo = Mason:EnsureFlyout(id)
                  fo.cols = nil
                  if Mason.ShouldShowFlyoutChildren and Mason:ShouldShowFlyoutChildren(id) then
                    Mason:LayoutFlyoutChildren(id, true)
                  end
                else
                  Mason:FlyoutSetCols(id, v)
                end
              end)
            end,
          },
          close = {
            type = "execute",
            name = "Close flyout",
            order = 11,
            func = function()
              Mason:QueueIfCombat(function()
                Mason:CloseAllFlyouts()
              end)
            end,
          },
          howto = {
            type = "description",
            order = 12,
            name = "Blizzard flyouts (Portal, Warband, Skyriding) become Mason children. Toggle is locked + OOC only.",
          },
        },
      },
      ghosts = {
        type = "group",
        name = "Ghosts",
        order = 60,
        args = {},
      },
      about = {
        type = "group",
        name = "About",
        order = 80,
        args = {
          blurb = {
            type = "description",
            fontSize = "medium",
            name = function()
              local specID = Mason:GetCurrentSpecID()
              return string.format(
                "Mason places your abilities.\nSpec: %s (%s)",
                SpecName(specID),
                tostring(specID or "?")
              )
            end,
          },
        },
      },
    },
  }

  local dbOpts = AceDBOptions:GetOptionsTable(self.db)
  dbOpts.inline = true
  dbOpts.order = 20
  dbOpts.name = "Profiles"
  self.options.args.profiles = {
    type = "group",
    name = "Profiles",
    order = 70,
    args = {
      note = {
        type = "description",
        order = 1,
        name = "Switching Existing Profiles loads binds and layout (positions, sizes, rules, snap, grid) for this spec.",
      },
      exportFull = {
        type = "execute",
        name = "Export",
        order = 2,
        func = function()
          Mason:ExportShare("full")
        end,
      },
      import = {
        type = "execute",
        name = "Import…",
        order = 3,
        func = function()
          Mason:ShowShareDialog("", true)
        end,
      },
      acedb = dbOpts,
    },
  }

  AceConfig:RegisterOptionsTable("Mason", self.options)
  self:RefreshGhostOptions()
  self:RefreshPiecesOptions()
end
