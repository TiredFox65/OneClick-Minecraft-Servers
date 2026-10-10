@echo off
:startup
cls
setlocal EnableDelayedExpansion
set "VVERSION=3.0"
for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
title OneClick Minecraft Servers
:ram_check
for /f %%A in ('powershell -Command "(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB -as [int]"') do set "TotalRAM_GB=%%A"
if %TotalRAM_GB% LSS 5 (
echo %ESC%[31mERROR: System RAM below 4GB. WE STRONGLY DISRECOMMEND HOSTING A SERVER ON THIS CRAP.%ESC%[0m
)
:internet_check
set "internet=false"
ping -n 1 google.com >nul && set "internet=true"
if "!internet!"=="false" (
echo %ESC%[33mWARNING: No Internet Connection Detected. Making new servers is not possible.%ESC%[0m
)
:update_check
set "githubversion="
if "!internet!"=="false" (
echo %ESC%[33mWARNING: Cannot check for Updates without an Internet Connection.%ESC%[0m
goto java_check
)
for /f "delims=" %%A in ('powershell -NoProfile -Command "(Invoke-RestMethod 'https://api.github.com/repos/TiredFox65/OneClick-Minecraft-Servers/releases/latest').tag_name" 2^>nul') do set "githubversion=%%A"
if not defined githubversion (
echo %ESC%[31mERROR: Could not check for updates.%ESC%[0m
goto java_check
)
echo Newest Version: %githubversion%
if /I not "%githubversion%"=="%VVERSION%" (
echo %ESC%[33mWARNING: A newer version is available. Older versions might not be secure.^(update using "Update"^)%ESC%[0m
) else (
echo %ESC%[32mNewest Version is Installed.%ESC%[0m
)
:java_check
set "JAVA_VERSION="
set "JAVA_PATH="
java -version >nul 2>&1
for /f "tokens=3" %%i in ('java -version 2^>^&1 ^| findstr /C:"version"') do set "JAVA_VERSION=%%~i"
for /f "delims=" %%i in ('where java.exe 2^>^&1 ^| findstr /C:!JAVA_VERSION!') do set "JAVA_PATH=%%i"
java -version >nul 2>&1 && set "installedjava=1" || set "installedjava=0"
:uninstall_check
if not exist "uninstall.bat" (
>"uninstall.bat" (
echo @echo off
echo set "TARGET=%%~dp0"
echo set "CLEANER=%%TEMP%%\cleanup_%%RANDOM%%.bat"
echo ^(
echo echo @echo off
echo echo timeout /t 2 /nobreak ^^^>nul
echo echo rd /s /q "%%TARGET%%"
echo echo del "%%~f0"
echo ^) ^> "%%CLEANER%%"
echo start "" /b cmd /c ""%%CLEANER%%""
echo exit
)
)
:system_info
if %TotalRAM_GB% GTR 127 (
echo %ESC%[91mTotal %ESC%[33msystem %ESC%[93mRAM %ESC%[92mdetected: %ESC%[36m%TotalRAM_GB% GB %ESC%[34m^(Holy %ESC%[95mMoly^^!^)%ESC%[0m
) else if %TotalRAM_GB% GTR 63 (
echo %ESC%[95mTotal system RAM detected: %TotalRAM_GB% GB ^(Respect^^!^)%ESC%[0m
) else if %TotalRAM_GB% GTR 31 (
echo %ESC%[92mTotal system RAM detected: %TotalRAM_GB% GB%ESC%[0m
) else if %TotalRAM_GB% GTR 15 (
echo %ESC%[33mTotal system RAM detected: %TotalRAM_GB% GB%ESC%[0m
) else if %TotalRAM_GB% GTR 7 (
echo %ESC%[31mTotal system RAM detected: %TotalRAM_GB% GB ^(Seriously?^)%ESC%[0m
)
if installedjava==0 (
echo %ESC%[31mJava is NOT installed or not in PATH.%ESC%[0m
) else (
echo %ESC%[32mJava is installed and in PATH.%ESC%[0m
echo %ESC%[32mJava version: !JAVA_VERSION!%ESC%[0m
echo %ESC%[32mJava found at: !JAVA_PATH!%ESC%[0m
)
if internet=="false" (
echo %ESC%[31mInternet Available: !internet!%ESC%[0m
) else (
echo %ESC%[32mInternet Available: !internet!%ESC%[0m
)
:2
set "internet=false"
ping -n 1 google.com >nul && set "internet=true"
set /p "MODE=Enter Instructions> "
if /I "!MODE!"=="help" goto help1
if /I "!MODE!"=="Create" goto 1
if /I "!MODE!"=="Settings" goto settings
if /I "!MODE!"=="Status" goto status
if /I "!MODE!"=="Graphical" goto GBL
if /I "!MODE!"=="Start" start "MCServer" start.bat && goto 2
if /I "!MODE!"=="Stop" start "tmp" stop.bat && goto 2
if /I "!MODE!"=="Restart" start "tmp" server\restart.bat && goto 2
if /I "!MODE!"=="uninstall" goto uninstall
if /I "!MODE!"=="update" goto update
if /I "!MODE!"=="reload" goto startup
if /I "!MODE!"=="Backups" goto backups
if /I "!MODE!"=="Version" goto Ver
if /I "!MODE!"=="Exit" exit
if /I "!MODE!"=="Clear" goto cls1
echo Syntax Error (try "Help")
goto 2
:update
if "!internet!"=="false" (
echo %ESC%[31mERROR: Cannot update without an Internet connection.%ESC%[0m
goto 2
)
set "githubversion="
for /f "delims=" %%A in ('powershell -NoProfile -Command "(Invoke-RestMethod 'https://api.github.com/repos/TiredFox65/OneClick-Minecraft-Servers/releases/latest').tag_name" 2^>nul') do set "githubversion=%%A"
if not defined githubversion (
echo %ESC%[31mERROR: Could not determine the latest version.%ESC%[0m
goto 2
)
if /I "%VERSION%"=="%githubversion%" (
echo %ESC%[32mNewest Version Already Installed.%ESC%[0m
goto 2
)
echo %ESC%[32mDownloading version %githubversion% ...%ESC%[0m
del "download.bat" 2>nul
curl -fL "https://github.com/TiredFox65/OneClick-Minecraft-Servers/releases/latest/download/main.bat" -o "download.bat"
if not exist "download.bat" (
echo %ESC%[31mERROR: Download failed.%ESC%[0m
goto 2
)
(
echo @echo off
echo timeout /t 2 /nobreak ^>nul
echo copy /y "download.bat" "%~dp0main.bat" ^>nul
echo del "download.bat"
echo start "" "%~dp0main.bat"
echo del "%%~f0"
) > "updater.bat"
echo %ESC%[32mUpdate downloaded. Restarting...%ESC%[0m
start "" /b cmd /c "updater.bat"
exit
:uninstall
echo %ESC%[31mWARNING: This will delete all server files, backups and uninstall the application.%ESC%[0m
set /p "CONFIRMUNINSTALL=Are you sure you want to uninstall?(y/n)> "
if /I "!CONFIRMUNINSTALL!"=="n" goto 2
if /I "!CONFIRMUNINSTALL!"=="y" echo Uninstalling... && start "" /b cmd /c ""uninstall.bat"" && exit
echo %ESC%[33mSyntax Error: Assuming NO...%ESC%[0m
goto 2
:backups
if not exist "backups" mkdir backups
set "SERVERUP=false"
tasklist /FI "IMAGENAME eq java.exe" /NH | findstr /I /C:"java.exe" >nul && set "SERVERUP=true"
if %SERVERUP%==true (
echo %ESC%[31mERROR: Backups can only be done when the server is stopped.%ESC%[0m
goto 2
)
set /p "BACKUPMODE=Enter Backup Instructions> "
if /I "!BACKUPMODE!"=="help" goto help4
if /I "!BACKUPMODE!"=="create" goto backup
if /I "!BACKUPMODE!"=="restore" goto restore
if /I "!BACKUPMODE!"=="back" goto 2
if /I "!BACKUPMODE!"=="load" goto backupload
goto backups
:backupload
set /p "BACKUPNAME=Backup Name to Load> "
if not exist "backups\%BACKUPNAME%.bak" (
echo %ESC%[31mERROR: Backup not found.%ESC%[0m
goto backups
)
del backups\restore.bak 2>nul
rmdir /s /q backups\restore 2>nul
robocopy server backups\restore /E /Z /R:3 /W:5
tar -a -c -f backups\restore.bak -C backups\restore .
rmdir /s /q backups\restore
rmdir /s /q server
mkdir server
tar -xf "backups\%BACKUPNAME%.bak" -C "server"
if exist "server\backups\%BACKUPNAME%\" (
robocopy "server\backups\%BACKUPNAME%" "server" /E /R:3 /W:5 >nul
if errorlevel 8 (
echo %ESC%[31mERROR: Could not move the loaded server files into the server directory.%ESC%[0m
goto backups
)
rmdir /s /q "server\backups\%BACKUPNAME%"
rmdir "server\backups" 2>nul
)
echo %ESC%[32mBackup Loaded.%ESC%[0m
goto backups
:restore
rmdir /s /q server
mkdir server
tar -xf "backups\restore.bak" -C "server"
if exist "server\backups\restore\" (
robocopy "server\backups\restore" "server" /E /R:3 /W:5 >nul
if errorlevel 8 (
echo %ESC%[31mERROR: Could not move the restored server files into the server directory.%ESC%[0m
goto backups
)
rmdir /s /q "server\backups\restore"
rmdir "server\backups" 2>nul
)
echo %ESC%[32mServer Restored.%ESC%[0m
goto backups
:backup
set /p "BACKUPNAME=Enter Backup Name> "
robocopy server backups\%BACKUPNAME% /E /Z /R:3 /W:5
tar -a -c -f backups\%BACKUPNAME%.bak -C backups\%BACKUPNAME% .
rmdir /s /q backups\%BACKUPNAME%
echo %ESC%[32mBackup Complete.%ESC%[0m
goto backups
:help4
echo List of Possible Instructions:
echo Create, Creates a Backup of the Server.
echo Load, Loads a Backup of the Server.
echo Restore, Restores the Server from latest load overwrite.
echo Help, Shows this help.
echo Back, goes back.
goto backups
:status
if /I "!SERVERUP!"=="true" (
echo %ESC%[32mMinecraft server is running.%ESC%[0m
) else (
echo %ESC%[33mNo Java Server or Process Running on Machine.%ESC%[0m
)
goto 2
:cls1
cls
if %TotalRAM_GB% GTR 127 (
echo %ESC%[91mTotal %ESC%[33msystem %ESC%[93mRAM %ESC%[92mdetected: %ESC%[36m%TotalRAM_GB% GB %ESC%[34m^(Holy %ESC%[95mMoly^^!^)%ESC%[0m
) else if %TotalRAM_GB% GTR 63 (
echo %ESC%[95mTotal system RAM detected: %TotalRAM_GB% GB ^(Respect^^!^)%ESC%[0m
) else if %TotalRAM_GB% GTR 31 (
echo %ESC%[92mTotal system RAM detected: %TotalRAM_GB% GB%ESC%[0m
) else if %TotalRAM_GB% GTR 15 (
echo %ESC%[33mTotal system RAM detected: %TotalRAM_GB% GB%ESC%[0m
) else if %TotalRAM_GB% GTR 7 (
echo %ESC%[31mTotal system RAM detected: %TotalRAM_GB% GB ^(Seriously?^)%ESC%[0m
)
if installedjava==0 (
echo %ESC%[31mJava is NOT installed or not in PATH.%ESC%[0m
) else (
echo %ESC%[32mJava is installed and in PATH.%ESC%[0m
echo %ESC%[32mJava version: !JAVA_VERSION!%ESC%[0m
echo %ESC%[32mJava found at: !JAVA_PATH!%ESC%[0m
)
if internet=="false" (
echo %ESC%[31mInternet Available: !internet!%ESC%[0m
) else (
echo %ESC%[32mInternet Available: !internet!%ESC%[0m
)
goto 2
:cls2
if %TotalRAM_GB% GTR 127 (
echo %ESC%[91mTotal %ESC%[33msystem %ESC%[93mRAM %ESC%[92mdetected: %ESC%[36m%TotalRAM_GB% GB %ESC%[34m^(Holy %ESC%[95mMoly^^!^)%ESC%[0m
) else if %TotalRAM_GB% GTR 63 (
echo %ESC%[95mTotal system RAM detected: %TotalRAM_GB% GB ^(Respect^^!^)%ESC%[0m
) else if %TotalRAM_GB% GTR 31 (
echo %ESC%[92mTotal system RAM detected: %TotalRAM_GB% GB%ESC%[0m
) else if %TotalRAM_GB% GTR 15 (
echo %ESC%[33mTotal system RAM detected: %TotalRAM_GB% GB%ESC%[0m
) else if %TotalRAM_GB% GTR 7 (
echo %ESC%[31mTotal system RAM detected: %TotalRAM_GB% GB ^(Seriously?^)%ESC%[0m
)
if installedjava==0 (
echo %ESC%[31mJava is NOT installed or not in PATH.%ESC%[0m
) else (
echo %ESC%[32mJava is installed and in PATH.%ESC%[0m
echo %ESC%[32mJava version: !JAVA_VERSION!%ESC%[0m
echo %ESC%[32mJava found at: !JAVA_PATH!%ESC%[0m
)
if internet=="false" (
echo %ESC%[31mInternet Available: !internet!%ESC%[0m
) else (
echo %ESC%[32mInternet Available: !internet!%ESC%[0m
)
goto settings
:GBL
cd server
echo Not Available
cd ..
goto 2
:help1
echo List of Possible Instructions:
echo Help, Shows this help.
echo Version, Shows the product version.
echo Settings, Opens the Settings menu.
echo Create, Creates/Overwrites the current server.
echo Graphical, Starts the server with a dedicated GUI.
echo Start, Starts the server.
echo Stop, Force-quits the server.^(Use stop in the server console for graceful shutdown.^)
echo Restart, Force-restarts the server.^(Use stop in the server console for graceful shutdown.^)
echo Status, Shows the current server status.
echo Backups, Opens the backup menu.
echo Update, Updates the program.
echo Reload, Reloads the startup configuration.
echo Uninstall, Uninstalls the program.
echo Clear, Clears the screen.
echo Exit, Exits the program.
goto 2
:help3
echo List of Possible Instructions:
echo Help, Shows this help.
echo Ram, Lets you set the RAM Ammount for the Server.
echo Back, goes back.
goto settings
:Ver
echo =======================
echo Version: %VVERSION%
echo =======================
goto 2
:settings
set /p "MODE1=Enter Settings> "
if /I "!MODE1!"=="help" goto help3
if /I "!MODE1!"=="ram" goto setram
if /I "!MODE1!"=="clear" goto cls2
if /I "!MODE1!"=="back" goto 2
echo Syntax Error (try "Help")
goto settings
:setram
set ModsEmpty=1
if exist "server\mods" (
for /f %%A in ('dir /b "server\mods" 2^>nul') do set ModsEmpty=0
)
set /p "XMS=Enter Minimum Ram(GB)> "
echo %XMS%| findstr /r "^[0-9][0-9]*$" >nul || (
echo %ESC%[31mERROR: Minimum RAM must be a number.%ESC%[0m
goto setram
)
if %XMS% LSS 1 (
echo %ESC%[31mERROR: Minimum RAM cannot be below 1GB.%ESC%[0m
goto setram
)
if %XMS% GTR %TotalRAM_GB% (
echo %ESC%[31mERROR: Minimum RAM exceeds system RAM.%ESC%[0m
goto setram
)
:setram2
set /p "XMX=Enter Maximum Ram(GB)> "
echo %XMX%| findstr /r "^[0-9][0-9]*$" >nul || (
echo %ESC%[31mERROR: Maximum RAM must be a number.%ESC%[0m
goto setram2
)
if %XMX% LSS %XMS% (
echo %ESC%[31mERROR: Maximum RAM cannot be lower than Minimum RAM.%ESC%[0m
goto setram2
)
if %XMX% GTR %TotalRAM_GB% (
echo %ESC%[31mERROR: Maximum RAM exceeds system RAM.%ESC%[0m
goto setram2
)
set /a HalfRAM=%TotalRAM_GB% / 2
if %XMX% GTR %HalfRAM% (
echo %ESC%[33mWARNING: You are allocating more than 50%% of system RAM.%ESC%[0m
set /p "RSC=Are you certain you need this much Ram?(y/n)> "
if /I "!RSC!"=="n" goto setram2
if /I "!RSC!"=="y" goto setram3
echo %ESC%[33mSyntax Error: Assuming NO...%ESC%[0m
goto setram2
)
if %XMX% LSS 2 (
echo %ESC%[33mWARNING: Maximum RAM below 2GB may cause instability.%ESC%[0m
set /p "RSC=Are you certain you want this?(y/n)> "
if /I "!RSC!"=="n" goto setram2
if /I "!RSC!"=="y" goto setram3
echo %ESC%[33mSyntax Error: Assuming NO...%ESC%[0m
goto setram2
)
if %ModsEmpty%==0 if %XMX% LSS 4 (
echo %ESC%[33mWARNING: Mods detected. Less than 4GB may cause lag.%ESC%[0m
set /p "RSC=Are you certain you want this?(y/n)> "
if /I "!RSC!"=="n" goto setram2
if /I "!RSC!"=="y" goto setram3
echo %ESC%[33mSyntax Error: Assuming NO...%ESC%[0m
goto setram2
)
if %ModsEmpty%==1 if %XMX% GTR 8 (
echo %ESC%[33mWARNING: No mods detected. More than 8GB is unnecessary.%ESC%[0m
set /p "RSC=Are you certain you want to use an unnecessary amount of Ram?(y/n)> "
if /I "!RSC!"=="n" goto setram2
if /I "!RSC!"=="y" goto setram3
echo %ESC%[33mSyntax Error: Assuming NO...%ESC%[0m
goto setram2
)
:setram3
(
echo -Xms%XMS%G
echo -Xmx%XMX%G
) > server\user_jvm_args.txt
:1
if exist "server\*" (
echo %ESC%[31mWARNING: This Action will Overwrite the Server%ESC%[0m
set /p "AOW=Do you want to Overwrite the Server?(y/n)> "
if /I "!AOW!"=="n" goto 2
if /I "!AOW!"=="y" goto 3
echo %ESC%[33mSyntax Error: Assuming NO...%ESC%[0m
goto 2
)
:3
set "SERVERUP=false"
tasklist /FI "IMAGENAME eq java.exe" /NH | findstr /I /C:"java.exe" >nul && set "SERVERUP=true"
if %SERVERUP%==true (
echo %ESC%[31mERROR: Server can only be Created while Current Server is stopped.%ESC%[0m
goto 2
)
if not exist "server\mods" mkdir server\mods
if not exist "start.bat" (
echo cd server > start.bat
echo start "MCServer" run.bat >> start.bat
echo exit >> start.bat
)
if not exist "stop.bat" (
echo cd server > stop.bat
echo start "tmp" stop.bat >> stop.bat
echo exit >> stop.bat
)
rd /s /q "server"
rd /s /q "mods"
mkdir "server"
mkdir "mods"
set /p "VERSION=Enter the version you want to run> "
if /I "!VERSION!"=="forge-1.7.10" goto forge1.7.10
if /I "!VERSION!"=="forge-1.8.9" goto forge1.8.9
if /I "!VERSION!"=="forge-1.12.2" goto forge1.12.2
if /I "!VERSION!"=="forge-1.16.5" goto forge1.16.5
if /I "!VERSION!"=="forge-1.18.2" goto forge1.18.2
if /I "!VERSION!"=="forge-1.19.2" goto forge1.19.2
if /I "!VERSION!"=="forge-1.20.1" goto forge1.20.1
if /I "!VERSION!"=="forge-1.20.2" goto forge1.20.2
if /I "!VERSION!"=="forge-1.20.4" goto forge1.20.4
if /I "!VERSION!"=="forge-1.21.1" goto forge1.21.1
if /I "!VERSION!"=="forge-1.21.4" goto forge1.21.4
if /I "!VERSION!"=="fabric-1.14.4" goto fabric1.14.4
if /I "!VERSION!"=="fabric-1.15.2" goto fabric1.15.2
if /I "!VERSION!"=="fabric-1.16.5" goto fabric1.16.5
if /I "!VERSION!"=="fabric-1.18.2" goto fabric1.18.2
if /I "!VERSION!"=="fabric-1.19.2" goto fabric1.19.2
if /I "!VERSION!"=="fabric-1.20.1" goto fabric1.20.1
if /I "!VERSION!"=="fabric-1.20.4" goto fabric1.20.4
if /I "!VERSION!"=="fabric-1.21.1" goto fabric1.21.1
if /I "!VERSION!"=="fabric-1.21.4" goto fabric1.21.4
if /I "!VERSION!"=="back" goto 2
if /I "!VERSION!"=="help" goto help2
echo Version not found! (try "Help")
goto 3
:help2
echo List of Possible Entries:
echo Forge-1.7.10
echo Forge-1.8.9
echo Forge-1.12.2
echo Forge-1.16.5
echo Forge-1.18.2
echo Forge-1.19.2
echo Forge-1.20.1
echo Forge-1.20.2
echo Forge-1.20.4
echo Forge-1.21.1
echo Forge-1.21.4
echo Fabric-1.14.4
echo Fabric-1.15.2
echo Fabric-1.16.5
echo Fabric-1.18.2
echo Fabric-1.19.2
echo Fabric-1.20.1
echo Fabric-1.20.4
echo Fabric-1.21.1
echo Fabric-1.21.4
echo Help, shows this help.
echo Back, goes back.
goto 3
:forge1.7.10
echo Loading Forge 1.7.10...
cd server
curl https://maven.minecraftforge.net/net/minecraftforge/forge/1.7.10-10.13.4.1614-1.7.10/forge-1.7.10-10.13.4.1614-1.7.10-installer.jar -o installer.jar
java -jar installer.jar --installServer server
del installer.jar
cd ..
goto fullload
:forge1.8.9
echo Loading Forge 1.8.9...
cd server
curl https://maven.minecraftforge.net/net/minecraftforge/forge/1.8.9-11.15.1.2318-1.8.9/forge-1.8.9-11.15.1.2318-1.8.9-installer.jar -o installer.jar
java -jar installer.jar --installServer server
del installer.jar
cd ..
goto fullload
:forge1.12.2
echo Loading Forge 1.12.2...
curl https://maven.minecraftforge.net/net/minecraftforge/forge/1.12.2-14.23.5.2859/forge-1.12.2-14.23.5.2859-installer.jar -o installer.jar
java -jar installer.jar --installServer server
del installer.jar
goto fullload
:forge1.16.5
echo Loading Forge 1.16.5...
curl https://maven.minecraftforge.net/net/minecraftforge/forge/1.16.5-36.2.34/forge-1.16.5-36.2.34-installer.jar -o installer.jar
java -jar installer.jar --installServer server
del installer.jar
goto fullload
:forge1.18.2
echo Loading Forge 1.18.2...
curl https://maven.minecraftforge.net/net/minecraftforge/forge/1.18.2-40.3.0/forge-1.18.2-40.3.0-installer.jar -o installer.jar
java -jar installer.jar --installServer server
del installer.jar
goto fullload
:forge1.19.2
echo Loading Forge 1.19.2...
curl https://maven.minecraftforge.net/net/minecraftforge/forge/1.19.2-43.5.0/forge-1.19.2-43.5.0-installer.jar -o installer.jar
java -jar installer.jar --installServer server
del installer.jar
goto fullload
:forge1.20.1
echo Loading Forge 1.20.1...
curl https://maven.minecraftforge.net/net/minecraftforge/forge/1.20.1-47.4.10/forge-1.20.1-47.4.10-installer.jar -o installer.jar
java -jar installer.jar --installServer server
del installer.jar
goto fullload
:forge1.20.2
echo Loading Forge 1.20.2...
curl https://maven.minecraftforge.net/net/minecraftforge/forge/1.20.2-48.1.0/forge-1.20.2-48.1.0-installer.jar -o installer.jar
java -jar installer.jar --installServer server
del installer.jar
goto fullload
:forge1.20.4
echo Loading Forge 1.20.4...
curl https://maven.minecraftforge.net/net/minecraftforge/forge/1.20.4-49.2.0/forge-1.20.4-49.2.0-installer.jar -o installer.jar
java -jar installer.jar --installServer server
del installer.jar
goto fullload
:forge1.21.1
echo Loading Forge 1.21.1...
curl https://maven.minecraftforge.net/net/minecraftforge/forge/1.21.1-52.1.0/forge-1.21.1-52.1.0-installer.jar -o installer.jar
java -jar installer.jar --installServer server
del installer.jar
goto fullload
:forge1.21.4
echo Loading Forge 1.21.4...
curl https://maven.minecraftforge.net/net/minecraftforge/forge/1.21.4-54.1.14/forge-1.21.4-54.1.14-installer.jar -o installer.jar
java -jar installer.jar --installServer server
del installer.jar
goto fullload
:fabric1.14.4
echo Loading Fabric 1.14.4...
cd server
curl https://meta.fabricmc.net/v2/versions/loader/1.14.4/0.19.5/1.1.2/server/jar -o server.jar
java -jar server.jar server -mcversion 1.14.4 -loader 0.19.5 -downloadMinecraft -dir server
cd ..
goto fullload
:fabric1.15.2
echo Loading Fabric 1.15.2...
cd server
curl https://meta.fabricmc.net/v2/versions/loader/1.15.2/0.19.5/1.1.2/server/jar -o server.jar
java -jar server.jar server -mcversion 1.15.2 -loader 0.19.5 -downloadMinecraft -dir server
cd ..
goto fullload
:fabric1.16.5
echo Loading Fabric 1.16.5...
cd server
curl https://meta.fabricmc.net/v2/versions/loader/1.16.5/0.19.3/1.1.1/server/jar -o server.jar
java -jar server.jar server -mcversion 1.16.5 -loader 0.19.3 -downloadMinecraft -dir server
cd ..
goto fullload
:fabric1.18.2
echo Loading Fabric 1.18.2...
cd server
curl https://meta.fabricmc.net/v2/versions/loader/1.18.2/0.19.5/1.1.2/server/jar -o server.jar
java -jar server.jar server -mcversion 1.18.2 -loader 0.19.5 -downloadMinecraft -dir server
cd ..
goto fullload
:fabric1.19.2
echo Loading Fabric 1.19.2...
cd server
curl https://meta.fabricmc.net/v2/versions/loader/1.19.2/0.19.5/1.1.2/server/jar -o server.jar
java -jar server.jar server -mcversion 1.19.2 -loader 0.19.5 -downloadMinecraft -dir server
cd ..
goto fullload
:fabric1.20.1
echo Loading Fabric 1.20.1...
curl https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.1/fabric-installer-1.0.1.jar -o installer.jar
java -jar installer.jar server -mcversion 1.20.1 -loader 0.15.11 -downloadMinecraft -dir server
del installer.jar
del server\fabric-server-launch.jar
goto fullload
:fabric1.20.4
echo Loading Fabric 1.20.4...
curl https://meta.fabricmc.net/v2/versions/loader/1.20.4/0.19.5/1.1.2/server/jar -o installer.jar
java -jar installer.jar server -mcversion 1.20.4 -loader 0.15.11 -downloadMinecraft -dir server
del installer.jar
del server\fabric-server-launch.jar
goto fullload
:fabric1.21.1
echo Loading Fabric 1.21.1...
curl https://meta.fabricmc.net/v2/versions/loader/1.21.1/0.19.5/1.1.2/server/jar -o installer.jar
java -jar installer.jar server -mcversion 1.21.1 -loader 0.15.11 -downloadMinecraft -dir server
del installer.jar
del server\fabric-server-launch.jar
goto fullload
:fabric1.21.4
echo Loading Fabric 1.21.4...
curl https://meta.fabricmc.net/v2/versions/loader/1.21.4/0.19.5/1.1.2/server/jar -o installer.jar
java -jar installer.jar server -mcversion 1.21.4 -loader 0.15.11 -downloadMinecraft -dir server
del installer.jar
del server\fabric-server-launch.jar
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
for /f %%A in ('powershell -Command "(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB -as [int]"') do set TotalRAM_GB=%%A
echo Total system RAM detected: %TotalRAM_GB% GB
if /I "!VERSION!"=="forge-1.7.10" goto CRFo1.7.10
if /I "!VERSION!"=="forge-1.8.9" goto CRFo1.8.9
if /I "!VERSION!"=="forge-1.12.2" goto CRFo1.12.2
if /I "!VERSION!"=="forge-1.16.5" goto CRFo1.16.5
if /I "!VERSION!"=="forge-1.20.1" goto CRFo1.20.1
if /I "!VERSION!"=="forge-1.20.2" goto CRFo1.20.2
if /I "!VERSION!"=="forge-1.20.4" goto CRFo1.20.4
if /I "!VERSION!"=="forge-1.21.1" goto CRFo1.21.1
if /I "!VERSION!"=="forge-1.21.4" goto CRFo1.21.4
if /I "!VERSION!"=="fabric-1.14.4" goto CRFa1.14.4
if /I "!VERSION!"=="fabric-1.15.2" goto CRFa1.15.2
if /I "!VERSION!"=="fabric-1.16.5" goto CRFa1.16.5
if /I "!VERSION!"=="fabric-1.18.2" goto CRFa1.18.2
if /I "!VERSION!"=="fabric-1.19.2" goto CRFa1.19.2
if /I "!VERSION!"=="fabric-1.20.1" goto CRFa1.20.1
if /I "!VERSION!"=="fabric-1.20.4" goto CRFa1.20.4
if /I "!VERSION!"=="fabric-1.21.1" goto CRFa1.21.1
if /I "!VERSION!"=="fabric-1.21.4" goto CRFa1.21.4
:CRFo1.7.10
set "STOP_MARKER=minecraft_server.1.7.10.jar"
echo eula=true> server\eula.txt
timeout /t 2 /nobreak
echo eula=true> server\eula.txt
(
echo title MCServer
echo setlocal enabledelayedexpansion
echo java !JVM_ARGS! -jar minecraft_server.1.7.10.jar nogui
echo exit
) > server\run.bat
goto fullload2
:CRFo1.8.9
set "STOP_MARKER=minecraft_server.1.8.9.jar"
echo eula=true> server\eula.txt
timeout /t 2 /nobreak
echo eula=true> server\eula.txt
(
echo title MCServer
echo setlocal enabledelayedexpansion
echo java !JVM_ARGS! -jar minecraft_server.1.8.9.jar nogui
echo exit
) > server\run.bat
goto fullload2
:CRFo1.12.2
set "STOP_MARKER=minecraft_server.1.12.2.jar"
echo eula=true> server\eula.txt
timeout /t 2 /nobreak
echo eula=true> server\eula.txt
(
echo title MCServer
echo setlocal enabledelayedexpansion
echo java !JVM_ARGS! -jar minecraft_server.1.12.2.jar nogui
echo exit
) > server\run.bat
goto fullload2
:CRFo1.16.5
set "STOP_MARKER=minecraft_server.1.16.5.jar"
echo eula=true> server\eula.txt
timeout /t 2 /nobreak
echo eula=true> server\eula.txt
(
echo title MCServer
echo setlocal enabledelayedexpansion
echo java !JVM_ARGS! -jar minecraft_server.1.16.5.jar nogui
echo exit
) > server\run.bat
goto fullload2
:CRFo1.18.2
set "STOP_MARKER=libraries\net\minecraftforge\forge\1.18.2-40.3.0\forge-1.18.2-40.3.0-server.jar"
echo eula=true> server\eula.txt
cd server
start "MCServer" run.bat nogui
timeout /t 5 /nobreak
cd ..
echo eula=true> server\eula.txt
timeout /t 2 /nobreak
echo eula=true> server\eula.txt
(
echo title MCServer
echo setlocal enabledelayedexpansion
echo java !JVM_ARGS! -jar libraries/net/minecraftforge/forge/1.18.2-40.3.0/forge-1.18.2-40.3.0.jar nogui
echo exit
) > server\run.bat
goto fullload2
:CRFo1.19.2
set "STOP_MARKER=libraries\net\minecraftforge\forge\1.19.2-43.5.0\forge-1.19.2-43.5.0-server.jar"
echo eula=true> server\eula.txt
cd server
start "MCServer" run.bat nogui
cd ..
echo eula=true> server\eula.txt
timeout /t 2 /nobreak
echo eula=true> server\eula.txt
(  
echo title MCServer
echo setlocal enabledelayedexpansion
echo java !JVM_ARGS! -jar libraries/net/minecraftforge/forge/1.19.2-43.5.0/forge-1.19.2-43.5.0.jar nogui
echo exit
) > server\run.bat
goto fullload2
:CRFo1.20.1
set "STOP_MARKER=libraries\net\minecraftforge\forge\1.20.1-47.4.10\forge-1.20.1-47.4.10-server.jar"
echo eula=true> server\eula.txt
timeout /t 2 /nobreak
echo eula=true> server\eula.txt
goto fullload2
:CRFo1.20.2
set "STOP_MARKER=libraries\net\minecraftforge\forge\1.20.2-48.1.0\forge-1.20.2-48.1.0-server.jar"
echo eula=true> server\eula.txt
timeout /t 2 /nobreak
echo eula=true> server\eula.txt
goto fullload2
:CRFo1.20.4
set "STOP_MARKER=libraries\net\minecraftforge\forge\1.20.4-49.2.0\forge-1.20.4-49.2.0-server.jar"
echo eula=true> server\eula.txt
timeout /t 2 /nobreak
echo eula=true> server\eula.txt
goto fullload2
:CRFo1.21.1
set "STOP_MARKER=libraries\net\minecraftforge\forge\1.21.1-52.1.0\forge-1.21.1-52.1.0-server.jar"
echo eula=true> server\eula.txt
timeout /t 2 /nobreak
echo eula=true> server\eula.txt
goto fullload2
:CRFo1.21.4
set "STOP_MARKER=libraries\net\minecraftforge\forge\1.21.4-54.1.14\forge-1.21.4-54.1.14-server.jar"
echo eula=true> server\eula.txt
timeout /t 2 /nobreak
echo eula=true> server\eula.txt
goto fullload2
:CRFa1.14.4
set "STOP_MARKER=server.jar"
cd server
start "MCServer" java !JVM_ARGS! -jar server.jar nogui
timeout /t 5 /nobreak
cd ..
echo eula=true> server\eula.txt
timeout /t 2 /nobreak
echo eula=true> server\eula.txt
(
echo title MCServer
echo setlocal enabledelayedexpansion
echo java !JVM_ARGS! -jar server.jar nogui
echo exit
) > server\run.bat
goto fullload2
:CRFa1.15.2
set "STOP_MARKER=server.jar"
cd server
start "MCServer" java !JVM_ARGS! -jar server.jar nogui
timeout /t 5 /nobreak
cd ..
echo eula=true> server\eula.txt
timeout /t 2 /nobreak
echo eula=true> server\eula.txt
(
echo title MCServer
echo setlocal enabledelayedexpansion
echo java !JVM_ARGS! -jar server.jar nogui
echo exit
) > server\run.bat
goto fullload2
:CRFa1.16.5
set "STOP_MARKER=.fabric/server/1.16.5-server.jar"
cd server
start "MCServer" java !JVM_ARGS! -jar .fabric/server/1.16.5-server.jar nogui
timeout /t 5 /nobreak
cd ..
echo eula=true> server\eula.txt
timeout /t 2 /nobreak
echo eula=true> server\eula.txt
(
echo title MCServer
echo setlocal enabledelayedexpansion
echo java !JVM_ARGS! -jar .fabric/server/1.16.5-server.jar nogui
echo exit
) > server\run.bat
goto fullload2
:CRFa1.18.2
set "STOP_MARKER=.fabric/server/1.18.2-server.jar"
cd server
start "MCServer" java !JVM_ARGS! -jar .fabric/server/1.18.2-server.jar nogui
timeout /t 5 /nobreak
cd ..
echo eula=true> server\eula.txt
timeout /t 2 /nobreak
echo eula=true> server\eula.txt
(   
echo title MCServer
echo setlocal enabledelayedexpansion
echo java !JVM_ARGS! -jar .fabric/server/1.18.2-server.jar nogui
echo exit
) > server\run.bat
goto fullload2
:CRFa1.19.2
set "STOP_MARKER=.fabric/server/1.19.2-server.jar"
cd server
start "MCServer" java !JVM_ARGS! -jar .fabric/server/1.19.2-server.jar nogui
timeout /t 5 /nobreak
cd ..
echo eula=true> server\eula.txt
timeout /t 2 /nobreak
echo eula=true> server\eula.txt
(
echo title MCServer
echo setlocal enabledelayedexpansion
echo java !JVM_ARGS! -jar .fabric/server/1.19.2-server nogui
echo exit
) > server\run.bat
goto fullload2
:CRFa1.20.1
set "STOP_MARKER=server.jar"
cd server
start "tmp" java !JVM_ARGS! -jar server.jar nogui
timeout /t 5 /nobreak
cd ..
echo eula=true> server\eula.txt
timeout /t 2 /nobreak
echo eula=true> server\eula.txt
(
echo title MCServer
echo setlocal enabledelayedexpansion
echo java !JVM_ARGS! -jar server.jar nogui
echo exit
) > server\run.bat
goto fullload2
:CRFa1.20.4
set "STOP_MARKER=server.jar"
cd server
start "tmp" java !JVM_ARGS! -jar ..\.fabric\server\1.20.4-server.jar nogui
timeout /t 5 /nobreak
cd ..
echo eula=true> server\eula.txt
timeout /t 2 /nobreak
echo eula=true> server\eula.txt
(
echo title MCServer
echo setlocal enabledelayedexpansion
echo java !JVM_ARGS! -jar ..\.fabric\server\1.20.4-server.jar nogui
echo exit
) > server\run.bat
goto fullload2
:CRFa1.21.1
set "STOP_MARKER=server.jar"
cd server
start "tmp" java !JVM_ARGS! -jar ..\.fabric\server\1.21.1-server.jar nogui
timeout /t 5 /nobreak
cd ..
echo eula=true> server\eula.txt
timeout /t 2 /nobreak
echo eula=true> server\eula.txt
(
echo title MCServer
echo setlocal enabledelayedexpansion
echo java !JVM_ARGS! -jar ..\.fabric\server\1.21.1-server.jar nogui
echo exit
) > server\run.bat
goto fullload2
:CRFa1.21.4
set "STOP_MARKER=server.jar"
cd server
start "tmp" java !JVM_ARGS! -jar ..\.fabric\server\1.21.4-server.jar nogui
timeout /t 5 /nobreak
cd ..
echo eula=true> server\eula.txt
timeout /t 2 /nobreak
echo eula=true> server\eula.txt
(
echo title MCServer
echo setlocal enabledelayedexpansion
echo java !JVM_ARGS! -jar ..\.fabric\server\1.21.4-server.jar nogui
echo exit
) > server\run.bat
goto fullload2
:fullload2
powershell -NoProfile -Command "$marker='!STOP_MARKER!'; $found=$false; foreach ($p in (Get-CimInstance -ClassName Win32_Process)) { if ($p.Name -eq 'java.exe' -and $p.CommandLine -like ('*' + $marker + '*')) { $found=$true; ^& taskkill.exe /PID $p.ProcessId /T /F; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } } }; if (-not $found) { Write-Host 'No matching Minecraft server process found.'; exit 1 }"
if /I "!VERSION!"=="forge-1.18.2" set "strun=java @user_jvm_args.txt @libraries/net/minecraftforge/forge/1.18.2-40.3.0/win_args.txt nogui %%*"
if /I "!VERSION!"=="forge-1.19.2" set "strun=java @user_jvm_args.txt @libraries/net/minecraftforge/forge/1.19.2-43.5.0/win_args.txt nogui %%*"
if /I "!VERSION!"=="forge-1.20.1" set "strun=java @user_jvm_args.txt @libraries/net/minecraftforge/forge/1.20.1-47.4.10/win_args.txt nogui %%*"
if /I "!VERSION!"=="forge-1.20.2" set "strun=java @user_jvm_args.txt @libraries/net/minecraftforge/forge/1.20.2-48.1.0/win_args.txt nogui %%*"
if /I "!VERSION!"=="forge-1.20.4" set "strun=java @user_jvm_args.txt @libraries/net/minecraftforge/forge/1.20.4-49.2.0/win_args.txt nogui %%*"
if /I "!VERSION!"=="forge-1.21.1" set "strun=java @user_jvm_args.txt @libraries/net/minecraftforge/forge/1.21.1-52.1.0/win_args.txt nogui %%*"
if /I "!VERSION!"=="forge-1.21.4" set "strun=java @user_jvm_args.txt @libraries/net/minecraftforge/forge/1.21.4-54.1.14/win_args.txt nogui %%*"
if /I "!VERSION!"=="fabric-1.14.4" set "strun=java @user_jvm_args.txt -jar server.jar nogui %%*"
if /I "!VERSION!"=="fabric-1.15.2" set "strun=java @user_jvm_args.txt -jar server.jar nogui %%*"
if /I "!VERSION!"=="fabric-1.19.2" set "strun=java @user_jvm_args.txt -jar .fabric/server/1.19.2-server.jar nogui %%*"
if /I "!VERSION!"=="fabric-1.20.1" set "strun=java @user_jvm_args.txt -jar server.jar nogui %%*"
if /I "!VERSION!"=="fabric-1.20.4" set "strun=java @user_jvm_args.txt -jar ..\.fabric\server\1.20.4-server.jar nogui %%*"
if /I "!VERSION!"=="fabric-1.21.1" set "strun=java @user_jvm_args.txt -jar ..\.fabric\server\1.21.1-server.jar nogui %%*"
if /I "!VERSION!"=="fabric-1.21.4" set "strun=java @user_jvm_args.txt -jar ..\.fabric\server\1.21.4-server.jar nogui %%*"
(
echo setlocal enabledelayedexpansion
echo title MCServer
echo !strun!
echo exit
) > server\run.bat

(
echo powershell -NoProfile -Command "$marker='!STOP_MARKER!'; $found=$false; foreach ($p in (Get-CimInstance -ClassName Win32_Process)) { if ($p.Name -eq 'java.exe' -and $p.CommandLine -like ('*' + $marker + '*')) { $found=$true; ^& taskkill.exe /PID $p.ProcessId /T /F; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } } }; if (-not $found) { Write-Host 'No matching Minecraft server process found.'; exit 1 }"
echo exit
) > server\stop.bat
echo setlocal enabledelayedexpansion > server\restart.bat
echo start "tmp" stop.bat >> server\restart.bat
echo timeout /t 2 /nobreak >> server\restart.bat
echo start "MCServer" start.bat >> server\restart.bat
echo exit >> server\restart.bat
timeout /t 2 /nobreak
cd server
start "MCServer" run.bat
cd ..
goto 2
