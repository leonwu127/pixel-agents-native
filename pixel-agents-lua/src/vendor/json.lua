-- Minimal pure-Lua JSON decoder (inspired by rxi/json.lua, MIT).
-- Supports: objects, arrays, strings (with \" \\ \/ \b \f \n \r \t \uXXXX
-- escapes), numbers (int/float, exponents, sign), booleans, null.
-- Enough for Claude Code JSONL records; does not implement JSON encoding.

local M = {}

local function parse_error(pos, msg)
  error(string.format("JSON parse error at position %d: %s", pos, msg), 3)
end

local function skip_ws(s, i)
  while i <= #s do
    local b = s:byte(i)
    if b ~= 32 and b ~= 9 and b ~= 10 and b ~= 13 then break end
    i = i + 1
  end
  return i
end

local parse_value  -- forward

local function utf8_emit(cp)
  if cp < 0x80 then
    return string.char(cp)
  elseif cp < 0x800 then
    return string.char(0xC0 + math.floor(cp / 0x40), 0x80 + (cp % 0x40))
  elseif cp < 0x10000 then
    return string.char(
      0xE0 + math.floor(cp / 0x1000),
      0x80 + math.floor((cp / 0x40) % 0x40),
      0x80 + (cp % 0x40))
  else
    return string.char(
      0xF0 + math.floor(cp / 0x40000),
      0x80 + math.floor((cp / 0x1000) % 0x40),
      0x80 + math.floor((cp / 0x40) % 0x40),
      0x80 + (cp % 0x40))
  end
end

local function parse_string(s, i)
  -- precondition: s:sub(i, i) == '"'
  i = i + 1
  local buf = {}
  while i <= #s do
    local c = s:sub(i, i)
    if c == '"' then
      return table.concat(buf), i + 1
    elseif c == "\\" then
      local esc = s:sub(i + 1, i + 1)
      if esc == '"' then buf[#buf + 1] = '"'; i = i + 2
      elseif esc == "\\" then buf[#buf + 1] = "\\"; i = i + 2
      elseif esc == "/" then buf[#buf + 1] = "/"; i = i + 2
      elseif esc == "n" then buf[#buf + 1] = "\n"; i = i + 2
      elseif esc == "t" then buf[#buf + 1] = "\t"; i = i + 2
      elseif esc == "r" then buf[#buf + 1] = "\r"; i = i + 2
      elseif esc == "b" then buf[#buf + 1] = "\b"; i = i + 2
      elseif esc == "f" then buf[#buf + 1] = "\f"; i = i + 2
      elseif esc == "u" then
        local hex = s:sub(i + 2, i + 5)
        if #hex ~= 4 or not hex:match("^%x%x%x%x$") then
          parse_error(i, "bad \\u escape")
        end
        local cp = tonumber(hex, 16)
        buf[#buf + 1] = utf8_emit(cp)
        i = i + 6
      else
        parse_error(i, "bad escape \\" .. esc)
      end
    else
      buf[#buf + 1] = c
      i = i + 1
    end
  end
  parse_error(i, "unterminated string")
end

local function parse_number(s, i)
  local start = i
  if s:sub(i, i) == "-" then i = i + 1 end
  while i <= #s do
    local c = s:sub(i, i)
    if c:match("[0-9.eE+%-]") then i = i + 1 else break end
  end
  local n = tonumber(s:sub(start, i - 1))
  if not n then parse_error(start, "bad number") end
  return n, i
end

local function parse_array(s, i)
  i = i + 1  -- skip [
  local arr = {}
  i = skip_ws(s, i)
  if s:sub(i, i) == "]" then return arr, i + 1 end
  while true do
    local v; v, i = parse_value(s, i)
    arr[#arr + 1] = v
    i = skip_ws(s, i)
    local c = s:sub(i, i)
    if c == "]" then return arr, i + 1 end
    if c ~= "," then parse_error(i, "expected , or ] in array, got " .. tostring(c)) end
    i = skip_ws(s, i + 1)
  end
end

local function parse_object(s, i)
  i = i + 1  -- skip {
  local obj = {}
  i = skip_ws(s, i)
  if s:sub(i, i) == "}" then return obj, i + 1 end
  while true do
    i = skip_ws(s, i)
    if s:sub(i, i) ~= '"' then parse_error(i, "expected string key") end
    local key; key, i = parse_string(s, i)
    i = skip_ws(s, i)
    if s:sub(i, i) ~= ":" then parse_error(i, "expected : after key " .. tostring(key)) end
    i = skip_ws(s, i + 1)
    local v; v, i = parse_value(s, i)
    obj[key] = v
    i = skip_ws(s, i)
    local c = s:sub(i, i)
    if c == "}" then return obj, i + 1 end
    if c ~= "," then parse_error(i, "expected , or } in object, got " .. tostring(c)) end
    i = i + 1
  end
end

function parse_value(s, i)
  i = skip_ws(s, i)
  local c = s:sub(i, i)
  if c == "{" then return parse_object(s, i) end
  if c == "[" then return parse_array(s, i) end
  if c == '"' then return parse_string(s, i) end
  if c == "t" and s:sub(i, i + 3) == "true" then return true, i + 4 end
  if c == "f" and s:sub(i, i + 4) == "false" then return false, i + 5 end
  if c == "n" and s:sub(i, i + 3) == "null" then return nil, i + 4 end
  if c == "-" or c:match("%d") then return parse_number(s, i) end
  parse_error(i, "unexpected char: " .. tostring(c))
end

function M.decode(s)
  if type(s) ~= "string" then error("json.decode: expected string, got " .. type(s), 2) end
  local v = parse_value(s, 1)
  return v
end

return M
