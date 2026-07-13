@echo off
set ACME=C:\app\acme\acme.exe
if exist "%ACME%" goto run
where acme >nul 2>&1 && set ACME=acme && goto run
echo ACME assembler not found. Install ACME or set path in build.bat
exit /b 1
:run
"%ACME%" -v3 squaredoom.asm
if errorlevel 1 exit /b 1
echo Built squaredoom.prg
dir squaredoom.prg
