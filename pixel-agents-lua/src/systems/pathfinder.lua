-- Breadth-first pathfinding on a tile grid.
-- Pure Lua, no IO, no Love2D dependency — covered by spec/pathfinder_spec.lua.
--
-- Usage:
--   local path = pathfinder.findPath({
--     size    = { cols = 20, rows = 11 },
--     blocked = { ["5,3"] = true, ... },        -- set of tile keys "col,row"
--     from    = { col = 0, row = 5 },
--     to      = { col = 5, row = 3 },
--   })
--
-- Returns a list { {col, row}, {col, row}, ... } from `from` to `to` inclusive,
-- or nil if no path exists. If `from == to`, returns a single-tile path.

local M = {}

local function key(c, r)
  return c .. "," .. r
end

M.key = key

-- 4-directional neighbors (N/E/S/W).
local DIRS = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }

function M.findPath(opts)
  local size = opts.size
  local from = opts.from
  local to = opts.to
  local blocked = opts.blocked or {}
  local cols, rows = size.cols, size.rows

  if from.col == to.col and from.row == to.row then
    return { { col = from.col, row = from.row } }
  end

  if blocked[key(from.col, from.row)] or blocked[key(to.col, to.row)] then
    return nil
  end

  local visited = { [key(from.col, from.row)] = true }
  local parent = { [key(from.col, from.row)] = false }  -- false terminates back-walk
  local queue = { { col = from.col, row = from.row } }
  local head = 1

  while head <= #queue do
    local cur = queue[head]
    head = head + 1

    if cur.col == to.col and cur.row == to.row then
      -- Reconstruct path by walking parents back to start.
      local path = {}
      local node = cur
      while node do
        table.insert(path, 1, { col = node.col, row = node.row })
        node = parent[key(node.col, node.row)]
        if node == false then break end
      end
      return path
    end

    for _, d in ipairs(DIRS) do
      local nc, nr = cur.col + d[1], cur.row + d[2]
      if nc >= 0 and nc < cols and nr >= 0 and nr < rows then
        local nk = key(nc, nr)
        if not visited[nk] and not blocked[nk] then
          visited[nk] = true
          parent[nk] = { col = cur.col, row = cur.row }
          queue[#queue + 1] = { col = nc, row = nr }
        end
      end
    end
  end

  return nil
end

return M
