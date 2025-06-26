#
# setup.ps1
#
# Script for automatically setting up a new Windows installation to install and copy
# over the necessary configuration files for each program.
#

# Requirements for complete setup that must be manually installed:
#   - PowerShell 7 (to guarantee compatibility with this script)
#   - WSL (to use Tmux, Windows Terminal profiles assume WSL is installed)
#
# Can install these quickly through the following commands:
#   winget install --id Microsoft.PowerShell --source winget
#   (or)
#   winget install --id Microsoft.PowerShell.Preview --source winget
#
#   wsl --install
#
# Then restart your machine for WSL to finish installing.
#
# From:
#   https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.5#install-powershell-using-winget-recommended
#   https://learn.microsoft.com/en-us/windows/wsl/install

#Requires -Version 7.0

[CmdletBinding()]
param(
    [switch] $NormalGit
)

Write-Host "Installing applications, this may take a while..."

# Git needs to be installed before anything, since other programs rely on it
if (-Not $NormalGit) {
    winget install --id Microsoft.Git --source winget
}
else {
    winget install --id Git.Git --source winget
}

#
# Configure Windows Terminal (WT)
#

# Install Oh-My-Posh for PowerShell theme and also Nerd Font installation
winget install --id JanDeDobbeleer.OhMyPosh --source winget

# Install the DroidSansM Nerd Font families
$OhMyPosh = $env:LOCALAPPDATA\Programs\oh-my-posh\bin\oh-my-posh.exe
$OhMyPosh font install droidsansmono

# Copy over the PowerShell 7 profile to $PROFILE so that it runs
# every time that the prompt opens
Start-Process powershell -Verb RunAs -ArgumentList "-NoExit -Command cd '$PWD'; Copy-Item -Path .\Microsoft.PowerShell_profile.ps1 -Destination $PROFILE; exit"

# Install editors
winget install --id Microsoft.VisualStudioCode --source winget
winget install --id Neovim.Neovim --source winget

Write-Host "Copying configurations over for each application..."

# Replace configuration for WT
Copy-Item -Path $PSScriptRoot\.wt\settings.json -Destination "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

# Replace configurations for VSCode
Copy-Item -Path $PSScriptRoot\.vscode\settings.json -Destination "$env:APPDATA\Code\User\settings.json"
Copy-Item -Path $PSScriptRoot\.vscode\keybindings.json -Destination "$env:APPDATA\Code\User\keybindings.json"

# Copy over Neovim configuration to %LocalAppData%\nvim using its own script
$PSScriptRoot\.nvim\CopyConfiguration.ps1

#
# Configure WSL
#

wsl.exe -e ./setup-wsl.sh

#
# Manual Configurations
#

Write-Host "The following need to be manually configured:"
Write-Host "- PowerToys"

