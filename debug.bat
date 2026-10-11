@echo off
setlocal EnableDelayedExpansion
if /I "%~1"=="survey" goto survey_test
if "%~2"=="" (
set "time=15"
) else (
set "time=%~2"
)
rmdir /s /q debug 2>nul
mkdir debug
copy /y Main.bat debug >nul
del ..\debugreport.txt 2>nul
if /I "%~1"=="all" goto all_debug
goto single_debug
:all_debug
echo Testing All...
start /wait "" /D "%CD%\debug" cmd /c "Main.bat api -g MCVERSIONS > ..\versions.txt"
for /f "usebackq tokens=*" %%V in ("versions.txt") do (
for %%W in (%%V) do (
echo Testing %%W ...
start /wait "" /D "%CD%\debug" cmd /c "Main.bat api -c %%W"
timeout /t !time! /nobreak >nul
taskkill /FI "WINDOWTITLE eq MCServer*" /T /F >nul 2>&1
powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; $result = [System.Windows.Forms.MessageBox]::Show('Did the test for %%W work?', 'Debug.bat', 'YesNoCancel', 'Question'); if ($result -eq 'Yes') { exit 0 } elseif ($result -eq 'No') { exit 1 } else { exit 2 }"
if errorlevel 2 goto cancel_debug
if errorlevel 1 (
echo %%W NOT WORKING>>..\debugreport.txt
) else (
echo %%W WORKING>>..\debugreport.txt
)
rmdir /s /q debug 2>nul
mkdir debug
copy /y Main.bat debug >nul
)
)
del versions.txt 2>nul
start "" ..\debugreport.txt
exit /b 0
:cancel_debug
del versions.txt 2>nul
echo Canceled.
if exist ..\debugreport.txt start "" ..\debugreport.txt
exit /b 0
:single_debug
start "" /D "%CD%\debug" Main.bat
exit /b 0
:survey_test
set "SURVEY_TEST_CONFIRM="
set /p "SURVEY_TEST_CONFIRM=This sends eight debug-tagged test events to the live PostHog project. Type SEND to continue> "
if /I not "!SURVEY_TEST_CONFIRM!"=="SEND" (
echo Survey test canceled.
exit /b 0
)
set "SURVEY_TEST_MAIN=%~dp0Main.bat"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$main=Get-Content -LiteralPath $env:SURVEY_TEST_MAIN -Raw;if($main -notmatch 'VVERSION='){throw 'Could not read VVERSION from Main.bat.'};$version=($main -split 'VVERSION=')[1].Split([char]34)[0].Split([char]10)[0].Trim();if($main -notmatch 'POSTHOG_TOKEN='){throw 'Could not read the PostHog ingestion token from Main.bat.'};$token=($main -split 'POSTHOG_TOKEN=')[1].Split([char]34)[0].Split([char]10)[0].Trim();$debugUuid='debug-'+[guid]::NewGuid().ToString();$names=@('api_get','api_server_created','contribution_mode_entered','contribution_mode_left','first_open','ram_selected','script_opened','server_created');foreach($name in $names){$timestamp=[DateTime]::UtcNow.ToString('o');$properties=@{UUID=$debugUuid;AppVersion=('debug'+$version);timestamp=$timestamp;('$insert_id')=[guid]::NewGuid().ToString()};switch($name){'api_get' {$properties.Requested='debugVVERSION'};'api_server_created' {$properties.MCVersion='debug1.20.1';$properties.Type='debugpaper';$properties.Default=$true;$properties.RAMS=4;$properties.RAMX=8};'server_created' {$properties.MCVersion='debug1.20.1';$properties.Type='debugpaper';$properties.Default=$true;$properties.RAMS=4;$properties.RAMX=8};'ram_selected' {$properties.Default=$true;$properties.RAMS=4;$properties.RAMX=8}};$record=@{api_key=$token;event=$name;distinct_id=$debugUuid;properties=$properties;timestamp=$timestamp};$body=$record | ConvertTo-Json -Depth 8 -Compress;$response=Invoke-WebRequest -Uri 'https://eu.i.posthog.com/i/v0/e/' -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 5 -UseBasicParsing;$ack=$response.Content | ConvertFrom-Json;if([int]$response.StatusCode -ne 200 -or $ack.status -ne 'Ok'){throw ('PostHog did not acknowledge event '+$name)};Write-Host ('Acknowledged '+$name)}"
if errorlevel 1 (
echo Survey test failed. Some earlier events may already have been accepted.
exit /b 1
)
echo All eight debug survey events were acknowledged.
exit /b 0