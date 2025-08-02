# Environment variables
$env:PSREADLINE_VTINPUT=1

# This should already be bound by default, but just in case
Set-PSReadLineKeyHandler -Chord 'Ctrl+Backspace' -Function BackwardKillWord

# Oh-My-Posh wants this
[Console]::OutputEncoding = [Text.Encoding]::UTF8

oh-my-posh init pwsh --config "$env:USERPROFILE\theme-v2.omp.json" | Invoke-Expression