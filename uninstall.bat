@echo off
set "TARGET=%~dp0"
set "CLEANER=%TEMP%\cleanup_%RANDOM%.bat"

(
    echo @echo off
    echo timeout /t 2 /nobreak ^>nul
    echo rd /s /q "%TARGET%"
    echo del "%%~f0"
) > "%CLEANER%"

start "" /b cmd /c ""%CLEANER%""
exit