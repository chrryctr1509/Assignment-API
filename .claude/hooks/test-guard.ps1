# test-guard.ps1 — Windows PowerShell mirror of test-guard.sh
# Hook type: PreToolUse (Bash)
# Warns if git commit is run without a recent test pass.
# Like the .sh version, NOT registered in settings.json — called from git-manager logic.

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

if (-not $command) {
    Write-Output '{"decision": "pass"}'
    exit 0
}

if ($command -match 'git commit') {
    $logPath = "/tmp/pre-commit-test.log"
    $staleLog = $true

    if (Test-Path $logPath) {
        $ageMinutes = ((Get-Date) - (Get-Item $logPath).LastWriteTime).TotalMinutes
        if ($ageMinutes -le 30) { $staleLog = $false }
    }

    if ($staleLog) {
        Write-Output '{"decision": "warn", "message": "⚠️ REGRESSION GUARD: git commit detected tanpa recent test run (<30 menit). Jalankan test suite dulu."}'
        exit 0
    }

    $content = Get-Content $logPath -Raw -ErrorAction SilentlyContinue
    if ($content -match '(?i)fail|error|FAILED') {
        Write-Output '{"decision": "warn", "message": "⚠️ REGRESSION GUARD: Test terakhir ada FAILURE. Review /tmp/pre-commit-test.log sebelum commit."}'
        exit 0
    }

    Write-Output '{"decision": "pass"}'
    exit 0
}

Write-Output '{"decision": "pass"}'
exit 0
