# Pixel Agents Lua MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Love2D + Lua desktop application (`pixel-agents-lua/`) that visualizes running Claude Code CLI sessions as pixel-art characters in an office — functionally equivalent to the core of `pixel-agents-native` (the VS Code extension in this repo) but entirely decoupled from VS Code.

**Architecture:** Single main scene on top of Love2D callbacks. Central `World` Lua table holds run-time state. Pure-Lua systems (parser, pathfinder, watcher-core) are TDD'd with `busted` and never touch `love.*`. File polling runs in `love.thread` so the main loop never blocks. A `Provider` contract isolates Claude-specific logic so future providers (Codex, OpenCode) can be added without touching the core.

**Tech Stack:**
- Runtime: Love2D ≥ 11.x, Lua 5.1 (bundled with Love2D)
- Testing: `busted` (standalone Lua, no Love2D)
- Libraries: `json.lua` (rxi/json.lua, vendored), `luafilesystem` (`lfs`, apt install)
- Assets: Reused PNGs from `pixel-agents-native` (`webview-ui/public/assets/`)
- Target platform: WSL2 on Windows 11 (via WSLg)

**Spec:** `wiki/pixel-agents-lua/design.md`
**Backlog:** `wiki/pixel-agents-lua/BACKLOG.md`

---

## File Structure

All files are created **inside** `pixel-agents-lua/` unless otherwise stated.

```
pixel-agents-lua/
├── .gitignore              — ignore *.love, lua build artifacts
├── README.md               — run instructions, prereqs
├── conf.lua                — Love2D window/module config (loaded before main.lua)
├── main.lua                — Love2D entry; thin shell calling into scene
│
├── src/
│   ├── assert.lua          — assertf(cond, fmt, ...) helper
│   ├── config.lua          — read ~/.pixel-agents-lua/config.lua (layoutFile field)
│   ├── provider.lua        — Provider interface + factory
│   ├── world.lua           — central state: characters, seats, layout, event FSM
│   ├── camera.lua          — pan/zoom
│   ├── assets.lua          — load PNG on boot; index by [kind][direction][frame]
│   │
│   ├── providers/
│   │   └── claude.lua      — Provider impl for Claude Code
│   │
│   ├── systems/
│   │   ├── parser.lua      — JSONL line → { kind, ... } (Claude-specific, pure)
│   │   ├── pathfinder.lua  — BFS on layout grid (pure)
│   │   ├── watcher.lua     — scanOnce(dirs, state) → {newLines, newState} (pure)
│   │   ├── watcher_thread.lua — Love2D thread entry: loops watcher.scanOnce
│   │   └── renderer.lua    — draw floor → walls → furniture → chars → bubbles
│   │
│   ├── entities/
│   │   └── character.lua   — Character FSM + animation frame stepping
│   │
│   ├── layout/
│   │   ├── types.lua       — documented shapes (comments only)
│   │   └── loader.lua      — load Lua layout file → runtime layout
│   │
│   └── vendor/
│       └── json.lua        — rxi/json.lua, MIT, vendored
│
├── layouts/
│   └── mvp_v0.lua          — the starter office layout
│
├── assets/                 — symlink to ../webview-ui/public/assets/
│
└── spec/                   — busted tests (pure Lua, no Love2D required)
    ├── helper.lua          — shared test utilities (tmp dirs, fixtures)
    ├── assert_spec.lua
    ├── parser_spec.lua
    ├── claude_provider_spec.lua
    ├── pathfinder_spec.lua
    ├── world_spec.lua
    ├── layout_loader_spec.lua
    ├── watcher_spec.lua
    └── integration/
        └── e2e_smoke_spec.lua
```

---

## Phase 0 · Scaffolding (Tasks 1–4)

### Task 1: Create project skeleton

**Files:**
- Create: `pixel-agents-lua/.gitignore`
- Create: `pixel-agents-lua/README.md`

- [ ] **Step 1: Create directory tree**

Run:
```bash
cd /home/zhiqinglwu/pixel-agents-native
mkdir -p pixel-agents-lua/{src/{providers,systems,entities,layout,vendor},layouts,spec/integration}
```

- [ ] **Step 2: Create `pixel-agents-lua/.gitignore`**

```gitignore
# Love2D build output
*.love

# Lua
*.luac

# Local dev
.luarocks/

# Editor
*.swp
```

- [ ] **Step 3: Create `pixel-agents-lua/README.md`**

```markdown
# Pixel Agents Lua

A Love2D + Lua pixel-art visualizer for running Claude Code CLI sessions.
MVP target: WSL2 on Windows 11.

## Prereqs

```bash
sudo apt install love lua-filesystem luarocks
luarocks install --local busted
```

## Run

```bash
cd pixel-agents-lua
love .
```

In a separate WSL terminal:

```bash
claude --session-id $(uuidgen)
```

The character appears in the Love2D window.

## Test

```bash
cd pixel-agents-lua
busted spec/
```

## Design & Backlog

- Design: `../wiki/pixel-agents-lua/design.md`
- Backlog: `../wiki/pixel-agents-lua/BACKLOG.md`
```

- [ ] **Step 4: Commit**

```bash
git add pixel-agents-lua/.gitignore pixel-agents-lua/README.md
git commit -m "feat(pixel-agents-lua): scaffold project directory"
```

---

### Task 2: Minimal Love2D window

**Files:**
- Create: `pixel-agents-lua/conf.lua`
- Create: `pixel-agents-lua/main.lua`

- [ ] **Step 1: Create `pixel-agents-lua/conf.lua`**

```lua
function love.conf(t)
  t.identity = "pixel-agents-lua"
  t.version = "11.4"
  t.window.title = "Pixel Agents"
  t.window.width = 1024
  t.window.height = 640
  t.window.resizable = true
  t.window.vsync = 1
  t.console = true
end
```

- [ ] **Step 2: Create `pixel-agents-lua/main.lua`**

```lua
function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")
  love.graphics.setBackgroundColor(0.12, 0.12, 0.18)
  print("[info] [main] pixel-agents-lua started")
end

function love.update(dt)
end

function love.draw()
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("pixel-agents-lua — empty scene", 16, 16)
end

function love.quit()
  print("[info] [main] goodbye")
  return false
end
```

- [ ] **Step 3: Verify window opens**

Run:
```bash
cd pixel-agents-lua
love .
```

Expected: A 1024×640 window opens with dark bluish background, shows the text. Close with the window X.

If `love` is not installed: `sudo apt install love`.

- [ ] **Step 4: Commit**

```bash
git add pixel-agents-lua/conf.lua pixel-agents-lua/main.lua
git commit -m "feat(pixel-agents-lua): minimal Love2D window"
```

---

### Task 3: Install Lua dependencies + vendor json.lua

**Files:**
- Create: `pixel-agents-lua/src/vendor/json.lua`

- [ ] **Step 1: Install system Lua deps**

Run:
```bash
sudo apt install -y lua-filesystem luarocks
luarocks install --local busted
```

Verify:
```bash
lua -e 'require("lfs"); print("lfs ok")'
~/.luarocks/bin/busted --version
```

Expected: `lfs ok` prints. Busted version prints (e.g. `2.2.0`).

If `~/.luarocks/bin/busted` isn't found, add to PATH:
```bash
echo 'export PATH="$HOME/.luarocks/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

- [ ] **Step 2: Download and vendor `rxi/json.lua`**

Run:
```bash
cd pixel-agents-lua
curl -fsSL https://raw.githubusercontent.com/rxi/json.lua/master/json.lua -o src/vendor/json.lua
```

Verify the file:
```bash
head -5 src/vendor/json.lua
```

Expected: Contains a copyright header mentioning rxi and MIT License.

- [ ] **Step 3: Smoke-test json.lua**

Run:
```bash
cd pixel-agents-lua
lua -e 'package.path = "src/vendor/?.lua;" .. package.path; local j = require("json"); print(j.encode({hello="world"}))'
```

Expected: `{"hello":"world"}` (key order may vary).

- [ ] **Step 4: Commit**

```bash
git add pixel-agents-lua/src/vendor/json.lua
git commit -m "feat(pixel-agents-lua): vendor rxi/json.lua"
```

---

### Task 4: Set up busted test runner

**Files:**
- Create: `pixel-agents-lua/.busted`
- Create: `pixel-agents-lua/spec/helper.lua`
- Create: `pixel-agents-lua/spec/sanity_spec.lua`

- [ ] **Step 1: Create `.busted` config**

Create `pixel-agents-lua/.busted`:

```lua
return {
  default = {
    lpath = "./src/?.lua;./src/?/init.lua;./src/vendor/?.lua",
    output = "utfTerminal",
    verbose = true,
  }
}
```

- [ ] **Step 2: Create `spec/helper.lua` for shared utilities**

```lua
-- spec/helper.lua — shared test helpers
local M = {}

-- Create a temp directory, return its absolute path; caller cleans up
function M.make_tmp_dir()
  local p = os.tmpname()
  os.remove(p)
  os.execute("mkdir -p " .. p)
  return p
end

-- Remove a directory tree (POSIX only; tests are Linux-only per spec)
function M.rm_rf(path)
  assert(path and path:match("^/tmp/") or path:match("^/var/folders/"),
    "refusing to rm_rf outside tmp dirs: " .. tostring(path))
  os.execute("rm -rf " .. path)
end

-- Write a string to path (creates parent dirs)
function M.write_file(path, content)
  os.execute("mkdir -p $(dirname " .. path .. ")")
  local f = assert(io.open(path, "w"))
  f:write(content)
  f:close()
end

-- Append a string to an existing file
function M.append_file(path, content)
  local f = assert(io.open(path, "a"))
  f:write(content)
  f:close()
end

return M
```

- [ ] **Step 3: Create `spec/sanity_spec.lua`**

```lua
describe("sanity", function()
  it("runs lua math", function()
    assert.are.equal(4, 2 + 2)
  end)

  it("can require vendored json", function()
    local json = require("json")
    assert.are.equal('{"a":1}', json.encode({a=1}))
  end)
end)
```

- [ ] **Step 4: Run busted to verify setup**

Run:
```bash
cd pixel-agents-lua
busted spec/sanity_spec.lua
```

Expected:
```
●●
2 successes / 0 failures / 0 errors / 0 pending : ... seconds
```

- [ ] **Step 5: Commit**

```bash
git add pixel-agents-lua/.busted pixel-agents-lua/spec/helper.lua pixel-agents-lua/spec/sanity_spec.lua
git commit -m "test(pixel-agents-lua): busted setup with sanity spec"
```

---

## Phase 1 · Pure logic, TDD (Tasks 5–12)

### Task 5: `assert.lua` — assertf helper

**Files:**
- Create: `pixel-agents-lua/spec/assert_spec.lua`
- Create: `pixel-agents-lua/src/assert.lua`

- [ ] **Step 1: Write the failing test**

Create `pixel-agents-lua/spec/assert_spec.lua`:

```lua
local A = require("assert")

describe("assert.lua", function()
  it("passes through when cond is truthy", function()
    assert.has_no.errors(function() A.assertf(true, "should not fire") end)
    assert.has_no.errors(function() A.assertf(1, "should not fire") end)
    assert.has_no.errors(function() A.assertf("x", "should not fire") end)
  end)

  it("raises a formatted error when cond is falsy", function()
    local ok, err = pcall(function() A.assertf(false, "seat %d missing", 5) end)
    assert.is_false(ok)
    assert.matches("seat 5 missing", err)
  end)

  it("handles nil cond", function()
    local ok, err = pcall(function() A.assertf(nil, "got nil") end)
    assert.is_false(ok)
    assert.matches("got nil", err)
  end)
end)
```

- [ ] **Step 2: Run test, verify it fails**

Run: `busted spec/assert_spec.lua`
Expected: module 'assert' not found.

- [ ] **Step 3: Implement `src/assert.lua`**

```lua
-- src/assert.lua — tiny assertion helper
local M = {}

function M.assertf(cond, fmt, ...)
  if not cond then
    error(string.format(fmt, ...), 2)
  end
  return cond
end

return M
```

- [ ] **Step 4: Run test, verify it passes**

Run: `busted spec/assert_spec.lua`
Expected: 3 successes / 0 failures.

- [ ] **Step 5: Commit**

```bash
git add pixel-agents-lua/src/assert.lua pixel-agents-lua/spec/assert_spec.lua
git commit -m "feat(pixel-agents-lua): add assertf helper"
```

---

### Task 6: `parser.lua` — JSONL line → event

**Background:** This module turns a raw JSONL line (from `~/.claude/projects/<hash>/*.jsonl`) into a structured event. It is Claude-specific and pure (no IO). See `CLAUDE.md` ("JSONL record types") and `wiki/pixel-agents-lua/design.md` §6.3 for semantics.

**Files:**
- Create: `pixel-agents-lua/spec/parser_spec.lua`
- Create: `pixel-agents-lua/src/systems/parser.lua`

- [ ] **Step 1: Write the failing test**

Create `pixel-agents-lua/spec/parser_spec.lua`:

```lua
local parser = require("systems.parser")

local function line_tool_use()
  return [[{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_1","name":"Read","input":{"file_path":"/x/main.lua"}}]}}]]
end

local function line_tool_result()
  return [[{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"toolu_1","content":"ok"}]}}]]
end

local function line_turn_duration()
  return [[{"type":"system","subtype":"turn_duration","duration_ms":1200}]]
end

local function line_text_user()
  return [[{"type":"user","message":{"content":"hello"}}]]
end

describe("parser.parseLine", function()
  it("returns nil for malformed JSON", function()
    assert.is_nil(parser.parseLine("not json"))
  end)

  it("parses tool_use → tool_start", function()
    local e = parser.parseLine(line_tool_use())
    assert.are.equal("tool_start", e.kind)
    assert.are.equal("toolu_1", e.toolId)
    assert.are.equal("Read", e.toolName)
    assert.are.equal("/x/main.lua", e.input.file_path)
  end)

  it("parses tool_result → tool_end", function()
    local e = parser.parseLine(line_tool_result())
    assert.are.equal("tool_end", e.kind)
    assert.are.equal("toolu_1", e.toolId)
  end)

  it("parses system turn_duration → turn_end", function()
    local e = parser.parseLine(line_turn_duration())
    assert.are.equal("turn_end", e.kind)
  end)

  it("returns nil for plain-text user prompt", function()
    assert.is_nil(parser.parseLine(line_text_user()))
  end)

  it("handles mixed content array with text + tool_use", function()
    local l = [[{"type":"assistant","message":{"content":[{"type":"text","text":"thinking"},{"type":"tool_use","id":"t2","name":"Write","input":{}}]}}]]
    local e = parser.parseLine(l)
    assert.are.equal("tool_start", e.kind)
    assert.are.equal("Write", e.toolName)
  end)
end)
```

- [ ] **Step 2: Run test, verify it fails**

Run: `busted spec/parser_spec.lua`
Expected: module 'systems.parser' not found.

- [ ] **Step 3: Implement `src/systems/parser.lua`**

```lua
-- src/systems/parser.lua — Claude JSONL line → structured event (pure)
local json = require("json")

local M = {}

local function find_block(content, kind)
  if type(content) ~= "table" then return nil end
  for _, block in ipairs(content) do
    if type(block) == "table" and block.type == kind then
      return block
    end
  end
  return nil
end

-- parseLine(rawLine: string) -> event | nil
-- event shape:
--   { kind = "tool_start", toolId, toolName, input }
--   { kind = "tool_end",   toolId }
--   { kind = "turn_end" }
function M.parseLine(raw)
  if not raw or raw == "" then return nil end
  local ok, obj = pcall(json.decode, raw)
  if not ok or type(obj) ~= "table" then return nil end

  local t = obj.type
  if t == "assistant" then
    local content = obj.message and obj.message.content
    local tu = find_block(content, "tool_use")
    if tu then
      return {
        kind = "tool_start",
        toolId = tu.id,
        toolName = tu.name,
        input = tu.input or {},
      }
    end
    return nil

  elseif t == "user" then
    local content = obj.message and obj.message.content
    if type(content) == "string" then return nil end
    local tr = find_block(content, "tool_result")
    if tr then
      return { kind = "tool_end", toolId = tr.tool_use_id }
    end
    return nil

  elseif t == "system" and obj.subtype == "turn_duration" then
    return { kind = "turn_end" }
  end

  return nil
end

return M
```

- [ ] **Step 4: Run test, verify it passes**

Run: `busted spec/parser_spec.lua`
Expected: 6 successes / 0 failures.

- [ ] **Step 5: Commit**

```bash
git add pixel-agents-lua/src/systems/parser.lua pixel-agents-lua/spec/parser_spec.lua
git commit -m "feat(pixel-agents-lua): JSONL parser for Claude records"
```

---

### Task 7: `provider.lua` — interface + factory

**Files:**
- Create: `pixel-agents-lua/spec/provider_spec.lua`
- Create: `pixel-agents-lua/src/provider.lua`

- [ ] **Step 1: Write the failing test**

Create `pixel-agents-lua/spec/provider_spec.lua`:

```lua
local provider = require("provider")

describe("provider.create", function()
  it("errors on unknown id", function()
    local ok, err = pcall(function() provider.create("nopenope") end)
    assert.is_false(ok)
    assert.matches("unknown provider", err)
  end)

  it("returns a table with the required contract fields", function()
    local p = provider.create("claude")
    assert.are.equal("claude", p.id)
    assert.is_string(p.displayName)
    assert.is_function(p.sessionDirs)
    assert.is_string(p.sessionFilePattern)
    assert.is_function(p.normalize)
    assert.is_function(p.formatToolStatus)
    assert.is_table(p.permissionExemptTools)
  end)
end)
```

- [ ] **Step 2: Run test, verify it fails**

Run: `busted spec/provider_spec.lua`
Expected: module 'provider' not found.

- [ ] **Step 3: Implement `src/provider.lua`**

```lua
-- src/provider.lua — Provider interface + factory
local assertf = require("assert").assertf

local M = {}

local registry = {}

-- Register a provider table. Called by provider modules at require time.
function M.register(impl)
  assertf(type(impl) == "table", "provider impl must be a table")
  assertf(type(impl.id) == "string" and impl.id ~= "", "provider must have non-empty id")
  assertf(type(impl.displayName) == "string", "provider needs displayName")
  assertf(type(impl.sessionDirs) == "function", "provider needs sessionDirs()")
  assertf(type(impl.sessionFilePattern) == "string", "provider needs sessionFilePattern string")
  assertf(type(impl.normalize) == "function", "provider needs normalize()")
  assertf(type(impl.formatToolStatus) == "function", "provider needs formatToolStatus()")
  assertf(type(impl.permissionExemptTools) == "table", "provider needs permissionExemptTools table")
  registry[impl.id] = impl
  return impl
end

function M.create(id)
  -- Lazy-require so tests can require provider.lua without pulling in all impls
  if id == "claude" and not registry["claude"] then
    require("providers.claude")
  end
  local p = registry[id]
  assertf(p, "unknown provider: %s", tostring(id))
  return p
end

return M
```

- [ ] **Step 4: Run test, verify expected failure**

Run: `busted spec/provider_spec.lua`

Expected: unknown-id test passes; contract-fields test fails because `providers.claude` doesn't exist yet. That's fine — the next task creates it. Commit provider.lua alone now.

- [ ] **Step 5: Commit**

```bash
git add pixel-agents-lua/src/provider.lua pixel-agents-lua/spec/provider_spec.lua
git commit -m "feat(pixel-agents-lua): Provider interface and factory"
```

---

### Task 8: `providers/claude.lua` — Claude Code provider

**Files:**
- Create: `pixel-agents-lua/spec/claude_provider_spec.lua`
- Create: `pixel-agents-lua/src/providers/claude.lua`

- [ ] **Step 1: Write the failing test**

Create `pixel-agents-lua/spec/claude_provider_spec.lua`:

```lua
local provider = require("provider")
local claude = require("providers.claude")

describe("providers.claude", function()
  it("registers as id = 'claude'", function()
    assert.are.equal("claude", claude.id)
    assert.are.equal(claude, provider.create("claude"))
  end)

  it("sessionDirs returns ~/.claude/projects", function()
    local dirs = claude.sessionDirs()
    assert.is_table(dirs)
    assert.is_true(#dirs >= 1)
    assert.matches("%.claude/projects$", dirs[1])
  end)

  it("sessionFilePattern is *.jsonl", function()
    assert.are.equal("*.jsonl", claude.sessionFilePattern)
  end)

  it("permissionExemptTools contains Read/Grep/Glob/WebFetch", function()
    assert.is_true(claude.permissionExemptTools.Read)
    assert.is_true(claude.permissionExemptTools.Grep)
    assert.is_true(claude.permissionExemptTools.Glob)
    assert.is_true(claude.permissionExemptTools.WebFetch)
    assert.is_nil(claude.permissionExemptTools.Bash)
  end)

  it("formatToolStatus(Read, {file_path}) returns 'Reading <basename>'", function()
    assert.are.equal("Reading main.lua",
      claude.formatToolStatus("Read", {file_path = "/home/me/src/main.lua"}))
  end)

  it("formatToolStatus(Write, {file_path}) returns 'Writing <basename>'", function()
    assert.are.equal("Writing foo.ts",
      claude.formatToolStatus("Write", {file_path = "/x/foo.ts"}))
  end)

  it("formatToolStatus(Bash, {command}) returns 'Running <truncated>'", function()
    local s = claude.formatToolStatus("Bash", {command = "ls -la"})
    assert.matches("^Running", s)
    assert.matches("ls", s)
  end)

  it("formatToolStatus falls back to tool name for unknown tools", function()
    assert.are.equal("Unknown", claude.formatToolStatus("Unknown", {}))
  end)

  it("normalize delegates to parser.parseLine", function()
    local l = [[{"type":"system","subtype":"turn_duration"}]]
    local e = claude.normalize(l)
    assert.are.equal("turn_end", e.kind)
  end)
end)
```

- [ ] **Step 2: Run test, verify it fails**

Run: `busted spec/claude_provider_spec.lua`
Expected: module 'providers.claude' not found.

- [ ] **Step 3: Implement `src/providers/claude.lua`**

```lua
-- src/providers/claude.lua — Claude Code provider
local parser = require("systems.parser")
local provider = require("provider")

local function home()
  return os.getenv("HOME") or error("HOME not set")
end

local function basename(path)
  if type(path) ~= "string" then return "" end
  return path:match("([^/\\]+)$") or path
end

local function truncate(s, n)
  if type(s) ~= "string" then return "" end
  if #s <= n then return s end
  return s:sub(1, n - 1) .. "…"
end

local exempt = {
  Read = true, Grep = true, Glob = true, WebFetch = true,
  LS = true, TodoWrite = true,
}

local function formatToolStatus(name, input)
  input = input or {}
  if name == "Read" then
    return "Reading " .. basename(input.file_path)
  elseif name == "Write" then
    return "Writing " .. basename(input.file_path)
  elseif name == "Edit" then
    return "Editing " .. basename(input.file_path)
  elseif name == "Bash" then
    return "Running " .. truncate(input.command or "", 40)
  elseif name == "Grep" then
    return "Searching " .. truncate(input.pattern or "", 30)
  elseif name == "Glob" then
    return "Matching " .. truncate(input.pattern or "", 30)
  elseif name == "WebFetch" then
    return "Fetching " .. truncate(input.url or "", 40)
  elseif name == "Task" then
    return "Subagent " .. truncate(input.description or "", 30)
  else
    return name
  end
end

local impl = {
  id = "claude",
  displayName = "Claude Code",
  sessionDirs = function()
    return { home() .. "/.claude/projects" }
  end,
  sessionFilePattern = "*.jsonl",
  normalize = parser.parseLine,
  formatToolStatus = formatToolStatus,
  permissionExemptTools = exempt,
}

provider.register(impl)

return impl
```

- [ ] **Step 4: Run both provider test files, verify they pass**

Run:
```bash
busted spec/provider_spec.lua spec/claude_provider_spec.lua
```

Expected: all tests pass (11 successes / 0 failures combined).

- [ ] **Step 5: Commit**

```bash
git add pixel-agents-lua/src/providers/claude.lua pixel-agents-lua/spec/claude_provider_spec.lua
git commit -m "feat(pixel-agents-lua): Claude Code provider implementation"
```

---

### Task 9: `pathfinder.lua` — BFS on grid

**Files:**
- Create: `pixel-agents-lua/spec/pathfinder_spec.lua`
- Create: `pixel-agents-lua/src/systems/pathfinder.lua`

- [ ] **Step 1: Write the failing test**

Create `pixel-agents-lua/spec/pathfinder_spec.lua`:

```lua
local pf = require("systems.pathfinder")

-- build a grid from a multi-line string; '.' = walkable, '#' = blocked
-- returns blocked[y][x] = true
local function grid(s)
  local b = {}
  local y = 0
  for line in s:gmatch("[^\n]+") do
    y = y + 1
    b[y] = {}
    for x = 1, #line do
      local c = line:sub(x, x)
      b[y][x] = (c == "#")
    end
  end
  return b, #s:match("^[^\n]+"), y
end

describe("pathfinder.findPath", function()
  it("returns one-tile path when start == end", function()
    local blocked = grid([[....
....]])
    local p = pf.findPath(blocked, {x=2,y=1}, {x=2,y=1})
    assert.are.same({{x=2,y=1}}, p)
  end)

  it("finds a direct horizontal path", function()
    local blocked = grid([[.....]])
    local p = pf.findPath(blocked, {x=1,y=1}, {x=5,y=1})
    assert.are.equal(5, #p)
    assert.are.same({x=1,y=1}, p[1])
    assert.are.same({x=5,y=1}, p[5])
  end)

  it("routes around a wall", function()
    local blocked = grid([[.....
..#..
..#..
.....]])
    local p = pf.findPath(blocked, {x=3,y=1}, {x=3,y=4})
    assert.is_truthy(p)
    for _, t in ipairs(p) do
      assert.is_falsy(blocked[t.y][t.x], "path walked through wall at "..t.x..","..t.y)
    end
  end)

  it("returns nil when target unreachable", function()
    local blocked = grid([[...#...
...#...
...#...]])
    local p = pf.findPath(blocked, {x=1,y=1}, {x=7,y=1})
    assert.is_nil(p)
  end)

  it("returns nil when start is blocked", function()
    local blocked = grid([[#..]])
    local p = pf.findPath(blocked, {x=1,y=1}, {x=3,y=1})
    assert.is_nil(p)
  end)

  it("returns nil when end is blocked", function()
    local blocked = grid([[..#]])
    local p = pf.findPath(blocked, {x=1,y=1}, {x=3,y=1})
    assert.is_nil(p)
  end)
end)
```

- [ ] **Step 2: Run test, verify it fails**

Run: `busted spec/pathfinder_spec.lua`
Expected: module 'systems.pathfinder' not found.

- [ ] **Step 3: Implement `src/systems/pathfinder.lua`**

```lua
-- src/systems/pathfinder.lua — 4-way BFS on a blocked grid (pure)
local M = {}

local DIRS = { {0,-1}, {1,0}, {0,1}, {-1,0} }

local function in_bounds(blocked, x, y)
  return blocked[y] and blocked[y][x] ~= nil
end

local function is_blocked(blocked, x, y)
  return blocked[y][x] == true
end

-- findPath(blocked, from, to) -> {tiles} | nil
-- blocked[y][x] = true means impassable; any truthy value at [y][x] means in-bounds.
-- from / to: {x=, y=} (1-indexed).
function M.findPath(blocked, from, to)
  if not in_bounds(blocked, from.x, from.y) then return nil end
  if not in_bounds(blocked, to.x, to.y) then return nil end
  if is_blocked(blocked, from.x, from.y) then return nil end
  if is_blocked(blocked, to.x, to.y) then return nil end

  if from.x == to.x and from.y == to.y then
    return { {x=from.x, y=from.y} }
  end

  local function key(x, y) return y * 100000 + x end
  local visited = { [key(from.x, from.y)] = true }
  local came_from = {}
  local queue = { {x=from.x, y=from.y} }
  local head = 1

  while head <= #queue do
    local cur = queue[head]; head = head + 1
    for _, d in ipairs(DIRS) do
      local nx, ny = cur.x + d[1], cur.y + d[2]
      if in_bounds(blocked, nx, ny) and not is_blocked(blocked, nx, ny) then
        local k = key(nx, ny)
        if not visited[k] then
          visited[k] = true
          came_from[k] = cur
          if nx == to.x and ny == to.y then
            local path = { {x=nx, y=ny} }
            local p = cur
            while p do
              table.insert(path, 1, {x=p.x, y=p.y})
              p = came_from[key(p.x, p.y)]
            end
            return path
          end
          queue[#queue+1] = {x=nx, y=ny}
        end
      end
    end
  end
  return nil
end

return M
```

- [ ] **Step 4: Run test, verify it passes**

Run: `busted spec/pathfinder_spec.lua`
Expected: 6 successes / 0 failures.

- [ ] **Step 5: Commit**

```bash
git add pixel-agents-lua/src/systems/pathfinder.lua pixel-agents-lua/spec/pathfinder_spec.lua
git commit -m "feat(pixel-agents-lua): BFS pathfinder"
```

---

### Task 10: `layout/loader.lua` — Lua layout file loader

**Files:**
- Create: `pixel-agents-lua/src/layout/types.lua`
- Create: `pixel-agents-lua/spec/layout_loader_spec.lua`
- Create: `pixel-agents-lua/src/layout/loader.lua`

- [ ] **Step 1: Create `src/layout/types.lua` (documentation only)**

```lua
-- src/layout/types.lua — documentation of layout file shape.
-- This module has no runtime behavior. It exists so layout authors can
-- read one file to learn the schema.
--
-- A layout file returns a table with this shape:
--
--   return {
--     size = { cols = 20, rows = 11 },
--     door = { x = 1, y = 6 },     -- single tile where new characters spawn
--     seats = {                     -- order = seat assignment priority
--       { x = 4, y = 4, facing = "down" },
--       { x = 8, y = 4, facing = "down" },
--     },
--     furniture = {                 -- purely visual; each tile listed here
--                                   -- counts as blocked for pathfinding
--                                   -- UNLESS it's a seat tile
--       { kind = "desk", x = 4, y = 3, footprint = { {0,0} } },
--       { kind = "desk", x = 8, y = 3, footprint = { {0,0} } },
--     },
--   }
--
-- Fields:
--   size.cols / size.rows : integer, grid dimensions
--   door                  : { x, y } — valid walkable tile
--   seats                 : array of { x, y, facing } — facing ∈ "up"|"down"|"left"|"right"
--                           tiles must be walkable AND not overlap furniture footprints
--   furniture             : array of {
--                             kind     : string (matches assets.lua sprite id),
--                             x, y     : top-left tile,
--                             footprint: array of {dx, dy} offsets from (x, y)
--                                        Each (x+dx, y+dy) is marked blocked
--                                        (unless the tile is a seat).
--                           }
--
-- Runtime layout (produced by loader.load):
--   {
--     size      = { cols, rows },
--     door      = { x, y },
--     seats     = [{ id, x, y, facing, occupant = nil }],
--     furniture = [...],          -- same shape as input
--     blocked   = blocked[y][x],  -- true = impassable, false = walkable, nil = out-of-bounds
--   }

return {}
```

- [ ] **Step 2: Write the failing test**

Create `pixel-agents-lua/spec/layout_loader_spec.lua`:

```lua
local loader = require("layout.loader")
local helper = require("spec.helper")

local SAMPLE = [[
return {
  size = { cols = 5, rows = 3 },
  door = { x = 1, y = 2 },
  seats = {
    { x = 3, y = 2, facing = "down" },
  },
  furniture = {
    { kind = "desk", x = 3, y = 1, footprint = { {0, 0} } },
  },
}
]]

describe("layout.loader", function()
  local tmp

  before_each(function()
    tmp = helper.make_tmp_dir()
  end)

  after_each(function()
    helper.rm_rf(tmp)
  end)

  it("loads a valid file", function()
    local path = tmp .. "/l.lua"
    helper.write_file(path, SAMPLE)
    local L = loader.load(path)
    assert.are.equal(5, L.size.cols)
    assert.are.equal(3, L.size.rows)
    assert.are.same({x=1, y=2}, L.door)
    assert.are.equal(1, #L.seats)
    assert.are.equal("seat_1", L.seats[1].id)
    assert.are.equal("down", L.seats[1].facing)
    assert.is_nil(L.seats[1].occupant)
  end)

  it("builds blocked[y][x] marking furniture tiles", function()
    local path = tmp .. "/l.lua"
    helper.write_file(path, SAMPLE)
    local L = loader.load(path)
    assert.is_true(L.blocked[1][3])  -- desk at (3,1) is blocked
    assert.is_false(L.blocked[1][1])  -- empty tile is walkable
    assert.is_false(L.blocked[2][3])  -- seat tile stays walkable
  end)

  it("raises on missing file", function()
    local ok, err = pcall(function() loader.load(tmp .. "/nope.lua") end)
    assert.is_false(ok)
    assert.matches("could not load layout", err)
  end)

  it("raises on missing size field", function()
    local path = tmp .. "/bad.lua"
    helper.write_file(path, "return { door={x=1,y=1}, seats={}, furniture={} }")
    local ok, err = pcall(function() loader.load(path) end)
    assert.is_false(ok)
    assert.matches("size", err)
  end)

  it("raises when door is out of bounds", function()
    local path = tmp .. "/bad.lua"
    helper.write_file(path, "return { size={cols=3,rows=3}, door={x=99,y=99}, seats={}, furniture={} }")
    local ok, err = pcall(function() loader.load(path) end)
    assert.is_false(ok)
    assert.matches("door", err)
  end)
end)
```

- [ ] **Step 3: Run test, verify it fails**

Run: `busted spec/layout_loader_spec.lua`
Expected: module 'layout.loader' not found.

- [ ] **Step 4: Implement `src/layout/loader.lua`**

```lua
-- src/layout/loader.lua — load a Lua layout file and build runtime state
local assertf = require("assert").assertf

local M = {}

local function in_bounds(size, x, y)
  return x >= 1 and y >= 1 and x <= size.cols and y <= size.rows
end

local function new_blocked(size)
  local b = {}
  for y = 1, size.rows do
    b[y] = {}
    for x = 1, size.cols do
      b[y][x] = false
    end
  end
  return b
end

local function validate(raw)
  assertf(type(raw) == "table", "layout must return a table")
  assertf(type(raw.size) == "table", "layout missing size field")
  assertf(type(raw.size.cols) == "number" and raw.size.cols > 0, "bad size.cols")
  assertf(type(raw.size.rows) == "number" and raw.size.rows > 0, "bad size.rows")
  assertf(type(raw.door) == "table", "layout missing door")
  assertf(in_bounds(raw.size, raw.door.x, raw.door.y),
    "door %d,%d out of bounds for %dx%d",
    raw.door.x or -1, raw.door.y or -1, raw.size.cols, raw.size.rows)
  assertf(type(raw.seats) == "table", "layout missing seats")
  assertf(type(raw.furniture) == "table", "layout missing furniture")
end

function M.load(path)
  local chunk, err = loadfile(path)
  assertf(chunk, "could not load layout %s: %s", path, tostring(err))
  local ok, raw = pcall(chunk)
  assertf(ok, "layout %s errored: %s", path, tostring(raw))
  validate(raw)

  local blocked = new_blocked(raw.size)

  -- Mark furniture footprints as blocked.
  for _, f in ipairs(raw.furniture) do
    for _, off in ipairs(f.footprint or { {0,0} }) do
      local x, y = f.x + off[1], f.y + off[2]
      if in_bounds(raw.size, x, y) then
        blocked[y][x] = true
      end
    end
  end

  -- Seats are walkable (chairs allow the owner to sit).
  local seats = {}
  for i, s in ipairs(raw.seats) do
    assertf(in_bounds(raw.size, s.x, s.y), "seat %d out of bounds", i)
    blocked[s.y][s.x] = false
    seats[i] = {
      id = "seat_" .. i,
      x = s.x, y = s.y,
      facing = s.facing or "down",
      occupant = nil,
    }
  end

  -- Door must be walkable too.
  blocked[raw.door.y][raw.door.x] = false

  return {
    size = raw.size,
    door = { x = raw.door.x, y = raw.door.y },
    seats = seats,
    furniture = raw.furniture,
    blocked = blocked,
  }
end

return M
```

- [ ] **Step 5: Run tests, verify they pass**

Run: `busted spec/layout_loader_spec.lua`
Expected: 5 successes / 0 failures.

- [ ] **Step 6: Commit**

```bash
git add pixel-agents-lua/src/layout/types.lua pixel-agents-lua/src/layout/loader.lua pixel-agents-lua/spec/layout_loader_spec.lua
git commit -m "feat(pixel-agents-lua): layout loader with schema validation"
```

---

### Task 11: `world.lua` — state + event apply

**Files:**
- Create: `pixel-agents-lua/spec/world_spec.lua`
- Create: `pixel-agents-lua/src/world.lua`

- [ ] **Step 1: Write the failing test**

Create `pixel-agents-lua/spec/world_spec.lua`:

```lua
local World = require("world")

local function fake_layout()
  return {
    size = {cols=5, rows=3},
    door = {x=1, y=2},
    seats = {
      {id="seat_1", x=3, y=2, facing="down", occupant=nil},
      {id="seat_2", x=4, y=2, facing="down", occupant=nil},
    },
    furniture = {},
    blocked = {
      [1]={false,false,false,false,false},
      [2]={false,false,false,false,false},
      [3]={false,false,false,false,false},
    },
  }
end

describe("world", function()
  local w
  before_each(function() w = World.new(fake_layout()) end)

  describe("addCharacter", function()
    it("adds a character and assigns first free seat", function()
      w:addCharacter("s1")
      local c = w:getCharacter("s1")
      assert.is_truthy(c)
      assert.are.equal("seat_1", c.targetSeatId)
      assert.are.equal("s1", w.layout.seats[1].occupant)
    end)

    it("assigns next seat on second character", function()
      w:addCharacter("s1"); w:addCharacter("s2")
      assert.are.equal("seat_2", w:getCharacter("s2").targetSeatId)
    end)

    it("leaves character seatless when office is full", function()
      w:addCharacter("s1"); w:addCharacter("s2"); w:addCharacter("s3")
      assert.is_nil(w:getCharacter("s3").targetSeatId)
      assert.are.equal("idle", w:getCharacter("s3").state)
    end)
  end)

  describe("apply(tool_start)", function()
    it("maps Read → state=read", function()
      w:addCharacter("s1")
      w:apply("s1", {kind="tool_start", toolId="t1", toolName="Read", input={}})
      assert.are.equal("read", w:getCharacter("s1").state)
    end)

    it("maps Write → state=type", function()
      w:addCharacter("s1")
      w:apply("s1", {kind="tool_start", toolId="t1", toolName="Write", input={}})
      assert.are.equal("type", w:getCharacter("s1").state)
    end)
  end)

  describe("apply(turn_end)", function()
    it("sets state=idle and bubble=waiting", function()
      w:addCharacter("s1")
      w:apply("s1", {kind="tool_start", toolId="t1", toolName="Read", input={}})
      w:apply("s1", {kind="turn_end"})
      local c = w:getCharacter("s1")
      assert.are.equal("idle", c.state)
      assert.are.equal("waiting", c.bubble)
    end)
  end)

  describe("removeCharacter", function()
    it("frees the seat and reassigns to idle-at-door waiters in FIFO order", function()
      w:addCharacter("s1"); w:addCharacter("s2"); w:addCharacter("s3")  -- s3 seatless
      w:removeCharacter("s1")
      assert.is_nil(w:getCharacter("s1"))
      assert.are.equal("seat_1", w:getCharacter("s3").targetSeatId)
      assert.are.equal("s3", w.layout.seats[1].occupant)
    end)
  end)
end)
```

- [ ] **Step 2: Run test, verify it fails**

Run: `busted spec/world_spec.lua`
Expected: module 'world' not found.

- [ ] **Step 3: Implement `src/world.lua`**

```lua
-- src/world.lua — central runtime state and event FSM (pure Lua)
local assertf = require("assert").assertf

local M = {}
M.__index = M

local TOOL_STATE = {
  Write = "type", Edit = "type", Bash = "type", Task = "type",
  Read = "read", Grep = "read", Glob = "read", WebFetch = "read",
}

function M.new(layout)
  assertf(layout, "world requires a layout")
  local self = setmetatable({}, M)
  self.layout = layout
  self.characters = {}     -- sessionId → character table
  self.order = {}           -- insertion order of seatless chars (for FIFO reassign)
  return self
end

local function first_free_seat(layout)
  for _, s in ipairs(layout.seats) do
    if s.occupant == nil then return s end
  end
  return nil
end

local function new_character(sessionId, door)
  return {
    sessionId = sessionId,
    state = "idle",
    pos = { x = door.x, y = door.y },
    targetSeatId = nil,
    path = nil,
    facing = "down",
    animFrame = 1,
    animTime = 0,
    bubble = nil,          -- nil | "waiting" | "permission"
    bubbleUntil = nil,     -- wall-clock seconds when bubble should clear (nil = sticky)
    toolName = nil,
    toolStatus = nil,
    activeToolIds = {},    -- toolId → permission-timer start time (0 = exempt, skip)
  }
end

function M:getCharacter(id) return self.characters[id] end

function M:addCharacter(sessionId)
  assertf(type(sessionId) == "string" and sessionId ~= "", "need sessionId")
  if self.characters[sessionId] then return self.characters[sessionId] end
  local c = new_character(sessionId, self.layout.door)
  self.characters[sessionId] = c
  local seat = first_free_seat(self.layout)
  if seat then
    seat.occupant = sessionId
    c.targetSeatId = seat.id
    c.state = "walk"
  else
    table.insert(self.order, sessionId)
  end
  return c
end

function M:removeCharacter(sessionId)
  local c = self.characters[sessionId]
  if not c then return end
  -- Free seat
  for _, s in ipairs(self.layout.seats) do
    if s.occupant == sessionId then s.occupant = nil end
  end
  self.characters[sessionId] = nil
  -- Remove from waitlist if present
  for i, id in ipairs(self.order) do
    if id == sessionId then table.remove(self.order, i); break end
  end
  -- Reassign freed seat to the first waitlisted character
  if #self.order > 0 then
    local next_id = table.remove(self.order, 1)
    local waiter = self.characters[next_id]
    local seat = first_free_seat(self.layout)
    if waiter and seat then
      seat.occupant = next_id
      waiter.targetSeatId = seat.id
      waiter.state = "walk"
    end
  end
end

function M:apply(sessionId, event)
  local c = self.characters[sessionId]
  if not c then return end

  if event.kind == "tool_start" then
    local mapped = TOOL_STATE[event.toolName]
    if mapped then c.state = mapped end
    c.toolName = event.toolName
    c.toolStatus = event.toolStatus
    c.activeToolIds[event.toolId or "_"] = true
    c.bubble = nil

  elseif event.kind == "tool_end" then
    if event.toolId then c.activeToolIds[event.toolId] = nil end

  elseif event.kind == "turn_end" then
    c.state = "idle"
    c.bubble = "waiting"
    c.toolName = nil
    c.toolStatus = nil
    c.activeToolIds = {}

  elseif event.kind == "permission_timeout" then
    c.bubble = "permission"
  end
end

return M
```

- [ ] **Step 4: Run test, verify it passes**

Run: `busted spec/world_spec.lua`
Expected: 7 successes / 0 failures.

- [ ] **Step 5: Commit**

```bash
git add pixel-agents-lua/src/world.lua pixel-agents-lua/spec/world_spec.lua
git commit -m "feat(pixel-agents-lua): World state + event FSM"
```

---

### Task 12: `watcher.lua` — pure scanOnce

**Background:** The polling loop runs inside `love.thread` but the *algorithm* is a pure function: given a list of directories and a per-file state table (offset + partial-line buffer), return the new lines discovered and the updated state. This lets us unit-test without any Love2D at all.

**Files:**
- Create: `pixel-agents-lua/spec/watcher_spec.lua`
- Create: `pixel-agents-lua/src/systems/watcher.lua`

- [ ] **Step 1: Write the failing test**

Create `pixel-agents-lua/spec/watcher_spec.lua`:

```lua
local watcher = require("systems.watcher")
local helper = require("spec.helper")

describe("watcher.scanOnce", function()
  local tmp, state

  before_each(function()
    tmp = helper.make_tmp_dir()
    state = {}
  end)

  after_each(function()
    helper.rm_rf(tmp)
  end)

  it("detects new files and emits a discovery event", function()
    helper.write_file(tmp .. "/sess-1.jsonl", "")
    local out = watcher.scanOnce({tmp}, "*.jsonl", state)
    assert.are.equal(1, #out.events)
    assert.are.equal("session_discovered", out.events[1].kind)
    assert.are.equal("sess-1", out.events[1].sessionId)
  end)

  it("reads new lines from a file on subsequent scans", function()
    local path = tmp .. "/sess-1.jsonl"
    helper.write_file(path, '{"a":1}\n')
    local _, s1 = watcher.scanOnce({tmp}, "*.jsonl", state).state, watcher.scanOnce({tmp}, "*.jsonl", state)
    -- second scan after appending
    helper.append_file(path, '{"b":2}\n{"c":3}\n')
    local r = watcher.scanOnce({tmp}, "*.jsonl", state)
    local lines = {}
    for _, e in ipairs(r.events) do
      if e.kind == "raw_line" then lines[#lines+1] = e.line end
    end
    assert.are.equal(2, #lines)  -- b and c
    assert.matches('"b":2', lines[1])
    assert.matches('"c":3', lines[2])
  end)

  it("holds partial lines in a buffer until newline arrives", function()
    local path = tmp .. "/sess-1.jsonl"
    helper.write_file(path, "")
    watcher.scanOnce({tmp}, "*.jsonl", state)  -- prime
    helper.append_file(path, '{"partial":')
    local r1 = watcher.scanOnce({tmp}, "*.jsonl", state)
    local raw_lines = 0
    for _, e in ipairs(r1.events) do if e.kind == "raw_line" then raw_lines = raw_lines + 1 end end
    assert.are.equal(0, raw_lines)
    helper.append_file(path, '"rest":true}\n')
    local r2 = watcher.scanOnce({tmp}, "*.jsonl", state)
    local found
    for _, e in ipairs(r2.events) do if e.kind == "raw_line" then found = e.line; break end end
    assert.is_truthy(found)
    assert.matches('"partial":"rest":true', found)
  end)

  it("ignores files that don't match pattern", function()
    helper.write_file(tmp .. "/sess.txt", "nope\n")
    local r = watcher.scanOnce({tmp}, "*.jsonl", state)
    assert.are.equal(0, #r.events)
  end)

  it("scans nested subdirectories one level deep", function()
    -- Claude uses ~/.claude/projects/<hash>/<session>.jsonl — one level nested
    os.execute("mkdir -p " .. tmp .. "/proj-a")
    helper.write_file(tmp .. "/proj-a/sess-x.jsonl", "")
    local r = watcher.scanOnce({tmp}, "*.jsonl", state)
    assert.are.equal(1, #r.events)
    assert.are.equal("sess-x", r.events[1].sessionId)
  end)
end)
```

- [ ] **Step 2: Run test, verify it fails**

Run: `busted spec/watcher_spec.lua`
Expected: module 'systems.watcher' not found.

- [ ] **Step 3: Implement `src/systems/watcher.lua`**

```lua
-- src/systems/watcher.lua — pure polling logic.
-- scanOnce(dirs, pattern, state) -> { events = {...}, state = state }
-- state (opaque to caller, mutated in place) holds per-file:
--   { offset = <bytes read>, buffer = <partial line>, discovered = <bool> }
local lfs = require("lfs")

local M = {}

local function basename_no_ext(path)
  local n = path:match("([^/]+)$") or path
  return (n:gsub("%.jsonl$", ""))
end

local function pattern_to_lua(glob)
  -- supports only "*.ext" for MVP
  local ext = glob:match("^%*%.(.+)$")
  assert(ext, "only *.ext patterns supported")
  return "%." .. ext .. "$"
end

local function list_jsonl(root, lua_pattern)
  local out = {}
  local ok, err = pcall(function()
    for entry in lfs.dir(root) do
      if entry ~= "." and entry ~= ".." then
        local full = root .. "/" .. entry
        local attr = lfs.attributes(full)
        if attr then
          if attr.mode == "file" and entry:match(lua_pattern) then
            out[#out+1] = full
          elseif attr.mode == "directory" then
            -- descend one level only (matches Claude's layout)
            for sub in lfs.dir(full) do
              if sub ~= "." and sub ~= ".." then
                local subpath = full .. "/" .. sub
                local sattr = lfs.attributes(subpath)
                if sattr and sattr.mode == "file" and sub:match(lua_pattern) then
                  out[#out+1] = subpath
                end
              end
            end
          end
        end
      end
    end
  end)
  -- silently skip dirs that don't exist; caller may show "waiting for sessions"
  return out, ok and nil or err
end

local function read_new_bytes(path, offset)
  local f = io.open(path, "rb")
  if not f then return "", offset end
  f:seek("set", offset)
  local data = f:read("*a") or ""
  local new_offset = offset + #data
  f:close()
  return data, new_offset
end

-- emit complete lines from (buffer .. data), return { lines, new_buffer }
local function split_lines(buffer, data)
  local combined = buffer .. data
  local lines = {}
  local last = 1
  for i = 1, #combined do
    if combined:sub(i, i) == "\n" then
      lines[#lines+1] = combined:sub(last, i - 1)
      last = i + 1
    end
  end
  return lines, combined:sub(last)
end

function M.scanOnce(dirs, pattern, state)
  local lua_pattern = pattern_to_lua(pattern)
  local events = {}

  for _, root in ipairs(dirs) do
    local files = list_jsonl(root, lua_pattern)
    for _, path in ipairs(files) do
      local fstate = state[path]
      if not fstate then
        fstate = { offset = 0, buffer = "", discovered = false }
        state[path] = fstate
      end

      if not fstate.discovered then
        fstate.discovered = true
        events[#events+1] = {
          kind = "session_discovered",
          sessionId = basename_no_ext(path),
          filePath = path,
        }
      end

      local data, new_offset = read_new_bytes(path, fstate.offset)
      fstate.offset = new_offset
      if data ~= "" then
        local lines, new_buf = split_lines(fstate.buffer, data)
        fstate.buffer = new_buf
        for _, l in ipairs(lines) do
          events[#events+1] = {
            kind = "raw_line",
            sessionId = basename_no_ext(path),
            line = l,
          }
        end
      end
    end
  end

  return { events = events, state = state }
end

return M
```

- [ ] **Step 4: Run test, verify it passes**

Run: `busted spec/watcher_spec.lua`
Expected: 5 successes / 0 failures.

- [ ] **Step 5: Commit**

```bash
git add pixel-agents-lua/src/systems/watcher.lua pixel-agents-lua/spec/watcher_spec.lua
git commit -m "feat(pixel-agents-lua): pure scanOnce polling logic"
```

---

## Phase 2 · Love2D integration (Tasks 13–20)

From here on, code runs *inside* Love2D. Tests are manual — each task has a concrete visual verification step.

### Task 13: Symlink assets from pixel-agents-native

**Files:**
- Create: `pixel-agents-lua/assets` (symlink)

- [ ] **Step 1: Create the symlink**

Run:
```bash
cd /home/zhiqinglwu/pixel-agents-native/pixel-agents-lua
ln -s ../webview-ui/public/assets assets
```

- [ ] **Step 2: Verify**

Run:
```bash
ls pixel-agents-lua/assets/
ls pixel-agents-lua/assets/characters/
```

Expected: first `ls` shows directories (`characters`, `furniture`, …) plus PNG files (`floors.png`, `walls.png`). Second `ls` shows `char_0.png` through `char_5.png`.

- [ ] **Step 3: Commit (symlink target is repo-internal)**

```bash
git add pixel-agents-lua/assets
git commit -m "feat(pixel-agents-lua): symlink assets from pixel-agents-native"
```

---

### Task 14: `assets.lua` — load PNG at boot

**Files:**
- Create: `pixel-agents-lua/src/assets.lua`

- [ ] **Step 1: Implement `src/assets.lua`**

Actual asset layout under `assets/` (symlinked to `webview-ui/public/assets/`):
- `assets/characters/char_0.png` .. `char_5.png` — per-palette sprite sheets
- `assets/floors/floor_0.png` .. `floor_8.png` — individual 16×16 floor tiles
- `assets/walls/wall_0.png` — single wall tile
- `assets/furniture/<KIND>/*.png` — directories, each with 1+ PNGs

```lua
-- src/assets.lua — load PNG files from assets/ into love.graphics.Image objects.
-- Called once from love.load. Crashes with a clear error if a required file is missing.

local M = {}

local CHARACTER_FILES = {
  "assets/characters/char_0.png",
  "assets/characters/char_1.png",
  "assets/characters/char_2.png",
  "assets/characters/char_3.png",
  "assets/characters/char_4.png",
  "assets/characters/char_5.png",
}

local function load_image(path)
  if not love.filesystem.getInfo(path) then
    error("missing asset: " .. path)
  end
  return love.graphics.newImage(path)
end

function M.load()
  local images = { characters = {}, tiles = {}, furniture = {} }

  for i, rel in ipairs(CHARACTER_FILES) do
    images.characters[i] = load_image(rel)
  end

  -- MVP picks floor_0 as the sole floor texture.
  images.tiles.floor = load_image("assets/floors/floor_0.png")
  images.tiles.wall  = load_image("assets/walls/wall_0.png")

  -- Furniture: pick the first PNG in each known kind directory.
  -- The layout references `kind` strings; assets/furniture/<KIND>/ contains
  -- one or more PNGs. MVP only uses `desk` and `chair`.
  local function first_png(kind_dir)
    local dir = "assets/furniture/" .. kind_dir
    local items = love.filesystem.getDirectoryItems(dir)
    for _, f in ipairs(items) do
      if f:match("%.png$") then return dir .. "/" .. f end
    end
    error("no PNG found in " .. dir)
  end

  images.furniture.desk  = load_image(first_png("DESK"))
  images.furniture.chair = load_image(first_png("WOODEN_CHAIR"))

  return images
end

return M
```

- [ ] **Step 2: Smoke-test by loading in Love2D**

Modify `pixel-agents-lua/main.lua` temporarily to call assets.load on boot:

```lua
local assets

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")
  love.graphics.setBackgroundColor(0.12, 0.12, 0.18)
  package.path = "./src/?.lua;./src/?/init.lua;./src/vendor/?.lua;" .. package.path
  assets = require("assets").load()
  print("[info] loaded " .. #assets.characters .. " character sprites")
end

function love.update(dt) end

function love.draw()
  love.graphics.print("assets loaded: " .. #assets.characters .. " characters", 16, 16)
  love.graphics.draw(assets.characters[1], 16, 48)
  love.graphics.draw(assets.tiles.floor, 16, 160)   -- single 16×16 floor tile
  love.graphics.draw(assets.furniture.desk, 40, 160) -- first desk PNG
end

function love.quit() return false end
```

- [ ] **Step 3: Verify visually**

Run: `love .` from `pixel-agents-lua/`.
Expected: window shows the text and two PNGs rendered (character sprite sheet at 48, floor tile sheet at 160).

Close the window.

- [ ] **Step 4: Commit**

```bash
git add pixel-agents-lua/src/assets.lua pixel-agents-lua/main.lua
git commit -m "feat(pixel-agents-lua): assets loader with smoke test"
```

---

### Task 15: `layouts/mvp_v0.lua` — starter layout

**Files:**
- Create: `pixel-agents-lua/layouts/mvp_v0.lua`

- [ ] **Step 1: Create the layout**

A small office: 12 columns × 7 rows. Door at left edge. Four seats across the middle row, each with a desk tile directly above.

```lua
-- layouts/mvp_v0.lua — minimal office for MVP
return {
  size = { cols = 12, rows = 7 },
  door = { x = 1, y = 4 },
  seats = {
    { x = 3,  y = 4, facing = "up" },
    { x = 5,  y = 4, facing = "up" },
    { x = 8,  y = 4, facing = "up" },
    { x = 10, y = 4, facing = "up" },
  },
  furniture = {
    { kind = "desk",  x = 3,  y = 3, footprint = { {0, 0} } },
    { kind = "desk",  x = 5,  y = 3, footprint = { {0, 0} } },
    { kind = "desk",  x = 8,  y = 3, footprint = { {0, 0} } },
    { kind = "desk",  x = 10, y = 3, footprint = { {0, 0} } },
  },
}
```

- [ ] **Step 2: Smoke-test via loader**

Run:
```bash
cd pixel-agents-lua
lua -e 'package.path = "./src/?.lua;./src/vendor/?.lua;" .. package.path; local L = require("layout.loader").load("layouts/mvp_v0.lua"); print("size:", L.size.cols, L.size.rows, "seats:", #L.seats)'
```

Expected: `size: 12 7 seats: 4`

- [ ] **Step 3: Commit**

```bash
git add pixel-agents-lua/layouts/mvp_v0.lua
git commit -m "feat(pixel-agents-lua): MVP v0 office layout"
```

---

### Task 16: `entities/character.lua` — FSM + animation

**Files:**
- Create: `pixel-agents-lua/src/entities/character.lua`

- [ ] **Step 1: Implement the module**

Character uses the character table created in `world.lua`. This module provides pure functions that operate on those tables — no new structs.

```lua
-- src/entities/character.lua — character update: path following + animation frame stepping
-- Operates on character tables created by world.new_character.

local M = {}

local ANIM_INTERVAL = 0.2     -- seconds per frame
local WALK_SPEED    = 3.0     -- tiles per second

-- Per-state sprite row and frame count (7 frames per row in char_*.png).
-- Row 0 = down, row 1 = up, row 2 = right (left = flipped right).
-- Frames: 0=walk1, 1=walk2, 2=walk3, 3=type1, 4=type2, 5=read1, 6=read2.
local FRAMES = {
  idle = {3, 3},    -- hold walk2 (actually frame index 1 is standing-pose)
  walk = {0, 3},
  type = {3, 2},
  read = {5, 2},
}

local FACING_ROW = {
  down = 0, up = 1, right = 2, left = 2,  -- left = right row, flipped in renderer
}

-- update(c, dt) — advance animation timer and, if walking, path position.
function M.update(c, dt, world)
  if c.state == "walk" and c.path and #c.path > 0 then
    -- Move toward the next path tile
    local next_tile = c.path[1]
    local dx = next_tile.x - c.pos.x
    local dy = next_tile.y - c.pos.y
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist < 0.05 then
      c.pos.x, c.pos.y = next_tile.x, next_tile.y
      table.remove(c.path, 1)
      if #c.path == 0 then
        -- arrived at seat
        c.state = "idle"
        local seat = M.findSeat(world, c.targetSeatId)
        c.facing = seat and seat.facing or c.facing
      end
    else
      local step = WALK_SPEED * dt
      if step > dist then step = dist end
      c.pos.x = c.pos.x + (dx / dist) * step
      c.pos.y = c.pos.y + (dy / dist) * step
      if math.abs(dx) > math.abs(dy) then
        c.facing = dx > 0 and "right" or "left"
      else
        c.facing = dy > 0 and "down" or "up"
      end
    end
  end

  -- Animation frame advance
  c.animTime = (c.animTime or 0) + dt
  while c.animTime >= ANIM_INTERVAL do
    c.animTime = c.animTime - ANIM_INTERVAL
    c.animFrame = (c.animFrame or 1) + 1
  end

  -- Bubble TTL
  if c.bubbleUntil and love and love.timer and love.timer.getTime() >= c.bubbleUntil then
    c.bubble = nil
    c.bubbleUntil = nil
  end
end

function M.findSeat(world, seatId)
  for _, s in ipairs(world.layout.seats) do
    if s.id == seatId then return s end
  end
  return nil
end

-- Return { frame = 0-indexed int, row = 0-indexed int, flip = bool } for renderer.
function M.spriteFrame(c)
  local spec = FRAMES[c.state] or FRAMES.idle
  local base, count = spec[1], spec[2]
  local idx = base + ((c.animFrame or 1) - 1) % count
  local row = FACING_ROW[c.facing] or 0
  local flip = (c.facing == "left")
  return { frame = idx, row = row, flip = flip }
end

return M
```

- [ ] **Step 2: Run the existing test suite to make sure nothing breaks**

Run:
```bash
cd pixel-agents-lua
busted spec/
```

Expected: all existing specs pass (character.lua has no own specs since animation is hand-verified).

- [ ] **Step 3: Commit**

```bash
git add pixel-agents-lua/src/entities/character.lua
git commit -m "feat(pixel-agents-lua): character FSM + animation frame spec"
```

---

### Task 17: `camera.lua` — pan/zoom

**Files:**
- Create: `pixel-agents-lua/src/camera.lua`

- [ ] **Step 1: Implement camera**

```lua
-- src/camera.lua — simple pan + integer-zoom camera
local M = {}
M.__index = M

local TILE_SIZE = 16
local MIN_ZOOM = 1
local MAX_ZOOM = 6

function M.new()
  return setmetatable({
    x = 0, y = 0,       -- world-space offset (pixels)
    zoom = 3,            -- integer multiplier
    dragging = false,
    dragStart = nil,
  }, M)
end

function M:tileSize()
  return TILE_SIZE * self.zoom
end

function M:apply()
  love.graphics.push()
  love.graphics.translate(-self.x, -self.y)
  love.graphics.scale(self.zoom, self.zoom)
end

function M:unapply()
  love.graphics.pop()
end

function M:mousepressed(x, y, btn)
  if btn == 3 then     -- middle button pans
    self.dragging = true
    self.dragStart = { x = x + self.x, y = y + self.y }
  end
end

function M:mousereleased(x, y, btn)
  if btn == 3 then self.dragging = false end
end

function M:mousemoved(x, y, dx, dy)
  if self.dragging and self.dragStart then
    self.x = self.dragStart.x - x
    self.y = self.dragStart.y - y
  end
end

function M:wheelmoved(_, dy)
  if dy > 0 and self.zoom < MAX_ZOOM then
    self.zoom = self.zoom + 1
  elseif dy < 0 and self.zoom > MIN_ZOOM then
    self.zoom = self.zoom - 1
  end
end

return M
```

- [ ] **Step 2: Commit**

```bash
git add pixel-agents-lua/src/camera.lua
git commit -m "feat(pixel-agents-lua): pan/zoom camera"
```

---

### Task 18: `systems/renderer.lua` — draw the office

**Files:**
- Create: `pixel-agents-lua/src/systems/renderer.lua`

- [ ] **Step 1: Implement renderer**

```lua
-- src/systems/renderer.lua — draw layout + characters + bubbles.
-- Scaling is handled by camera; all draws happen in logical (tile-space * TILE_SIZE) coordinates.

local character_module = require("entities.character")

local TILE = 16
local CHAR_W, CHAR_H = 16, 32
local CHAR_FRAME_W = 16  -- 7 frames × 16 wide
local CHAR_ROW_H   = 32  -- 3 directions × 32 tall

local M = {}

local function drawTiles(world, assets)
  -- Draw the single 16×16 floor tile at every grid cell.
  local img = assets.tiles.floor
  for y = 1, world.layout.size.rows do
    for x = 1, world.layout.size.cols do
      love.graphics.draw(img, (x-1) * TILE, (y-1) * TILE)
    end
  end
end

local function drawFurniture(world, assets)
  for _, f in ipairs(world.layout.furniture) do
    local img = assets.furniture[f.kind]
    if img then
      local px = (f.x - 1) * TILE
      local py = (f.y - 1) * TILE - (img:getHeight() - TILE)  -- sprite aligned to bottom of its tile
      love.graphics.draw(img, px, py)
    end
  end
  -- Draw chairs over seats
  for _, s in ipairs(world.layout.seats) do
    local img = assets.furniture.chair
    if img then
      local px = (s.x - 1) * TILE
      local py = (s.y - 1) * TILE - (img:getHeight() - TILE)
      love.graphics.draw(img, px, py)
    end
  end
end

local function drawCharacter(c, assets)
  local sprite = character_module.spriteFrame(c)
  local paletteIdx = ((c.paletteIdx or 0) % #assets.characters) + 1
  local sheet = assets.characters[paletteIdx]
  local quad = love.graphics.newQuad(
    sprite.frame * CHAR_FRAME_W,
    sprite.row * CHAR_ROW_H,
    CHAR_FRAME_W, CHAR_ROW_H,
    sheet:getDimensions()
  )
  local sx, sy = sprite.flip and -1 or 1, 1
  local ox = sprite.flip and CHAR_FRAME_W or 0
  local px = (c.pos.x - 1) * TILE
  local py = (c.pos.y - 1) * TILE - (CHAR_ROW_H - TILE)
  love.graphics.draw(sheet, quad, px + ox, py, 0, sx, sy)
end

local function drawBubble(c)
  if not c.bubble then return end
  local px = (c.pos.x - 1) * TILE
  local py = (c.pos.y - 1) * TILE - (CHAR_ROW_H - TILE) - 10
  if c.bubble == "waiting" then
    love.graphics.setColor(0.4, 1.0, 0.5, 1.0)
    love.graphics.rectangle("fill", px, py, 12, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("✓", px + 1, py - 1)
  elseif c.bubble == "permission" then
    love.graphics.setColor(1.0, 0.7, 0.2, 1.0)
    love.graphics.rectangle("fill", px, py, 12, 10)
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("...", px + 1, py - 2)
  end
  love.graphics.setColor(1, 1, 1)
end

function M.render(world, assets)
  drawTiles(world, assets)
  drawFurniture(world, assets)

  -- Collect characters and z-sort by y for proper layering
  local sorted = {}
  for _, c in pairs(world.characters) do sorted[#sorted+1] = c end
  table.sort(sorted, function(a, b) return a.pos.y < b.pos.y end)
  for _, c in ipairs(sorted) do drawCharacter(c, assets); drawBubble(c) end
end

return M
```

- [ ] **Step 2: Commit (visual verification happens in Task 20)**

```bash
git add pixel-agents-lua/src/systems/renderer.lua
git commit -m "feat(pixel-agents-lua): renderer (tiles, furniture, characters, bubbles)"
```

---

### Task 19: `watcher_thread.lua` — Love2D thread entry

**Files:**
- Create: `pixel-agents-lua/src/systems/watcher_thread.lua`

- [ ] **Step 1: Implement thread entry**

```lua
-- src/systems/watcher_thread.lua — Love2D thread entry.
-- This file is NOT required normally; it's launched via love.thread.newThread(path).
-- Runs until it receives a "quit" command on its input channel.

-- Thread receives args via thread:start(dirs, pattern). Inside a thread,
-- Love2D provides its own globals (love.thread, love.timer).
local dirs, pattern = ...

package.path = "./src/?.lua;./src/?/init.lua;./src/vendor/?.lua;" .. package.path

local watcher = require("systems.watcher")
local lfs = require("lfs")

local out = love.thread.getChannel("agent_events")
local ctl = love.thread.getChannel("agent_ctl")

local state = {}
local POLL_INTERVAL = 0.5

while true do
  -- Non-blocking control check
  local cmd = ctl:pop()
  if cmd == "quit" then break end

  local ok, result = pcall(watcher.scanOnce, dirs, pattern, state)
  if ok then
    for _, ev in ipairs(result.events) do
      out:push(ev)
    end
  else
    out:push({ kind = "watcher_error", message = tostring(result) })
  end

  love.timer.sleep(POLL_INTERVAL)
end
```

- [ ] **Step 2: Commit**

```bash
git add pixel-agents-lua/src/systems/watcher_thread.lua
git commit -m "feat(pixel-agents-lua): watcher_thread entry"
```

---

### Task 20: `scenes/office.lua` + rewire `main.lua`

**Files:**
- Create: `pixel-agents-lua/src/scenes/office.lua`
- Modify: `pixel-agents-lua/main.lua`

- [ ] **Step 1: Create `src/scenes/office.lua`**

```lua
-- src/scenes/office.lua — the single MVP scene.
-- Owns world + systems + input dispatch; called from main.lua.

local Assets = require("assets")
local Loader = require("layout.loader")
local World = require("world")
local provider = require("provider")
local Camera = require("camera")
local Renderer = require("systems.renderer")
local pathfinder = require("systems.pathfinder")
local character_module = require("entities.character")

local M = {}
M.__index = M

function M.new(opts)
  local self = setmetatable({}, M)
  self.assets = Assets.load()
  self.layout = Loader.load(opts.layoutFile or "layouts/mvp_v0.lua")
  self.world = World.new(self.layout)
  self.provider = provider.create(opts.providerId or "claude")
  self.camera = Camera.new()
  self.channel = love.thread.getChannel("agent_events")
  self.ctl = love.thread.getChannel("agent_ctl")

  self.watcherThread = love.thread.newThread("src/systems/watcher_thread.lua")
  self.watcherThread:start(self.provider.sessionDirs(), self.provider.sessionFilePattern)

  self.nextPalette = 0   -- palette index for the next new character
  self.pendingPermission = {}  -- toolId → { sessionId, dueAt }
  self.PERMISSION_MS = 7.0

  return self
end

function M:update(dt)
  -- Drain events from watcher thread
  while true do
    local ev = self.channel:pop()
    if not ev then break end
    self:handleEvent(ev)
  end

  -- Advance permission timers
  local now = love.timer.getTime()
  for toolId, entry in pairs(self.pendingPermission) do
    if now >= entry.dueAt then
      local c = self.world:getCharacter(entry.sessionId)
      if c and c.activeToolIds[toolId] then
        c.bubble = "permission"
      end
      self.pendingPermission[toolId] = nil
    end
  end

  -- Advance each character
  for _, c in pairs(self.world.characters) do
    character_module.update(c, dt, self.world)
    -- Ensure walking characters have a path
    if c.state == "walk" and (not c.path or #c.path == 0) and c.targetSeatId then
      local seat = character_module.findSeat(self.world, c.targetSeatId)
      if seat then
        c.path = pathfinder.findPath(self.layout.blocked,
          {x = math.floor(c.pos.x + 0.5), y = math.floor(c.pos.y + 0.5)},
          {x = seat.x, y = seat.y})
        -- drop the starting tile (we're already there)
        if c.path and #c.path > 0 and c.path[1].x == math.floor(c.pos.x + 0.5)
           and c.path[1].y == math.floor(c.pos.y + 0.5) then
          table.remove(c.path, 1)
        end
      end
    end
    -- Clear stale waiting bubble after 2s
    if c.bubble == "waiting" and not c.bubbleUntil then
      c.bubbleUntil = love.timer.getTime() + 2.0
    end
  end
end

function M:handleEvent(raw)
  if raw.kind == "watcher_error" then
    print("[warn] [watcher] " .. tostring(raw.message))
    return
  end

  if raw.kind == "session_discovered" then
    self.world:addCharacter(raw.sessionId)
    local c = self.world:getCharacter(raw.sessionId)
    c.paletteIdx = self.nextPalette
    self.nextPalette = (self.nextPalette + 1) % #self.assets.characters
    return
  end

  if raw.kind == "raw_line" then
    local ev = self.provider.normalize(raw.line)
    if not ev then return end
    if ev.kind == "tool_start" then
      ev.toolStatus = self.provider.formatToolStatus(ev.toolName, ev.input)
      if not self.provider.permissionExemptTools[ev.toolName] then
        self.pendingPermission[ev.toolId or "_"] = {
          sessionId = raw.sessionId,
          dueAt = love.timer.getTime() + self.PERMISSION_MS,
        }
      end
    elseif ev.kind == "tool_end" then
      if ev.toolId then self.pendingPermission[ev.toolId] = nil end
    end
    self.world:apply(raw.sessionId, ev)
  end
end

function M:draw()
  self.camera:apply()
  Renderer.render(self.world, self.assets)
  self.camera:unapply()

  love.graphics.setColor(1, 1, 1)
  love.graphics.print(string.format("characters: %d  |  middle-drag to pan  |  wheel to zoom",
    (function() local n = 0; for _ in pairs(self.world.characters) do n = n + 1 end; return n end)()),
    8, 8)
end

function M:mousepressed(x, y, btn) self.camera:mousepressed(x, y, btn) end
function M:mousereleased(x, y, btn) self.camera:mousereleased(x, y, btn) end
function M:mousemoved(x, y, dx, dy) self.camera:mousemoved(x, y, dx, dy) end
function M:wheelmoved(x, y) self.camera:wheelmoved(x, y) end

function M:close()
  self.ctl:push("quit")
  self.watcherThread:wait()
end

return M
```

- [ ] **Step 2: Rewrite `main.lua` to use the scene**

```lua
-- main.lua — Love2D entrypoint
package.path = "./src/?.lua;./src/?/init.lua;./src/vendor/?.lua;" .. package.path

local Office

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")
  love.graphics.setBackgroundColor(0.12, 0.12, 0.18)
  Office = require("scenes.office").new({ layoutFile = "layouts/mvp_v0.lua" })
end

function love.update(dt) Office:update(dt) end
function love.draw() Office:draw() end

function love.mousepressed(x, y, btn) Office:mousepressed(x, y, btn) end
function love.mousereleased(x, y, btn) Office:mousereleased(x, y, btn) end
function love.mousemoved(x, y, dx, dy) Office:mousemoved(x, y, dx, dy) end
function love.wheelmoved(x, y) Office:wheelmoved(x, y) end

function love.quit()
  Office:close()
  return false
end
```

- [ ] **Step 3: Visual smoke test — empty office**

Run:
```bash
cd pixel-agents-lua
love .
```

Expected:
- Window shows the office: a floor tiled in one pattern, 4 desks in a row, 4 chairs in front of them
- "characters: 0" text at top-left
- Middle-drag pans the view
- Mouse wheel zooms in/out
- Console prints `[info] [main]` lines without errors

Close the window.

- [ ] **Step 4: Visual integration test — one live agent**

In a second WSL terminal:
```bash
claude --session-id "$(cat /proc/sys/kernel/random/uuid)"
```

Back in the Love2D window, expected within ~1 second:
- "characters: 1" at top-left
- A pixel character appears at the door (left edge) and walks to the first seat
- Ask Claude to read a file — character switches to read animation
- Ask Claude to write a file — character switches to type animation
- When Claude finishes a reply — green check bubble appears above the character, fades after 2s
- Ask Claude to run `ls` (Bash) — wait 7s — amber "..." bubble appears above the character
- Approve the tool — bubble clears

If any step fails, note it in the manual-test checklist (Task 22) and debug.

- [ ] **Step 5: Commit**

```bash
git add pixel-agents-lua/src/scenes/office.lua pixel-agents-lua/main.lua
git commit -m "feat(pixel-agents-lua): scene + main wiring, end-to-end visualizer"
```

---

## Phase 3 · Polish (Tasks 21–23)

### Task 21: `config.lua` — user config file

**Files:**
- Create: `pixel-agents-lua/src/config.lua`
- Modify: `pixel-agents-lua/main.lua`

- [ ] **Step 1: Implement config loader**

```lua
-- src/config.lua — read ~/.pixel-agents-lua/config.lua.
-- Missing or malformed → return defaults.
local M = {}

local DEFAULTS = {
  layoutFile = "layouts/mvp_v0.lua",
  providerId = "claude",
}

function M.load()
  local home = os.getenv("HOME")
  if not home then return DEFAULTS end
  local path = home .. "/.pixel-agents-lua/config.lua"
  local chunk = loadfile(path)
  if not chunk then return DEFAULTS end
  local ok, user = pcall(chunk)
  if not ok or type(user) ~= "table" then return DEFAULTS end
  local merged = {}
  for k, v in pairs(DEFAULTS) do merged[k] = v end
  for k, v in pairs(user) do merged[k] = v end
  return merged
end

return M
```

- [ ] **Step 2: Wire into `main.lua`**

Replace the `love.load` body:

```lua
function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")
  love.graphics.setBackgroundColor(0.12, 0.12, 0.18)
  local cfg = require("config").load()
  Office = require("scenes.office").new(cfg)
end
```

- [ ] **Step 3: Verify**

Run `love .` — should behave identically. Now create `~/.pixel-agents-lua/config.lua` with a bad value:

```bash
mkdir -p ~/.pixel-agents-lua
echo 'return { layoutFile = "layouts/nope.lua" }' > ~/.pixel-agents-lua/config.lua
love .
```

Expected: crash with clear "could not load layout layouts/nope.lua" message (from loader, per §7 "Layout file missing → crash at load with clear error").

Remove the bad config:
```bash
rm ~/.pixel-agents-lua/config.lua
```

- [ ] **Step 4: Commit**

```bash
git add pixel-agents-lua/src/config.lua pixel-agents-lua/main.lua
git commit -m "feat(pixel-agents-lua): user config with sane defaults"
```

---

### Task 22: Integration smoke test

**Files:**
- Create: `pixel-agents-lua/spec/integration/e2e_smoke_spec.lua`

- [ ] **Step 1: Write the test**

```lua
-- spec/integration/e2e_smoke_spec.lua — wire watcher → parser → world end-to-end
-- without Love2D. Uses the pure scanOnce / normalize / apply paths.
local helper = require("spec.helper")
local watcher = require("systems.watcher")
local provider = require("provider")
local World = require("world")

local SAMPLE_LAYOUT = {
  size = {cols=5, rows=3},
  door = {x=1, y=2},
  seats = { {id="seat_1", x=3, y=2, facing="down", occupant=nil} },
  furniture = {},
  blocked = {
    [1]={false,false,false,false,false},
    [2]={false,false,false,false,false},
    [3]={false,false,false,false,false},
  },
}

local function session_jsonl()
  return table.concat({
    [[{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Read","input":{"file_path":"/x/m.lua"}}]}}]],
    [[{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t1","content":"ok"}]}}]],
    [[{"type":"system","subtype":"turn_duration"}]],
  }, "\n") .. "\n"
end

describe("e2e: jsonl → watcher → provider.normalize → world", function()
  local tmp

  before_each(function() tmp = helper.make_tmp_dir() end)
  after_each(function() helper.rm_rf(tmp) end)

  it("lands the character in idle+waiting after a full turn", function()
    local state = {}
    local claude = provider.create("claude")
    local world = World.new(SAMPLE_LAYOUT)

    -- Initial empty scan to register the dir (prime state)
    helper.write_file(tmp .. "/sess-z.jsonl", "")
    watcher.scanOnce({tmp}, "*.jsonl", state)
    -- Simulate claude writing the whole session in one go
    helper.append_file(tmp .. "/sess-z.jsonl", session_jsonl())

    local r = watcher.scanOnce({tmp}, "*.jsonl", state)
    for _, ev in ipairs(r.events) do
      if ev.kind == "session_discovered" then
        world:addCharacter(ev.sessionId)
      elseif ev.kind == "raw_line" then
        local e = claude.normalize(ev.line)
        if e then world:apply(ev.sessionId, e) end
      end
    end

    local c = world:getCharacter("sess-z")
    assert.is_truthy(c)
    assert.are.equal("idle", c.state)
    assert.are.equal("waiting", c.bubble)
  end)
end)
```

- [ ] **Step 2: Run test**

Run: `busted spec/integration/e2e_smoke_spec.lua`
Expected: 1 success / 0 failures.

Then full suite:
```bash
busted spec/
```
Expected: all previously-passing specs still pass.

- [ ] **Step 3: Commit**

```bash
git add pixel-agents-lua/spec/integration/e2e_smoke_spec.lua
git commit -m "test(pixel-agents-lua): end-to-end smoke spec"
```

---

### Task 23: Manual test checklist + final docs

**Files:**
- Create: `wiki/pixel-agents-lua/manual-test-checklist.md`
- Modify: `pixel-agents-lua/README.md`

- [ ] **Step 1: Create the checklist**

`wiki/pixel-agents-lua/manual-test-checklist.md`:

```markdown
# Pixel Agents Lua — Manual Test Checklist

Run before every commit to `pixel-agents-lua` branch.

**Setup**

- [ ] `sudo apt install love lua-filesystem luarocks` + `luarocks install --local busted`
- [ ] Clean state: `rm -rf ~/.claude/projects/*` (OPTIONAL — wipes your Claude history, use at own risk)

**Smoke**

- [ ] `cd pixel-agents-lua && busted spec/` → all green
- [ ] `cd pixel-agents-lua && love .` → empty office with 4 desks/chairs visible

**Agent lifecycle**

- [ ] Second WSL terminal: `claude --session-id $(uuidgen)`
- [ ] Within ~1s: character appears at door, walks to first seat
- [ ] Ask Claude to `read main.lua` → read animation (sprite frames 5–6)
- [ ] Ask Claude to `write a hello world` → type animation (sprite frames 3–4)
- [ ] After Claude's reply completes → green ✓ bubble appears, fades after ~2s
- [ ] Ask Claude to run `ls` (Bash) → wait 7s → amber "..." bubble appears
- [ ] Approve the tool in the terminal → bubble clears

**Multi-agent**

- [ ] Third WSL terminal: `claude --session-id $(uuidgen)`
- [ ] Second character spawns, walks to the second seat
- [ ] Both characters animate independently as their sessions act

**`/clear`**

- [ ] In one Claude session, type `/clear`
- [ ] Old character fades out after ~60s
- [ ] New JSONL from the same session → new character appears

**Camera**

- [ ] Middle-mouse drag: view pans
- [ ] Mouse wheel: zoom in/out (integer multiples 1× → 6×)

**Shutdown**

- [ ] Close the Love2D window → process exits cleanly (no hanging thread)
- [ ] `ps aux | grep -i love` → no leftover processes
```

- [ ] **Step 2: Update README**

Update `pixel-agents-lua/README.md` to match what's actually built. Keep previous content, just add a "Status" section at the top:

```markdown
## Status

**MVP complete** — scope per `wiki/pixel-agents-lua/design.md`.

- Pure visualizer for Claude Code CLI
- File-polling input (hooks mode deferred — see BACKLOG)
- WSL2 on Windows 11 only

## Test

- Unit: `busted spec/`
- Manual: `wiki/pixel-agents-lua/manual-test-checklist.md`
```

- [ ] **Step 3: Run the manual checklist from top to bottom, fix any failures**

Common issues and pointers:
- Character spawns but never walks → pathfinder test may have passed with an edge case not covered; check `Office:update` path-building block
- Permission bubble never appears → check that `PERMISSION_MS` is 7.0 and that non-exempt tool actually maps to the right name
- App hangs on close → `Office:close` must `ctl:push("quit")` before `watcherThread:wait()`

- [ ] **Step 4: Commit**

```bash
git add wiki/pixel-agents-lua/manual-test-checklist.md pixel-agents-lua/README.md
git commit -m "docs(pixel-agents-lua): manual test checklist, updated README"
```

---

## Self-review pass-through

All spec requirements mapped to tasks:

| Spec § | Requirement | Task(s) |
|---|---|---|
| §2.1 #1 | Multi-agent concurrency | T11 (world add/remove), T20 (per-event dispatch) |
| §2.1 #2 | idle / walk / type / read animations | T16 (FSM + frames), T18 (sprite draw) |
| §2.1 #3 | Seats / walking to desk | T11 (seat assignment), T16 (path follow), T20 (path build) |
| §2.1 #4 | Waiting + permission bubbles | T11 (apply turn_end), T18 (draw), T20 (7s timer) |
| §2.1 #5 | Static Lua layout | T10 (loader), T15 (mvp_v0) |
| §2.1 #6 | Camera pan | T17 (camera) |
| §4.1 | Architecture layering | T20 (composition) |
| §4.3 | Tick loop shape | T20 (update/draw) |
| §5 | All 15+ modules | T5–T20 |
| §5.2 | Provider contract | T7 + T8 |
| §6.1 | Cold boot, no history replay | T12 (offset starts at 0 but first-scan doesn't emit old-file lines because `discovered=false` only triggers discovery event; all existing bytes become "first batch") — NOTE: this currently WOULD replay history. Fix by priming offset to file size on first sight. See next paragraph. |
| §6.2 | New agent spawns at door, first-free seat | T11 + T20 |
| §6.3 | Tool → animation mapping | T11 (TOOL_STATE table) |
| §6.4 | turn_end → idle + waiting bubble, fade 2s | T11 + T20 |
| §6.5 | Permission 7s timer | T20 (pendingPermission) |
| §6.6 | `/clear` detection (stale timeout) | **NOT IMPLEMENTED** — added as follow-up item, see below |
| §6.7 | Clean shutdown | T20 Office:close |
| §7 | Error handling matrix | T10 (crash on bad layout), T14 (crash on missing asset), T20 (watcher_error print) |
| §8.1 | Unit tests parser/provider/pathfinder/world/layout/watcher | T6/T8/T9/T11/T10/T12 |
| §8.3 | Integration smoke | T22 |
| §8.4 | Manual checklist | T23 |

**Gap 1 — Cold boot does replay history.** The spec says "Watcher records start-time mtime and only reports files newer than that, or new lines in pre-existing files. Pre-boot completed sessions are not rendered." The plan as written will emit `session_discovered` + `raw_line` for every existing line in every existing file. **Fix below.**

**Gap 2 — `/clear` detection + stale session cleanup not implemented.** The plan's world `removeCharacter` exists but no system ever calls it.

Fixing both inline so implementers have a self-contained plan:

### Task 24: Cold-boot prime + stale session cleanup

**Files:**
- Modify: `pixel-agents-lua/src/systems/watcher.lua:84-110` (the `read_new_bytes` block and the per-file state init)
- Modify: `pixel-agents-lua/src/scenes/office.lua` (add stale check in `update`)

- [ ] **Step 1: Modify `scanOnce` to seed offset from current file size at first sight of a file, **only** when `state.primed ~= true`. After priming, normal tailing resumes.**

Replace in `src/systems/watcher.lua` the inner per-file block:

```lua
      local fstate = state[path]
      if not fstate then
        fstate = { offset = 0, buffer = "", discovered = false }
        state[path] = fstate
        -- Cold-boot prime: on FIRST sight during the FIRST scan of the whole
        -- watcher, seed offset to current file size so we don't replay history.
        if not state.__primed then
          local attr = lfs.attributes(path)
          if attr and attr.size then fstate.offset = attr.size end
        end
      end
```

Then at the very end of `scanOnce`, before `return`, add:

```lua
  state.__primed = true
```

- [ ] **Step 2: Update watcher tests to assert priming behavior**

Add to `spec/watcher_spec.lua`:

```lua
  it("does not emit raw_line for history present before first scan", function()
    local path = tmp .. "/sess-old.jsonl"
    helper.write_file(path, '{"old":true}\n{"older":true}\n')
    local r = watcher.scanOnce({tmp}, "*.jsonl", state)
    local raw_lines = 0
    for _, e in ipairs(r.events) do if e.kind == "raw_line" then raw_lines = raw_lines + 1 end end
    assert.are.equal(0, raw_lines)
    -- But the session is still discovered
    assert.are.equal(1, #r.events)
    assert.are.equal("session_discovered", r.events[1].kind)
    -- New lines after priming DO get emitted
    helper.append_file(path, '{"new":true}\n')
    local r2 = watcher.scanOnce({tmp}, "*.jsonl", state)
    local lines = {}
    for _, e in ipairs(r2.events) do if e.kind == "raw_line" then lines[#lines+1] = e.line end end
    assert.are.equal(1, #lines)
    assert.matches('"new":true', lines[1])
  end)
```

- [ ] **Step 3: Add stale session cleanup to `Office:update`**

Change `src/scenes/office.lua`: add `self.lastActivity = {}` in `M.new` after `self.pendingPermission`. In `handleEvent`, any `raw_line` updates `self.lastActivity[raw.sessionId] = love.timer.getTime()`. At the end of `update(dt)`, after the character loop, add:

```lua
  -- Stale session cleanup
  local STALE = 60.0
  local now = love.timer.getTime()
  local to_remove = {}
  for sid, _ in pairs(self.world.characters) do
    local last = self.lastActivity[sid] or 0
    if now - last > STALE and last > 0 then
      to_remove[#to_remove+1] = sid
    end
  end
  for _, sid in ipairs(to_remove) do
    self.world:removeCharacter(sid)
    self.lastActivity[sid] = nil
  end
```

- [ ] **Step 4: Run all tests**

Run: `busted spec/`
Expected: all tests pass including the new priming test.

- [ ] **Step 5: Manual verify**

Run `love .` — start a Claude session — stop talking to it for 60s — character should fade out and disappear. If the test is too slow, temporarily set `STALE = 10.0` for the manual run.

- [ ] **Step 6: Commit**

```bash
git add pixel-agents-lua/src/systems/watcher.lua pixel-agents-lua/src/scenes/office.lua pixel-agents-lua/spec/watcher_spec.lua
git commit -m "fix(pixel-agents-lua): cold-boot history priming + stale session cleanup"
```

---

## After the Last Task

- [ ] Run `busted spec/` one final time.
- [ ] Run through `wiki/pixel-agents-lua/manual-test-checklist.md` start to finish.
- [ ] If anything fails, open a new commit per fix. Do not squash the history.
- [ ] Push the branch: `git push -u origin pixel-agents-lua`
- [ ] Update `wiki/pixel-agents-lua/BACKLOG.md` with any new deferred items discovered during implementation.

MVP complete when the manual checklist passes top-to-bottom.
