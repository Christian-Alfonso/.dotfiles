function Get-LoggedOnDesktopUser {
    $Identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    if ($Identity) {
        return $Identity
    }

    return "$env:COMPUTERNAME\$env:USERNAME"
}

function Register-TemporaryUserTask {
    param(
        [Parameter(Mandatory)]
        [string] $TaskName,
        [Parameter(Mandatory)]
        [string] $ScriptPath,
        [string] $ScriptArguments = "",
        [Parameter(Mandatory)]
        [string] $Description,
        [Parameter(Mandatory)]
        [string] $LoggedOnUser
    )

    $PowerShellExecutable = (Get-Process -Id $PID).Path
    if (-not $PowerShellExecutable) {
        throw "Could not determine the PowerShell executable used to run this script"
    }

    $ResolvedScriptPath = (Resolve-Path -LiteralPath $ScriptPath).Path
    $Argument = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$ResolvedScriptPath`""
    if ($ScriptArguments) {
        $Argument += " $ScriptArguments"
    }

    $Action = New-ScheduledTaskAction `
        -Execute $PowerShellExecutable `
        -Argument $Argument
    $Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(5)
    $Principal = New-ScheduledTaskPrincipal `
        -UserId $LoggedOnUser `
        -LogonType Interactive `
        -RunLevel Limited

    Write-Host "Scheduling user-scoped task '$TaskName' for $LoggedOnUser..."
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $Action `
        -Trigger $Trigger `
        -Principal $Principal `
        -Description $Description `
        -Force | Out-Null

    Start-ScheduledTask -TaskName $TaskName
}

function Wait-TemporaryUserTask {
    param(
        [Parameter(Mandatory)]
        [string] $TaskName,
        [int] $TimeoutSeconds = 900
    )

    $Deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    do {
        Start-Sleep -Seconds 1
        $Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
        $TaskResult = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction Stop

        if ($Task.State -in @("Running", "Queued")) {
            continue
        }

        if ($Task.State -eq "Ready" -and $TaskResult.LastTaskResult -eq 267011) {
            continue
        }

        if ($Task.State -eq "Ready") {
            return $TaskResult.LastTaskResult
        }
    } while ((Get-Date) -lt $Deadline)

    throw "Timed out waiting for scheduled user-scope task '$TaskName'"
}

function Invoke-TemporaryUserTask {
    param(
        [Parameter(Mandatory)]
        [string] $TaskName,
        [Parameter(Mandatory)]
        [string] $ScriptPath,
        [string] $ScriptArguments = "",
        [Parameter(Mandatory)]
        [string] $Description,
        [int] $TimeoutSeconds = 900
    )

    $LoggedOnUser = Get-LoggedOnDesktopUser

    try {
        Register-TemporaryUserTask `
            -TaskName $TaskName `
            -ScriptPath $ScriptPath `
            -ScriptArguments $ScriptArguments `
            -Description $Description `
            -LoggedOnUser $LoggedOnUser

        return Wait-TemporaryUserTask `
            -TaskName $TaskName `
            -TimeoutSeconds $TimeoutSeconds
    }
    finally {
        if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
            $RunningTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            if ($RunningTask -and $RunningTask.State -in @("Running", "Queued")) {
                Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            }
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        }
    }
}

Export-ModuleMember -Function @(
    "Get-LoggedOnDesktopUser",
    "Register-TemporaryUserTask",
    "Wait-TemporaryUserTask",
    "Invoke-TemporaryUserTask"
)
