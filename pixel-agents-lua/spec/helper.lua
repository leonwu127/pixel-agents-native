-- Pure-Lua busted-compatible test harness (per design.md D12).
-- No C deps, runs on bare luajit.exe.
-- API mirrors busted: describe / it / assert.are.equal / assert.is_nil / etc.
-- Each spec file ends with `helper.run()` which exits with non-zero on any failure.

local M = {}

local describes = {}
local current_describe = nil

-- ============================================================
-- describe / it
-- ============================================================

function describe(name, fn)
  local outer = current_describe
  current_describe = { name = name, its = {} }
  table.insert(describes, current_describe)
  fn()
  current_describe = outer
end

function it(name, fn)
  if not current_describe then
    error("it() must be inside a describe() block", 2)
  end
  table.insert(current_describe.its, { name = name, fn = fn })
end

-- ============================================================
-- assert
-- ============================================================

local function tostr(v)
  if type(v) == "table" then
    local parts = {}
    local n = 0
    for k, vv in pairs(v) do
      n = n + 1
      if n > 6 then parts[#parts + 1] = "..."; break end
      parts[#parts + 1] = tostring(k) .. "=" .. tostring(vv)
    end
    return "{" .. table.concat(parts, ", ") .. "}"
  end
  if type(v) == "string" then return string.format("%q", v) end
  return tostring(v)
end

local function deep_equal(a, b)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for k, v in pairs(a) do
    if not deep_equal(v, b[k]) then return false end
  end
  for k, _ in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end

local function fail(msg) error(msg, 3) end

local assert_t = setmetatable({}, {
  __call = function(_, cond, msg)
    if not cond then fail(msg or "assertion failed") end
    return cond
  end,
})

assert_t.are = {
  equal = function(expected, actual)
    if expected ~= actual then
      fail(string.format("expected %s, got %s", tostr(expected), tostr(actual)))
    end
  end,
  same = function(expected, actual)
    if not deep_equal(expected, actual) then
      fail(string.format("tables differ: expected %s, got %s", tostr(expected), tostr(actual)))
    end
  end,
}

assert_t.are_not = {
  equal = function(expected, actual)
    if expected == actual then
      fail(string.format("expected values to differ, both %s", tostr(expected)))
    end
  end,
}

function assert_t.is_nil(v)
  if v ~= nil then fail("expected nil, got " .. tostr(v)) end
end

function assert_t.is_not_nil(v)
  if v == nil then fail("expected non-nil, got nil") end
end

function assert_t.is_true(v)
  if v ~= true then fail("expected true, got " .. tostr(v)) end
end

function assert_t.is_false(v)
  if v ~= false then fail("expected false, got " .. tostr(v)) end
end

function assert_t.is_truthy(v)
  if not v then fail("expected truthy, got " .. tostr(v)) end
end

function assert_t.is_falsy(v)
  if v then fail("expected falsy, got " .. tostr(v)) end
end

function assert_t.has_error(fn, expected_msg)
  local ok, err = pcall(fn)
  if ok then fail("expected function to error but it didn't") end
  if expected_msg and not string.find(tostring(err), expected_msg, 1, true) then
    fail(string.format("error message mismatch: got %s, expected to contain %s",
      tostr(tostring(err)), tostr(expected_msg)))
  end
end

assert_t.has_no = {
  errors = function(fn)
    local ok, err = pcall(fn)
    if not ok then fail("expected no error but got: " .. tostring(err)) end
  end,
}

_G.rawassert = _G.assert
_G.assert = assert_t

-- ============================================================
-- runner
-- ============================================================

function M.run()
  local pass, fail_count = 0, 0
  local failures = {}

  for _, d in ipairs(describes) do
    for _, t in ipairs(d.its) do
      local ok, err = xpcall(t.fn, debug.traceback)
      if ok then
        pass = pass + 1
        io.write(".")
      else
        fail_count = fail_count + 1
        io.write("F")
        failures[#failures + 1] = { group = d.name, name = t.name, err = err }
      end
      io.flush()
    end
  end

  io.write("\n")
  for _, f in ipairs(failures) do
    io.write(string.format("\nFAIL: %s :: %s\n  %s\n", f.group, f.name, f.err))
  end

  io.write(string.format("\n%d passed, %d failed\n", pass, fail_count))

  describes = {}
  current_describe = nil

  os.exit(fail_count == 0 and 0 or 1)
end

return M
