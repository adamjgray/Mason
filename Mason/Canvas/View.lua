local Mason = LibStub("AceAddon-3.0"):GetAddon("Mason")

local function TextureForPiece(piece)
  local ptype = piece.type or "spell"
  if ptype == "spell" then
    if C_Spell and C_Spell.GetSpellTexture then
      return C_Spell.GetSpellTexture(piece.spellID or piece.spellName)
    end
  elseif ptype == "item" and piece.itemID then
    if C_Item and C_Item.GetItemIconByID then
      return C_Item.GetItemIconByID(piece.itemID)
    end
    if GetItemIcon then
      return GetItemIcon(piece.itemID)
    end
  elseif ptype == "macro" and piece.macroName and GetMacroInfo then
    local _, icon = GetMacroInfo(piece.macroName)
    return icon
  end
  return 134400
end

function Mason:PaintView(exec, piece)
  if not exec or not piece then
    return
  end
  local icon = exec.masonIcon
  if not icon then
    local name = exec:GetName()
    icon = exec:CreateTexture(name and (name .. "Icon") or nil, "BACKGROUND")
    icon:SetAllPoints(exec)
    exec.masonIcon = icon
  end
  icon:SetTexture(TextureForPiece(piece))

  local hotkey = exec.masonHotkey
  if not hotkey then
    local name = exec:GetName()
    hotkey = exec:CreateFontString(name and (name .. "HotKey") or nil, "OVERLAY", "NumberFontNormal")
    hotkey:SetPoint("TOPRIGHT", exec, "TOPRIGHT", -2, -1)
    exec.masonHotkey = hotkey
  end
  if piece.key and piece.key ~= "" then
    hotkey:SetText(piece.key)
  else
    hotkey:SetText("")
  end
end

function Mason:WireExecutorView(exec)
  if exec.masonViewWired then
    return
  end
  exec.masonViewWired = true
end
