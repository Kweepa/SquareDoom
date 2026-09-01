@echo off
setlocal
cd /d "%~dp0"

if exist "%~dp0setup-env.bat" call "%~dp0setup-env.bat"

if defined VICE if exist "%VICE%" goto launch
if defined VICE_BIN if exist "%VICE_BIN%\x64sc.exe" (
  set VICE=%VICE_BIN%\x64sc.exe
  goto launch
)
where x64sc >nul 2>&1 && (
  for /f "delims=" %%i in ('where x64sc') do (
    set VICE=%%i
    goto launch
  )
)
echo VICE x64sc not found. Install VICE or set VICE / VICE_BIN in setup-env.bat
echo See SETUP.md
exit /b 1

:launch
set "DISK=%~dp0squaredoom.d64"
set "DRIVEOPTS=-trapdevice8 +drive8truedrive"
if /i "%~1"=="krill" set "DISK=%~dp0squaredoom-krill.d64"
if /i "%~1"=="krill" set "DRIVEOPTS=+trapdevice8 -drive8truedrive"
if /i "%~1"=="--krill" set "DISK=%~dp0squaredoom-krill.d64"
if /i "%~1"=="--krill" set "DRIVEOPTS=+trapdevice8 -drive8truedrive"
if not exist "%DISK%" (
  echo %DISK% missing after build
  exit /b 1
)

start "" "%VICE%" -silent -autostartprgmode 0 %DRIVEOPTS% -8 "%DISK%" -autostart "%DISK%"
