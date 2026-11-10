# Downloads kanata into .tmp\kanata in this repo and runs it with the shared config.
# Run from the repo root: .\hosts\windows\kanata.ps1
# Pass -DownloadOnly to download and stage the binary and config without running kanata.
# Pass -Schedule to also register a logon scheduled task and start it instead of running in the foreground (off by default).
# Pass -User NAME (with -Schedule) to run kanata for a different user than the one running this script.
# Each step is logged to the console.
# Keep $version in step with the kanata in nixpkgs (the shared kanata.kbd targets it).
param(
    [string]$User = $env:USERNAME, # the one user kanata runs for (only used with -Schedule)
    [switch]$DownloadOnly,
    [switch]$Schedule
)
$ErrorActionPreference = 'Stop'

$version = '1.12.0'
$zipSha256 = '13947ed78cfa3284bfef854e3c542c74ab366236b72fd9f7e039f8638deead9d' # windows-binaries-x64.zip
$exeInZip = 'kanata_windows_tty_winIOv2_x64.exe'

$dir = Join-Path $PSScriptRoot '..\..\.tmp\kanata'
New-Item -ItemType Directory -Force $dir | Out-Null
$dir = (Resolve-Path $dir).Path
$exe = Join-Path $dir 'kanata.exe'
$cfg = Join-Path $dir 'kanata.kbd'
$port = 6666

function Log([string]$msg) {
    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    Write-Host $line
}

try {
    Log "start: kanata v$version, dir=$dir, schedule=$Schedule, downloadOnly=$DownloadOnly"

    $zip = Join-Path $dir "kanata-$version.zip"
    Log 'downloading zip'
    Invoke-WebRequest "https://github.com/jtroo/kanata/releases/download/v$version/windows-binaries-x64.zip" -OutFile $zip
    Log 'verifying sha256'
    if ((Get-FileHash $zip -Algorithm SHA256).Hash -ne $zipSha256) { throw "kanata $version zip hash mismatch" }

    if ($Schedule) {
        Log 'stopping existing scheduled task'
        Stop-ScheduledTask -TaskName 'kanata' -ErrorAction SilentlyContinue
    }
    Log 'extracting zip'
    Expand-Archive $zip -DestinationPath (Join-Path $dir "kanata-$version") -Force
    Copy-Item (Join-Path $dir "kanata-$version\$exeInZip") $exe -Force
    Log 'copying config'
    Copy-Item (Join-Path $PSScriptRoot '..\shared\kanata\kanata.kbd') $cfg -Force

    if ($Schedule) {
        Log "registering scheduled task for $User"
        $action = New-ScheduledTaskAction -Execute $exe -Argument "--cfg `"$cfg`" --port $port"
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $User
        $principal = New-ScheduledTaskPrincipal -UserId $User -LogonType Interactive -RunLevel Limited
        $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit 0 -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
        Register-ScheduledTask -TaskName 'kanata' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    }

    Log "kanata v$version downloaded to $dir"
    if ($DownloadOnly) { return }
    if ($Schedule) {
        Start-ScheduledTask -TaskName 'kanata'
        Log 'kanata started via scheduled task (also at every logon)'
    } else {
        Log "running: $exe --cfg $cfg --port $port"
        & $exe --cfg $cfg --port $port
        Log "kanata exited with code $LASTEXITCODE"
    }
} catch {
    Log "error: $($_.Exception.Message)"
    throw
}
