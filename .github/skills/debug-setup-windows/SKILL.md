---
name: debug-setup-windows
description: Debug and explain failures in the Windows setup script using the latest logs without rerunning or elevating privileges. Use when setup-windows.ps1 fails, hangs on an interactive prompt, or needs investigation from a transcript.
---

# Debug Setup for Windows

Use this skill when the user wants to diagnose the repository's Windows bootstrap script at `.setup/setup-windows.ps1` using logs and prior output rather than trying to execute it directly.

## Goal

Act as an advisory debugger for the setup script. Read the most recent run log, explain what failed, identify likely causes, and recommend the next manual step without re-running or escalating privileges.

## Security model

This is a read-only, advisory skill:

- never execute installer or system-changing commands
- never bypass `#Requires -RunAsAdministrator`
- never escalate privileges on the user's behalf
- never auto-retry the setup script
- prefer reading a log file created by the user's own run of the script

## Required behavior

1. Check for a recent log file created by the script or by the user.
2. Prefer the newest log file in a predictable location such as `.setup/setup-windows.log` or `.github/skills/debug-setup-windows/setup-windows.log`.
3. If no log exists, ask the user to run the script manually and save the transcript or output.
4. Read the log and identify the last fatal error, non-zero exit code, or interactive prompt.
5. Explain likely causes in plain language:
   - missing admin rights
   - PowerShell 7 not installed
   - WinGet or winget configuration not available
   - Git or submodule setup not present
   - interactive license prompts or confirmations (`[y/n]`)
   - required tools or prerequisites missing
   - policy or environment restrictions
6. Recommend the next manual action only, without re-running the script.
7. Stop after identifying the root issue and summarizing the evidence from the log.

## Preferred log pattern

The most practical approach is to have `setup-windows.ps1` create a fresh log on each run, such as:

```powershell
$logPath = Join-Path $PSScriptRoot 'setup-windows.log'
Start-Transcript -Path $logPath -Force
try {
    # script body
}
catch {
    Write-Error $_
    throw
}
finally {
    Stop-Transcript
}
```

This gives the user a stable, most-recent-run artifact that the skill can inspect.

## Safer fallback flow

If the user cannot or should not run the script in an elevated session:

1. Ask the user to run the setup command manually in an elevated PowerShell 7 window.
2. Tell them to capture output with a transcript or `Tee-Object`.
3. Read the log or pasted output.
4. Explain what failed, why it failed, and the next manual step.
5. Stop without re-running it.

Example manual command for the user:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\.setup\setup-windows.ps1 2>&1 | Tee-Object .\.github\skills\debug-setup-windows\setup-windows.log
```

## Error handling guidance

- Treat the last log entry or the first fatal exception as the authoritative failure.
- If the log shows an interactive prompt such as `[y/n]`, explain that WinGet is waiting for confirmation and is not a code-level failure in the dotfiles repo itself.
- Distinguish between user interaction problems, environment issues, and script failures.
- Preserve the original evidence rather than replacing it with a generic message.
- Recommend the next step the user can take manually, such as approving the prompt, opening an elevated shell, or installing a missing prerequisite.

## Important constraints

- Never execute the script automatically.
- Never attempt to bypass `#Requires -RunAsAdministrator`.
- Never claim the setup succeeded unless the user confirms a successful run.
- If the script fails, summarize the issue and the evidence in a short, user-friendly explanation.
- Keep the flow user-controlled, observable, and least-privilege by default.
