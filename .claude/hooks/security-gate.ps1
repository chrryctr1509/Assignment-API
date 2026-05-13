# security-gate.ps1 — PreToolUse hook for Bash commands (Windows PowerShell)
# Blocks dangerous operations. Exit 2 + stderr = Claude reads and adjusts.
# PowerShell port of security-gate.sh

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

# Read JSON input from stdin
$Input = $null
try {
    $RawInput = [Console]::In.ReadToEnd()
    if ($RawInput) {
        $Input = $RawInput | ConvertFrom-Json
    }
} catch {
    # No input or invalid JSON — allow
    exit 0
}

$Command = $null
if ($Input -and $Input.tool_input -and $Input.tool_input.command) {
    $Command = $Input.tool_input.command
}

if (-not $Command) {
    exit 0
}

$LogFile = Join-Path $ScriptDir "hook-log.txt"

function Write-BlockLog {
    param([string]$Reason)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp BLOCKED: $Reason | cmd: $Command" | Out-File -Append -FilePath $LogFile -Encoding UTF8
}

function Send-BlockNotify {
    param([string]$Cmd, [string]$Source)
    $NotifyScript = Join-Path $ProjectRoot ".claude\telegram\notify-blocked.sh"
    if (Test-Path $NotifyScript) {
        # Try bash (Git Bash) for notification — non-blocking
        Start-Job -ScriptBlock {
            param($s, $c, $src)
            & bash $s $c $src 2>$null
        } -ArgumentList $NotifyScript, $Cmd, $Source | Out-Null
    }
}

function Write-CleanupLog {
    param([string]$Reason)
    $Timestamp = Get-Date -Format "HH:mm:ss"
    "[$Timestamp] CLEANUP-ALLOW: $Reason" | Out-File -Append -FilePath $LogFile -Encoding UTF8
}

# Block: git push to protected branches (main, master, develop, staging)
if ($Command -match 'git\s+push\s+.*\b(main|master|develop|staging)\b') {
    Write-BlockLog "git push to protected branch detected"
    [Console]::Error.WriteLine("BLOCKED: git push to protected branch detected. Use feature branches and PR instead.")
    Send-BlockNotify $Command "security-gate"
    exit 2
}

# Block: git push --force
if ($Command -match 'git\s+push\s+.*--force') {
    Write-BlockLog "git push --force is forbidden"
    [Console]::Error.WriteLine("BLOCKED: git push --force is forbidden. Use non-destructive push.")
    Send-BlockNotify $Command "security-gate"
    exit 2
}
if ($Command -match 'git\s+push\s+-f\b') {
    Write-BlockLog "git push -f (force) is forbidden"
    [Console]::Error.WriteLine("BLOCKED: git push -f (force) is forbidden.")
    Send-BlockNotify $Command "security-gate"
    exit 2
}

# Block: destructive git operations (reset --hard, checkout --, clean -f)
if ($Command -match 'git\s+reset\s+--hard') {
    Write-BlockLog "git reset --hard is forbidden (data loss risk)"
    [Console]::Error.WriteLine("BLOCKED: git reset --hard is forbidden. Use git stash or git revert instead.")
    Send-BlockNotify $Command "security-gate"
    exit 2
}
if ($Command -match 'git\s+checkout\s+--\s+\.') {
    Write-BlockLog "git checkout -- . is forbidden (discards all unstaged changes)"
    [Console]::Error.WriteLine("BLOCKED: git checkout -- . is forbidden. Use git stash to save changes.")
    Send-BlockNotify $Command "security-gate"
    exit 2
}
if ($Command -match 'git\s+clean\s+-[a-zA-Z]*f') {
    Write-BlockLog "git clean -f is forbidden (permanently deletes untracked files)"
    [Console]::Error.WriteLine("BLOCKED: git clean -f is forbidden. Review untracked files manually.")
    Send-BlockNotify $Command "security-gate"
    exit 2
}

# Block: DROP DATABASE, TRUNCATE, DELETE FROM WHERE 1
if ($Command -match '(?i)DROP\s+(DATABASE|TABLE)') {
    Write-BlockLog "DROP DATABASE/TABLE detected"
    [Console]::Error.WriteLine("BLOCKED: DROP DATABASE/TABLE is forbidden.")
    Send-BlockNotify $Command "security-gate"
    exit 2
}
if ($Command -match '(?i)TRUNCATE\s+') {
    Write-BlockLog "TRUNCATE detected"
    [Console]::Error.WriteLine("BLOCKED: TRUNCATE is forbidden.")
    Send-BlockNotify $Command "security-gate"
    exit 2
}
if ($Command -match '(?i)DELETE\s+FROM\s+.*WHERE\s+1') {
    Write-BlockLog "DELETE FROM WHERE 1 (mass delete) detected"
    [Console]::Error.WriteLine("BLOCKED: Mass DELETE detected.")
    Send-BlockNotify $Command "security-gate"
    exit 2
}

# Patched: artisan tinker --execute SQL guard
if ($Command -match '(?i)artisan\s+tinker\s+--execute') {
    if ($Command -match '(?i)(DROP\s+(DATABASE|TABLE)|TRUNCATE|DELETE\s+FROM.*WHERE\s+1|DB::statement.*DROP|DB::unprepared)') {
        Write-BlockLog "Dangerous SQL in artisan tinker --execute"
        [Console]::Error.WriteLine("BLOCKED: artisan tinker --execute contains dangerous SQL pattern. Use migrations instead.")
        Send-BlockNotify $Command "security-gate"
        exit 2
    }
}

# === SAFE CLEANUP WHITELIST (BEFORE rm -rf block) ===
# Allow rm -rf on known safe directories that agents legitimately need to clean
if ($Command -match 'rm\s+-r[f]*\s') {
    # Worktree cleanup (agent worktrees after pipeline)
    if ($Command -match '\.claude[/\\]worktrees[/\\]') {
        Write-CleanupLog "worktree cleanup"
        exit 0
    }
    # Build artifact cleanup (stale build, Fix Protocol Step 2)
    if ($Command -match '(node_modules[/\\]\.cache|__pycache__|\.pytest_cache|\.next[/\\]|\.nuxt[/\\]|dist[/\\]|build[/\\]|out[/\\]|\.vite[/\\])') {
        Write-CleanupLog "build artifact cleanup"
        exit 0
    }
    # Video frame cleanup (post-pipeline)
    if ($Command -match 'docs[/\\]video-frames[/\\]') {
        Write-CleanupLog "video frames cleanup"
        exit 0
    }
    # Git worktree prune (safe git maintenance)
    if ($Command -match 'git\s+worktree\s+prune') {
        Write-CleanupLog "git worktree prune"
        exit 0
    }
}

# Block: rm -rf at SYSTEM root or truly critical directories
# Fixed: match only paths that ARE system directories, not paths containing them
if ($Command -match 'rm\s+-r[f]*\s+\s*(\/\s|\/home\s|\/home\/\s|\/var\s|\/etc\s|\/usr\s|\.\.\s|\.\.\/)') {
    Write-BlockLog "rm -rf on critical system directory detected"
    [Console]::Error.WriteLine("BLOCKED: rm -rf on critical system directory.")
    Send-BlockNotify $Command "security-gate"
    exit 2
}
# Also block rm -rf / (root filesystem)
if ($Command -match 'rm\s+-r[f]*\s+/$') {
    Write-BlockLog "rm -rf / detected"
    [Console]::Error.WriteLine("BLOCKED: rm -rf / is forbidden.")
    Send-BlockNotify $Command "security-gate"
    exit 2
}
# Block: Remove-Item on Windows system paths
if ($Command -match 'Remove-Item\s+.*-Recurse.*\b(C:\\Windows|C:\\Users\s|C:\\Program)') {
    Write-BlockLog "Remove-Item on Windows system directory detected"
    [Console]::Error.WriteLine("BLOCKED: Remove-Item on Windows system directory is forbidden.")
    Send-BlockNotify $Command "security-gate"
    exit 2
}

# Block: curl/wget to non-allowed URLs
if ($Command -match '(curl|wget)\s') {
    if ($Command -notmatch '(localhost|127\.0\.0\.1|github\.com|raw\.githubusercontent\.com|api\.github\.com|gist\.githubusercontent\.com|gitlab\.com|api\.gitlab\.com|api\.telegram\.org|registry\.npmjs\.org|pypi\.org|packagist\.org|rubygems\.org|proxy\.golang\.org|repo1\.maven\.org|dl\.google\.com|stackoverflow\.com|docs\.python\.org|docs\.djangoproject\.com|laravel\.com|vuejs\.org|reactjs\.org|nodejs\.org|developer\.mozilla\.org)') {
        Write-BlockLog "curl/wget to external URL not in allowlist"
        [Console]::Error.WriteLine("BLOCKED: curl/wget to external URL not in allowlist. Gunakan WebFetch tool untuk akses URL eksternal — WebFetch tidak di-block oleh security-gate.")
        Send-BlockNotify $Command "security-gate"
        exit 2
    }
}

# === DOCKER ENFORCEMENT ===
$DockerAssess = Join-Path $ProjectRoot "docs\docker-assessment.md"
$BareCommands = '^(npm |npx |pip |pip3 |composer |php |python |python3 |pytest |phpunit |jest |node )'

# === REWRITABLE COMMANDS EXCEPTION (Brief 27.a) ===
# Mirror of security-gate.sh exception — ensures Windows PowerShell users get same behavior.
# When adding rewrite-docker-* hook, update BOTH .sh and .ps1.
$RewritablePatterns = '^\s*(php\s+artisan|npm|npx|composer|pip|pip3)\b'

if ($Command -match $RewritablePatterns) {
    $Timestamp = Get-Date -Format "HH:mm:ss"
    "[$Timestamp] REWRITABLE-ALLOW: pattern matches rewrite hook (will be rewritten)" | Out-File -Append -FilePath $LogFile -Encoding UTF8
    exit 0
}
# === END REWRITABLE COMMANDS EXCEPTION ===

if ($Command -match $BareCommands) {
    # Check: is this a docker exec command? If yes, ALLOW
    if ($Command -notmatch 'docker exec') {
        $CmdName = ($Command -split '\s+')[0]

        # === MCP SERVER WHITELIST ===
        $McpWhitelist = 'chrome-devtools-mcp|@playwright/mcp|@anthropic-ai'
        if ($Command -match "npx.*($McpWhitelist)") {
            $Timestamp = Get-Date -Format "HH:mm:ss"
            "[$Timestamp] MCP-ALLOW: npx MCP server command" | Out-File -Append -FilePath $LogFile -Encoding UTF8
            exit 0
        }
        # Also allow if command matches a server arg from project .mcp.json
        $McpJson = Join-Path $ProjectRoot ".mcp.json"
        if (Test-Path $McpJson) {
            try {
                $McpConfig = Get-Content $McpJson -Raw | ConvertFrom-Json
                foreach ($Server in $McpConfig.mcpServers.PSObject.Properties) {
                    foreach ($Arg in $Server.Value.args) {
                        if ($Arg -and -not $Arg.StartsWith("-") -and $Command -match [regex]::Escape($Arg)) {
                            $Timestamp = Get-Date -Format "HH:mm:ss"
                            "[$Timestamp] MCP-ALLOW: matches .mcp.json server ($($Server.Name))" | Out-File -Append -FilePath $LogFile -Encoding UTF8
                            exit 0
                        }
                    }
                }
            } catch {}
        }

        # Check: is this service in host_services?
        if (Test-Path $DockerAssess) {
            $Content = Get-Content $DockerAssess -Raw
            if ($Content -match '(?s)Host Services.*?Execution Rules') {
                $HostSection = $Matches[0]
                if ($HostSection -match "(?i)$CmdName") {
                    $Timestamp = Get-Date -Format "HH:mm:ss"
                    "[$Timestamp] HOST-ALLOW: $CmdName (in host_services)" | Out-File -Append -FilePath $LogFile -Encoding UTF8
                    exit 0
                }
            }

            # AUTO-HINT: Try to detect correct container
            $Container = $null
            switch -Regex ($CmdName) {
                '^(php|composer|phpunit)$' {
                    if ($Content -match '(?im)(php|laravel|app).*container:\s*(\S+)') { $Container = $Matches[2] }
                }
                '^(npm|npx|node|jest)$' {
                    if ($Content -match '(?im)(node|frontend|fe).*container:\s*(\S+)') { $Container = $Matches[2] }
                }
                '^(python|python3|pip|pip3|pytest)$' {
                    if ($Content -match '(?im)(python|backend|api).*container:\s*(\S+)') { $Container = $Matches[2] }
                }
            }

            if ($Container) {
                [Console]::Error.WriteLine("BLOCKED: '$CmdName' must run in Docker container.")
                [Console]::Error.WriteLine("AUTO-HINT: Use instead: docker exec -it $Container $Command")
                $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                "[$Timestamp] BLOCKED+HINT: bare $CmdName -> docker exec -it $Container (auto-hint)" | Out-File -Append -FilePath $LogFile -Encoding UTF8
                Send-BlockNotify $Command "security-gate:docker-enforce"
                exit 2
            }
        }

        # No docker-assessment or no container detected — generic block
        [Console]::Error.WriteLine("BLOCKED: '$CmdName' must run in Docker container. Use: docker exec -it [container] $Command")
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "[$Timestamp] BLOCKED: bare $CmdName (must use docker exec)" | Out-File -Append -FilePath $LogFile -Encoding UTF8
        Send-BlockNotify $Command "security-gate:docker-enforce"
        exit 2
    }
}

exit 0