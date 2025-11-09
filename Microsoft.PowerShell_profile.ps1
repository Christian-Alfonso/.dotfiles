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

# Needed for arrow keys and other keystroke sequences to work in
# specifically Tmux from WSL (Bash and Zsh work fine without this)
#
# This enables VT (Virtual Terminal) mode instead of normal
# Win32 Console API for the PSReadLine module
$env:PSREADLINE_VTINPUT=1

oh-my-posh init pwsh --config "$env:USERPROFILE\theme-v2.omp.json" | Invoke-Expression

# --------------------------------- #