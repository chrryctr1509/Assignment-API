# context-monitor.ps1 — PostToolUse hook for Bash
# Monitors token usage and emits COMPACT_NOW warning when context is pressured.
# Reads wave-execution-state.md and token reports for heuristics.
# Output to stdout (Claude reads). Always exit 0.
# PowerShell port of context-monitor.sh

$ErrorActionPreference = "SilentlyContinue"

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

# Consume stdin (required by Claude Code hook contract — discard for this hook)
try { [Console]::In.ReadToEnd() | Out-Null } catch {}

# Only check periodically — every 10th Bash call — to avoid overhead
$CounterFile = Join-Path $env:TEMP "context-monitor-counter"
$Count = 0
try {
    $Count = [int](Get-Content $CounterFile -Raw -ErrorAction SilentlyContinue)
} catch {}
$Count++
$Count | Out-File -FilePath $CounterFile -Encoding UTF8 -NoNewline

if (($Count % 10) -ne 0) {
    exit 0
}

# Check wave execution state for progress indication
$WaveState = Join-Path $ProjectRoot "docs\wave-execution-state.md"
if (-not (Test-Path $WaveState)) {
    exit 0
}

$WaveContent = Get-Content $WaveState -Raw -ErrorAction SilentlyContinue
if (-not $WaveContent) {
    exit 0
}

# Count total checkboxes [ ] and [x]
$TotalFiles     = ([regex]::Matches($WaveContent, '^\s*-\s*\[[ x]\]', 'Multiline')).Count
$CompletedFiles = ([regex]::Matches($WaveContent, '^\s*-\s*\[x\]',   'Multiline')).Count

if ($TotalFiles -eq 0) {
    exit 0
}

# Check token report if available
$TokenReport = Join-Path $ProjectRoot "docs\token-reports\current-pipeline.md"
if (Test-Path $TokenReport) {
    $ReportContent = Get-Content $TokenReport -Raw -ErrorAction SilentlyContinue
    if ($ReportContent) {
        # Extract the last standalone number that follows "total.*:"
        $TokenMatches = [regex]::Matches($ReportContent, '(?i)total.*?:\s*(\d+)')
        if ($TokenMatches.Count -gt 0) {
            $TokensUsed = [int]$TokenMatches[$TokenMatches.Count - 1].Groups[1].Value
            if ($TokensUsed -gt 700000) {
                Write-Output "WARNING CONTEXT MONITOR: Token usage high (~${TokensUsed}). COMPACT_NOW — compact context before spawning next agent."
                exit 0
            }
        }
    }
}

# Heuristic: wave with 20+ completed files likely needs compaction
if ($CompletedFiles -gt 20) {
    $Progress = [int]($CompletedFiles * 100 / $TotalFiles)
    if ($Progress -gt 50 -and $Progress -lt 90) {
        Write-Output "WARNING CONTEXT MONITOR: Progress ${CompletedFiles}/${TotalFiles} files (${Progress}%). Consider COMPACT_NOW between waves."
    }
}

exit 0
