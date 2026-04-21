# Pixel Agents Lua — Claude Code hook script.
# Invoked by Claude Code per hook event (SessionStart/Stop/PreToolUse/...).
# Reads the hook event JSON from stdin, looks up our local HTTP server via
# ~/.pixel-agents-lua/server.json, and POSTs the event to it.
#
# Exits 0 on every code path so a failure here never blocks Claude.

$ErrorActionPreference = 'SilentlyContinue'

try {
    $body = [Console]::In.ReadToEnd()
    if (-not $body) { exit 0 }

    $serverJson = Join-Path $env:USERPROFILE '.pixel-agents-lua\server.json'
    if (-not (Test-Path -LiteralPath $serverJson)) { exit 0 }

    $server = Get-Content -LiteralPath $serverJson -Raw | ConvertFrom-Json
    if (-not $server.port -or -not $server.token) { exit 0 }

    $uri = "http://127.0.0.1:$($server.port)/api/hooks/claude"
    $headers = @{ Authorization = "Bearer $($server.token)" }

    Invoke-RestMethod -Uri $uri -Method Post `
        -Body $body -ContentType 'application/json' `
        -Headers $headers -TimeoutSec 2 | Out-Null
} catch {
    # Swallow; the hook must never surface errors to Claude.
}
exit 0
