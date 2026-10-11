@echo off
if /I "%~1"=="-f" goto yes
powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; $result = [System.Windows.Forms.MessageBox]::Show('Do you really want to Uninstall? This will delete all server files, backups and uninstall the application.', 'Uninstall OneClick-Minecraft-Servers', 'YesNo', 'Question'); if ($result -eq 'Yes') { exit 0 } else { exit 1 }"
if errorlevel 1 exit /b 0
:yes
set "TARGET=%~dp0"
set "CLEANER=%TEMP%\cleanup_%RANDOM%.bat"
(
echo @echo off
echo timeout /t 2 /nobreak ^>nul
echo rd /s /q "%TARGET%"
echo del "%~f0"
) > "%CLEANER%"
start "" /b cmd /c ""%CLEANER%""
exit