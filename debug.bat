@echo off
setlocal EnableDelayedExpansion
if "%~2"=="" (
set "time=15"
) else (
set "time=%~2"
)
rmdir /s /q debug 2>nul
mkdir debug
copy /y Main.bat debug >nul
del debugreport.txt 2>nul
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
echo %%W NOT WORKING>>debugreport.txt
) else (
echo %%W WORKING>>debugreport.txt
)
rmdir /s /q debug 2>nul
mkdir debug
copy /y Main.bat debug >nul
)
)
del versions.txt 2>nul
start "" debugreport.txt
exit /b 0
:cancel_debug
del versions.txt 2>nul
echo Canceled.
if exist debugreport.txt start "" debugreport.txt
exit /b 0
:single_debug
start "" /D "%CD%\debug" Main.bat
exit /b 0