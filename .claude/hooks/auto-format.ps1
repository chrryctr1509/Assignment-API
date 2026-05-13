# auto-format.ps1 — PostToolUse hook for Write|Edit
# Auto-formats code files after save. Always exit 0 (non-blocking).
# PowerShell port of auto-format.sh

$ErrorActionPreference = "SilentlyContinue"

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

# Read JSON input from stdin
$InputData = $null
try {
    $RawInput = [Console]::In.ReadToEnd()
    if ($RawInput) {
        $InputData = $RawInput | ConvertFrom-Json
    }
} catch {}

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

# Skip non-code / doc / config files
if ($FilePath -match '\.(md|json|yml|yaml|txt|template|log|csv|xml)$') {
    exit 0
}

# Extract extension
$Ext = [System.IO.Path]::GetExtension($FilePath).TrimStart('.').ToLower()

switch ($Ext) {
    'php' {
        $Fixer = Get-Command "php-cs-fixer" -ErrorAction SilentlyContinue
        if ($Fixer) {
            & php-cs-fixer fix $FilePath --quiet 2>$null
        }
    }

    { $_ -in @('js','ts','jsx','tsx','css','scss') } {
        $Prettier = Get-Command "prettier" -ErrorAction SilentlyContinue
        $Npx      = Get-Command "npx"      -ErrorAction SilentlyContinue
        if ($Prettier) {
            & prettier --write $FilePath --log-level silent 2>$null
        } elseif ($Npx) {
            & npx prettier --write $FilePath --log-level silent 2>$null
        }
    }

    'py' {
        $Black = Get-Command "black" -ErrorAction SilentlyContinue
        $Ruff  = Get-Command "ruff"  -ErrorAction SilentlyContinue
        if ($Black) {
            & black --quiet $FilePath 2>$null
        }
        if ($Ruff) {
            & ruff check --fix --quiet $FilePath 2>$null
        }
    }
}

exit 0
