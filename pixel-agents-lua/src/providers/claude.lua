-- Claude Code provider: normalizes JSONL into AgentEvents, maps tools to
-- character states, and discovers session directories.
-- Self-registers with src.provider on require.

local parser = require("src.systems.parser")
local provider = require("src.provider")

-- Tools that don't require user permission — their timer doesn't fire.
-- Matches pixel-agents-native behavior (read-only tools are safe).
local EXEMPT = {
  Read = true,
  Grep = true,
  Glob = true,
  LS = true,
  WebFetch = true,
  WebSearch = true,
  Task = true,   -- sub-agent task, permission handled by sub-agent
  TodoWrite = true,
}

-- Tool name -> character animation state.
-- "type" (Write/Edit/Bash/Task) vs "read" (Read/Grep/Glob/WebFetch).
local TOOL_STATE = {
  Read = "read",
  Grep = "read",
  Glob = "read",
  LS = "read",
  WebFetch = "read",
  WebSearch = "read",
  Write = "type",
  Edit = "type",
  MultiEdit = "type",
  Bash = "type",
  Task = "type",
  TodoWrite = "type",
  NotebookEdit = "type",
}

-- Return a short display string for a tool invocation.
local function basename(p)
  return (p and p:match("[^/\\]+$")) or p or ""
end

local function format_tool_status(name, input)
  input = input or {}
  if name == "Read" or name == "Write" or name == "Edit" or name == "MultiEdit" then
    return string.format("%s %s", name, basename(input.file_path))
  end
  if name == "Bash" then
    local cmd = input.command or ""
    if #cmd > 40 then cmd = cmd:sub(1, 37) .. "..." end
    return "Bash " .. cmd
  end
  if name == "Grep" or name == "Glob" then
    return string.format("%s %s", name, tostring(input.pattern or ""))
  end
  return name or "?"
end

local function factory(opts)
  -- `opts.session_dirs_fn` is a zero-arg function returning a list of
  -- absolute directory paths to scan. Defaults to an empty list.
  local session_dirs_fn = opts.session_dirs_fn or function() return {} end

  return {
    id = "claude",
    displayName = "Claude Code",
    sessionFilePattern = "%.jsonl$",         -- Lua pattern for `sessionDirs` files
    sessionDirs = session_dirs_fn,
    normalize = parser.parseLine,
    formatToolStatus = format_tool_status,
    permissionExemptTools = EXEMPT,
    toolStateMap = TOOL_STATE,
  }
end

provider.register("claude", factory)

return factory
