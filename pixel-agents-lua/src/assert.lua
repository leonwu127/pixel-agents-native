-- Format-string assert helper.
-- Usage: assertf(cond, "expected %d got %d", a, b)
-- Returns `cond` when truthy so it can be chained.

local M = {}

function M.assertf(cond, fmt, ...)
  if not cond then
    error(string.format(fmt, ...), 2)
  end
  return cond
end

return M
