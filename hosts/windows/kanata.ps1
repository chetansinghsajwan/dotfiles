# Installs kanata on Windows and starts it at logon with the shared config.
# Run from the repo root in an elevated PowerShell: .\hosts\windows\kanata.ps1
$ErrorActionPreference = 'Stop'

$dir = Join-Path $env:LOCALAPPDATA 'kanata'
New-Item -ItemType Directory -Force $dir | Out-Null

$rel = Invoke-RestMethod 'https://api.github.com/repos/jtroo/kanata/releases/latest'
$asset = $rel.assets | Where-Object { $_.name -eq 'kanata.exe' } | Select-Object -First 1
Invoke-WebRequest $asset.browser_download_url -OutFile (Join-Path $dir 'kanata.exe')
Copy-Item (Join-Path $PSScriptRoot '..\shared\kanata\kanata.kbd') (Join-Path $dir 'kanata.kbd') -Force

$action = New-ScheduledTaskAction -Execute (Join-Path $dir 'kanata.exe') `
    -Argument "--cfg `"$(Join-Path $dir 'kanata.kbd')`" --port 6666"
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit 0 -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName 'kanata' -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName 'kanata'
Write-Host "kanata $($rel.tag_name) installed and started."
