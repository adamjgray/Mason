local Mason = LibStub("AceAddon-3.0"):GetAddon("Mason")

local queue = {}
local pendingNotifies = {}

function Mason:QueueIfCombat(fn)
  if InCombatLockdown() then
    queue[#queue + 1] = fn
    return true
  end
  fn()
  return false
end

function Mason:StashNotify(msg)
  pendingNotifies[#pendingNotifies + 1] = msg
end

function Mason:ApplyOverridesAndNotify(messages)
  messages = messages or {}
  if InCombatLockdown() then
    for i = 1, #messages do
      self:StashNotify(messages[i])
    end
    return self:QueueIfCombat(function()
      self:ApplyOverrides()
    end)
  end
  self:ApplyOverrides()
  for i = 1, #messages do
    self:Notify(messages[i])
  end
  return false
end

function Mason:FlushCombatQueue()
  if InCombatLockdown() then
    return
  end
  local pending = queue
  queue = {}
  for i = 1, #pending do
    pending[i]()
  end
  local msgs = pendingNotifies
  pendingNotifies = {}
  for i = 1, #msgs do
    self:Notify(msgs[i])
  end
end
