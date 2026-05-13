# rewrite-docker-composer.ps1 (Brief 28) — mirror of .sh

$ErrorActionPreference = "Stop"
$inputJson = [Console]::In.ReadToEnd()

try { $hookInput = $inputJson | ConvertFrom-Json } catch { Write-Output $inputJson; exit 0 }

$cmd = $hookInput.tool_input.command
if (-not $cmd) { Write-Output $inputJson; exit 0 }

if ($cmd -match '^\s*docker\s+(exec|compose)') { Write-Output $inputJson; exit 0 }
if ($cmd -notmatch '(^|[;&|]\s*)\s*composer\s+') { Write-Output $inputJson; exit 0 }

$projectRoot = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }

$pipelineState = Join-Path $projectRoot "docs/pipeline-state.md"
if (Test-Path $pipelineState) {
    $stateContent = Get-Content $pipelineState -Raw -ErrorAction SilentlyContinue
    if ($stateContent -match '(?im)^\s*-?\s*project_mode\s*:\s*host\b') {
        [Console]::Error.WriteLine("[rewrite-docker-composer] SKIP: project_mode=host")
        Write-Output $inputJson; exit 0
    }
}

$dockerAssess = Join-Path $projectRoot "docs/docker-assessment.md"
if (Test-Path $dockerAssess) {
    $content = Get-Content $dockerAssess -Raw
    if ($content -match '(?ms)^## *Host Services(.*?)(?=^## |\z)') {
        if ($Matches[1] -match '(?i)\b(php|composer|laravel)\b') {
            [Console]::Error.WriteLine("[rewrite-docker-composer] SKIP: php/composer in Host Services")
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
    [Console]::Error.WriteLine("[rewrite-docker-composer] SKIP: no docker-compose.yml")
    Write-Output $inputJson; exit 0
}

# Service regex priority: PHP-specific names first, generic 'app|backend' as fallback.
# Brief 28.a removed 'api' (typically Python) and reordered for correctness.
$container = $null
$composeContent = Get-Content $composeFile -Raw
if ($composeContent -match 'services:\s*\n((?:  \w[\w-]*:[\s\S]*?)(?=\n[^\s]|\z))') {
    $serviceMatch = [regex]::Match($Matches[1], '(?m)^  (laravel|php|app|backend):', 'IgnoreCase')
    if ($serviceMatch.Success) { $container = $serviceMatch.Groups[1].Value }
}
if (-not $container) {
    [Console]::Error.WriteLine("[rewrite-docker-composer] SKIP: no php-related service (laravel|php|app|backend)")
    Write-Output $inputJson; exit 0
}

$newCmd = $cmd -replace '(^|[;&|]\s*)\s*composer\s+', "`$1docker exec -it $container composer "
[Console]::Error.WriteLine("[rewrite-docker-composer] $cmd -> $newCmd")

$hookInput.tool_input.command = $newCmd
$hookInput | ConvertTo-Json -Depth 10 -Compress
exit 0
