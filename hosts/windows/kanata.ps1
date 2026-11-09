# Installs kanata on Windows and starts it at logon with the shared config.
# Run from the repo root in an elevated PowerShell: .\hosts\windows\kanata.ps1
# Pass -User NAME to run kanata for a different user than the one running this script.
# Keep $version in step with the kanata in nixpkgs (the shared kanata.kbd targets it).
param([string]$User = $env:USERNAME) # the one user kanata runs for
$ErrorActionPreference = 'Stop'

$version = '1.12.0'
$zipSha256 = '13947ed78cfa3284bfef854e3c542c74ab366236b72fd9f7e039f8638deead9d' # windows-binaries-x64.zip
$exeInZip = 'kanata_windows_tty_winIOv2_x64.exe'

$dir = Join-Path $env:LOCALAPPDATA 'kanata'
New-Item -ItemType Directory -Force $dir | Out-Null

$zip = Join-Path $env:TEMP "kanata-$version.zip"
Invoke-WebRequest "https://github.com/jtroo/kanata/releases/download/v$version/windows-binaries-x64.zip" -OutFile $zip
if ((Get-FileHash $zip -Algorithm SHA256).Hash -ne $zipSha256) { throw "kanata $version zip hash mismatch" }

Stop-ScheduledTask -TaskName 'kanata' -ErrorAction SilentlyContinue
Expand-Archive $zip -DestinationPath $env:TEMP\kanata-$version -Force
Copy-Item "$env:TEMP\kanata-$version\$exeInZip" (Join-Path $dir 'kanata.exe') -Force
Copy-Item (Join-Path $PSScriptRoot '..\shared\kanata\kanata.kbd') (Join-Path $dir 'kanata.kbd') -Force

$action = New-ScheduledTaskAction -Execute (Join-Path $dir 'kanata.exe') `
    -Argument "--cfg `"$(Join-Path $dir 'kanata.kbd')`" --port 6666"
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $User
$principal = New-ScheduledTaskPrincipal -UserId $User -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit 0 -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName 'kanata' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName 'kanata'
Write-Host "kanata v$version installed and started."
