# orchestrator-guard.ps1 — Orchestrator write WHITELIST
# PowerShell mirror of orchestrator-guard.sh
# Rule: orchestrator can only WRITE to *.md files and allowed paths.
# Scope: PreToolUse Write|Edit only (NOT Bash — to avoid blocking git-manager)

$Input = $args[0]
if (-not $Input) {
    try { $Input = [Console]::In.ReadToEnd() } catch { $Input = "" }
}

try {
    $Data = $Input | ConvertFrom-Json -ErrorAction Stop
    $FilePath = if ($Data.tool_input.file_path) { $Data.tool_input.file_path } elseif ($Data.tool_input.path) { $Data.tool_input.path } else { "" }
} catch {
    $FilePath = ""
}

# Jika tidak ada file path, allow
if (-not $FilePath) { exit 0 }

# ── Write/Edit Tool Guard (WHITELIST) ──────────────────────

# WHITELIST: allowed paths
if ($FilePath -match '\.md$') { exit 0 }
if ($FilePath -match '^docs/') { exit 0 }
if ($FilePath -match '^\.claude[\\/]memory[\\/]') { exit 0 }
if ($FilePath -match '^\.claude[\\/]hooks[\\/]hook-log') { exit 0 }
if ($FilePath -match '\.template$') { exit 0 }

# BLOCK everything else
Write-Host "==============================================================" -ForegroundColor Red
Write-Host "BLOCKED: Orchestrator hanya boleh Write/Edit file *.md dan docs/" -ForegroundColor Red
Write-Host "File: $FilePath" -ForegroundColor Red
Write-Host ""
Write-Host "Kamu adalah CONDUCTOR, bukan PLAYER." -ForegroundColor Yellow
Write-Host "  Application code → be-developer / fe-developer"
Write-Host "  Git operations → git-manager"
Write-Host "  Docker/infra → env-configurator / docker-manager"
Write-Host "==============================================================" -ForegroundColor Red
exit 2
