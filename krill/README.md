# Krill loader v194 — prebuilt for SquareDoom

Binaries only; the loader source is not vendored here. Built from Krill's
`loader` project, repository version 194:

    make -C src PLATFORM=c64 prg INSTALL=2000 RESIDENT=c400 ZP=60 \
         EXTCONFIGPATH=<repo>/krill/config

with [`krill/config/loaderconfig.inc`](config/loaderconfig.inc): `LOAD_TO_API = 1`,
`UNINSTALL_API = 0`, `DECOMPRESSOR = NONE`, `LOAD_COMPD_API = 0`; everything
else stock.

The committed `loader.prg` is that v194 resident at `$C400` (236 B). Install
`$2000` / ZP `$60` are unchanged. If ca65 is unavailable, rebase the same
binary (`RESIDENT` `$8F14` → `$C400`); do not relocate `install.prg`.

| file | load address | notes |
|---|---|---|
| `loader.prg` | `$C400`–`$C4EC` | resident, 236 B. Always-RAM hole between screen `$C000` and sprites `$C800`. Boot KERNAL-loads it. |
| `install.prg` | `$2000`–`$3B52` | transient. Run once at boot; MENU and GAME overwrite it. |
| `loadersymbols-c64.inc` | — | the build's own symbol/config dump. |

`$C400` is always RAM (not under I/O). `$01` must still be `BANK_LOADER` (`$35`) around
`jsr loadraw` (IEC `$DD00`), under `SEI`. The GAME image is `$0400`–`$B800` and
does not cover `$C400`.
