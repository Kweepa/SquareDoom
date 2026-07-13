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
if not exist "%~dp0squaredoom.prg" (
  echo squaredoom.prg missing after build
  exit /b 1
)

rem mode 1
start "" "%VICE%" -autostart "%~dp0squaredoom.prg" -autostartprgmode 1
