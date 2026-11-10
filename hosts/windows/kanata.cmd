@echo off
rem Downloads kanata into .tmp\kanata in this repo and runs it with the shared config (cmd twin of kanata.ps1).
rem Run from the repo root: hosts\windows\kanata.cmd
rem Pass /downloadonly to download and stage the binary and config without running kanata.
rem Pass /schedule to also register a logon scheduled task and start it instead of running in the foreground (off by default).
rem Pass /user NAME (with /schedule) to run kanata for a different user than the one running this script.
rem Each step is logged to the console.
rem Keep version in step with the kanata in nixpkgs (the shared kanata.kbd targets it).
setlocal EnableDelayedExpansion

set "user=%USERNAME%"
set "schedule="
set "downloadonly="
:args
if "%~1"=="" goto args_done
if /i "%~1"=="/schedule" (set "schedule=1") else if /i "%~1"=="/downloadonly" (set "downloadonly=1") else if /i "%~1"=="/user" (set "user=%~2" & shift) else (echo unknown argument: %~1 & exit /b 1)
shift
goto args
:args_done

set "version=1.12.0"
set "zipSha256=13947ed78cfa3284bfef854e3c542c74ab366236b72fd9f7e039f8638deead9d"
set "exeInZip=kanata_windows_tty_winIOv2_x64.exe"

set "dir=%~dp0..\..\.tmp\kanata"
if not exist "%dir%" mkdir "%dir%" || exit /b 1
for %%d in ("%dir%") do set "dir=%%~fd"
set "port=6666"

call :log "start: kanata v%version%, dir=%dir%, schedule=%schedule%, downloadonly=%downloadonly%"

set "zip=%dir%\kanata-%version%.zip"
call :log "downloading zip"
curl.exe -fsSL -o "%zip%" "https://github.com/jtroo/kanata/releases/download/v%version%/windows-binaries-x64.zip" || (call :log "error: download failed" & exit /b 1)

call :log "verifying sha256"
set "actual="
for /f "skip=1 tokens=*" %%h in ('certutil -hashfile "%zip%" SHA256') do if not defined actual set "actual=%%h"
set "actual=!actual: =!"
if /i not "!actual!"=="%zipSha256%" (call :log "error: kanata %version% zip hash mismatch" & exit /b 1)

if defined schedule (
    call :log "stopping existing scheduled task"
    schtasks /end /tn kanata >nul 2>&1
)
call :log "extracting zip"
set "extract=%dir%\kanata-%version%"
if not exist "%extract%" mkdir "%extract%"
tar -xf "%zip%" -C "%extract%" || (call :log "error: extract failed" & exit /b 1)
copy /y "%extract%\%exeInZip%" "%dir%\kanata.exe" >nul || (call :log "error: copying exe failed" & exit /b 1)
call :log "copying config"
copy /y "%~dp0..\shared\kanata\kanata.kbd" "%dir%\kanata.kbd" >nul || (call :log "error: copying config failed" & exit /b 1)

if defined schedule (
    call :log "registering scheduled task for !user!"
    rem schtasks has no flags for restart-on-failure or no time limit, so register from XML.
    set "xml=%TEMP%\kanata-task.xml"
    > "!xml!" (
        echo ^<?xml version="1.0" encoding="UTF-8"?^>
        echo ^<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task"^>
        echo   ^<Triggers^>^<LogonTrigger^>^<UserId^>!user!^</UserId^>^</LogonTrigger^>^</Triggers^>
        echo   ^<Principals^>^<Principal id="Author"^>^<UserId^>!user!^</UserId^>^<LogonType^>InteractiveToken^</LogonType^>^<RunLevel^>LeastPrivilege^</RunLevel^>^</Principal^>^</Principals^>
        echo   ^<Settings^>^<ExecutionTimeLimit^>PT0S^</ExecutionTimeLimit^>^<RestartOnFailure^>^<Interval^>PT1M^</Interval^>^<Count^>3^</Count^>^</RestartOnFailure^>^</Settings^>
        echo   ^<Actions Context="Author"^>^<Exec^>^<Command^>!dir!\kanata.exe^</Command^>^<Arguments^>--cfg "!dir!\kanata.kbd" --port !port!^</Arguments^>^</Exec^>^</Actions^>
        echo ^</Task^>
    )
    schtasks /create /tn kanata /xml "!xml!" /f >nul || (call :log "error: registering task failed" & exit /b 1)
)

call :log "kanata v%version% downloaded to %dir%"
if defined downloadonly exit /b 0
if defined schedule (
    schtasks /run /tn kanata >nul || (call :log "error: starting task failed" & exit /b 1)
    call :log "kanata started via scheduled task, also at every logon"
    exit /b 0
)
call :log "running: %dir%\kanata.exe --cfg %dir%\kanata.kbd --port %port%"
"%dir%\kanata.exe" --cfg "%dir%\kanata.kbd" --port %port%
set "rc=%errorlevel%"
call :log "kanata exited with code %rc%"
exit /b %rc%

:log
echo %date% %time% %~1
exit /b 0
