-- Pure polling logic. No IO itself — caller supplies an `io_ops` table:
--
--   io_ops.list_dir(dir)                  -> { "a.jsonl", "b.jsonl", ... }
--   io_ops.get_size(abs_path)             -> integer size in bytes
--   io_ops.read_range(abs_path, off, n)   -> string with the requested bytes
--
-- This keeps scanOnce testable without touching the filesystem.
-- `watcher_thread.lua` (Love2D side) supplies a real implementation using
-- `io.popen("dir")` and `io.open`.

local M = {}

-- Create an initial empty state table.
function M.new_state()
  return { files = {} }  -- abs_path -> { offset, buffer }
end

-- dirs: list of absolute directory paths
-- file_pattern: Lua string pattern; matched against filename (e.g. "%.jsonl$")
-- state: previous state (or M.new_state())
-- io_ops: see module header
--
-- Returns: {
--   new_lines = { { dir, file, session_id, line }, ... },   (in scan order)
--   state     = updated state table (replaces the old one)
-- }
function M.scanOnce(dirs, file_pattern, state, io_ops)
  local new_lines = {}
  local new_state = { files = {} }

  for _, dir in ipairs(dirs) do
    local ok_list, names = pcall(io_ops.list_dir, dir)
    if ok_list and type(names) == "table" then
      for _, name in ipairs(names) do
        if name:match(file_pattern) then
          local abs = dir .. "/" .. name
          local ok_size, size = pcall(io_ops.get_size, abs)
          if ok_size and type(size) == "number" then
            local prev = state.files[abs] or { offset = 0, buffer = "" }
            local start = prev.offset
            local buffer = prev.buffer
            if size < prev.offset then
              -- File was truncated or rotated; re-read from start.
              start = 0
              buffer = ""
            end
            if size > start then
              local ok_read, chunk = pcall(io_ops.read_range, abs, start, size - start)
              if ok_read and type(chunk) == "string" then
                buffer = buffer .. chunk
              end
            end

            -- Extract newline-terminated lines, keep any trailing partial.
            local session_id = name:match("(.+)%.jsonl$") or name
            while true do
              local nl = buffer:find("\n", 1, true)
              if not nl then break end
              local line = buffer:sub(1, nl - 1)
              if line:sub(-1) == "\r" then line = line:sub(1, -2) end
              if line ~= "" then
                new_lines[#new_lines + 1] = {
                  dir = dir,
                  file = name,
                  session_id = session_id,
                  line = line,
                }
              end
              buffer = buffer:sub(nl + 1)
            end

            new_state.files[abs] = { offset = size, buffer = buffer }
          end
        end
      end
    end
  end

  return { new_lines = new_lines, state = new_state }
end

return M
