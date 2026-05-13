# token-tracker.ps1 — Stop hook
# Finalizes token usage report from orchestrator-tracked data.
# Orchestrator writes per-agent rows during pipeline; this hook closes the report.
# Always exit 0 (non-blocking).
# PowerShell port of token-tracker.sh

$ErrorActionPreference = "SilentlyContinue"

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$LogFile     = Join-Path $ScriptDir "hook-log.txt"

$ReportDir     = Join-Path $ProjectRoot "docs\token-reports"
$CurrentReport = Join-Path $ReportDir "current-pipeline.md"

# Only finalize if orchestrator created a tracking file
if (-not (Test-Path $CurrentReport)) {
    exit 0
}

# Load .env for Telegram credentials
$EnvFile = Join-Path $ProjectRoot ".env"
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^([^#][^=]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim(), "Process")
        }
    }
}

$Token  = $env:TELEGRAM_BOT_TOKEN
$ChatId = $env:TELEGRAM_CHAT_ID

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$Readable  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Get current git branch
$Branch = "N/A"
try {
    Push-Location $ProjectRoot
    $Branch = (& git branch --show-current 2>$null)
    Pop-Location
} catch {
    Pop-Location -ErrorAction SilentlyContinue
}
if (-not $Branch) { $Branch = "N/A" }

# Calculate totals: sum all standalone integers in the report
$ReportContent = Get-Content $CurrentReport -Raw -ErrorAction SilentlyContinue
$TotalTokens = 0
if ($ReportContent) {
    $NumberMatches = [regex]::Matches($ReportContent, '\d+')
    foreach ($M in $NumberMatches) {
        $TotalTokens += [long]$M.Value
    }
}

# Append session totals footer to the current report
$Footer = @"

---
## Session Totals
- Finalized: $Readable
- Branch: $Branch
- Approximate total tokens: $TotalTokens (from agent spawns only)
"@
$Footer | Out-File -Append -FilePath $CurrentReport -Encoding UTF8

# Archive: copy current report to timestamped file
$Archive = Join-Path $ReportDir "pipeline-${Timestamp}.md"
Copy-Item $CurrentReport $Archive -ErrorAction SilentlyContinue

# Send summary to Telegram if configured
if ($Token -and $ChatId) {
    try {
        $AgentCount = (Get-Content $CurrentReport -ErrorAction SilentlyContinue |
            Where-Object { $_ -match '^\|' }).Count

        $Summary = "Token Report: ~${TotalTokens} tokens across ${AgentCount} agent spawns (${Branch})"
        $Body = @{
            chat_id                  = $ChatId
            text                     = $Summary
            disable_web_page_preview = $true
        }
        Invoke-RestMethod -Uri "https://api.telegram.org/bot$Token/sendMessage" `
            -Method Post -Body $Body -ErrorAction SilentlyContinue | Out-Null
    } catch {}
}

# Log completion
"[$Readable] TOKEN_REPORT: finalized $Archive" | Out-File -Append -FilePath $LogFile -Encoding UTF8

exit 0
