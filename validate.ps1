param(
    [string]$TargetDir = (Split-Path -Parent $MyInvocation.MyCommand.Path)
)

$ErrorActionPreference = "Stop"
$exitCode = 0

function Write-Pass { Write-Host "  [PASS] $($args[0])" -ForegroundColor Green }
function Write-Fail { Write-Host "  [FAIL] $($args[0])" -ForegroundColor Red; $script:exitCode = 1 }
function Write-Warn { Write-Host "  [WARN] $($args[0])" -ForegroundColor Yellow }

Write-Host "Validating skill structure: $TargetDir" -ForegroundColor Cyan
Write-Host ""

# ---- 1. Required Directories ----
Write-Host "=== 1. Required Directories ===" -ForegroundColor Cyan
$requiredDirs = @("agents", "assets\templates", "references")
$dirError = $false
foreach ($dir in $requiredDirs) {
    $path = Join-Path -Path $TargetDir -ChildPath $dir
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Fail "Missing directory: $dir"
        $dirError = $true
    } else {
        Write-Pass "Directory exists: $dir"
    }
}
if ($dirError) { exit 1 }
Write-Host ""

# ---- 2. Required Files ----
Write-Host "=== 2. Required Files ===" -ForegroundColor Cyan
$files = @(
    "SKILL.md",
    "agents\claude.yaml",
    "agents\openai.yaml",
    "agents\deepseek.yaml",
    "references\01-scene-atmosphere.md",
    "references\02-action-description.md",
    "references\03-detail-description.md",
    "references\04-emotion-expression.md",
    "references\05-sentence-dialogue.md",
    "references\06-character-creation.md",
    "references\07-plot-pacing.md",
    "references\08-immersion.md",
    "references\09-battle-scenes.md",
    "references\10-psychological-description.md",
    "references\11-story-architecture.md",
    "references\12-hooks-opening.md"
)
$fileError = $false
foreach ($f in $files) {
    $path = Join-Path -Path $TargetDir -ChildPath $f
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Fail ("Missing file: " + $f)
        $fileError = $true
    } else {
        Write-Pass ("File exists: " + $f)
    }
}
if ($fileError) { exit 1 }
Write-Host ""

# Read SKILL.md with explicit UTF-8
$utf8 = [System.Text.UTF8Encoding]::new($false)
$skillMd = Join-Path -Path $TargetDir -ChildPath "SKILL.md"
$skillBytes = [System.IO.File]::ReadAllBytes($skillMd)
$skillContent = $utf8.GetString($skillBytes)

# ---- 3. SKILL.md Frontmatter ----
Write-Host "=== 3. SKILL.md Frontmatter ===" -ForegroundColor Cyan
$fmMatch = [regex]::Match($skillContent, '^---\s*\n(.*?)\n---', 'Singleline')
if ($fmMatch.Success) {
    $fm = $fmMatch.Groups[1].Value
    Write-Pass "Frontmatter delimiters found"
    if ($fm -match 'name:\s*\S') { Write-Pass "Field: name" } else { Write-Fail "Missing: name" }
    if ($fm -match 'description:\s*\S') { Write-Pass "Field: description" } else { Write-Fail "Missing: description" }
} else {
    Write-Fail "SKILL.md missing valid frontmatter"
}
Write-Host ""

# ---- 4. Reference Consistency ----
Write-Host "=== 4. Reference Consistency ===" -ForegroundColor Cyan
$actualRefs = @(Get-ChildItem -LiteralPath (Join-Path $TargetDir "references") -Filter "*.md" | % { $_.Name })

$mentioned = @{}
[regex]::Matches($skillContent, 'references/[\w-]+\.md') | % {
    $mentioned[($_.Value -replace '^references/','')] = $true
}

$mentioned.Keys | % {
    if ($_ -in $actualRefs) { Write-Pass ("Ref found: " + $_) } else { Write-Fail ("Ref NOT FOUND: " + $_) }
}
$actualRefs | ? { $_ -notin $mentioned.Keys } | % { Write-Warn ("Unreferenced file: " + $_) }
Write-Host ""

# ---- 5. Agent YAML Validation ----
Write-Host "=== 5. Agent YAML Validation ===" -ForegroundColor Cyan
$yamlFiles = @(
    (Join-Path $TargetDir "agents\claude.yaml"),
    (Join-Path $TargetDir "agents\openai.yaml"),
    (Join-Path $TargetDir "agents\deepseek.yaml")
)
$yamlFields = @('display_name','short_description','activation_keywords','capabilities','default_prompt')

foreach ($yp in $yamlFiles) {
    $yn = Split-Path -Leaf $yp
    Write-Host ("  [" + $yn + "]") -ForegroundColor White
    $yc = Get-Content -LiteralPath $yp -Raw
    foreach ($f in $yamlFields) {
        if ($yc -match ($f + ':\s*\S')) { Write-Pass ($yn + " field: " + $f) } else { Write-Fail ($yn + " MISSING: " + $f) }
    }
    if ($yc -match '#\{') { Write-Warn ($yn + " has placeholders") }
}
Write-Host ""

# ---- 6. Workflow-Reference Mapping (dynamic from SKILL.md) ----
Write-Host "=== 6. Workflow-Reference Mapping (dynamic) ===" -ForegroundColor Cyan
$wfHeaders = @(
    @("#### 工作流1：同步写作（从零新建）", "#### 工作流2：多维润色（综合改稿）"),
    @("#### 工作流2：多维润色（综合改稿）", "#### 工作流3：定向优化（专项强化）"),
    @("#### 工作流3：定向优化（专项强化）", "#### 工作流4：卡文诊断（方向破局）"),
    @("#### 工作流4：卡文诊断（方向破局）", $null)
)
$wfMap = @{}
for ($i = 0; $i -lt $wfHeaders.Length; $i++) {
    $startTag = $wfHeaders[$i][0]
    $endTag = $wfHeaders[$i][1]
    $wfId = $i + 1
    $startIdx = $skillContent.IndexOf($startTag)
    if ($startIdx -eq -1) { Write-Warn ("Workflow " + $wfId + " header not found in SKILL.md"); continue }
    $endIdx = if ($endTag) { $skillContent.IndexOf($endTag, $startIdx + 1) } else { -1 }
    if ($endIdx -eq -1) { $endIdx = $skillContent.Length }
    $section = $skillContent.Substring($startIdx, $endIdx - $startIdx)
    $refs = @()
    $refMatches = [regex]::Matches($section, '【加载参考:\s*references/(\d+)-[\w-]+\.md】')
    foreach ($m in $refMatches) { $num = $m.Groups[1].Value; if ($num -notin $refs) { $refs += $num } }
    $refMatches = [regex]::Matches($section, '附带参考.*?references/(\d+)-[\w-]+\.md')
    foreach ($m in $refMatches) { $num = $m.Groups[1].Value; if ($num -notin $refs) { $refs += $num } }
    $refMatches = [regex]::Matches($section, '(?:和|及|与)\s*references/(\d+)-[\w-]+\.md')
    foreach ($m in $refMatches) { $num = $m.Groups[1].Value; if ($num -notin $refs) { $refs += $num } }
    $refs = $refs | Sort-Object
    $wfMap[$wfId] = $refs
    Write-Host ("  Workflow " + $wfId + " references " + ($refs -join ', ')) -ForegroundColor Gray
}
$refDir = Join-Path $TargetDir "references"
$wfMap.Keys | % {
    $wf = $_
    $ok = $true
    $wfMap[$wf] | % {
        $found = (Get-ChildItem $refDir -Filter ($_ + "-*.md")).Count -gt 0
        if (-not $found) { Write-Fail ("Workflow " + $wf + " ref #" + $_ + " missing"); $ok = $false }
    }
    if ($ok) { Write-Pass ("Workflow " + $wf + " refs OK") }
}
Write-Host ""

# ---- 7. Checklist Sections ----
Write-Host "=== 7. Checklist Sections ===" -ForegroundColor Cyan
$checklistNames = @("场景画面","情绪表达","动作对白","人物塑造","代入感","节奏与段落")
$checklistRefPairs = @(
    @("01-scene-atmosphere.md", "场景画面"),
    @("04-emotion-expression.md", "情绪表达"),
    @("02-action-description.md", "动作对白"),
    @("05-sentence-dialogue.md", "动作对白"),
    @("06-character-creation.md", "人物塑造"),
    @("03-detail-description.md", "人物塑造"),
    @("08-immersion.md", "代入感"),
    @("07-plot-pacing.md", "节奏段落"),
    @("05-sentence-dialogue.md", "节奏段落")
)

foreach ($cn in $checklistNames) {
    $pattern = $cn + "检查清单"
    if ($skillContent -match $pattern) { Write-Pass ("Checklist found: " + $cn) } else { Write-Fail ("Checklist MISSING: " + $cn) }
}
foreach ($pair in $checklistRefPairs) {
    $rp = Join-Path $TargetDir ("references\" + $pair[0])
    if (Test-Path $rp) { Write-Pass ($pair[1] + " -> " + $pair[0]) } else { Write-Fail ($pair[1] + " -> " + $pair[0] + " NOT FOUND") }
}
Write-Host ""

# ---- 8. Workflow Steps ----
Write-Host "=== 8. Workflow Steps ===" -ForegroundColor Cyan
$wfSteps = @(
    @("1", @("定叙事基调","同步写作","自检复核")),
    @("2", @("原文定位","多维同步扫描","同步修改","复核")),
    @("3", @("定位薄弱维度","加载参考","专项优化")),
    @("4", @("卡点定位","生成方向","选择执行"))
)
foreach ($wf in $wfSteps) {
    $name = "Workflow " + $wf[0]
    $allOk = $true
    foreach ($step in $wf[1]) {
        if ($skillContent -match $step) { Write-Pass ($name + " step: " + $step) } else { Write-Warn ($name + " MISSING: " + $step); $allOk = $false }
    }
    if ($allOk) { Write-Pass ($name + ": all steps OK") }
}
Write-Host ""

# ---- 9. Verify Multi-Dimension Workflow Design ----
Write-Host "=== 9. Multi-Dimension Workflow Design ===" -ForegroundColor Cyan

# Check that workflow 1 has synchronous multi-dimension writing step
if ($skillContent -match "同步写作") {
    Write-Pass "Workflow 1 has synchronous multi-dimension writing step"
} else {
    Write-Fail "Workflow 1 missing synchronous multi-dimension writing step"
}

# Check that workflow 2 has multi-dimension synchronous scan
if ($skillContent -match "多维同步扫描") {
    Write-Pass "Workflow 2 has multi-dimension synchronous scan"
} else {
    Write-Fail "Workflow 2 missing multi-dimension synchronous scan"
}
Write-Host ""

# ---- 10. MCP Server Integrity ----
Write-Host "=== 10. MCP Server Integrity ===" -ForegroundColor Cyan
$mcpDir = Join-Path $TargetDir "mcp-server"
if (-not (Test-Path $mcpDir)) {
    Write-Warn "mcp-server directory not found — skipping MCP checks"
} else {
    $mcpItems = @(
        @("package.json", "Package manifest"),
        @("index.js", "Server entry point"),
        @("start-mcp.cmd", "Startup script"),
        @("ref-index.json", "Pre-built index")
    )
    foreach ($item in $mcpItems) {
        $path = Join-Path $mcpDir $item[0]
        $label = $item[1]
        if (Test-Path -LiteralPath $path) {
            Write-Pass ("MCP " + $label + " (" + $item[0] + ")")
        } else {
            Write-Fail ("MCP " + $label + " (" + $item[0] + ") — missing")
        }
    }
    $nmPath = Join-Path $mcpDir "node_modules"
    if (Test-Path -LiteralPath $nmPath -PathType Container) {
        Write-Pass ("MCP Dependencies installed (node_modules/)")
    } else {
        Write-Fail ("MCP Dependencies NOT installed (node_modules/) — run 'npm install' in mcp-server/")
    }
}
Write-Host ""

# ---- 11. Index Heading Coverage ----
Write-Host "=== 11. Index Heading Coverage ===" -ForegroundColor Cyan
$mcpDirCheck = Join-Path $TargetDir "mcp-server"
if (-not (Test-Path (Join-Path $mcpDirCheck "build-index.js"))) {
    Write-Warn "build-index.js not found — skipping heading coverage check"
} else {
    $buildOutput = & "node" (Join-Path $mcpDirCheck "build-index.js") 2>&1
    $warnings = $buildOutput | Where-Object { $_ -match '\[WARN\]' }
    $hasError = $buildOutput | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
    if ($hasError) {
        Write-Fail "Index build failed — check Node.js installation"
    } elseif ($warnings.Count -gt 0) {
        foreach ($w in $warnings) { Write-Fail $w }
        Write-Fail "$($warnings.Count) unmapped ## heading(s) found — update SECTION_MAP in build-index.js"
    } else {
        Write-Pass "All ## headings in references/ are mapped in SECTION_MAP"
    }
}
Write-Host ""

# ---- Summary ----
Write-Host "=== Summary ===" -ForegroundColor Cyan
if ($exitCode -eq 0) { Write-Host "  All validations passed." -ForegroundColor Green } else { Write-Host ("  Failures: " + $exitCode) -ForegroundColor Red }
Write-Host ""
exit $exitCode