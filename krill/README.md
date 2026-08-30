# Krill loader v194 — prebuilt for SquareDoom

Binaries only; the loader source is not vendored here. Built from Krill's
`loader` project, repository version 194:

    make -C src PLATFORM=c64 prg INSTALL=2000 RESIDENT=8e00 ZP=60 \
         EXTCONFIGPATH=<repo>/krill/config

with [`krill/config/loaderconfig.inc`](config/loaderconfig.inc): `LOAD_TO_API = 1`,
`UNINSTALL_API = 0`, `DECOMPRESSOR = NONE`, `LOAD_COMPD_API = 0`; everything
else stock.

| file | load address | notes |
|---|---|---|
| `loader.prg` | `$8E00`–`$8EEC` | resident, 236 B. Below the map; boot KERNAL-loads it. |
| `install.prg` | `$2000`–`$3B52` | transient. Run once at boot; MENU and GAME overwrite it. |
| `loadersymbols-c64.inc` | — | the build's own symbol/config dump. |

`$8E00` is always RAM. `$01` must still be `BANK_LOADER` (`$35`) around
`jsr loadraw` (IEC `$DD00`), under `SEI`. GAME/HIGH loads must not cover `$8E00`.
