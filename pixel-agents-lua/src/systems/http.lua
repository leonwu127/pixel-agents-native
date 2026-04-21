-- Pure HTTP/1.1 request parser + response builder + JSON encoder + auth helper.
-- No socket / IO / Love2D deps; everything is string-in / table-out so the
-- server_thread runner can drive it and specs can assert without a real socket.

local M = {}

-- ---------- JSON encoder ----------
-- Minimal encoder: handles strings, numbers, booleans, nil, arrays, objects.
-- Deterministic key order on objects (sorted) so server.json is stable and
-- specs can string-compare output.

local function is_array(t)
  local n = 0
  for k, _ in pairs(t) do
    if type(k) ~= "number" then return false end
    n = n + 1
  end
  if n == 0 then return false end
  -- Check contiguous 1..n
  for i = 1, n do
    if t[i] == nil then return false end
  end
  return true, n
end

local escape_map = {
  ['"']  = '\\"',
  ['\\'] = '\\\\',
  ['\b'] = '\\b',
  ['\f'] = '\\f',
  ['\n'] = '\\n',
  ['\r'] = '\\r',
  ['\t'] = '\\t',
}

local function encode_string(s)
  local result = s:gsub('[%z\1-\31\\"]', function(c)
    if escape_map[c] then return escape_map[c] end
    return string.format("\\u%04x", c:byte())
  end)
  return '"' .. result .. '"'
end

local encode_value
encode_value = function(v)
  local t = type(v)
  if t == "nil" then
    return "null"
  elseif t == "boolean" then
    return v and "true" or "false"
  elseif t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then
      error("json: cannot encode NaN or Infinity")
    end
    if v == math.floor(v) and math.abs(v) < 1e15 then
      return string.format("%d", v)
    end
    return string.format("%.14g", v)
  elseif t == "string" then
    return encode_string(v)
  elseif t == "table" then
    local ok, n = is_array(v)
    if ok then
      local parts = {}
      for i = 1, n do parts[i] = encode_value(v[i]) end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      -- Object: sort keys for determinism
      local keys = {}
      for k, _ in pairs(v) do
        if type(k) ~= "string" then
          error("json: object keys must be strings")
        end
        keys[#keys + 1] = k
      end
      table.sort(keys)
      local parts = {}
      for i, k in ipairs(keys) do
        parts[i] = encode_string(k) .. ":" .. encode_value(v[k])
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  else
    error("json: cannot encode type " .. t)
  end
end

M.json_encode = encode_value

-- ---------- HTTP request parsing ----------

-- Parse a raw HTTP/1.1 request string. Returns {method, path, headers, body}
-- or nil, err. Headers are lowercased keys. Only supports simple requests;
-- we do not handle chunked bodies or pipelining (the hook script sends one
-- short POST per event and closes).
function M.parse_request(raw)
  if type(raw) ~= "string" then return nil, "not a string" end

  local header_end = raw:find("\r\n\r\n", 1, true)
  if not header_end then return nil, "incomplete headers" end

  local header_block = raw:sub(1, header_end - 1)
  local body = raw:sub(header_end + 4)

  local lines = {}
  for line in header_block:gmatch("([^\r\n]+)") do
    lines[#lines + 1] = line
  end
  if #lines == 0 then return nil, "empty request" end

  local method, path, version = lines[1]:match("^(%u+) (%S+) (HTTP/1%.[01])$")
  if not method then return nil, "malformed request line" end

  local headers = {}
  for i = 2, #lines do
    local k, v = lines[i]:match("^([^:]+):%s*(.*)$")
    if k then headers[k:lower()] = v end
  end

  -- If Content-Length is declared and body is short, return partial marker so
  -- the caller can decide to read more.
  local cl = tonumber(headers["content-length"])
  local complete = true
  if cl and #body < cl then complete = false end

  return {
    method  = method,
    path    = path,
    version = version,
    headers = headers,
    body    = body,
    complete = complete,
    content_length = cl,
  }
end

-- Returns true if Authorization header matches `Bearer <expected_token>`.
-- Constant-time-ish comparison (length + loop) to discourage timing leaks.
function M.auth_ok(headers, expected_token)
  if type(headers) ~= "table" or type(expected_token) ~= "string" then
    return false
  end
  local got = headers["authorization"]
  if type(got) ~= "string" then return false end
  local expected = "Bearer " .. expected_token
  if #got ~= #expected then return false end
  local diff = 0
  for i = 1, #got do
    if got:byte(i) ~= expected:byte(i) then diff = diff + 1 end
  end
  return diff == 0
end

-- ---------- HTTP response builder ----------

local STATUS_TEXT = {
  [200] = "OK",
  [400] = "Bad Request",
  [401] = "Unauthorized",
  [404] = "Not Found",
  [413] = "Payload Too Large",
  [500] = "Internal Server Error",
}

function M.make_response(status, body, content_type)
  body = body or ""
  content_type = content_type or "text/plain"
  local status_text = STATUS_TEXT[status] or "OK"
  return string.format(
    "HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s",
    status, status_text, content_type, #body, body
  )
end

-- ---------- Route matcher ----------

-- Extract provider id from /api/hooks/<providerId>. Returns nil if path does
-- not match or the id contains unsafe characters.
local HOOK_PREFIX = "/api/hooks/"

function M.parse_hook_path(path)
  if type(path) ~= "string" then return nil end
  if path:sub(1, #HOOK_PREFIX) ~= HOOK_PREFIX then return nil end
  local id = path:sub(#HOOK_PREFIX + 1)
  if id == "" then return nil end
  if id:match("^[a-z0-9%-]+$") then return id end
  return nil
end

M.HOOK_PREFIX = HOOK_PREFIX

-- ---------- Server-side request handling (pure) ----------

-- Given parsed request + server token, decide the response.
-- Returns { status, body, providerId?, event? }.
-- `event` is only set when the request should be forwarded to the main
-- thread (valid POST /api/hooks/<id> with auth + JSON with session_id +
-- hook_event_name).
function M.handle(req, token, json_decode, max_body)
  max_body = max_body or 65536

  if not req then
    return { status = 400, body = "bad request" }
  end

  if req.method == "GET" and req.path == "/api/health" then
    return { status = 200, body = '{"status":"ok"}' }
  end

  if req.method ~= "POST" then
    return { status = 404, body = "not found" }
  end

  if #req.body > max_body then
    return { status = 413, body = "payload too large" }
  end

  if not M.auth_ok(req.headers, token) then
    return { status = 401, body = "unauthorized" }
  end

  local provider_id = M.parse_hook_path(req.path)
  if not provider_id then
    return { status = 400, body = "invalid provider id" }
  end

  local ok, event = pcall(json_decode, req.body)
  if not ok or type(event) ~= "table" then
    return { status = 400, body = "invalid json" }
  end
  if type(event.session_id) ~= "string" or type(event.hook_event_name) ~= "string" then
    return { status = 400, body = "missing required fields" }
  end

  return {
    status = 200,
    body = "ok",
    providerId = provider_id,
    event = event,
  }
end

return M
