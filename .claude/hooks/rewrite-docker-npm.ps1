# rewrite-docker-npm.ps1 (Brief 28)
# PreToolUse hook: environment-aware rewrite for npm/npx commands
# Mirror of rewrite-docker-npm.sh
#
# Requires: Claude Code v2.0.10+, PowerShell 5.1+

$ErrorActionPreference = "Stop"

$inputJson = [Console]::In.ReadToEnd()

try {
    $hookInput = $inputJson | ConvertFrom-Json
} catch {
    Write-Output $inputJson
    exit 0
}

$cmd = $hookInput.tool_input.command
if (-not $cmd) {
    Write-Output $inputJson
    exit 0
}

if ($cmd -match '^\s*docker\s+(exec|compose)') {
    Write-Output $inputJson
    exit 0
}

if ($cmd -notmatch '(^|[;&|]\s*)\s*(npm|npx)\s+') {
    Write-Output $inputJson
    exit 0
}

# Skip MCP-related npx
if ($cmd -match 'npx\s+.*?(chrome-devtools-mcp|@playwright/mcp|@anthropic-ai)') {
    Write-Output $inputJson
    exit 0
}

$projectRoot = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }

# === TIER 0 ===
$pipelineState = Join-Path $projectRoot "docs/pipeline-state.md"
if (Test-Path $pipelineState) {
    $stateContent = Get-Content $pipelineState -Raw -ErrorAction SilentlyContinue
    if ($stateContent -match '(?im)^\s*-?\s*project_mode\s*:\s*host\b') {
        [Console]::Error.WriteLine("[rewrite-docker-npm] SKIP: project_mode=host in pipeline-state.md")
        Write-Output $inputJson
        exit 0
    }
}

# === TIER 1 ===
$dockerAssess = Join-Path $projectRoot "docs/docker-assessment.md"
if (Test-Path $dockerAssess) {
    $content = Get-Content $dockerAssess -Raw
    if ($content -match '(?ms)^## *Host Services(.*?)(?=^## |\z)') {
        $hostSection = $Matches[1]
        if ($hostSection -match '(?i)\b(node|npm|npx|frontend|yarn)\b') {
            [Console]::Error.WriteLine("[rewrite-docker-npm] SKIP: node/npm in Host Services")
            Write-Output $inputJson
            exit 0
        }
    }
}

# === TIER 2 ===
$composeFile = $null
foreach ($f in @("docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml")) {
    $path = Join-Path $projectRoot $f
    if (Test-Path $path) {
        $composeFile = $path
        break
    }
}

if (-not $composeFile) {
    [Console]::Error.WriteLine("[rewrite-docker-npm] SKIP: no docker-compose.yml (bare host project)")
    Write-Output $inputJson
    exit 0
}

# === TIER 3 ===
$container = $null
$composeContent = Get-Content $composeFile -Raw
if ($composeContent -match 'services:\s*\n((?:  \w[\w-]*:[\s\S]*?)(?=\n[^\s]|\z))') {
    $servicesBlock = $Matches[1]
    $serviceMatch = [regex]::Match($servicesBlock, '(?m)^  (frontend|web|node|ui|client):', 'IgnoreCase')
    if ($serviceMatch.Success) {
        $container = $serviceMatch.Groups[1].Value
    }
}

if (-not $container) {
    [Console]::Error.WriteLine("[rewrite-docker-npm] SKIP: no frontend-related service in docker-compose.yml")
    Write-Output $inputJson
    exit 0
}

# === REWRITE ===
$newCmd = $cmd -replace '(^|[;&|]\s*)\s*(npm|npx)\s+', "`$1docker exec -it $container `$2 "
[Console]::Error.WriteLine("[rewrite-docker-npm] $cmd -> $newCmd")

$hookInput.tool_input.command = $newCmd
$hookInput | ConvertTo-Json -Depth 10 -Compress
exit 0
