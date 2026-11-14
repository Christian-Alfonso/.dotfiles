[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Search all PowerShell module paths instead of assuming Documents or OneDrive.
$ModuleRoots = @(
    $env:PSModulePath -split [IO.Path]::PathSeparator
)

$ModuleFiles = foreach ($root in $ModuleRoots) {
    if (Test-Path $root) {
        Get-ChildItem -Path $root -Filter 'Microsoft.PowerToys.Configure.psm1' -File -Recurse -ErrorAction SilentlyContinue
    }
}

$ModuleFiles = $ModuleFiles | Sort-Object -Property FullName -Unique

if (-not $ModuleFiles) {
    throw 'Microsoft.PowerToys.Configure was not found in a PowerShell module path.'
}

$PatchedCount = 0
$AlreadyPatchedCount = 0
$ExpectedPattern = '\$_.DisplayVersion\s+-eq\s+"([0-9]+\.[0-9]+\.[0-9]+)"'
$PatchedPattern = '\$_.DisplayVersion\s+-like\s+"([0-9]+\.[0-9]+\.[0-9]+)\*"'

foreach ($moduleFileInfo in $ModuleFiles) {
    $ModuleFile = $moduleFileInfo.FullName
    $BackupFile = "$ModuleFile.bak"

    # Running the fix more than once restores the original file before reapplying it.
    if (Test-Path $BackupFile) {
        Copy-Item -LiteralPath $BackupFile -Destination $ModuleFile -Force
    }

    $Content = Get-Content -Path $ModuleFile -Raw

    if ($Content -match $PatchedPattern) {
        $AlreadyPatchedCount++
        continue
    }

    if ($Content -notmatch $ExpectedPattern) {
        continue
    }

    if (-not (Test-Path $BackupFile)) {
        Copy-Item -LiteralPath $ModuleFile -Destination $BackupFile -Force
    }

    # Preserve "$_.DisplayVersion" literally and replace only the exact version value.
    $PatchedContent = [regex]::Replace(
        $Content,
        $ExpectedPattern,
        [System.Text.RegularExpressions.MatchEvaluator] {
            param($Match)
            '$_.DisplayVersion -like "' + $Match.Groups[1].Value + '*"'
        }
    )

    Set-Content -LiteralPath $ModuleFile -Value $PatchedContent -Encoding UTF8 -NoNewline

    # ParseFile checks the patched PSM1 for PowerShell syntax errors without executing it.
    # Its AST is returned through $Tokens and any diagnostics through $ParseErrors;
    # Out-Null suppresses the AST object because this script only needs $ParseErrors.
    $Tokens = $null
    $ParseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $ModuleFile,
        [ref] $Tokens,
        [ref] $ParseErrors
    ) | Out-Null

    if ($ParseErrors.Count -gt 0) {
        throw "Patched module still contains PowerShell syntax errors: $ModuleFile`n$($ParseErrors[0].Message)"
    }

    $PatchedCount++
    Write-Host "Patched PowerToys DSC module: $ModuleFile"
}

if ($PatchedCount -eq 0 -and $AlreadyPatchedCount -eq 0) {
    throw 'The PowerToys DSC module was found, but the version-mismatch expression was not found in its PSM1 file.'
}

if ($PatchedCount -eq 0) {
    Write-Host 'PowerToys DSC module is already patched.'
}