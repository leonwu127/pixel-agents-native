package.path = "./?.lua;./?/init.lua;" .. package.path
local helper = require("spec.helper")
local watcher = require("src.systems.watcher")

-- Build a fake io_ops backed by an in-memory "filesystem" map: path -> content.
local function make_io(fs)
  return {
    list_dir = function(dir)
      local names = {}
      for path, _ in pairs(fs) do
        local d, f = path:match("^(.+)/([^/]+)$")
        if d == dir then names[#names + 1] = f end
      end
      table.sort(names)
      return names
    end,
    get_size = function(path)
      local content = fs[path]
      if not content then error("no such file: " .. path) end
      return #content
    end,
    read_range = function(path, offset, n)
      local content = fs[path]
      if not content then error("no such file: " .. path) end
      return content:sub(offset + 1, offset + n)
    end,
  }
end

describe("watcher.scanOnce", function()
  it("returns no lines on empty dir", function()
    local fs = {}
    local res = watcher.scanOnce({ "/d" }, "%.jsonl$", watcher.new_state(), make_io(fs))
    assert.are.equal(0, #res.new_lines)
  end)

  it("reads all lines from a freshly-seen file", function()
    local fs = { ["/d/abc.jsonl"] = "line1\nline2\n" }
    local res = watcher.scanOnce({ "/d" }, "%.jsonl$", watcher.new_state(), make_io(fs))
    assert.are.equal(2, #res.new_lines)
    assert.are.equal("line1", res.new_lines[1].line)
    assert.are.equal("line2", res.new_lines[2].line)
    assert.are.equal("abc", res.new_lines[1].session_id)
    assert.are.equal("/d", res.new_lines[1].dir)
    assert.are.equal("abc.jsonl", res.new_lines[1].file)
  end)

  it("only reports lines appended since last scan", function()
    local fs = { ["/d/abc.jsonl"] = "line1\n" }
    local s1 = watcher.scanOnce({ "/d" }, "%.jsonl$", watcher.new_state(), make_io(fs))
    assert.are.equal(1, #s1.new_lines)

    fs["/d/abc.jsonl"] = "line1\nline2\nline3\n"
    local s2 = watcher.scanOnce({ "/d" }, "%.jsonl$", s1.state, make_io(fs))
    assert.are.equal(2, #s2.new_lines)
    assert.are.equal("line2", s2.new_lines[1].line)
    assert.are.equal("line3", s2.new_lines[2].line)
  end)

  it("holds partial trailing lines in buffer until newline arrives", function()
    local fs = { ["/d/abc.jsonl"] = "line1\nparti" }
    local s1 = watcher.scanOnce({ "/d" }, "%.jsonl$", watcher.new_state(), make_io(fs))
    assert.are.equal(1, #s1.new_lines)  -- only "line1"

    fs["/d/abc.jsonl"] = "line1\npartial\n"
    local s2 = watcher.scanOnce({ "/d" }, "%.jsonl$", s1.state, make_io(fs))
    assert.are.equal(1, #s2.new_lines)
    assert.are.equal("partial", s2.new_lines[1].line)
  end)

  it("handles \\r\\n CRLF line endings", function()
    local fs = { ["/d/abc.jsonl"] = "a\r\nb\r\n" }
    local res = watcher.scanOnce({ "/d" }, "%.jsonl$", watcher.new_state(), make_io(fs))
    assert.are.equal(2, #res.new_lines)
    assert.are.equal("a", res.new_lines[1].line)
    assert.are.equal("b", res.new_lines[2].line)
  end)

  it("skips files not matching pattern", function()
    local fs = {
      ["/d/a.jsonl"] = "x\n",
      ["/d/b.txt"] = "y\n",
    }
    local res = watcher.scanOnce({ "/d" }, "%.jsonl$", watcher.new_state(), make_io(fs))
    assert.are.equal(1, #res.new_lines)
    assert.are.equal("a.jsonl", res.new_lines[1].file)
  end)

  it("no-op rescan produces no new lines", function()
    local fs = { ["/d/a.jsonl"] = "x\ny\n" }
    local s1 = watcher.scanOnce({ "/d" }, "%.jsonl$", watcher.new_state(), make_io(fs))
    local s2 = watcher.scanOnce({ "/d" }, "%.jsonl$", s1.state, make_io(fs))
    assert.are.equal(0, #s2.new_lines)
  end)

  it("resets on truncation", function()
    local fs = { ["/d/a.jsonl"] = "line1\nline2\nline3\n" }
    local s1 = watcher.scanOnce({ "/d" }, "%.jsonl$", watcher.new_state(), make_io(fs))
    assert.are.equal(3, #s1.new_lines)

    -- File shrinks (e.g. rotated). State offset > new size triggers reset.
    fs["/d/a.jsonl"] = "short\n"
    local s2 = watcher.scanOnce({ "/d" }, "%.jsonl$", s1.state, make_io(fs))
    assert.are.equal(1, #s2.new_lines)
    assert.are.equal("short", s2.new_lines[1].line)
  end)

  it("handles multiple files in one scan", function()
    local fs = {
      ["/d/a.jsonl"] = "a1\n",
      ["/d/b.jsonl"] = "b1\nb2\n",
    }
    local res = watcher.scanOnce({ "/d" }, "%.jsonl$", watcher.new_state(), make_io(fs))
    assert.are.equal(3, #res.new_lines)
    local by_session = {}
    for _, nl in ipairs(res.new_lines) do
      by_session[nl.session_id] = (by_session[nl.session_id] or 0) + 1
    end
    assert.are.equal(1, by_session["a"])
    assert.are.equal(2, by_session["b"])
  end)

  it("tolerates missing dir (list_dir pcall)", function()
    local io_ops = {
      list_dir = function(_) error("ENOENT") end,
      get_size = function() return 0 end,
      read_range = function() return "" end,
    }
    local res = watcher.scanOnce({ "/nope" }, "%.jsonl$", watcher.new_state(), io_ops)
    assert.are.equal(0, #res.new_lines)
  end)
end)

helper.run()
