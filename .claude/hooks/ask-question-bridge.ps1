# ask-question-bridge.ps1 — PreToolUse hook for AskUserQuestion
# Captures question text, sends to Telegram with inline keyboard.
# Supports multi-session: writes to pending-questions/ queue directory.
# Does NOT block — exits 0 always so terminal still shows the question.
# PowerShell port of ask-question-bridge.sh

$ErrorActionPreference = "SilentlyContinue"

$ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot  = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$TelegramDir  = Join-Path $ProjectRoot ".claude\telegram"
$QueueDir     = Join-Path $TelegramDir "pending-questions"

# Ensure queue directory exists
if (-not (Test-Path $QueueDir)) {
    New-Item -ItemType Directory -Path $QueueDir -Force | Out-Null
}

# If native channel mode is active and session process is alive — skip custom bridge.
# Native channel delivers AskUserQuestion to Telegram and routes response back
# into Claude's conversation context without needing file queue or tmux.
$ChannelModeFile = Join-Path $TelegramDir "channel-mode.env"
if (Test-Path $ChannelModeFile) {
    $ChannelEnv = @{}
    Get-Content $ChannelModeFile | ForEach-Object {
        if ($_ -match '^([^#][^=]+)=(.*)$') {
            $ChannelEnv[$Matches[1].Trim()] = $Matches[2].Trim()
        }
    }
    if ($ChannelEnv['CHANNEL_MODE'] -eq 'native') {
        $SessionPid = [int]($ChannelEnv['SESSION_PID'])
        if ($SessionPid -gt 0) {
            $PidAlive = Get-Process -Id $SessionPid -ErrorAction SilentlyContinue
            if ($PidAlive) {
                exit 0
            }
        }
    }
}

# Clean up stale pending questions (>10 minutes old)
$NowEpoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
Get-ChildItem -Path $QueueDir -Filter "q-*.json" -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        $Content = Get-Content $_.FullName -Raw | ConvertFrom-Json
        if ($Content.timestamp) {
            $FileTime = [DateTimeOffset]::Parse($Content.timestamp).ToUnixTimeSeconds()
            $Elapsed  = $NowEpoch - $FileTime
            if ($Elapsed -gt 600) {
                Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {}
}

# Read JSON from stdin
$RawInput = $null
try {
    $RawInput = [Console]::In.ReadToEnd()
} catch {}

if (-not $RawInput) {
    exit 0
}

$InputData = $null
try {
    $InputData = $RawInput | ConvertFrom-Json
} catch {
    exit 0
}

# Extract question text
$Question = $null
if ($InputData -and $InputData.tool_input) {
    if ($InputData.tool_input.question) {
        $Question = $InputData.tool_input.question
    } elseif ($InputData.tool_input.questions -and $InputData.tool_input.questions.Count -gt 0) {
        $Question = $InputData.tool_input.questions[0].question
    }
}

if (-not $Question) {
    exit 0
}

# Extract options labels if available
$OptionsJson = "null"
try {
    $Labels = @()
    if ($InputData.tool_input.questions) {
        foreach ($q in $InputData.tool_input.questions) {
            if ($q.options) {
                foreach ($opt in $q.options) {
                    if ($opt.label) { $Labels += $opt.label }
                }
            }
        }
    }
    if ($Labels.Count -gt 0) {
        $OptionsJson = $Labels | ConvertTo-Json -Compress
    }
} catch {}

# Generate unique question ID using millisecond timestamp
$QId = "q-$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())"

# Project name for session identification
$ProjectName   = Split-Path -Leaf $ProjectRoot
$SessionLabel  = $ProjectName

# Write to queue directory
$PendingFile = Join-Path $QueueDir "$QId.json"
$PendingData = [ordered]@{
    id            = $QId
    question      = $Question
    options       = $OptionsJson
    tmux_target   = ""
    project_name  = $ProjectName
    session_label = $SessionLabel
    timestamp     = (Get-Date -Format "o")
    status        = "pending"
}
$PendingData | ConvertTo-Json -Depth 3 | Out-File -FilePath $PendingFile -Encoding UTF8

# Send to Telegram (non-blocking, background)
$NotifyScript = Join-Path $TelegramDir "notify-question.sh"
if (Test-Path $NotifyScript) {
    $env:PENDING_FILE = $PendingFile
    Start-Job -ScriptBlock {
        param($Script, $PFile)
        $env:PENDING_FILE = $PFile
        & bash $Script 2>$null
    } -ArgumentList $NotifyScript, $PendingFile | Out-Null
}

# Always exit 0 — never block AskUserQuestion
exit 0
