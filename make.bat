@echo off
setlocal
cd /d "%~dp0"

call build.bat
if errorlevel 1 exit /b 1

set VICE=C:\app\vice3.10\bin\x64sc.exe
if not exist "%VICE%" (
  echo VICE not found: %VICE%
  exit /b 1
)
if not exist "%~dp0squaredoom.d64" (
  echo squaredoom.d64 missing after build
  exit /b 1
)

rem Attach full d64 (autostart alone can leave a temp disk with only SQUAREDOOM)
start "" "%VICE%" -silent -autostartprgmode 0 -8 "%~dp0squaredoom.d64" -autostart "%~dp0squaredoom.d64"
