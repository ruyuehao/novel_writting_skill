#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Register novel-writing MCP server to opencode.json
.DESCRIPTION
    Auto-detect skill directory path, generate MCP server config and
    write to opencode.json via text insertion (preserves comments, key order, formatting).
.PARAMETER ConfigPath
    Specify opencode.json path. Auto-search up to 6 parent dirs when empty.
.PARAMETER PrintOnly
    Only print config JSON, do not write to file.
.EXAMPLE
    .\register-mcp.ps1
    .\register-mcp.ps1 -PrintOnly
    .\register-mcp.ps1 -ConfigPath "C:\project\opencode.json"
#>
param(
    [string]$ConfigPath = "",
    [switch]$PrintOnly
)

$ErrorActionPreference = "Stop"

# ---- 1. Resolve skill root ----
$skillDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$mcpDir = Join-Path $skillDir "mcp-server"
$indexJs = Join-Path $mcpDir "index.js"

if (-not (Test-Path $indexJs)) {
    Write-Error ("MCP entry not found: " + $indexJs)
    Write-Error "Make sure register-mcp.ps1 is in the novel-writing skill root."
    exit 1
}

$mcpEntry = Join-Path $mcpDir "start-mcp.cmd"
if (-not (Test-Path $mcpEntry)) {
    $mcpEntry = $indexJs
}

$mcpEntryPath = (Resolve-Path $mcpEntry).Path -replace '\\', '\\'
$serverName = "novel-writing"

# Generate server JSON text (no ConvertTo-Json, pure string construction)
$serverEntryJson = '    "' + $serverName + '": {
      "command": "cmd",
      "args": [
        "/c",
        "' + $mcpEntryPath + '"
      ]
    }'

if ($PrintOnly) {
    Write-Host ""
    Write-Host "Add this inside the `"mcpServers`" block of opencode.json:`n"
    Write-Host $serverEntryJson
    Write-Host ""
    exit 0
}

# ---- 2. Find opencode.json ----
if ($ConfigPath -eq "") {
    $searchDir = $skillDir
    for ($i = 0; $i -lt 6; $i++) {
        $candidate = Join-Path $searchDir "opencode.json"
        if (Test-Path $candidate) {
            $ConfigPath = $candidate
            break
        }
        $parent = Split-Path $searchDir -Parent
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $searchDir) { break }
        $searchDir = $parent
    }
}

if ($ConfigPath -eq "" -or -not (Test-Path $ConfigPath)) {
    Write-Warning "opencode.json not found (searched 6 parent levels)"
    Write-Host "Use -PrintOnly to see the config JSON."
    exit 1
}

# ---- 3. Insert MCP server entry via text manipulation ----
function Find-MatchingBrace {
    param([string]$text, [int]$startAt)
    $depth = 0
    for ($i = $startAt; $i -lt $text.Length; $i++) {
        $c = $text[$i]
        if ($c -eq '{') { $depth++ }
        elseif ($c -eq '}') {
            $depth--
            if ($depth -eq 0) { return $i }
        }
    }
    return -1
}

try {
    $rawJson = Get-Content $ConfigPath -Raw -Encoding UTF8

    $mcpPattern = '"mcpServers"\s*:'
    $mcpMatch = [regex]::Match($rawJson, $mcpPattern)

    if ($mcpMatch.Success) {
        # Find opening brace of mcpServers value
        $braceStart = $rawJson.IndexOf('{', $mcpMatch.Index + $mcpMatch.Length)
        if ($braceStart -eq -1) { throw "Cannot parse mcpServers structure" }

        $braceEnd = Find-MatchingBrace -text $rawJson -startAt $braceStart
        if ($braceEnd -eq -1) { throw "Cannot find mcpServers closing brace" }

        # Check if braces contain existing entries
        $inner = $rawJson.Substring($braceStart + 1, $braceEnd - $braceStart - 1).Trim()
        $hasEntries = $inner.Length -gt 0

        if ($hasEntries) {
        # Insert before closing brace, with leading comma+newline and trailing newline
        $prefix = ",`r`n" + $serverEntryJson + "`r`n"
        $newJson = $rawJson.Substring(0, $braceEnd) + $prefix + $rawJson.Substring($braceEnd)
        } else {
            # Empty object -- insert after opening brace
            $prefix = "`r`n" + $serverEntryJson + "`r`n  "
            $newJson = $rawJson.Substring(0, $braceStart + 1) + $prefix + $rawJson.Substring($braceStart + 1)
        }
    } else {
        # No mcpServers key -- insert before root closing brace
        $lastBrace = $rawJson.LastIndexOf('}')
        if ($lastBrace -eq -1) { throw "Cannot find JSON root object" }

        $beforeRoot = $rawJson.Substring(0, $lastBrace).TrimEnd()
        $afterRoot = $rawJson.Substring($lastBrace)

        # Check if root already has properties (needs comma)
        $rootBody = $beforeRoot.TrimEnd(' ', "`r", "`n").TrimEnd('{').Trim()
        $needsComma = $rootBody.Length -gt 0
        $comma = if ($needsComma) { "," } else { "" }

        $mcpBlock = $comma + "`r`n  `"mcpServers`": {`r`n" + $serverEntryJson + "`r`n  }"
        $newJson = $beforeRoot + $mcpBlock + "`r`n" + $afterRoot
    }

    # Validate result: check balanced braces and strip comments for JSON parser
    # (opencode.json may contain JSONC comments that ConvertFrom-Json cannot parse)
    $stripped = $newJson -replace '(?m)^\s*//.*$', ''
    $stripped = $stripped -replace '/\*.*?\*/', ''
    $null = $stripped | ConvertFrom-Json

    [System.IO.File]::WriteAllText($ConfigPath, $newJson, [System.Text.UTF8Encoding]::new($true))
    Write-Host ("MCP server registered to: " + $ConfigPath)
} catch {
    Write-Error ("Write failed: " + $_)
    exit 1
}
