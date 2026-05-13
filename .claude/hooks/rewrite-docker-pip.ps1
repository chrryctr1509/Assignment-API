# rewrite-docker-pip.ps1 (Brief 28) — mirror of .sh

$ErrorActionPreference = "Stop"
$inputJson = [Console]::In.ReadToEnd()

try { $hookInput = $inputJson | ConvertFrom-Json } catch { Write-Output $inputJson; exit 0 }

$cmd = $hookInput.tool_input.command
if (-not $cmd) { Write-Output $inputJson; exit 0 }

if ($cmd -match '^\s*docker\s+(exec|compose)') { Write-Output $inputJson; exit 0 }
if ($cmd -notmatch '(^|[;&|]\s*)\s*(pip|pip3)\s+') { Write-Output $inputJson; exit 0 }

$projectRoot = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }

$pipelineState = Join-Path $projectRoot "docs/pipeline-state.md"
if (Test-Path $pipelineState) {
    $stateContent = Get-Content $pipelineState -Raw -ErrorAction SilentlyContinue
    if ($stateContent -match '(?im)^\s*-?\s*project_mode\s*:\s*host\b') {
        [Console]::Error.WriteLine("[rewrite-docker-pip] SKIP: project_mode=host")
        Write-Output $inputJson; exit 0
    }
}

$dockerAssess = Join-Path $projectRoot "docs/docker-assessment.md"
if (Test-Path $dockerAssess) {
    $content = Get-Content $dockerAssess -Raw
    if ($content -match '(?ms)^## *Host Services(.*?)(?=^## |\z)') {
        if ($Matches[1] -match '(?i)\b(python|pip|django|flask)\b') {
            [Console]::Error.WriteLine("[rewrite-docker-pip] SKIP: python/pip in Host Services")
            Write-Output $inputJson; exit 0
        }
    }
}

$composeFile = $null
foreach ($f in @("docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml")) {
    $path = Join-Path $projectRoot $f
    if (Test-Path $path) { $composeFile = $path; break }
}
if (-not $composeFile) {
    [Console]::Error.WriteLine("[rewrite-docker-pip] SKIP: no docker-compose.yml")
    Write-Output $inputJson; exit 0
}

# Service regex priority: Python-specific names first, 'api' as last fallback.
# Brief 28.a removed 'app|backend' to avoid overlap with PHP ecosystem.
# Edge case (Python service named 'app'): override via docker-assessment.md Host Services.
$container = $null
$composeContent = Get-Content $composeFile -Raw
if ($composeContent -match 'services:\s*\n((?:  \w[\w-]*:[\s\S]*?)(?=\n[^\s]|\z))') {
    $serviceMatch = [regex]::Match($Matches[1], '(?m)^  (python|django|flask|worker|api):', 'IgnoreCase')
    if ($serviceMatch.Success) { $container = $serviceMatch.Groups[1].Value }
}
if (-not $container) {
    [Console]::Error.WriteLine("[rewrite-docker-pip] SKIP: no python-related service (python|django|flask|worker|api)")
    Write-Output $inputJson; exit 0
}

$newCmd = $cmd -replace '(^|[;&|]\s*)\s*(pip|pip3)\s+', "`$1docker exec -it $container `$2 "
[Console]::Error.WriteLine("[rewrite-docker-pip] $cmd -> $newCmd")

$hookInput.tool_input.command = $newCmd
$hookInput | ConvertTo-Json -Depth 10 -Compress
exit 0
