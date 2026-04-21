-- Translate a raw Claude Code hook event (JSON-decoded table) into a
-- normalized scene-level event, or nil for events we don't handle.
--
-- Normalized event kinds (consumed by scenes/office.lua):
--   { kind = "spawn",         sessionId }
--   { kind = "despawn",       sessionId }
--   { kind = "tool_start",    sessionId, toolId, toolName, input }
--   { kind = "tool_end",      sessionId, toolId }
--   { kind = "turn_end",      sessionId }
--   { kind = "permission",    sessionId }
--   { kind = "prompt_submit", sessionId }
--
-- Pure, no IO; fully unit-testable.

local M = {}

-- Whitelist of hook event names we understand. Anything else returns nil.
local HANDLERS = {}

local function require_sid(raw)
  local sid = raw.session_id
  if type(sid) ~= "string" or sid == "" then return nil end
  return sid
end

HANDLERS.SessionStart = function(raw)
  local sid = require_sid(raw)
  if not sid then return nil end
  return { kind = "spawn", sessionId = sid }
end

HANDLERS.SessionEnd = function(raw)
  local sid = require_sid(raw)
  if not sid then return nil end
  return { kind = "despawn", sessionId = sid }
end

HANDLERS.Stop = function(raw)
  local sid = require_sid(raw)
  if not sid then return nil end
  return { kind = "turn_end", sessionId = sid }
end

HANDLERS.PreToolUse = function(raw)
  local sid = require_sid(raw)
  if not sid then return nil end
  if type(raw.tool_name) ~= "string" then return nil end
  return {
    kind      = "tool_start",
    sessionId = sid,
    toolId    = raw.tool_use_id,  -- may be nil for PreToolUse — scene will fallback
    toolName  = raw.tool_name,
    input     = raw.tool_input,
  }
end

HANDLERS.PostToolUse = function(raw)
  local sid = require_sid(raw)
  if not sid then return nil end
  return {
    kind      = "tool_end",
    sessionId = sid,
    toolId    = raw.tool_use_id,
  }
end

HANDLERS.PostToolUseFailure = HANDLERS.PostToolUse

HANDLERS.PermissionRequest = function(raw)
  local sid = require_sid(raw)
  if not sid then return nil end
  return { kind = "permission", sessionId = sid }
end

HANDLERS.UserPromptSubmit = function(raw)
  local sid = require_sid(raw)
  if not sid then return nil end
  return { kind = "prompt_submit", sessionId = sid }
end

-- Notification is ambiguous in Claude's API (idle vs permission prompt).
-- For MVP we ignore it; PermissionRequest already gives us an explicit
-- permission signal, and Stop gives us the idle/waiting signal.
HANDLERS.Notification = function(_) return nil end

-- Subagents are deferred per BACKLOG P2. Keep the hook registered (to avoid
-- desync with installer), but do nothing with the event.
HANDLERS.SubagentStart = function(_) return nil end
HANDLERS.SubagentStop  = function(_) return nil end

function M.normalize(raw)
  if type(raw) ~= "table" then return nil end
  local name = raw.hook_event_name
  if type(name) ~= "string" then return nil end
  local handler = HANDLERS[name]
  if not handler then return nil end
  return handler(raw)
end

-- Exposed for testing and for the installer to confirm coverage.
M.HANDLED_EVENTS = {
  "SessionStart", "SessionEnd", "Stop",
  "PreToolUse", "PostToolUse", "PostToolUseFailure",
  "PermissionRequest", "UserPromptSubmit",
  -- Registered but produce nil:
  "Notification", "SubagentStart", "SubagentStop",
}

return M
