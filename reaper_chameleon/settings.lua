-- reaper_chameleon/settings.lua
-- Persistent configuration backed by REAPER ExtState (reaper.ini).
-- Section name: chameleon_drummer

local M = {}

local SECTION = "chameleon_drummer"

{ Get a stored value; returns "" when unset. }
function M.get(key)
  return reaper.GetExtState(SECTION, key)
end

{ Store a value. }
function M.set(key, value)
  reaper.SetExtState(SECTION, key, value, true)
end

{ Resolve the Python interpreter path. Returns nil when unset or the
  file does not exist. Never opens a picker dialog -- callers that need
  to prompt should use settings.resolve_python_exe() with prompting. }
function M.resolve_python_exe()
  local exe = M.get("python_exe")
  if exe == "" then return nil end
  local f = io.open(exe, "rb")
  if not f then return nil end
  f:close()
  return exe
end

return M
