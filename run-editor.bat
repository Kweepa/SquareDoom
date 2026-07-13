@echo off
setlocal
cd /d "%~dp0editor"

echo Starting SquareDoom Map Editor...
echo Open http://127.0.0.1:8765/  (this window stays open; Ctrl+C to stop)
echo Autosave writes editor\episode1.json
echo.

start "" "http://127.0.0.1:8765/"

where python >nul 2>&1
if %ERRORLEVEL%==0 (
  python serve.py --port 8765
  goto :eof
)

where py >nul 2>&1
if %ERRORLEVEL%==0 (
  py serve.py --port 8765
  goto :eof
)

echo Could not find python or py. Install Python 3, then try again.
pause
