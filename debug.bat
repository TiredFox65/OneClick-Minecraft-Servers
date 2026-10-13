@echo off
setlocal EnableExtensions EnableDelayedExpansion
rem Usage: debug.bat [all | debug | single | list | help]
rem Exit codes: 0 = all tests passed; 1 = a test or harness failed; 2 = survey confirmation canceled.
if /I "%~1"=="survey" goto survey_test
if /I "%~1"=="all" goto run_all
if /I "%~1"=="list" goto run_harness
if /I "%~1"=="help" goto run_harness
goto run_gui

:run_all
set "HARNESS=%~dp0debug-harness.ps1"
if not exist "%HARNESS%" (
  echo ERROR: Missing debug-harness.ps1.
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%HARNESS%" all %2 %3 %4 %5 %6 %7
exit /b %errorlevel%

:run_harness
set "HARNESS=%~dp0debug-harness.ps1"
if not exist "%HARNESS%" (
  echo ERROR: Missing debug-harness.ps1.
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%HARNESS%" %*
exit /b %errorlevel%

:run_gui
set "DEBUG_DIR=%~dp0debug"
if not exist "%DEBUG_DIR%\" mkdir "%DEBUG_DIR%"
if errorlevel 1 (
  echo ERROR: Could not create the debug directory "%DEBUG_DIR%".
  exit /b 1
)
copy /y "%~dp0Main.bat" "%DEBUG_DIR%\Main.bat" >nul
if errorlevel 1 (
  echo ERROR: Could not copy Main.bat into "%DEBUG_DIR%".
  exit /b 1
)
start "" /D "%DEBUG_DIR%" cmd /c Main.bat
exit /b 0

:survey_test
set "SURVEY_TEST_CONFIRM="
set /p "SURVEY_TEST_CONFIRM=This sends eight debug-tagged test events to the live PostHog project. Type SEND to continue> "
if /I not "!SURVEY_TEST_CONFIRM!"=="SEND" (
  echo Survey test canceled.
  exit /b 2
)
set "SURVEY_TEST_MAIN=%~dp0Main.bat"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$main=Get-Content -LiteralPath $env:SURVEY_TEST_MAIN -Raw;if($main -notmatch 'VVERSION='){throw 'Could not read VVERSION from Main.bat.'};$version=($main -split 'VVERSION=')[1].Split([char]34)[0].Split([char]10)[0].Trim();if($main -notmatch 'POSTHOG_TOKEN='){throw 'Could not read the PostHog ingestion token from Main.bat.'};$token=($main -split 'POSTHOG_TOKEN=')[1].Split([char]34)[0].Split([char]10)[0].Trim();$debugUuid='debug-'+[guid]::NewGuid().ToString();$names=@('api_get','api_server_created','contribution_mode_entered','contribution_mode_left','first_open','ram_selected','script_opened','server_created');foreach($name in $names){$timestamp=[DateTime]::UtcNow.ToString('o');$properties=@{UUID=$debugUuid;AppVersion=('debug'+$version);timestamp=$timestamp;('$insert_id')=[guid]::NewGuid().ToString()};switch($name){'api_get' {$properties.Requested='debugVVERSION'};'api_server_created' {$properties.MCVersion='debug1.20.1';$properties.Type='debugpaper';$properties.Default=$true;$properties.RAMS=4;$properties.RAMX=8};'server_created' {$properties.MCVersion='debug1.20.1';$properties.Type='debugpaper';$properties.Default=$true;$properties.RAMS=4;$properties.RAMX=8};'ram_selected' {$properties.Default=$true;$properties.RAMS=4;$properties.RAMX=8}};$record=@{api_key=$token;event=$name;distinct_id=$debugUuid;properties=$properties;timestamp=$timestamp};$body=$record | ConvertTo-Json -Depth 8 -Compress;$response=Invoke-WebRequest -Uri 'https://eu.i.posthog.com/i/v0/e/' -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 5 -UseBasicParsing;$ack=$response.Content | ConvertFrom-Json;if([int]$response.StatusCode -ne 200 -or $ack.status -ne 'Ok'){throw ('PostHog did not acknowledge event '+$name)};Write-Host ('Acknowledged '+$name)}"
if errorlevel 1 (
  echo Survey test failed. Some earlier events may already have been accepted.
  exit /b 1
)
echo All eight debug survey events were acknowledged.
exit /b 0
