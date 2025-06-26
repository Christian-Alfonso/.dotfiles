# Environment variables
$env:PSREADLINE_VTINPUT=1

Set-PSReadLineKeyHandler -Chord 'Ctrl+Backspace' -Function BackwardKillWord
# Get-PSReadLineKeyHandler -Chord Ctrl+Backspace, Ctrl+w

# Oh-My-Posh wants this
[Console]::OutputEncoding = [Text.Encoding]::UTF8

oh-my-posh init pwsh --config "$env:USERPROFILE\theme.omp.json" | Invoke-Expression