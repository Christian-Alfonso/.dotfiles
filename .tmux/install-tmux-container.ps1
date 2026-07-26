#
# install-tmux-container.ps1
#
# Script for automatically building and installing a minimal Alpine WSL distro
# to act as a local tmux service. Using a WSL distro instead of an OCI container
# provides full Windows interop — pwsh.exe works, /mnt/c is mounted automatically.
#

[CmdletBinding()]
param(
    # Keep the existing WSL distro as-is instead of unregistering and reimporting from scratch
    [switch] $NoCleanup
)

#
# Tmux WSL Distro Setup
#

$TmuxDistroName = "tmux"
$TmuxDistroPath = "$env:LOCALAPPDATA\WSL\$TmuxDistroName"
$TmuxUser = "tmux"

if (!$NoCleanup) {
    # Guard: warn if the tmux distro is currently running — reinstalling it will
    # terminate all active tmux sessions, including the one this may be called from.
    $RunningDistros = wsl --list --running --quiet 2>&1 |
        ForEach-Object { ($_.ToString()).Trim() -replace '\x00', '' } |
        Where-Object { $_ -match '\S' }

    if ($RunningDistros -contains $TmuxDistroName) {
        $Confirm = Read-Host "Warning: the '$TmuxDistroName' WSL distro is currently running. Reinstalling will terminate all active tmux sessions. Continue? (y/n)"
        if ($Confirm -ne 'y' -and $Confirm -ne 'yes') {
            Write-Host "Aborted."
            return
        }
    }

    Write-Host "Unregistering existing tmux WSL distro (if present)..."
    $null = wsl --unregister $TmuxDistroName 2>&1
    Remove-Item -Recurse -Force $TmuxDistroPath -ErrorAction SilentlyContinue
}

# Download the latest Alpine minirootfs tarball
Write-Host "Fetching latest Alpine release info..."
$AlpineBaseUrl = "https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/x86_64"
$LatestReleasesYaml = [System.Text.Encoding]::UTF8.GetString(
    (Invoke-WebRequest "$AlpineBaseUrl/latest-releases.yaml" -UseBasicParsing).Content
)

$MinirootfsFile = [regex]::Match($LatestReleasesYaml, 'alpine-minirootfs-[\d.]+-x86_64\.tar\.gz').Value
if (!$MinirootfsFile) {
    throw "Could not determine latest Alpine minirootfs filename from release metadata"
}

$TempFolder = New-Item -ItemType Directory -Force -Path "$PSScriptRoot\..\.temp"
$DownloadPath = "$TempFolder\$MinirootfsFile"

Write-Host "Downloading $MinirootfsFile..."
Invoke-WebRequest "$AlpineBaseUrl/$MinirootfsFile" -OutFile $DownloadPath -UseBasicParsing

# Import the Alpine tarball as a WSL distro
Write-Host "Importing Alpine as WSL distro '$TmuxDistroName'..."
New-Item -ItemType Directory -Force -Path $TmuxDistroPath | Out-Null
wsl --import $TmuxDistroName $TmuxDistroPath $DownloadPath

if ($LASTEXITCODE -ne 0) {
    throw "WSL import failed!"
}

Remove-Item -Force $DownloadPath

# Install tmux and dependencies inside the distro
Write-Host "Installing tmux in the WSL distro..."
wsl -d $TmuxDistroName -- sh -c "apk update && apk upgrade && apk add --no-cache tmux ncurses bash"

if ($LASTEXITCODE -ne 0) {
    throw "Failed to install tmux in the WSL distro!"
}

# Create a dedicated non-root user to run tmux
Write-Host "Creating '$TmuxUser' user..."
wsl -d $TmuxDistroName -- sh -c "adduser -D -s /bin/bash $TmuxUser"

if ($LASTEXITCODE -ne 0) {
    throw "Failed to create '$TmuxUser' user!"
}

# Generate machine-local WSL distro keybindings sourced by .tmux.conf
Write-Host "Generating WSL distro keybindings..."
& "$PSScriptRoot\generate-wsl-binds.ps1"

# Copy in the default tmux configuration and the generated WSL bindings
Write-Host "Copying .tmux.conf and .wsl.tmux.conf..."
Copy-Item `
    -Path "$PSScriptRoot\.tmux.conf" `
    -Destination "\\wsl.localhost\$TmuxDistroName\home\$TmuxUser\.tmux.conf" `
    -Force
Copy-Item `
    -Path "$PSScriptRoot\.wsl.tmux.conf" `
    -Destination "\\wsl.localhost\$TmuxDistroName\home\$TmuxUser\.wsl.tmux.conf" `
    -Force

Write-Host "Tmux WSL distro installed successfully."
