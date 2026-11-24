#
# install-tmux-custom-alpine.ps1
#
# Script for automatically building and installing a minimal Alpine WSL distro
# to act as a local tmux service. The custom Alpine distro provides full Windows
# interop - pwsh.exe works, /mnt/c is mounted automatically.
#

[CmdletBinding()]
param(
    # Keep the existing WSL distro as-is instead of unregistering and reimporting from scratch
    [switch] $NoCleanup,

    # Schedule this script under the logged-on account as a limited, non-elevated task.
    [switch] $ScheduleAsUser,

    # Fail instead of prompting when the tmux distro is running.
    [switch] $NoPrompt
)

if ($ScheduleAsUser) {
    Import-Module (Join-Path $PSScriptRoot "..\modules\ScheduledUserTask\ScheduledUserTask.psm1") -Force

    $WorkerArguments = "-NoPrompt"
    if ($NoCleanup) {
        $WorkerArguments = "-NoCleanup $WorkerArguments"
    }

    $ExitCode = Invoke-TemporaryUserTask `
        -TaskName "Dotfiles-Tmux-Alpine-Install" `
        -ScriptPath $PSCommandPath `
        -ScriptArguments $WorkerArguments `
        -Description "Install the dotfiles tmux Alpine WSL distro as the logged-on user" `
        -TimeoutSeconds 1800

    if ($ExitCode -ne 0) {
        throw "User-scoped tmux Alpine installation failed with exit code $ExitCode"
    }

    Write-Host "User-scoped tmux Alpine installation completed successfully."
    return
}

function ConvertToGitMsysPath {
    param([Parameter(Mandatory)][string] $WindowsPath)

    # Git's bundled GPG expects Git/MSYS-style paths for its isolated keyring.
    $MsysPath = $WindowsPath.Replace('\', '/')
    if ($MsysPath -match '^([A-Za-z]):/(.*)$') {
        return "/$($Matches[1].ToLowerInvariant())/$($Matches[2])"
    }
    return $MsysPath
}

function Assert-AlpineRootfsHash {
    param(
        [Parameter(Mandatory)][string] $LatestReleasesYaml,
        [Parameter(Mandatory)][string] $DownloadPath
    )

    # The release metadata is the source of the expected hash for this exact
    # minirootfs tarball. A mismatch means the downloaded file was changed.
    $ReleaseSha256 = [regex]::Match(
        $LatestReleasesYaml,
        '(?ms)flavor:\s*alpine-minirootfs.*?\bsha256:\s*([0-9a-fA-F]{64})'
    ).Groups[1].Value
    if (!$ReleaseSha256) {
        throw "Could not determine the Alpine minirootfs SHA-256 hash from release metadata"
    }

    $ActualSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $DownloadPath).Hash
    if ($ActualSha256 -ne $ReleaseSha256.ToUpperInvariant()) {
        throw "Alpine minirootfs SHA-256 mismatch: expected $ReleaseSha256, got $ActualSha256"
    }

    Write-Host "Alpine release SHA-256 verified."
}

function Assert-AlpineRootfsSignature {
    param(
        [Parameter(Mandatory)][string] $AlpineBaseUrl,
        [Parameter(Mandatory)][string] $MinirootfsFile,
        [Parameter(Mandatory)][string] $DownloadPath,
        [Parameter(Mandatory)][string] $TempFolder
    )

    # Verify the tarball with Alpine's detached signature and a pinned public-key
    # fingerprint. GPG uses an isolated keyring so machine-wide trust settings
    # cannot affect the result.
    $AlpineSigningKeyUrl = "https://alpinelinux.org/keys/ncopa.asc"
    $AlpineSigningFingerprint = "0482D84022F52DF1C4E7CD43293ACD0907D9495A"
    $SignaturePath = "$DownloadPath.asc"
    $AlpineSigningKey = "$TempFolder\alpine-ncopa.asc"
    $GnupgHome = Join-Path $TempFolder "alpine-gpg"

    Write-Host "Downloading Alpine release signature..."
    Invoke-WebRequest "$AlpineBaseUrl/$MinirootfsFile.asc" -OutFile $SignaturePath -UseBasicParsing -TimeoutSec 300
    Invoke-WebRequest $AlpineSigningKeyUrl -OutFile $AlpineSigningKey -UseBasicParsing -TimeoutSec 300

    $GpgCommand = $null
    $GpgOnPath = Get-Command gpg.exe -ErrorAction SilentlyContinue
    if ($GpgOnPath) {
        $GpgCommand = $GpgOnPath.Source
    }
    else {
        $GitGpg = "$env:ProgramFiles\Git\usr\bin\gpg.exe"
        if (Test-Path $GitGpg) {
            $GpgCommand = $GitGpg
        }
    }
    if (!$GpgCommand) {
        throw "GPG is required to verify the Alpine release signature. Git for Windows was not found."
    }

    New-Item -ItemType Directory -Force -Path $GnupgHome | Out-Null

    $GnupgHomeArg = ConvertToGitMsysPath $GnupgHome
    $AlpineSigningKeyArg = ConvertToGitMsysPath $AlpineSigningKey
    $SignaturePathArg = ConvertToGitMsysPath $SignaturePath
    $DownloadPathArg = ConvertToGitMsysPath $DownloadPath

    & $GpgCommand --batch --homedir $GnupgHomeArg --import $AlpineSigningKeyArg 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Could not import the pinned Alpine signing key."
    }

    # Accept only the public key with the known Alpine release-signing fingerprint.
    $KeyListing = & $GpgCommand --batch --homedir $GnupgHomeArg --with-colons --fingerprint
    $PinnedKeyFound = $false
    foreach ($Line in $KeyListing) {
        $FingerprintMatch = [regex]::Match($Line, '^fpr:::::::::([0-9A-F]{40}):$')
        if ($FingerprintMatch.Success -and
            $FingerprintMatch.Groups[1].Value -eq $AlpineSigningFingerprint) {
            $PinnedKeyFound = $true
            break
        }
    }
    if (!$PinnedKeyFound) {
        throw "The imported key did not match the pinned Alpine signing fingerprint $AlpineSigningFingerprint."
    }

    $VerificationOutput = & $GpgCommand --batch --homedir $GnupgHomeArg --status-fd 1 --verify $SignaturePathArg $DownloadPathArg 2>&1
    $ValidSignature = $VerificationOutput -join "`n" -match
        "\[GNUPG:\] VALIDSIG $AlpineSigningFingerprint"
    if ($LASTEXITCODE -ne 0 -or !$ValidSignature) {
        throw "Alpine release signature verification failed:`n$($VerificationOutput -join "`n")"
    }

    Write-Host "Alpine release signature verified (fingerprint $AlpineSigningFingerprint)."
    Remove-Item -Force $SignaturePath, $AlpineSigningKey -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $GnupgHome -ErrorAction SilentlyContinue
}

#
# Tmux WSL Distro Setup
#

$TmuxDistroName = "tmux"
$TmuxDistroPath = "$env:LOCALAPPDATA\WSL\$TmuxDistroName"
$TmuxUser = "tmux"

if (!$NoCleanup) {
    # Guard: warn if the tmux distro is currently running - reinstalling it will
    # terminate all active tmux sessions, including the one this may be called from.
    $RunningDistros = wsl --list --running --quiet 2>&1 |
        ForEach-Object { ($_.ToString()).Trim() -replace '\x00', '' } |
        Where-Object { $_ -match '\S' }

    if ($RunningDistros -contains $TmuxDistroName) {
        if ($NoPrompt) {
            throw "The '$TmuxDistroName' WSL distro is running; refusing to reinstall it non-interactively."
        }

        $Confirm = Read-Host "Warning: the '$TmuxDistroName' WSL distro is currently running. Reinstalling will terminate all active tmux sessions. Continue? [y/N]"
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
    (Invoke-WebRequest "$AlpineBaseUrl/latest-releases.yaml" -UseBasicParsing -TimeoutSec 300).Content
)

$MinirootfsFile = [regex]::Match($LatestReleasesYaml, 'alpine-minirootfs-[\d.]+-x86_64\.tar\.gz').Value
if (!$MinirootfsFile) {
    throw "Could not determine latest Alpine minirootfs filename from release metadata"
}

$TempFolder = New-Item -ItemType Directory -Force -Path "$PSScriptRoot\..\.temp"
$DownloadPath = "$TempFolder\$MinirootfsFile"

Write-Host "Downloading $MinirootfsFile..."
Invoke-WebRequest "$AlpineBaseUrl/$MinirootfsFile" -OutFile $DownloadPath -UseBasicParsing -TimeoutSec 300

# Validate the downloaded bytes against Alpine's signed release metadata.
Assert-AlpineRootfsHash -LatestReleasesYaml $LatestReleasesYaml -DownloadPath $DownloadPath

# Authenticate the same tarball with Alpine's pinned release-signing key.
Assert-AlpineRootfsSignature `
    -AlpineBaseUrl $AlpineBaseUrl `
    -MinirootfsFile $MinirootfsFile `
    -DownloadPath $DownloadPath `
    -TempFolder $TempFolder

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
