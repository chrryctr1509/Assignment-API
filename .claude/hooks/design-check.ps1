# design-check.ps1 — PostToolUse hook for Write|Edit
# Checks CSS/JSX/TSX/SCSS/Vue files for forbidden design patterns.
# Output to stdout (Claude reads). Always exit 0.
# PowerShell port of design-check.sh

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

# Only check design-relevant files (.css, .scss, .jsx, .tsx, .vue)
if ($FilePath -notmatch '\.(css|scss|jsx|tsx|vue)$') {
    exit 0
}

if (-not (Test-Path $FilePath)) {
    exit 0
}

$Warnings = @()

# Default forbidden fonts (generic/overused — indicate AI slop)
$ForbiddenFonts = 'Inter|Roboto|Arial|Poppins|system-ui'

# Load custom forbidden fonts from design-direction.md if it exists
$DesignDir = Join-Path $ProjectRoot "docs\design-direction.md"
if (Test-Path $DesignDir) {
    $DesignContent = Get-Content $DesignDir -Raw
    # Extract font names from lines matching 'forbidden font' / 'font forbidden' / 'DILARANG font'
    $FontLines = $DesignContent -split "`n" | Where-Object {
        $_ -imatch '(forbidden.*font|font.*forbidden|DILARANG.*font)'
    }
    $CustomFonts = @()
    foreach ($Line in $FontLines) {
        $Matches2 = [regex]::Matches($Line, "'([^']+)'")
        foreach ($M in $Matches2) {
            $CustomFonts += $M.Groups[1].Value
        }
    }
    if ($CustomFonts.Count -gt 0) {
        $ForbiddenFonts = $CustomFonts -join '|'
    }
}

$FileContent = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
if (-not $FileContent) {
    exit 0
}

# --- Check 1: Forbidden fonts ---
$FontPattern = "font-family.*($ForbiddenFonts)"
$FontMatches = Select-String -Path $FilePath -Pattern $FontPattern -AllMatches -CaseSensitive:$false -ErrorAction SilentlyContinue
if ($FontMatches) {
    $Lines = ($FontMatches | ForEach-Object { $_.Line.Trim() }) -join "`n"
    $Warnings += "WARNING DESIGN: Forbidden font detected in ${FilePath}:`n$Lines"
}

# --- Check 2: Purple gradients ---
if ($FileContent -imatch 'purple.*gradient|gradient.*purple|#[89a-fA-F][0-9a-fA-F].*#[89a-fA-F]') {
    $Warnings += "WARNING DESIGN: Purple gradient pattern detected in $FilePath"
}

# --- Check 3: Heavy box-shadow blur (>20px) ---
if ($FileContent -match 'box-shadow.*\b[2-9][0-9]px') {
    $Warnings += "WARNING DESIGN: Heavy box-shadow blur (>20px) detected in $FilePath"
}

# --- Check 4: Excessive border-radius (>16px) ---
if ($FileContent -match 'border-radius:\s*[2-9][0-9]px|border-radius:\s*[1-9][0-9]{2,}px') {
    $Warnings += "WARNING DESIGN: Excessive border-radius (>16px) detected in $FilePath"
}

# --- Enhanced anti-slop patterns ---

# Check 5: Pink-to-purple gradients
if ($FileContent -imatch 'from-pink.*to-purple|from-purple.*to-pink|#[efdEFD][0-9a-fA-F].*#[89aA][0-9a-fA-F].*gradient|pink.*purple.*gradient|fuchsia.*violet') {
    $Warnings += "WARNING DESIGN: Pink-to-purple gradient detected (AI slop pattern) in $FilePath"
}

# Check 6: Overuse of rounded-full / pill shapes (>5 instances)
$PillMatches = [regex]::Matches($FileContent, 'rounded-full|border-radius:\s*9999|border-radius:\s*50%')
$PillCount = $PillMatches.Count
if ($PillCount -gt 5) {
    $Warnings += "WARNING DESIGN: Excessive rounded-full usage ($PillCount instances) in $FilePath — consider mixed border-radius"
}

# Check 7: Generic hero section pattern (heading + text + button, no unique elements)
if ($FileContent -match 'className.*hero') {
    $HeroElements  = ([regex]::Matches($FileContent, '<h[12]|<p|<button|<Button')).Count
    $UniqueElements = ([regex]::Matches($FileContent, '<img|<video|<svg|<canvas|<lottie|animation|motion')).Count
    if ($HeroElements -gt 2 -and $UniqueElements -eq 0) {
        $Warnings += "WARNING DESIGN: Generic hero section pattern (heading+text+CTA, no unique elements) in $FilePath"
    }
}

# Check 8: Stock / placeholder image references
if ($FileContent -imatch 'placeholder\.(png|jpg|svg)|unsplash\.com|picsum\.photos|via\.placeholder|lorem-pixel|stock-photo') {
    $Warnings += "WARNING DESIGN: Placeholder/stock image reference detected in $FilePath — replace with real assets"
}

# Output all warnings to stdout (Claude reads)
if ($Warnings.Count -gt 0) {
    $Warnings | ForEach-Object { Write-Output $_ }
}

exit 0
