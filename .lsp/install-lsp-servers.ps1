#Requires -Version 7.0
#Requires -RunAsAdministrator

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Add-PathForCurrentProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Entries
    )

    foreach ($Entry in $Entries) {
        if (-not (Test-Path $Entry)) {
            continue
        }

        $ExistingEntries = $env:Path -split ';'
        if ($ExistingEntries -notcontains $Entry) {
            $env:Path = "$Entry;$env:Path"
        }
    }
}

function InstallRust() {
    if (Get-Command "rustup" -ErrorAction SilentlyContinue) {
        Write-Host "rustup found. Updating Rust toolchain..."
        & rustup update
    }
    else {
        Write-Host "rustup not found. Downloading and installing Rust..."
        $RustupInstaller = "$TempFolder\rustup-init.exe"
        Invoke-WebRequest -Uri "https://win.rustup.rs/x86_64" -OutFile $RustupInstaller
        & $RustupInstaller -y
        Add-PathForCurrentProcess -Entries @("$env:USERPROFILE\.cargo\bin")
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Rust failed to install: $LASTEXITCODE"
    }

    if (-not (Get-Command "cargo" -ErrorAction SilentlyContinue)) {
        throw "cargo not found after Rust installation. Please restart your terminal and re-run the script."
    }

    Write-Host "Rust installation/update complete."
}

function InstallPython() {
    $PythonCommand = Get-Command "python" -ErrorAction SilentlyContinue
    if (-not $PythonCommand) {
        $PythonCommand = Get-Command "py" -ErrorAction SilentlyContinue
    }

    if ($PythonCommand) {
        Write-Host "Python found. Using existing installation."
        return
    }

    Write-Host "Python not found. Resolving latest stable Python release from python.org..."
    $PythonDownloadsPage = Invoke-WebRequest -Uri "https://www.python.org/downloads/windows/"
    $LatestReleaseMatch = [regex]::Match($PythonDownloadsPage.Content, '/downloads/release/python-(\d)(\d{1,2})(\d{1,2})/')

    if (-not $LatestReleaseMatch.Success) {
        throw "Could not determine the latest Python release from python.org."
    }

    $PythonVersion = "$($LatestReleaseMatch.Groups[1].Value).$($LatestReleaseMatch.Groups[2].Value).$($LatestReleaseMatch.Groups[3].Value)"
    Write-Host "Installing Python $PythonVersion..."

    $PythonInstaller = "$TempFolder\python-installer.exe"
    $PythonDownloadUrl = "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-amd64.exe"
    Invoke-WebRequest -Uri $PythonDownloadUrl -OutFile $PythonInstaller

    $Arguments = @(
        "/quiet",
        "InstallAllUsers=0",
        "PrependPath=1",
        "Include_test=0"
    )

    $PythonProcess = Start-Process -FilePath $PythonInstaller -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
    if ($PythonProcess.ExitCode -ne 0) {
        throw "Python failed to install: $($PythonProcess.ExitCode)"
    }

    $PythonUserBin = "$env:LOCALAPPDATA\Programs\Python\Python$($PythonVersion.Split('.')[0])$($PythonVersion.Split('.')[1])\Scripts"
    $PythonUserRoot = "$env:LOCALAPPDATA\Programs\Python\Python$($PythonVersion.Split('.')[0])$($PythonVersion.Split('.')[1])"
    Add-PathForCurrentProcess -Entries @($PythonUserBin, $PythonUserRoot)

    if (-not (Get-Command "python" -ErrorAction SilentlyContinue)) {
        throw "python not found after installation. Please restart your terminal and re-run the script."
    }

    Write-Host "Python installation complete."
}

$TempFolder = New-Item -ItemType Directory -Force -Path "$PSScriptRoot\temp"

Write-Host "Installing language-server toolchain for Copilot CLI-compatible symbol support..."

# Enable WinGet DSC before any winget configure calls below. This is required
# for winget configure to work and only needs to run once (subsequent runs are
# a no-op).
winget configure --enable

# Install Node.js and LLVM through WinGet DSC as the repository already does for
# its other tooling. This is the same pattern used by .nvim/neovim.dsc.yaml.
$LspConfig = Join-Path $PSScriptRoot "lsp.dsc.yaml"
winget configure $LspConfig

# Rust and Python use their own bootstrap flows instead of WinGet, matching the
# recommended installation approach for those toolchains.
InstallRust
InstallPython

# Add the current-process PATH entries that the installers may not have exposed
# yet, without duplicating anything that is already there. Use the currently
# resolved Python version rather than a pinned release folder name.
$PythonVersionPath = if (Get-Command "python" -ErrorAction SilentlyContinue) {
    $PythonExe = (Get-Command "python").Source
    $PythonDir = Split-Path $PythonExe -Parent
    Split-Path $PythonDir -Parent
}
else {
    $null
}

$PythonScriptsPath = if ($PythonVersionPath) { Join-Path $PythonVersionPath "Scripts" } else { $null }

Add-PathForCurrentProcess -Entries @(
    "$env:APPDATA\npm",
    "$env:USERPROFILE\.cargo\bin",
    "$env:USERPROFILE\.dotnet\tools",
"$env:USERPROFILE\go\bin",
"$env:ProgramFiles\Go\bin",
$PythonScriptsPath,
$PythonVersionPath,
"C:\Program Files\LLVM\bin",
"$env:ProgramFiles\dotnet"
)

# Install LSP servers via the language's recommended package manager.
Write-Host "Installing pyright via pip..."
& python -m pip install --upgrade pip
if ($LASTEXITCODE -ne 0) {
    throw "Failed to upgrade pip."
}

& python -m pip install pyright
if ($LASTEXITCODE -ne 0) {
    throw "Failed to install pyright."
}

Write-Host "Installing TypeScript LSP..."
& npm install -g typescript-language-server typescript
if ($LASTEXITCODE -ne 0) {
    throw "Failed to install TypeScript language server."
}

Write-Host "Installing Lua Language Server from the official GitHub release..."
$LuaRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/LuaLS/lua-language-server/releases/latest" -Headers @{
    "Accept" = "application/vnd.github+json"
    "User-Agent" = "PowerShell"
}
$LuaAsset = $LuaRelease.assets |
    Where-Object { $_.name -match 'win32-x64.*\.zip$' -and $_.name -notmatch 'debug' } |
    Sort-Object name -Descending |
    Select-Object -First 1

if (-not $LuaAsset) {
    throw "Could not find a Windows x64 Lua Language Server release asset."
}

$LuaZipPath = Join-Path $TempFolder "lua-language-server.zip"
$LuaExtractRoot = Join-Path $TempFolder "lua-language-server-extract"
$LuaInstallRoot = Join-Path $env:LOCALAPPDATA "lua-language-server"
$LuaBinPath = Join-Path $LuaInstallRoot "bin"

Invoke-WebRequest -Uri $LuaAsset.browser_download_url -OutFile $LuaZipPath
Remove-Item -Recurse -Force $LuaInstallRoot -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force $LuaExtractRoot -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $LuaBinPath | Out-Null
Expand-Archive -Path $LuaZipPath -DestinationPath $LuaExtractRoot -Force

$LuaServerExe = Get-ChildItem -Path $LuaExtractRoot -Recurse -Filter "lua-language-server.exe" | Select-Object -First 1
if (-not $LuaServerExe) {
    throw "Lua Language Server archive did not contain lua-language-server.exe."
}

Copy-Item -Path (Join-Path $LuaServerExe.DirectoryName "*") -Destination $LuaBinPath -Recurse -Force
if (-not (Test-Path (Join-Path $LuaBinPath "lua-language-server.exe"))) {
    throw "Lua Language Server was not installed correctly."
}

Add-PathForCurrentProcess -Entries @($LuaBinPath)

Write-Host "Installing PowerShell Editor Services from the official GitHub release..."
$PSESReleaseUrl = "https://github.com/PowerShell/PowerShellEditorServices/releases/latest/download/PowerShellEditorServices.zip"
$PSESZipPath = Join-Path $TempFolder "PowerShellEditorServices.zip"
$PSESInstallRoot = Join-Path $env:LOCALAPPDATA "PowerShellEditorServices"
$PSESBundlePath = Join-Path $PSESInstallRoot "PowerShellEditorServices"

Invoke-WebRequest -Uri $PSESReleaseUrl -OutFile $PSESZipPath
Remove-Item -Recurse -Force $PSESInstallRoot -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $PSESInstallRoot | Out-Null
Expand-Archive -Path $PSESZipPath -DestinationPath $PSESInstallRoot -Force

$PSESScript = Join-Path $PSESBundlePath "Start-EditorServices.ps1"
if (-not (Test-Path $PSESScript)) {
    throw "PowerShell Editor Services release bundle did not contain Start-EditorServices.ps1."
}

Add-PathForCurrentProcess -Entries @($PSESInstallRoot, $PSESBundlePath)

Write-Host "Installing Docker Language Server from the official Go repository..."
& go install github.com/docker/docker-language-server/cmd/docker-language-server@latest
if ($LASTEXITCODE -ne 0) {
    throw "Failed to install the Docker Language Server."
}

Write-Host "Installing C# language server (OmniSharp)..."
if (-not (Get-Command "dotnet" -ErrorAction SilentlyContinue)) {
    throw "dotnet not found after install; required for OmniSharp."
}

$OmniSharpTool = & dotnet tool list -g | Select-String "OmniSharp.Extensions.LanguageServer"
if ($OmniSharpTool) {
    & dotnet tool update --global OmniSharp.Extensions.LanguageServer --ignore-failed-sources
}
else {
    & dotnet tool install --global OmniSharp.Extensions.LanguageServer --ignore-failed-sources
}
if ($LASTEXITCODE -ne 0) {
    throw "Failed to install OmniSharp."
}

Write-Host "Installing rust-analyzer..."
& cargo install rust-analyzer --locked
if ($LASTEXITCODE -ne 0) {
    throw "Failed to install rust-analyzer."
}

# Verify the commands are available now that all installed tools are on PATH.
$RequiredCommands = @(
    "pyright",
    "typescript-language-server",
    "lua-language-server",
    "docker-language-server",
    "omnisharp",
    "rust-analyzer",
    "clangd"
)

foreach ($CommandName in $RequiredCommands) {
    if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
        throw "Required command '$CommandName' is not available on PATH after installation."
    }
}

$PSESScript = Join-Path $env:LOCALAPPDATA "PowerShellEditorServices\PowerShellEditorServices\Start-EditorServices.ps1"
if (-not (Test-Path $PSESScript)) {
    throw "PowerShell Editor Services release bundle was not installed correctly: $PSESScript"
}

# Copy the static config file into place. This keeps the install and config
# separate, and lets the repository own the actual LSP server mapping.
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ProjectConfigSource = Join-Path $PSScriptRoot "lsp-config.json"
$ProjectConfigPath = Join-Path $RepoRoot ".github\lsp.json"
$CopilotUserDir = Join-Path $HOME ".copilot"
$UserConfigPath = Join-Path $CopilotUserDir "lsp-config.json"

if (-not (Test-Path $ProjectConfigSource)) {
    throw "Missing LSP config template: $ProjectConfigSource"
}

New-Item -ItemType Directory -Force -Path $CopilotUserDir | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $ProjectConfigPath) | Out-Null

Copy-Item -Path $ProjectConfigSource -Destination $UserConfigPath -Force
Copy-Item -Path $ProjectConfigSource -Destination $ProjectConfigPath -Force

Write-Host "Copilot LSP toolchain installed and configured."
Write-Host "User config: $UserConfigPath"
Write-Host "Project config: $ProjectConfigPath"

Remove-Item -Recurse -Force $TempFolder
