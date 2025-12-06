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

# Needed for arrow keys and other keystroke sequences to work in
# specifically Tmux from WSL (Bash and Zsh work fine without this)
#
# This enables VT (Virtual Terminal) mode instead of normal
# Win32 Console API for the PSReadLine module
$env:PSREADLINE_VTINPUT=1

# For some reason, this needs to be manually bound so that the corresponding
# sequence sent by Windows Terminal for Ctrl+Backspace works properly when
# the PSREADLINE_VTINPUT environment variable is set (which, in turn, needs
# to be set for SSH connections to a PowerShell 7 prompt to have both working
# Ctrl+Left/Right and Ctrl+Backspace chords for word navigation/deletion)
Set-PSReadLineKeyHandler -Chord Alt+Backspace -Function BackwardKillWord

# Explicitly set alias for VSCode Insiders, because "code-insiders"
# is longer to type than just using "codei" as the alias name
Set-Alias -Name codei -Value "$env:LOCALAPPDATA\Programs\Microsoft VS Code Insiders\bin\code-insiders.cmd"

# Oh-My-Posh wants this
[Console]::OutputEncoding = [Text.Encoding]::UTF8

oh-my-posh init pwsh --config "$env:USERPROFILE\theme-v2.omp.json" | Invoke-Expression

# --------------------------------- #