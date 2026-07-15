@echo off
set ACME=C:\app\acme\acme.exe
if exist "%ACME%" goto run
where acme >nul 2>&1 && set ACME=acme && goto run
echo ACME assembler not found. Install ACME or set path in build.bat
exit /b 1
:run
node tools\cook.js
if errorlevel 1 exit /b 1
node tools\gentables.js
if errorlevel 1 exit /b 1
node tools\genblit.js
if errorlevel 1 exit /b 1
node tools\gendither.js
if errorlevel 1 exit /b 1
"%ACME%" -v3 --vicelabels squaredoom.lbl squaredoom.asm
if errorlevel 1 exit /b 1
python tools\sort_lbl.py squaredoom.lbl
if errorlevel 1 exit /b 1
echo Built squaredoom.prg
dir squaredoom.prg
