# Setup

Install the tools below, point `setup-env.bat` at them if they are not on your PATH, then run `make.bat`.

## Prerequisites

Recommended versions (what this repo is developed with). Nearby versions usually work; if something breaks, try matching these.

| Tool | Recommended | Used for |
|------|-------------|----------|
| [Node.js](https://nodejs.org/) | 24.18.1 | Asset generators under `tools/` |
| [Python 3](https://www.python.org/) | 3.14.6 | Disk image (`tools/mkdisk.py`), label sort, editor bundle |
| [ACME](https://sourceforge.net/projects/acme-crossass/) | 0.97 ("Zem", 4 Jul 2020) | Assemble the game and UI screens |
| [VICE](https://vice-emu.sourceforge.io/) | 3.10 | `c1541` builds `squaredoom.d64`; `x64sc` runs the game |
| [sidreloc](https://csdb.dk/release/?id=109000) | 1.0 Win32 | Relocate level SIDs from `$1000` → `$9000` for the disk image |

Add each tool’s install folder to your PATH if you can. Otherwise use a local env file (next section).

## Local paths (`setup-env.bat`)

1. Copy the example file:

```bat
copy setup-env.example.bat setup-env.bat
```

2. Edit `setup-env.bat` and uncomment / set paths that match your machine, for example:

```bat
set ACME=C:\path\to\acme.exe
set VICE=C:\path\to\x64sc.exe
set VICE_BIN=C:\path\to\vice\bin
set VICE_CHARGEN=C:\path\to\vice\C64\chargen-901225-01.bin
set SIDRELOC=C:\app\sidreloc\Release\sidreloc.exe
```

- `ACME` — full path to `acme.exe` (or leave unset if `acme` is on PATH)
- `VICE` — full path to `x64sc.exe` (or leave unset and use `VICE_BIN` / PATH)
- `VICE_BIN` — VICE `bin` folder containing `c1541` and usually `x64sc`
- `VICE_CHARGEN` — optional; C64 CHARROM dump for logo PETSCII glyphs. If unset, the build uses an embedded fallback.
- `SIDRELOC` — full path to `sidreloc.exe` (or leave unset if `sidreloc` is on PATH). Win32 build: [CSDb Sidreloc V1.0](https://csdb.dk/release/?id=109000).

`setup-env.bat` is gitignored — do not commit your personal paths.

## Build and run

From the repo root:

```bat
make.bat
```

That assembles the game, builds `squaredoom.d64`, and launches VICE.

### Level editor

```bat
run-editor.bat
```

Bundles the editor HTML and opens it in your browser (needs Python).

## Verify

If something is missing, `make.bat` prints which tool failed and points here. Typical checks:

```bat
node -v
python --version
acme --version
c1541 -help
x64sc -help
sidreloc -V
```
