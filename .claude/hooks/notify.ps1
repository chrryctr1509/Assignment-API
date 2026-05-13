# notify.ps1 — Send notifications to Telegram + local log (Windows PowerShell)
# Called by: Notification hook, other telegram scripts, agents
# PowerShell port of notify.sh
# Always exit 0 (non-blocking)

$ErrorActionPreference = "SilentlyContinue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$ProjectName = Split-Path -Leaf $ProjectRoot

# === CONFIGURATION ===
# Source .env from project root
$EnvFile = Join-Path $ProjectRoot ".env"
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^([^#][^=]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim(), "Process")
        }
    }
}

$Token = $env:TELEGRAM_BOT_TOKEN
$ChatId = $env:TELEGRAM_CHAT_ID
$LogFile = Join-Path $ScriptDir "hook-log.txt"

# Accept message from argument OR stdin
$Message = $null
if ($args.Count -gt 0) {
    $Message = $args -join " "
} else {
    # Try to parse JSON from stdin (Claude Code hook format)
    try {
        $RawInput = [Console]::In.ReadToEnd()
        if ($RawInput) {
            try {
                $Parsed = $RawInput | ConvertFrom-Json
                if ($Parsed.message) { $Message = $Parsed.message }
                elseif ($Parsed.notification) { $Message = $Parsed.notification }
                elseif ($Parsed.title) { $Message = $Parsed.title }
                else { $Message = $RawInput }

                if ($Parsed.body -and $Message -ne $RawInput) {
                    $Message = "$Message`: $($Parsed.body)"
                }
            } catch {
                $Message = $RawInput
            }
        }
    } catch {}
}

# Fallback if still empty
if (-not $Message) {
    $Message = "Claude Code notification (no message body)"
}

# === TIMESTAMP ===
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# === LOG (always, even without Telegram) ===
try {
    "[$Timestamp] NOTIFY: [$ProjectName] $Message" | Out-File -Append -FilePath $LogFile -Encoding UTF8
} catch {}

# === DETECT QUESTION/APPROVAL PATTERNS -> redirect to inline keyboard ===
$TelegramDir = Join-Path $ProjectRoot ".claude\telegram"
$QueueDir = Join-Path $TelegramDir "pending-questions"
$MsgLower = $Message.ToLower()

$QuestionPatterns = @(
    'waiting for your input',
    'waiting for input',
    'needs your approval',
    'approval for the plan',
    'approve',
    'permission'
)

$IsQuestion = $false
foreach ($pattern in $QuestionPatterns) {
    if ($MsgLower -match [regex]::Escape($pattern)) {
        $IsQuestion = $true
        break
    }
}

if ($IsQuestion) {
    if (-not (Test-Path $QueueDir)) {
        New-Item -ItemType Directory -Path $QueueDir -Force | Out-Null
    }

    # Detect known option patterns
    $OptionsJson = "null"
    if ($MsgLower -match '(approval for the plan|needs your approval for the plan)') {
        $OptionsJson = '["Yes, bypass permissions","Yes, manually approve","Tell Claude what to change"]'
    } elseif ($MsgLower -match '(permission to|wants to|allow.*tool)') {
        $OptionsJson = '["Allow","Deny"]'
    }

    # Write pending question
    $QId = "q-$(Get-Date -Format 'yyyyMMddHHmmssfff')"
    $SessionLabel = $ProjectName

    $PendingFile = Join-Path $QueueDir "$QId.json"
    $QuestionJson = @{
        id = $QId
        question = $Message
        options = $OptionsJson
        tmux_target = ""
        project_name = $ProjectName
        session_label = $SessionLabel
        timestamp = (Get-Date -Format "o")
        status = "pending"
    } | ConvertTo-Json -Depth 3
    $QuestionJson | Out-File -FilePath $PendingFile -Encoding UTF8

    # Send with inline keyboard if notify-question.sh exists
    $NotifyQuestion = Join-Path $TelegramDir "notify-question.sh"
    if (Test-Path $NotifyQuestion) {
        $env:PENDING_FILE = $PendingFile
        # Try bash (Git Bash) for Telegram notification
        try {
            & bash $NotifyQuestion 2>$null
        } catch {}
        exit 0
    }
}

# === SEND TO TELEGRAM (plain text for non-question notifications) ===
if ($Token -and $ChatId) {
    $LabeledMsg = "[$ProjectName] $Message"
    # Truncate to Telegram limit
    if ($LabeledMsg.Length -gt 4000) {
        $LabeledMsg = $LabeledMsg.Substring(0, 4000)
    }

    try {
        $Body = @{
            chat_id = $ChatId
            text = $LabeledMsg
            disable_web_page_preview = $true
        }
        Invoke-RestMethod -Uri "https://api.telegram.org/bot$Token/sendMessage" `
            -Method Post -Body $Body -ErrorAction SilentlyContinue | Out-Null
    } catch {}
}

exit 0
