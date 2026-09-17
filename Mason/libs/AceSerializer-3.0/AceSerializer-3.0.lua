--- AceSerializer-3.0
-- Serialize Lua values (except functions/userdata) to a string and back.
-- Compatible with the Ace3 AceSerializer-3.0 API (Serialize / Deserialize / Embed).

local MAJOR, MINOR = "AceSerializer-3.0", 5
local AceSerializer = LibStub:NewLibrary(MAJOR, MINOR)
if not AceSerializer then
  return
end

AceSerializer.embeds = AceSerializer.embeds or {}

local tconcat = table.concat
local strbyte = string.byte
local strchar = string.char
local gsub = string.gsub
local format = string.format
local type = type
local tostring = tostring
local tonumber = tonumber
local pairs = pairs
local select = select
local pcall = pcall

local function EscapeString(s)
  return (gsub(s, "[%z\001-\031\094\126]", function(c)
    return format("~%03d", strbyte(c))
  end))
end

local function UnescapeString(s)
  return (gsub(s, "~(%d%d%d)", function(d)
    return strchar(tonumber(d))
  end))
end

local function SerializeValue(v, res)
  local t = type(v)
  if t == "nil" then
    res[#res + 1] = "^Z"
  elseif t == "boolean" then
    res[#res + 1] = v and "^B" or "^b"
  elseif t == "number" then
    res[#res + 1] = "^N"
    res[#res + 1] = tostring(v)
  elseif t == "string" then
    res[#res + 1] = "^S"
    res[#res + 1] = EscapeString(v)
  elseif t == "table" then
    res[#res + 1] = "^T"
    for k, val in pairs(v) do
      SerializeValue(k, res)
      SerializeValue(val, res)
    end
    res[#res + 1] = "^t"
  else
    error("Cannot serialize type " .. t)
  end
end

function AceSerializer:Serialize(...)
  local n = select("#", ...)
  local res = { "^1" }
  for i = 1, n do
    SerializeValue((select(i, ...)), res)
  end
  return tconcat(res)
end

local function Parse(str, i)
  local tag = str:sub(i, i + 1)
  if tag == "^Z" then
    return nil, i + 2
  elseif tag == "^B" then
    return true, i + 2
  elseif tag == "^b" then
    return false, i + 2
  elseif tag == "^N" then
    local j = str:find("%^", i + 2)
    if not j then
      error("unterminated number")
    end
    local num = tonumber(str:sub(i + 2, j - 1))
    if not num then
      error("bad number")
    end
    return num, j
  elseif tag == "^S" then
    local j = str:find("%^", i + 2)
    if not j then
      error("unterminated string")
    end
    return UnescapeString(str:sub(i + 2, j - 1)), j
  elseif tag == "^T" then
    local t = {}
    i = i + 2
    while str:sub(i, i + 1) ~= "^t" do
      if i > #str then
        error("unterminated table")
      end
      local k
      k, i = Parse(str, i)
      local v
      v, i = Parse(str, i)
      t[k] = v
    end
    return t, i + 2
  end
  error("bad token at " .. tostring(i))
end

function AceSerializer:Deserialize(str)
  if type(str) ~= "string" or str:sub(1, 2) ~= "^1" then
    return false, "Invalid serialized data"
  end
  local ok, value = pcall(Parse, str, 3)
  if not ok then
    return false, value
  end
  return true, value
end

local mixins = { "Serialize", "Deserialize" }

function AceSerializer:Embed(target)
  for i = 1, #mixins do
    local name = mixins[i]
    target[name] = self[name]
  end
  self.embeds[target] = true
  return target
end

for target in pairs(AceSerializer.embeds) do
  AceSerializer:Embed(target)
end
