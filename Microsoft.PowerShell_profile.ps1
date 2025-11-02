# ----- Added by setup script ----- #

try {
    $currentRole = [Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()

    if ($currentRole.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "🔓 PowerShell is running as Administrator." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "❌ Error checking administrator status: $($_.Exception.Message)" -ForegroundColor Red
}

# This should already be bound by default, but just in case
Set-PSReadLineKeyHandler -Chord 'Ctrl+Backspace' -Function BackwardKillWord

# Oh-My-Posh wants this
[Console]::OutputEncoding = [Text.Encoding]::UTF8

oh-my-posh init pwsh --config "$env:USERPROFILE\theme-v2.omp.json" | Invoke-Expression

# --------------------------------- #