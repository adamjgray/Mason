local Mason = LibStub("AceAddon-3.0"):GetAddon("Mason")
local AceSerializer = LibStub("AceSerializer-3.0")
local LibDeflate = LibStub("LibDeflate")

local SCHEMA_MAJOR = 1

local PANEL_BACKDROP = {
  bgFile = "Interface\\Buttons\\WHITE8X8",
  edgeFile = "Interface\\Buttons\\WHITE8X8",
  edgeSize = 1,
  insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

local PANEL_STRATA = "DIALOG"
local PANEL_LEVEL = 200

local function CopyValue(v)
  if type(v) ~= "table" then
    return v
  end
  if CopyTable then
    return CopyTable(v)
  end
  local out = {}
  for k, val in pairs(v) do
    out[k] = CopyValue(val)
  end
  return out
end

local function ExportPiece(piece)
  local p = {
    id = piece.id,
    type = piece.type,
    key = piece.key,
    spellID = piece.spellID,
    spellName = piece.spellName,
    itemID = piece.itemID,
    macroName = piece.macroName,
    flyoutId = piece.flyoutId,
    specID = piece.specID,
  }
  if piece.macro ~= nil then
    p.macro = piece.macro
  end
  if piece.flyout ~= nil then
    p.flyout = CopyValue(piece.flyout)
  end
  return p
end

local function ExportView(view)
  local v = {
    x = view.x,
    y = view.y,
    size = view.size,
    visible = view.visible,
    ruleId = view.ruleId,
    ruleIds = type(view.ruleIds) == "table" and CopyValue(view.ruleIds) or nil,
  }
  if type(view.dock) == "table" then
    v.dock = CopyValue(view.dock)
  else
    v.dock = view.dock
  end
  if view.flyout ~= nil then
    v.flyout = CopyValue(view.flyout)
  end
  return v
end

local function SkinSharePanel(frame)
  if not frame or not frame.SetBackdrop then
    return
  end
  frame:SetBackdrop(PANEL_BACKDROP)
  frame:SetBackdropColor(0.07, 0.07, 0.07, 0.94)
  frame:SetBackdropBorderColor(0.75, 0.62, 0.18, 1)
end

local function PlayerClass()
  local _, class = UnitClass("player")
  return class
end

function Mason:Migrate(data)
  return data
end

function Mason:EncodeShare(data)
  local serialized = AceSerializer:Serialize(data)
  local compressed = LibDeflate:CompressDeflate(serialized)
  return LibDeflate:EncodeForPrint(compressed)
end

function Mason:DecodeShare(str)
  if type(str) ~= "string" or str == "" then
    return nil
  end
  local decoded = LibDeflate:DecodeForPrint(str)
  if not decoded then
    return nil
  end
  local decompressed = LibDeflate:DecompressDeflate(decoded)
  if not decompressed then
    return nil
  end
  local ok, data = AceSerializer:Deserialize(decompressed)
  if not ok or type(data) ~= "table" then
    return nil
  end
  return data
end

function Mason:BuildExport(kind)
  local specID = self:GetCurrentSpecID()
  local pieces = self:GetKit(specID)
  local data = {
    v = SCHEMA_MAJOR,
    addon = "Mason",
    kind = kind,
    specID = specID,
    class = PlayerClass(),
  }
  if kind == "kit" or kind == "full" then
    local kit = {}
    for id, piece in pairs(pieces) do
      kit[id] = ExportPiece(piece)
    end
    data.kit = kit
  end
  if kind == "layout" or kind == "full" then
    local views = {}
    local src = self:GetViews()
    for id in pairs(pieces) do
      if src[id] then
        views[id] = ExportView(src[id])
      end
    end
    data.views = views
  end
  return data
end

function Mason:EnsureShareDialog()
  if self.sharePanel then
    return self.sharePanel
  end
  if InCombatLockdown() then
    return nil
  end
  local panel = CreateFrame("Frame", "MasonSharePanel", UIParent, "BackdropTemplate")
  panel:SetSize(520, 280)
  panel:SetPoint("TOP", UIParent, "TOP", 0, -160)
  panel:SetFrameStrata(PANEL_STRATA)
  panel:SetFrameLevel(PANEL_LEVEL)
  panel:EnableMouse(true)
  panel:Hide()
  SkinSharePanel(panel)

  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", panel, "TOP", 0, -10)
  title:SetText("Mason export")
  panel.title = title

  local scroll = CreateFrame("ScrollFrame", "MasonShareScroll", panel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -36)
  scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -36, 44)

  local edit = CreateFrame("EditBox", "MasonShareEdit", scroll)
  edit:SetMultiLine(true)
  edit:SetFontObject(ChatFontNormal)
  edit:SetAutoFocus(false)
  edit:SetMaxLetters(0)
  edit:SetWidth(460)
  edit:SetHeight(400)
  edit:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  scroll:SetScrollChild(edit)
  panel.edit = edit
  panel.scroll = scroll

  local close = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  close:SetSize(80, 22)
  close:SetPoint("BOTTOM", panel, "BOTTOM", 50, 12)
  close:SetText("Close")
  close:EnableMouse(true)
  close:SetScript("OnClick", function()
    panel:Hide()
    edit:ClearFocus()
  end)
  panel.closeBtn = close

  local importBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  importBtn:SetSize(80, 22)
  importBtn:SetPoint("BOTTOM", panel, "BOTTOM", -50, 12)
  importBtn:SetText("Import")
  importBtn:EnableMouse(true)
  importBtn:SetScript("OnClick", function()
    Mason:ImportShare(edit:GetText())
  end)
  panel.importBtn = importBtn

  self.sharePanel = panel
  return panel
end

function Mason:ShowShareDialog(text, importMode)
  if InCombatLockdown() and not self.sharePanel then
    self.pendingShareDialog = { text = text or "", importMode = importMode }
    self:QueueIfCombat(function()
      local pending = Mason.pendingShareDialog
      Mason.pendingShareDialog = nil
      if pending then
        Mason:ShowShareDialog(pending.text, pending.importMode)
      end
    end)
    return
  end
  local panel = self:EnsureShareDialog()
  if not panel then
    return
  end
  panel.title:SetText(importMode and "Mason import" or "Mason export")
  if panel.importBtn then
    if importMode then
      panel.importBtn:Show()
      panel.closeBtn:SetPoint("BOTTOM", panel, "BOTTOM", 50, 12)
    else
      panel.importBtn:Hide()
      panel.closeBtn:SetPoint("BOTTOM", panel, "BOTTOM", 0, 12)
    end
  end
  local edit = panel.edit
  edit:SetText(text or "")
  panel:SetFrameStrata(PANEL_STRATA)
  panel:SetFrameLevel(PANEL_LEVEL)
  panel:EnableMouse(true)
  panel:Show()
  panel:Raise()
  edit:SetFocus()
  if not importMode and text and text ~= "" then
    edit:HighlightText()
  end
end

function Mason:BumpPieceIndex(id)
  local n = tonumber(string.match(tostring(id or ""), "^p_(%d+)$"))
  if not n then
    return
  end
  local nextIndex = self.db.profile.nextPieceIndex or 1
  if n >= nextIndex then
    self.db.profile.nextPieceIndex = n + 1
  end
end

function Mason:ApplyImportData(data)
  if type(data) ~= "table" then
    print("Mason: invalid import")
    return
  end
  local v = tonumber(data.v)
  if not v then
    print("Mason: invalid import")
    return
  end
  if v > SCHEMA_MAJOR then
    print("Mason: export is newer than this addon")
    return
  end
  if v < SCHEMA_MAJOR then
    data = self:Migrate(data)
  end
  local kind = data.kind
  if kind ~= "kit" and kind ~= "layout" and kind ~= "full" then
    print("Mason: invalid import")
    return
  end
  local you = self:GetCurrentSpecID()
  if data.specID and you and data.specID ~= you then
    self:Notify(string.format("imported kit for spec %s (you are %s)", tostring(data.specID), tostring(you)))
  end
  local function apply()
    if kind == "kit" or kind == "full" then
      local kit = self:GetSpecKit()
      if not kit then
        print("Mason: no specialization")
        return
      end
      for id, piece in pairs(data.kit or {}) do
        if type(piece) == "table" then
          local copy = ExportPiece(piece)
          copy.id = piece.id or id
          if copy.macroName == nil and piece.macro ~= nil then
            copy.macroName = piece.macro
          end
          kit.pieces[copy.id] = copy
          self:BumpPieceIndex(copy.id)
        end
      end
      self:ApplyOverrides()
      -- C-06: kit-only import membership must layout explicitly (ApplyOverrides is bind-only).
      -- kind == "full" still layouts via the views branch below.
      if kind == "kit" and self.ApplyLayout then
        self:ApplyLayout()
      end
    end
    if kind == "layout" or kind == "full" then
      local pieces = self:GetKit()
      local views = self:GetViews()
      for id, view in pairs(data.views or {}) do
        if pieces[id] and type(view) == "table" then
          views[id] = ExportView(view)
        end
      end
      self:ApplyLayout()
    end
  end
  local deferred = self:QueueIfCombat(apply)
  if deferred then
    print("Mason: queued until combat ends")
  end
end

function Mason:ExportShare(kind)
  if kind ~= "kit" and kind ~= "layout" and kind ~= "full" then
    print("Mason: usage: /mason export kit|layout|full")
    return
  end
  if not self:GetCurrentSpecID() then
    print("Mason: no specialization")
    return
  end
  local encoded = self:EncodeShare(self:BuildExport(kind))
  print(string.format("Mason: exported %s %d chars", kind, #encoded))
  self:ShowShareDialog(encoded, false)
end

function Mason:ImportShare(str)
  str = strtrim(str or "")
  if str == "" then
    print("Mason: invalid import")
    return
  end
  local data = self:DecodeShare(str)
  if not data then
    print("Mason: invalid import")
    return
  end
  self:ApplyImportData(data)
end
