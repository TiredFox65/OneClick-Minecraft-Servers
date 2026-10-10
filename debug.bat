@echo off
setlocal EnableDelayedExpansion
rmdir /s /q debug
mkdir debug
copy /y Main.bat debug
cd debug
start "" Main.bat