# file-protect.ps1 — PreToolUse hook for Write|Edit
# Blocks writes to sensitive files and enforces file-scope-contract.
# Exit 2 + stderr = Claude reads and adjusts.
# PowerShell port of file-protect.sh

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

# Read JSON input from stdin
$InputData = $null
try {
    $RawInput = [Console]::In.ReadToEnd()
    if ($RawInput) {
        $InputData = $RawInput | ConvertFrom-Json
    }
} catch {
    exit 0
}

$FilePath = $null
if ($InputData -and $InputData.tool_input) {
    if ($InputData.tool_input.file_path) {
        $FilePath = $InputData.tool_input.file_path
    } elseif ($InputData.tool_input.path) {
        $FilePath = $InputData.tool_input.path
    }
}

if (-not $FilePath) {
    exit 0
}

$LogFile = Join-Path $ScriptDir "hook-log.txt"

function Write-BlockLog {
    param([string]$Reason)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp BLOCKED: $Reason | file: $FilePath" | Out-File -Append -FilePath $LogFile -Encoding UTF8
}

function Invoke-Block {
    param([string]$Reason)
    Write-BlockLog $Reason
    [Console]::Error.WriteLine("BLOCKED: $Reason")
    exit 2
}

# Block: .env files (EXCEPT templates: .example, .template, .sample)
# Brief 29: parity with .sh — allow template files, block real credential files.
# Compound suffixes (.env.local.example) also allowed.
if ($FilePath -match '(^|[\\/])\.env($|\.)') {
    if ($FilePath -notmatch '\.(example|template|sample)$') {
        Invoke-Block "Writing to .env file is forbidden"
    }
}

# Block: credentials / secrets / private keys
if ($FilePath -imatch '(credentials|secrets|private\.key|\.pem)') {
    Invoke-Block "Writing to credentials/secrets file is forbidden"
}

# Block: agent self-modification
if ($FilePath -match '\.claude[\\/]agents[\\/]') {
    Invoke-Block "Agents cannot self-modify (.claude/agents/ is protected)"
}

# Block: hook self-modification (except hook-log.txt)
# Added by agent-review: prevent agents from modifying enforcement layer
if ($FilePath -match '\.claude[\\/]hooks[\\/]' -and $FilePath -notmatch 'hook-log\.txt$') {
    Invoke-Block "Hooks are protected (.claude/hooks/ is read-only for agents)"
}

# Block: hook self-modification (except hook-log.txt)
# Added by agent-review: prevent agents from modifying enforcement layer
if ($FilePath -match '\.claude[\\/]hooks[\\/]' -and $FilePath -notmatch 'hook-log\.txt$') {
    Invoke-Block "Hooks are protected (.claude/hooks/ is read-only for agents)"
}

# Block: hook self-modification (except hook-log.txt)
# Added by agent-review: prevent agents from modifying enforcement layer
if ($FilePath -match '\.claude[\\/]hooks[\\/]' -and $FilePath -notmatch 'hook-log\.txt$') {
    Invoke-Block "Hooks are protected (.claude/hooks/ is read-only for agents)"
}

# Allow: docs/, .claude/memory/, .claude/hooks/hook-log.txt
if ($FilePath -match '^(docs[\\/]|\.claude[\\/]memory[\\/]|\.claude[\\/]hooks[\\/]hook-log\.txt)') {
    exit 0
}

# Enforce file-scope-contract.md if it exists
$Contract = Join-Path $ProjectRoot "docs\file-scope-contract.md"
if (Test-Path $Contract) {
    $ContractContent = Get-Content $Contract -Raw
    if ($ContractContent -match 'ALLOWED_MODIFY|ALLOWED_CREATE') {
        $BaseName = Split-Path -Leaf $FilePath
        $InContract = $ContractContent -match [regex]::Escape($FilePath) -or $ContractContent -match [regex]::Escape($BaseName)
        if (-not $InContract) {
            # Check if broadly allowed path
            $BroadAllow = $FilePath -match '^(docs[\\/]|\.claude[\\/]|README)'
            if (-not $BroadAllow) {
                Invoke-Block "File not in file-scope-contract.md. Check docs/file-scope-contract.md"
            }
        }
    }
}

exit 0
