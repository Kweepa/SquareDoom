@echo off
setlocal
cd /d "%~dp0"

if exist "%~dp0setup-env.bat" call "%~dp0setup-env.bat"

call build.bat
if errorlevel 1 exit /b 1

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
if not exist "%~dp0squaredoom.d64" (
  echo squaredoom.d64 missing after build
  exit /b 1
)

rem Attach full d64 (autostart alone can leave a temp disk with only SQUAREDOOM)
start "" "%VICE%" -silent -autostartprgmode 0 -8 "%~dp0squaredoom.d64" -autostart "%~dp0squaredoom.d64"
