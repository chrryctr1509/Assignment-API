# git-delegation-guard.ps1 — Block orchestrator dari git mutating commands
# Hook type: PreToolUse (Bash)
# PowerShell mirror of git-delegation-guard.sh

$InputRaw = $args[0]
if (-not $InputRaw) {
    try { $InputRaw = [Console]::In.ReadToEnd() } catch { $InputRaw = "" }
}

try {
    $Data = $InputRaw | ConvertFrom-Json -ErrorAction Stop
    $command = $Data.tool_input.command
} catch {
    $command = ""
}

if (-not $command) { exit 0 }

# Skip guard jika env var set
if ($env:ORCHESTRATOR_GUARD_SKIP -eq "1") { exit 0 }

# Pattern 1: Git mutating commands — BLOCK
$mutatePattern = 'git\s+(commit|push|merge|rebase|cherry-pick|tag|stash|reset|checkout\s+-b|switch\s+-c|branch\s+-[dD]|branch\s+-m|worktree\s+(add|remove))'
if ($command -match $mutatePattern) {
    Write-Error "BLOCKED: Orchestrator git mutating command. SPAWN git-manager instead."
    exit 2
}

# Pattern 2: git add — conditional
if ($command -match 'git\s+add') {
    if ($command -match 'git\s+add\s+.*\.md$' -or $command -match 'git\s+add\s+docs/') {
        exit 0
    }
    Write-Error "BLOCKED: git add terlalu broad. SPAWN git-manager."
    exit 2
}

# Pattern 3: Git API calls — BLOCK
if ($command -match '(api\.github\.com|gitlab\.com/api|api\.gitlab)') {
    Write-Error "BLOCKED: Git API call. SPAWN pr-creator atau git-manager."
    exit 2
}

# Pattern 4: Read-only git — ALLOW
if ($command -match 'git\s+(log|status|diff|branch|remote|show|rev-parse|describe|fetch|ls-files|config\s+--get)') {
    exit 0
}

# Pattern 5: Unknown git — WARN
if ($command -match '^\s*git\s+') {
    Write-Warning "Unknown git command. Jika mutating, delegate ke git-manager."
    exit 0
}

exit 0
