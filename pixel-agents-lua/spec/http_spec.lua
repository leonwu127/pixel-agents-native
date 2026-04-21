package.path = "./?.lua;./?/init.lua;" .. package.path
local helper = require("spec.helper")
local http = require("src.systems.http")
local json = require("src.vendor.json")

local function req(method, path, headers, body)
  headers = headers or {}
  body = body or ""
  local lines = { string.format("%s %s HTTP/1.1", method, path) }
  local has_cl = false
  for k, v in pairs(headers) do
    if k:lower() == "content-length" then has_cl = true end
    lines[#lines + 1] = string.format("%s: %s", k, v)
  end
  if not has_cl then
    lines[#lines + 1] = string.format("Content-Length: %d", #body)
  end
  return table.concat(lines, "\r\n") .. "\r\n\r\n" .. body
end

describe("http.json_encode", function()
  it("encodes primitives", function()
    assert.are.equal("null", http.json_encode(nil))
    assert.are.equal("true", http.json_encode(true))
    assert.are.equal("false", http.json_encode(false))
    assert.are.equal("42", http.json_encode(42))
    assert.are.equal('"hi"', http.json_encode("hi"))
  end)

  it("escapes strings", function()
    assert.are.equal('"a\\nb"', http.json_encode("a\nb"))
    assert.are.equal('"a\\\\b"', http.json_encode("a\\b"))
    assert.are.equal('"a\\"b"', http.json_encode('a"b'))
  end)

  it("encodes arrays in order", function()
    assert.are.equal("[1,2,3]", http.json_encode({ 1, 2, 3 }))
  end)

  it("encodes objects with sorted keys (deterministic)", function()
    assert.are.equal('{"a":1,"b":2}', http.json_encode({ b = 2, a = 1 }))
  end)

  it("roundtrips through vendor json decoder", function()
    local original = { port = 54321, pid = 9999, token = "abc-def", startedAt = 1700000000 }
    local encoded = http.json_encode(original)
    local decoded = json.decode(encoded)
    assert.are.same(original, decoded)
  end)
end)

describe("http.parse_request", function()
  it("parses simple GET", function()
    local r = http.parse_request(req("GET", "/api/health"))
    assert.are.equal("GET", r.method)
    assert.are.equal("/api/health", r.path)
    assert.are.equal("HTTP/1.1", r.version)
    assert.is_true(r.complete)
  end)

  it("parses POST with body and headers", function()
    local r = http.parse_request(req("POST", "/api/hooks/claude",
      { ["Content-Type"] = "application/json", Authorization = "Bearer xyz" },
      '{"a":1}'))
    assert.are.equal("POST", r.method)
    assert.are.equal("/api/hooks/claude", r.path)
    assert.are.equal("application/json", r.headers["content-type"])
    assert.are.equal("Bearer xyz", r.headers["authorization"])
    assert.are.equal('{"a":1}', r.body)
    assert.is_true(r.complete)
  end)

  it("returns nil on malformed request line", function()
    local r, err = http.parse_request("garbage\r\n\r\n")
    assert.is_nil(r)
    assert.is_truthy(err)
  end)

  it("reports incomplete when body shorter than Content-Length", function()
    local raw = "POST /api/hooks/claude HTTP/1.1\r\nContent-Length: 10\r\n\r\nshort"
    local r = http.parse_request(raw)
    assert.is_not_nil(r)
    assert.is_false(r.complete)
  end)
end)

describe("http.auth_ok", function()
  it("accepts matching bearer token", function()
    assert.is_true(http.auth_ok({ authorization = "Bearer abc123" }, "abc123"))
  end)

  it("rejects missing header", function()
    assert.is_false(http.auth_ok({}, "abc123"))
  end)

  it("rejects wrong token", function()
    assert.is_false(http.auth_ok({ authorization = "Bearer wrong" }, "abc123"))
  end)

  it("rejects wrong scheme", function()
    assert.is_false(http.auth_ok({ authorization = "Basic abc123" }, "abc123"))
  end)
end)

describe("http.parse_hook_path", function()
  it("extracts provider id", function()
    assert.are.equal("claude", http.parse_hook_path("/api/hooks/claude"))
  end)

  it("rejects invalid chars", function()
    assert.is_nil(http.parse_hook_path("/api/hooks/claude/extra"))
    assert.is_nil(http.parse_hook_path("/api/hooks/Claude"))
    assert.is_nil(http.parse_hook_path("/api/hooks/"))
    assert.is_nil(http.parse_hook_path("/other/claude"))
  end)
end)

describe("http.make_response", function()
  it("builds 200 with body", function()
    local r = http.make_response(200, "ok")
    assert.is_truthy(r:find("HTTP/1%.1 200 OK"))
    assert.is_truthy(r:find("Content%-Length: 2"))
    assert.is_truthy(r:find("\r\n\r\nok$"))
  end)

  it("builds 401", function()
    local r = http.make_response(401, "nope")
    assert.is_truthy(r:find("HTTP/1%.1 401 Unauthorized"))
  end)
end)

describe("http.handle", function()
  local token = "secret-token"
  local valid_body = '{"session_id":"s1","hook_event_name":"Stop"}'

  it("GET /api/health returns 200", function()
    local r = http.parse_request(req("GET", "/api/health"))
    local resp = http.handle(r, token, json.decode)
    assert.are.equal(200, resp.status)
  end)

  it("POST hook with valid auth returns 200 and forwards event", function()
    local r = http.parse_request(req("POST", "/api/hooks/claude",
      { Authorization = "Bearer " .. token }, valid_body))
    local resp = http.handle(r, token, json.decode)
    assert.are.equal(200, resp.status)
    assert.are.equal("claude", resp.providerId)
    assert.are.equal("s1", resp.event.session_id)
    assert.are.equal("Stop", resp.event.hook_event_name)
  end)

  it("POST hook without auth returns 401", function()
    local r = http.parse_request(req("POST", "/api/hooks/claude",
      {}, valid_body))
    local resp = http.handle(r, token, json.decode)
    assert.are.equal(401, resp.status)
  end)

  it("POST hook with wrong auth returns 401", function()
    local r = http.parse_request(req("POST", "/api/hooks/claude",
      { Authorization = "Bearer wrong" }, valid_body))
    local resp = http.handle(r, token, json.decode)
    assert.are.equal(401, resp.status)
  end)

  it("POST with invalid provider id returns 400", function()
    local r = http.parse_request(req("POST", "/api/hooks/BAD_ID",
      { Authorization = "Bearer " .. token }, valid_body))
    local resp = http.handle(r, token, json.decode)
    assert.are.equal(400, resp.status)
  end)

  it("POST with malformed JSON returns 400", function()
    local r = http.parse_request(req("POST", "/api/hooks/claude",
      { Authorization = "Bearer " .. token }, "not json"))
    local resp = http.handle(r, token, json.decode)
    assert.are.equal(400, resp.status)
  end)

  it("POST without session_id returns 400", function()
    local r = http.parse_request(req("POST", "/api/hooks/claude",
      { Authorization = "Bearer " .. token }, '{"hook_event_name":"Stop"}'))
    local resp = http.handle(r, token, json.decode)
    assert.are.equal(400, resp.status)
  end)

  it("oversized body returns 413", function()
    local big = string.rep("x", 100)
    local r = http.parse_request(req("POST", "/api/hooks/claude",
      { Authorization = "Bearer " .. token }, big))
    local resp = http.handle(r, token, json.decode, 50)
    assert.are.equal(413, resp.status)
  end)

  it("non-POST non-health returns 404", function()
    local r = http.parse_request(req("DELETE", "/api/hooks/claude"))
    local resp = http.handle(r, token, json.decode)
    assert.are.equal(404, resp.status)
  end)
end)

helper.run()
