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
#   wsl --install Ubuntu
#
# Then restart your machine for WSL to finish installing.
#
# From:
#   https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.5#install-powershell-using-winget-recommended
#   https://learn.microsoft.com/en-us/windows/wsl/install

#Requires -Version 7.0
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    # Download the normal version of Git for Windows
    # instead of the Microsoft fork that has support
    # for other features like VFS for Git (GVFS).
    [switch] $NormalGit,

    # Do not prompt for font installation, either
    # because fonts are already installed or user
    # intends to install separately. Using these
    # configurations without installation of the
    # intended fonts is not recommended, and can
    # lead to issues.
    [switch] $NoFontInstall
)

$ErrorActionPreference = "Stop"

#
# Initial Setup
#

Write-Host "Installing applications, this may take a while..."

# Git needs to be installed before anything, since other programs rely on it
if ($NormalGit) {
    winget install --id Git.Git --source winget
}
else {
    winget install --id Microsoft.Git --source winget
}

# Configure Git for Windows to use the following settings. Need to do the same
# in the WSL setup script, there is no easy way to merge Git settings into the
# existing config file with username/email, aside from using the commands.
& $PSScriptRoot\setup-git.ps1

# If the Neovim submodule does not exist, we will need to pull it using the
# possibly brand new Git installation (as in, do not assume it is in the
# PATH variable yet, find it directly)
if (!(Test-Path "$PSScriptRoot\..\.nvim\*")) {
    Write-Warning "Neovim submodule not checked out, trying to pull it using Git"

    $Git = "$env:ProgramFiles\Git\cmd\git.exe"

    if (!(Test-Path $Git)) {
        throw "Could not find Git after installation, where did it install?"
    }

    & $Git submodule update --init --recursive

    if ($LASTEXITCODE -ne 0) {
        throw "Git submodule pull failed!"
    }
}

#
# Configure Windows Terminal (WT)
#

# Install Oh-My-Posh for PowerShell theme and also Nerd Font installation
& winget install --id JanDeDobbeleer.OhMyPosh --source winget

$OhMyPoshConfig = Convert-Path "$PSScriptRoot\..\theme-v2.omp.json"
Copy-Item -Path $OhMyPoshConfig -Destination "$env:USERPROFILE\theme-v2.omp.json"

# Oh-My-Posh apparently installs to one of two paths, figure out which one
# it is before calling it to install the font
$OhMyPoshPathOne = "$env:LOCALAPPDATA\Programs\oh-my-posh\bin\oh-my-posh.exe"
$OhMyPoshPathTwo = "$env:LOCALAPPDATA\Microsoft\WindowsApps\oh-my-posh.exe"

if (Test-Path $OhMyPoshPathOne) {
    $OhMyPosh = $OhMyPoshPathOne
}
elseif (Test-Path $OhMyPoshPathTwo) {
    $OhMyPosh = $OhMyPoshPathTwo
}
else {
    throw "Could not find Oh-My-Posh after installation, where did it install?"
}

# Copy over the PowerShell 7 profile to $PROFILE so that it runs
# every time that the prompt opens
#
# Rather than copying the file and overwriting the existing profile,
# we will append to the end of this existing profile so that PowerShell
# will not complain about the digital signature not being valid

$ProfileConfigPath = Convert-Path "$PSScriptRoot\..\Microsoft.PowerShell_profile.ps1"
$ProfileConfig = Get-Content $ProfileConfigPath

# Get the existing profile contents to see if the config is already in there
$ExistingProfileConfig = Get-Content $PROFILE

$PSConfigExists = $ExistingProfileConfig | ForEach-Object { $ProfileConfig -contains $_ }

if ($PSConfigExists) {
    Write-Warning "PowerShell profile config seems to already be present, skipping write"
}
else {
    Add-Content $PROFILE ""
    Add-Content $PROFILE $ProfileConfig
}

# Install editors, VSCode needs some additional options set through an override
winget install --id Microsoft.VisualStudioCode --source winget --override "/SILENT /MERGETASKS=\"addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath\""
winget install --id Neovim.Neovim --source winget

Write-Host "Copying configurations over for each application..."

# Replace configuration for WT
Copy-Item -Path "$PSScriptRoot\..\.wt\settings.json" -Destination "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

$VSCodeSettingsPath = "$env:APPDATA\Code\User\settings.json"
$VSCodeKeybindingsPath = "$env:APPDATA\Code\User\keybindings.json"

# If the VSCode settings or keybindings paths do not
# exist yet, they probably need to be created
if ((!(Test-Path $VSCodeSettingsPath)) -or (!(Test-Path $VSCodeKeybindingsPath))) {
    Write-Warning "At least one of the VSCode config paths is missing, opening VSCode once to create them"

    $VSCode = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd"

    # Open VSCode once initially to let it create those paths for us
    # before copying over the configuration files
    & $VSCode
}

# Replace configurations for VSCode
Copy-Item -Path "$PSScriptRoot\..\.vscode\settings.json" -Destination $VSCodeSettingsPath
Copy-Item -Path "$PSScriptRoot\..\.vscode\keybindings.json" -Destination $VSCodeKeybindingsPath

# Copy over Neovim configuration to %LocalAppData%\nvim using its own script
$NeovimCopyConfig = Convert-Path "$PSScriptRoot\..\.nvim\CopyConfiguration.ps1"
& $NeovimCopyConfig

# Also install Neovim dependencies using its own script
$NeovimInstallDepConfig = Convert-Path "$PSScriptRoot\..\.nvim\InstallDependencies.ps1"
& $NeovimInstallDepConfig

# Install PowerToys from configuration
#
# The best documentation for doing this comes from PowerToys itself
# (WinGet has documentation for PowerShell DSC, but it is not as useful here):
# https://github.com/microsoft/PowerToys/blob/main/doc/devdocs/core/settings/dsc-configure.md
#
# The individual DSC module options for the Microsoft.PowerToys.Configure/PowerToysConfigure
# resource to configure the different utilities in PowerToys can be found here:
# https://learn.microsoft.com/en-us/windows/powertoys/dsc-configure/psdsc
$PowerToysConfig = "$PSScriptRoot\..\.powertoys\powertoys.dsc.yaml"
winget configure $PowerToysConfig

# Replace custom layouts for FancyZones in PowerToys, there is no way to do this
# from the above PowerShell DSC configuration file as of writing
$FancyZonesCustomLayoutsPath = "$env:LOCALAPPDATA\Microsoft\PowerToys\FancyZones"

Copy-Item -Path "$PSScriptRoot\..\.powertoys\custom-layouts.json" -Destination $FancyZonesCustomLayoutsPath

#
# Configure WSL
#

Write-Host "Configuring WSL, you will likely be prompted more than once for root password..."

$SetupWSLScriptPath = wsl.exe wslpath -a -u "$PSScriptRoot\setup-wsl.sh".Replace("\", "\\")
wsl.exe -e bash -c "chmod +x $SetupWSLScriptPath; $SetupWSLScriptPath"

if ($LASTEXITCODE -ne 0) {
    throw "WSL configuration failed!"
}

#
# Manual Configurations/Installations
#

# At the moment, only manual installations need the temp folder
$TempFolder = New-Item -ItemType Directory -Force -Path "$PSScriptRoot\..\.temp"

# For now, just the one:
# 1. Font installation
#
# (Keeping the option open to add more later, TBD)
$ManualInstallsRequired = 1

if ($NoFontInstall) {
    $ManualInstallsRequired -= 1
    Write-Warning "Skipping font installation"
}

if ($ManualInstallsRequired -gt 0) {
    $ManualInstallInstructions = (
        "The remaining configurations require basic manual input to complete:`n" +
        $(if (!$NoFontInstall) {
                " - Font installation (DroidSansMono Nerd Font)`n"
            }) +
        "`n" +
        "These manual configurations are required for the configurations to work as expected."
    )

    Write-Warning $ManualInstallInstructions

    $ManualInstallConfirmation = Read-Host "Would you like to continue with manual installations? (y/n)?"
    if ($ManualInstallConfirmation -eq 'y' -or $ManualInstallConfirmation -eq 'yes') {
        #
        # Font Installation (DroidSansMono Nerd Font)
        #

        if (!$NoFontInstall) {
            # Install the DroidSansM Nerd Font families
            # using a direct download of the font and
            # manual installation to the font folder
            $NerdFontLink = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/DroidSansMono.zip"
            $NerdFontFile = Split-Path $NerdFontLink -leaf

            # Download the DroidSansM font family
            Invoke-WebRequest $NerdFontLink -OutFile $NerdFontFile

            $NerdFontFileBaseName = (Get-Item $NerdFontFile).BaseName
            $NerdFontExtractedFiles = New-Item -ItemType Directory -Force -Path "$TempFolder\NerdFont\$NerdFontFileBaseName"

            # Create the .temp directory if it does not already exist
            New-Item -ItemType Directory -Force -Path $NerdFontExtractedFiles

            # Extract the *.otf files for the font from the ZIP file
            # into the .temp directory folder
            Expand-Archive -Force -Path $NerdFontFile -DestinationPath $NerdFontExtractedFiles

            $NerdFontNames = @(
                "DroidSansMNerdFontMono-Regular.otf",
                "DroidSansMNerdFontPropo-Regular.otf",
                "DroidSansMNerdFont-Regular.otf"
            )

            $FontInstallInstructions = (
                "To install the DroidSansMono Nerd Font that is used by many`n" +
                "of these configuration files, you will need to manually install`n" +
                "them from windows that will pop up. Click the `"Install`" button`n" +
                "that will show up in the top left corner of the window for each one.`n" +
                "`n" +
                "There are 3 fonts in this font family that need to be installed:`n" +
                "`n " +
                ($NerdFontNames | ForEach-Object { "- $_`n" })
            )

            Write-Warning $FontInstallInstructions

            $FontInstallConfirmation = Read-Host "Would you like to launch the font installation windows (y/n)?"
            if ($FontInstallConfirmation -eq 'y' -or $FontInstallConfirmation -eq 'yes') {
                Write-Host "Launching windows, please click `"Install`" on each..."

                Start-Sleep -Seconds 2

                foreach ($Name in $NerdFontNames) {
                    # Expect user to install each of the fonts manually
                    # from the windows that pop up here, but there is
                    # no way to validate that they actually did
                    & "$NerdFontExtractedFiles\$Name"

                    # Open these slowly, there was some corruption of one
                    # of the fonts that would happening occasionally where
                    # the window would not open, but the other two would
                    Start-Sleep -Seconds 1
                }

                Write-Host "Done. All font windows should have launched by now."
            }
            else {
                Write-Host "Quitting font installation, use `"-NoFontInstall`" to run again without font installation"
            }

            Write-Host "`n"
            Read-Host "Continue by pressing enter after installation..."

            # Clean up by removing the downloaded file after extracting,
            # the extracted files will be cleaned up at the end by the
            # removal of the .temp folder
            Remove-Item -Force $NerdFontFile
        }
    }
    else {
        Write-Warning "Skipping manual configurations"
    }
}

# Clean up by removing all temporary files now that they are no longer needed
# (always download new ones on next script execution so these are not stale)
Remove-Item -Recurse -Force $TempFolder

Write-Host "Configuration complete!"
