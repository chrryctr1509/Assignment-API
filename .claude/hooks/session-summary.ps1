# session-summary.ps1 — Stop hook
# Reads hook-log.txt, compiles summary stats, sends to Telegram.
# Updates hook-analytics.md with session data.
# Always exit 0 (non-blocking).
# PowerShell port of session-summary.sh

$ErrorActionPreference = "SilentlyContinue"

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$LogFile     = Join-Path $ScriptDir "hook-log.txt"

if (-not (Test-Path $LogFile)) {
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

# Count event categories in the log
$LogLines = Get-Content $LogFile -ErrorAction SilentlyContinue

$Blocked       = ($LogLines | Select-String -Pattern 'BLOCKED'   -SimpleMatch).Count
$FormatFixes   = ($LogLines | Select-String -Pattern 'FORMAT'    -SimpleMatch).Count
$TestFails     = ($LogLines | Select-String -Pattern 'TEST FAIL' -SimpleMatch).Count
$Notifications = ($LogLines | Select-String -Pattern 'NOTIFY'    -SimpleMatch).Count

$ProjectName = Split-Path -Leaf $ProjectRoot

$Summary = @"
Session Summary [$ProjectName]:
- Blocked operations: $Blocked
- Format fixes: $FormatFixes
- Test failures: $TestFails
- Notifications: $Notifications
"@

# Send via Telegram if configured
if ($Token -and $ChatId) {
    try {
        $Body = @{
            chat_id                  = $ChatId
            text                     = $Summary
            disable_web_page_preview = $true
        }
        Invoke-RestMethod -Uri "https://api.telegram.org/bot$Token/sendMessage" `
            -Method Post -Body $Body -ErrorAction SilentlyContinue | Out-Null
    } catch {}
}

# Append SESSION_END to log
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"[$Timestamp] SESSION_END: $Summary" | Out-File -Append -FilePath $LogFile -Encoding UTF8

# Clean up temporary hook files older than 60 minutes from TEMP
$TempDir = $env:TEMP
if ($TempDir -and (Test-Path $TempDir)) {
    $Cutoff = (Get-Date).AddMinutes(-60)
    Get-ChildItem -Path $TempDir -Filter "claude-hook-*" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $Cutoff } |
        ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
}

# === Update Hook Analytics (cumulative) ===
$Analytics = Join-Path $ProjectRoot "docs\hook-analytics.md"

# Create from template if analytics file does not exist
if (-not (Test-Path $Analytics)) {
    $Template = Join-Path $ProjectRoot "docs\hook-analytics.md.template"
    if (Test-Path $Template) {
        Copy-Item $Template $Analytics -ErrorAction SilentlyContinue
    }
}

if (Test-Path $Analytics) {
    # Update "Last Updated" line
    $AnalyticsContent = Get-Content $Analytics -Raw -ErrorAction SilentlyContinue
    if ($AnalyticsContent) {
        $AnalyticsContent = $AnalyticsContent -replace '(?m)^## Last Updated:.*', "## Last Updated: $Timestamp"
        $AnalyticsContent | Out-File -FilePath $Analytics -Encoding UTF8 -NoNewline
    }

    # Count events from this session
    $DesignCount   = ($LogLines | Select-String -Pattern 'DESIGN'                    -SimpleMatch).Count
    $SecurityCount = ($LogLines | Select-String -Pattern 'BLOCKED'                   -SimpleMatch).Count
    $TestCount     = ($LogLines | Select-String -Pattern 'TEST FAIL'                 -SimpleMatch).Count
    $FormatCount   = ($LogLines | Select-String -Pattern 'formatted|prettier|black|ruff').Count

    if ($DesignCount -gt 0 -or $SecurityCount -gt 0) {
        $SessionEntry = @"

### Session: $Timestamp
- Design violations: $DesignCount
- Security blocks: $SecurityCount
- Test failures: $TestCount
- Format fixes: $FormatCount
"@
        $SessionEntry | Out-File -Append -FilePath $Analytics -Encoding UTF8
    }
}

exit 0
