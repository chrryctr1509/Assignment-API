# rewrite-docker-artisan.ps1 (Brief 27 + 27.b)
# PreToolUse hook: environment-aware rewrite — mirror of rewrite-docker-artisan.sh
#
# 4-tier detection: pipeline-state mode → docker-assessment → docker-compose → service name
#
# Requires: Claude Code v2.0.10+, PowerShell 5.1+
# Invoked by: .claude/hooks/dispatcher.ts

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

# Skip already-docker
if ($cmd -match '^\s*docker\s+(exec|compose)') {
    Write-Output $inputJson
    exit 0
}

# Only act on php artisan
if ($cmd -notmatch '(^|[;&|]\s*)\s*php\s+artisan\b') {
    Write-Output $inputJson
    exit 0
}

$projectRoot = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }

# === TIER 0: pipeline-state.md project_mode ===
$pipelineState = Join-Path $projectRoot "docs/pipeline-state.md"
if (Test-Path $pipelineState) {
    $stateContent = Get-Content $pipelineState -Raw -ErrorAction SilentlyContinue
    if ($stateContent -match '(?im)^\s*-?\s*project_mode\s*:\s*host\b') {
        [Console]::Error.WriteLine("[rewrite-docker-artisan] SKIP: project_mode=host in pipeline-state.md")
        Write-Output $inputJson
        exit 0
    }
}

# === TIER 1: docker-assessment.md Host Services ===
$dockerAssess = Join-Path $projectRoot "docs/docker-assessment.md"
if (Test-Path $dockerAssess) {
    $content = Get-Content $dockerAssess -Raw
    if ($content -match '(?ms)^## *Host Services(.*?)(?=^## |\z)') {
        $hostSection = $Matches[1]
        if ($hostSection -match '(?i)\b(php|artisan|laravel)\b') {
            [Console]::Error.WriteLine("[rewrite-docker-artisan] SKIP: php in Host Services (docker-assessment.md)")
            Write-Output $inputJson
            exit 0
        }
    }
}

# === TIER 2: docker-compose.yml presence ===
$composeFile = $null
foreach ($f in @("docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml")) {
    $path = Join-Path $projectRoot $f
    if (Test-Path $path) {
        $composeFile = $path
        break
    }
}

if (-not $composeFile) {
    [Console]::Error.WriteLine("[rewrite-docker-artisan] SKIP: no docker-compose.yml (bare host project)")
    Write-Output $inputJson
    exit 0
}

# === TIER 3: Matching service ===
$container = $null
$composeContent = Get-Content $composeFile -Raw
if ($composeContent -match 'services:\s*\n((?:  \w[\w-]*:[\s\S]*?)(?=\n[^\s]|\z))') {
    $servicesBlock = $Matches[1]
    $serviceMatch = [regex]::Match($servicesBlock, '(?m)^  (app|laravel|backend|php|api):', 'IgnoreCase')
    if ($serviceMatch.Success) {
        $container = $serviceMatch.Groups[1].Value
    }
}

if (-not $container) {
    [Console]::Error.WriteLine("[rewrite-docker-artisan] SKIP: docker-compose.yml has no php-related service")
    Write-Output $inputJson
    exit 0
}

# === REWRITE ===
$newCmd = $cmd -replace '(^|[;&|]\s*)\s*(php\s+artisan)\b', "`$1docker exec -it $container `$2"
[Console]::Error.WriteLine("[rewrite-docker-artisan] $cmd -> $newCmd")

$hookInput.tool_input.command = $newCmd
$hookInput | ConvertTo-Json -Depth 10 -Compress
exit 0
