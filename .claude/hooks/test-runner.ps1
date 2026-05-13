# test-runner.ps1 — PostToolUse hook for Write|Edit
# Runs related tests for changed files. Outputs failure details, silent on pass.
# Always exit 0 (non-blocking).
# PowerShell port of test-runner.sh

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
if ($FilePath -match '\.(md|json|yml|yaml|txt|template|log|csv|xml|sh)$') {
    exit 0
}

# Skip test files themselves (avoid infinite loop)
if ($FilePath -match '(\.test\.|\.spec\.|_test\.|Test\.php|test_.*\.py|__tests__)') {
    exit 0
}

$Ext        = [System.IO.Path]::GetExtension($FilePath).TrimStart('.').ToLower()
$ModuleName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)

# Docker-aware test execution: check docker-assessment.md for container names
$DockerAssess = Join-Path $ProjectRoot "docs\docker-assessment.md"
$HasDockerAssess = Test-Path $DockerAssess

function Get-DockerContainer {
    param([string]$Pattern)
    if ($HasDockerAssess) {
        $DocContent = Get-Content $DockerAssess -Raw
        if ($DocContent -match "(?im)($Pattern).*container:\s*(\S+)") {
            return $Matches[2]
        }
    }
    return $null
}

switch ($Ext) {
    'php' {
        $HasConfig = (Test-Path "phpunit.xml") -or (Test-Path "phpunit.xml.dist")
        if ($HasConfig) {
            $Container = Get-DockerContainer 'php|laravel|app'
            if ($Container) {
                $Result = & docker compose exec -T $Container php vendor/bin/phpunit --filter $ModuleName 2>&1
            } else {
                $Result = & php vendor/bin/phpunit --filter $ModuleName 2>&1
            }
            if ($LASTEXITCODE -ne 0) {
                Write-Output "WARNING TEST FAIL for ${FilePath}:"
                $Result | Select-Object -Last 20 | ForEach-Object { Write-Output $_ }
            }
        }
    }

    { $_ -in @('js','ts','jsx','tsx') } {
        $HasJest = (Test-Path "jest.config.js") -or (Test-Path "jest.config.ts") -or (Test-Path "vitest.config.ts") -or (Test-Path "package.json")
        if ($HasJest) {
            $Container = Get-DockerContainer 'node|frontend|fe'
            if ($Container) {
                $Result = & docker compose exec -T $Container npx jest --findRelatedTests $FilePath --passWithNoTests 2>&1
            } else {
                $Result = & npx jest --findRelatedTests $FilePath --passWithNoTests 2>&1
            }
            if ($LASTEXITCODE -ne 0) {
                Write-Output "WARNING TEST FAIL for ${FilePath}:"
                $Result | Select-Object -Last 20 | ForEach-Object { Write-Output $_ }
            }
        }
    }

    'py' {
        $Container = Get-DockerContainer 'python|backend|api'
        if ($Container) {
            $Result = & docker compose exec -T $Container pytest -k $ModuleName --no-header -q 2>&1
        } else {
            $Result = & pytest -k $ModuleName --no-header -q 2>&1
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Output "WARNING TEST FAIL for ${FilePath}:"
            $Result | Select-Object -Last 20 | ForEach-Object { Write-Output $_ }
        }
    }

    'go' {
        # Go test support
        $PkgDir = Split-Path -Parent $FilePath
        $Result = & go test "./$PkgDir/..." -run $ModuleName -count=1 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Output "WARNING TEST FAIL for ${FilePath}:"
            $Result | Select-Object -Last 20 | ForEach-Object { Write-Output $_ }
        }
    }

    { $_ -in @('kt','kts') } {
        # Kotlin test support
        if (Test-Path "gradlew.bat") {
            $Result = & .\gradlew.bat test --tests "*$ModuleName*" 2>&1
        } elseif (Test-Path "gradlew") {
            $Result = & bash ./gradlew test --tests "*$ModuleName*" 2>&1
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Output "WARNING TEST FAIL for ${FilePath}:"
            $Result | Select-Object -Last 20 | ForEach-Object { Write-Output $_ }
        }
    }
}

exit 0
