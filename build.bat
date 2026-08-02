@echo off
setlocal
cd /d "%~dp0"

if exist "%~dp0setup-env.bat" call "%~dp0setup-env.bat"

if defined ACME if exist "%ACME%" goto run
where acme >nul 2>&1 && set ACME=acme && goto run
echo ACME assembler not found. Install ACME or set ACME in setup-env.bat
echo See SETUP.md
exit /b 1
:run
node tools\cook.js
if errorlevel 1 exit /b 1
node tools\gentables.js
if errorlevel 1 exit /b 1
node tools\genpytab.js
if errorlevel 1 exit /b 1
node tools\genblit.js
if errorlevel 1 exit /b 1
node tools\gendither.js
if errorlevel 1 exit /b 1
node tools\gencharset.js
if errorlevel 1 exit /b 1
node tools\genmuzzle.js
if errorlevel 1 exit /b 1
node tools\genweaponhud.js
if errorlevel 1 exit /b 1
node tools\genshotgun.js
if errorlevel 1 exit /b 1
node tools\genitems.js
if errorlevel 1 exit /b 1
node tools\gen_wall_switch.js
if errorlevel 1 exit /b 1
node tools\genenemysprites.js
if errorlevel 1 exit /b 1
node tools\gensounds.js
if errorlevel 1 exit /b 1
node tools\genlogo.js
if errorlevel 1 exit /b 1
node tools\gensky.js
if errorlevel 1 exit /b 1
"%ACME%" screens\cred.asm
if errorlevel 1 exit /b 1
"%ACME%" screens\help.asm
if errorlevel 1 exit /b 1
"%ACME%" screens\ordr.asm
if errorlevel 1 exit /b 1
"%ACME%" screens\endg.asm
if errorlevel 1 exit /b 1
"%ACME%" -v3 --vicelabels squaredoom.lbl squaredoom.asm
if errorlevel 1 (
  echo.
  echo Assemble failed — check mem: warnings above for free bytes / overlaps.
  echo Ceilings: low^<$2940 minigunB  charset $3800..cock $3b80 mid^<$a000 level  high^<$c800 SQTAB
  echo Under-KERNAL BSS: $e000 SQTAB / COL_* / PROF  ^($01=$35^); MENU.PRG at MENU_BASE
  exit /b 1
)
python tools\sort_lbl.py squaredoom.lbl
if errorlevel 1 exit /b 1
python tools\gen_menu_imports.py squaredoom.lbl menu_imports.asm
if errorlevel 1 exit /b 1
"%ACME%" -v3 screens\menu.asm
if errorlevel 1 (
  echo.
  echo MENU.PRG assemble failed — overlay too large or missing imports.
  exit /b 1
)
python tools\mkdisk.py --out squaredoom.d64 --prg squaredoom.prg --levels levels --screens screens
if errorlevel 1 exit /b 1
echo Built squaredoom.prg and squaredoom.d64
echo Memory: see mem: TOTAL free warn above ^(low+mid+high+menu-budget^)
dir squaredoom.prg
dir squaredoom.d64
dir screens\menu.prg
