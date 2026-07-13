@echo off
setlocal
cd /d "%~dp0editor"

echo Starting SquareDoom Map Editor...
echo Open http://127.0.0.1:8765/  (this window stays open; Ctrl+C to stop)
echo.

start "" "http://127.0.0.1:8765/"

where python >nul 2>&1
if %ERRORLEVEL%==0 (
  python -m http.server 8765
  goto :eof
)

where py >nul 2>&1
if %ERRORLEVEL%==0 (
  py -m http.server 8765
  goto :eof
)

where npx >nul 2>&1
if %ERRORLEVEL%==0 (
  npx --yes serve -l 8765 .
  goto :eof
)

echo Could not find python, py, or npx. Install Python 3 or Node.js, then try again.
pause
