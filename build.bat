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
node tools\gensky.js
if errorlevel 1 exit /b 1
if not exist tmp mkdir tmp
copy /Y tmp_menu_hint_spr.asm tmp\menu_hint_spr.asm >nul
python tools\gen_menufont.py
if errorlevel 1 exit /b 1
python tools\gen_menu_text.py
if errorlevel 1 exit /b 1
python tools\gen_menu_cursor_sprites.py
if errorlevel 1 exit /b 1
python tools\gen_menu_logo_mcm.py
if errorlevel 1 exit /b 1
python tools\gen_splash.py
if errorlevel 1 exit /b 1
"%ACME%" sprites_bank3.asm
if errorlevel 1 exit /b 1
"%ACME%" gfx.asm
if errorlevel 1 exit /b 1

rem Krill disk first (236-byte loadraw, needs TDE / real 1541)
"%ACME%" -DUSE_KRILL=1 -v3 menu.asm
if errorlevel 1 (
  echo.
  echo MENU.PRG assemble failed ^(Krill^) — check end before $4000 / missing tmp\ gens.
  exit /b 1
)
"%ACME%" -DUSE_KRILL=1 boot.asm
if errorlevel 1 exit /b 1
"%ACME%" -DUSE_KRILL=1 -v3 --vicelabels squaredoom-krill.lbl squaredoom.asm
if errorlevel 1 (
  echo.
  echo Assemble failed ^(Krill^) — check mem: warnings. Code must end before Krill $8E00.
  exit /b 1
)
python tools\sort_lbl.py squaredoom-krill.lbl
if errorlevel 1 exit /b 1
python tools\split_game_high.py --lbl squaredoom-krill.lbl
if errorlevel 1 exit /b 1
python tools\mkdisk.py --krill --out squaredoom-krill.d64 --boot boot.prg --levels levels
if errorlevel 1 exit /b 1

rem Default disk: KERNAL LOAD (VICE virtual traps)
"%ACME%" -v3 menu.asm
if errorlevel 1 (
  echo.
  echo MENU.PRG assemble failed — check end before $4000 / missing tmp\ gens.
  exit /b 1
)
"%ACME%" boot.asm
if errorlevel 1 exit /b 1
"%ACME%" -v3 --vicelabels squaredoom.lbl squaredoom.asm
if errorlevel 1 (
  echo.
  echo Assemble failed — check mem: warnings above for free bytes / overlaps.
  echo Ceilings: GAME $0400 code^<$9000 map  py_tab $B000  SQTAB $BC00  screen $C400  sprites $C800-$D7BF  charset $D800
  echo Play default $01=$34; I/O windows $35. Under-KERNAL BSS $e000; kernal scrap after SEC_WDARK_END
  exit /b 1
)
python tools\sort_lbl.py squaredoom.lbl
if errorlevel 1 exit /b 1
python tools\split_game_high.py
if errorlevel 1 exit /b 1
python tools\mkdisk.py --out squaredoom.d64 --boot boot.prg --levels levels
if errorlevel 1 exit /b 1

python tools\gen_vice_mon.py
if errorlevel 1 exit /b 1

echo Built boot.prg splashc.prg splash.prg menu.prg gfx.prg game.prg high.prg
echo Disks: squaredoom.d64 ^(KERNAL, default^) and squaredoom-krill.d64
echo Memory: see mem: code warn above
dir boot.prg
dir splashc.prg
dir splash.prg
dir menu.prg
dir gfx.prg
dir game.prg
dir high.prg
dir squaredoom.d64
dir squaredoom-krill.d64
