@echo off
setlocal EnableDelayedExpansion
for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
title OneClick Minecraft Servers
echo Checking Architecture...
if not exist "libs" (
echo %ESC%[31mERROR: Libs Missing!%ESC%[0m
echo extracting package...
if not exist "Metadata.package" (
echo %ESC%[31mFATAL ERROR: Package Missing!%ESC%[0m
pause
exit
)
ren "Metadata.package" "Metadata.zip"
powershell -Command "Expand-Archive -Path 'Metadata.zip' -DestinationPath 'libs' -Force"
ren "Metadata.zip" "Metadata.package"
) else echo %ESC%[32mArchitecture Functional...%ESC%[0m
:2
if exist "mods" (
for /f %%A in ('dir /b "mods" 2^>nul') do (
robocopy "mods" "server\mods" /E /NFL /NDL /NJH /NJS /NP
)
)
set /p "MODE=Enter Instructions: "
if /I "%MODE%"=="help" goto help1
if /I "%MODE%"=="Create" goto 1
if /I "%MODE%"=="Version" goto Ver
if /I "%MODE%"=="Exit" exit
echo Syntax Error (try "Help")
goto 2
:help1
echo List of Possible Instructions:
echo Help, Shows this help.
echo Version, Shows the product version.
echo Create, Creates/Overwrites the Current Server.
goto 2
:Ver
echo =======================
echo Version: 0.80
echo =======================
goto 2
:1
for %%A in (server\*) do (
echo %ESC%[31mWARNING: This Action will Overwrite the Server%ESC%[0m
set /p "AOW=Do you want to Overwrite the Server?(y/n)"
if /I "!AOW!"=="n" goto 2
if /I "!AOW!"=="y" goto 3
echo %ESC%[33mSyntax Error: Assuming NO...%ESC%[0m
goto 2
)
:3
if not exist "server" mkdir server
if not exist "mods" mkdir mods
if not exist "run.bat" (
echo cd server > run.bat
echo start "" run.bat >> run.bat
echo cd .. >> run.bat
)
if not exist "stop.bat" (
echo cd server > stop.bat
echo start "" stop.bat >> stop.bat
echo cd .. >> stop.bat
)
rd /s /q "server"
rd /s /q "mods"
mkdir "server"
mkdir "mods"
set /p "VERSION=Enter the version you want to run: "
if /I "%VERSION%"=="forge-1.12.2" goto forge1.12.2
if /I "%VERSION%"=="forge-1.16.5" goto forge1.16.5
if /I "%VERSION%"=="forge-1.20.1" goto forge1.20.1
if /I "%VERSION%"=="fabric-1.16.5" goto fabric1.16.5
if /I "%VERSION%"=="fabric-1.20.1" goto fabric1.20.1
if /I "%VERSION%"=="back" goto 2
if /I "%VERSION%"=="help" goto help2
echo Version not found! (try "Help")
goto 3
:help2
echo List of Possible Entries:
echo Forge-1.12.2
echo Forge-1.16.5
echo Forge-1.20.1
echo Fabric-1.16.5
echo Fabric-1.20.1
echo Help, shows this help.
echo Back, goes back.
goto 3
:forge1.12.2
echo Loading Forge 1.12.2...
robocopy "libs\forge\1.12.2" "server" /E /NFL /NDL /NJH /NJS /NP
goto fullload
:forge1.16.5
echo Loading Forge 1.16.5...
robocopy "libs\forge\1.16.5" "server" /E /NFL /NDL /NJH /NJS /NP
goto fullload
:forge1.20.1
echo Loading Forge 1.20.1...
robocopy "libs\forge\1.20.1" "server" /E /NFL /NDL /NJH /NJS /NP
goto fullload
:fabric1.16.5
echo Loading Fabric 1.16.5...
robocopy "libs\fabric\1.16.5" "server" /E /NFL /NDL /NJH /NJS /NP
goto fullload
:fabric1.20.1
echo Loading Fabric 1.20.1...
robocopy "libs\fabric\1.20.1" "server" /E /NFL /NDL /NJH /NJS /NP
goto fullload
:fullload
echo -Xmx8G > server\user_jvm_args.txt
echo -Xms4G >> server\user_jvm_args.txt
set "JVM_ARGS="
for /f "usebackq tokens=*" %%A in ("server\user_jvm_args.txt") do (
if defined JVM_ARGS (
set "JVM_ARGS=!JVM_ARGS! %%A"
) else (
set "JVM_ARGS=%%A")
)
echo Creation in Progress...
if /I "%VERSION%"=="forge-1.12.2" goto CRFo1.12.2
if /I "%VERSION%"=="forge-1.16.5" goto CRFo1.16.5
if /I "%VERSION%"=="forge-1.20.1" goto CRFo1.20.1
if /I "%VERSION%"=="fabric-1.16.5" goto CRFa1.16.5
if /I "%VERSION%"=="fabric-1.20.1" goto CRFa1.20.1
:CRFo1.12.2
cd server
start "" java !JVM_ARGS! -jar minecraft_server.1.12.2.jar
timeout /t 5 /nobreak
start "" java !JVM_ARGS! -jar forge-1.12.2-14.23.5.2859.jar
cd ..
powershell -Command "(gc 'server\eula.txt') -replace 'eula=false','eula=true' | Out-File 'server\eula.txt' -encoding ascii"
timeout /t 20 /nobreak
powershell -Command "(gc 'server\eula.txt') -replace 'eula=false','eula=true' | Out-File 'server\eula.txt' -encoding ascii"
(
echo setlocal enabledelayedexpansion
echo java !JVM_ARGS! -jar forge-1.12.2-14.23.5.2859.jar
echo pause
) > server\run.bat
goto fullload2
:CRFo1.16.5
cd server
start "" java !JVM_ARGS! -jar minecraft_server.1.16.5.jar
timeout /t 5 /nobreak
start "" java !JVM_ARGS! -jar forge-1.16.5-36.2.34.jar
cd ..
powershell -Command "(gc 'server\eula.txt') -replace 'eula=false','eula=true' | Out-File 'server\eula.txt' -encoding ascii"
timeout /t 20 /nobreak
powershell -Command "(gc 'server\eula.txt') -replace 'eula=false','eula=true' | Out-File 'server\eula.txt' -encoding ascii"
(
echo setlocal enabledelayedexpansion
echo java !JVM_ARGS! -jar forge-1.16.5-36.2.34.jar
echo pause
) > server\run.bat
goto fullload2
:CRFo1.20.1
cd server
start "" run.bat
timeout /t 5 /nobreak
start "" run.bat
cd ..
powershell -Command "(gc 'server\eula.txt') -replace 'eula=false','eula=true' | Out-File 'server\eula.txt' -encoding ascii"
timeout /t 20 /nobreak
powershell -Command "(gc 'server\eula.txt') -replace 'eula=false','eula=true' | Out-File 'server\eula.txt' -encoding ascii"
goto fullload2
:CRFa1.16.5
:CRFa1.20.1
echo %ESC%[31mFATAL ERROR: This Version does not Support Fabric Servers!%ESC%[0m
goto 3
:fullload2
echo setlocal enabledelayedexpansion > server\stop.bat
echo taskkill /f /im java.exe >> server\stop.bat
echo exit >> server\stop.bat
echo setlocal enabledelayedexpansion > server\restart.bat
echo start "" stop.bat >> server\restart.bat
echo timeout /t 2 /nobreak >> server\restart.bat
echo start "" run.bat >> server\restart.bat
powershell -Command "(gc server\server.properties) -replace 'rcon=false','rcon=true' | Out-File server\server.properties -encoding ascii"
echo rcon.password=2Usn4HJa9osTuKwHJfP3 >> server\server.properties
echo rcon.port=25575 >> server\server.properties
taskkill /f /im java.exe
if exist "mods" (
for /f %%A in ('dir /b "mods" 2^>nul') do (
robocopy "mods" "server\mods" /E /NFL /NDL /NJH /NJS /NP
)
)
timeout /t 2 /nobreak
cd server
start "" run.bat
cd ..
goto 2

