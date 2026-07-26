#
# update-config-tmux-container.ps1
#
# Script for updating the .tmux.conf config file in the Tmux WSL distro.
# Also regenerates the machine-local .wsl.tmux.conf with current WSL distro bindings.
# Useful for testing a new configuration without reinstalling the distro.
#

$TmuxDistroName = "tmux"
$TmuxUser = "tmux"
$TmuxConfLinuxPath = "/home/$TmuxUser/.tmux.conf"

# Guard: ensure the tmux WSL distro is installed before attempting to update it
$InstalledDistros = wsl --list --quiet 2>&1 |
    ForEach-Object { ($_.ToString()).Trim() -replace '\x00', '' } |
    Where-Object { $_ -match '\S' }

if ($InstalledDistros -notcontains $TmuxDistroName) {
    throw "WSL distro '$TmuxDistroName' is not installed. Run install-tmux-container.ps1 first."
}

Write-Host "Copying .tmux.conf into '$TmuxDistroName' WSL distro..."
Copy-Item `
    -Path "$PSScriptRoot\.tmux.conf" `
    -Destination "\\wsl.localhost\$TmuxDistroName\home\$TmuxUser\.tmux.conf" `
    -Force

Write-Host "Generating WSL distro keybindings..."
& "$PSScriptRoot\generate-wsl-binds.ps1"

Copy-Item `
    -Path "$PSScriptRoot\.wsl.tmux.conf" `
    -Destination "\\wsl.localhost\$TmuxDistroName\home\$TmuxUser\.wsl.tmux.conf" `
    -Force

Write-Host "Reloading tmux configuration..."
$null = wsl -d $TmuxDistroName -u $TmuxUser -- tmux has-session 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "No tmux session is running. Configuration will take effect on next session start."
    return
}

wsl -d $TmuxDistroName -u $TmuxUser -- tmux source-file $TmuxConfLinuxPath 2>&1 | Tee-Object -Variable TmuxOutput

if ($LASTEXITCODE -ne 0) {
    Write-Warning "tmux source-file reported an error: $TmuxOutput"
}
else {
    Write-Host "Done. Tmux configuration updated successfully."
}
