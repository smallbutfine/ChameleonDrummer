# Template — Multi-Platform FreePascal/Lazarus Project

This is a **template folder** for starting new FreePascal/Lazarus projects with
a ready-to-use multi-platform build system. It was extracted from the
[ChameleonDrummer](https://github.com/smallbutfine/ChameleonDrummer) project
after 23+ commits of build fixes, CI work, and cross-compilation hardening.

## Quick start

1. **Copy the template** to a new directory (or new git repo):

   ```bash
   cp -r template/ MyNewProject/
   cd MyNewProject/
   git init
   ```

2. **Rename the project.** Replace `MyProject` with your project name in:

   | File | What to change |
   |---|---|
   | `NAME` | The project name (one word, no spaces) |
   | `MyProject.lpr` | Rename to `<YourName>.lpr`, update `program` declaration |
   | `gui/MyProject_gui.lpi` | Rename to `<YourName>_gui.lpi`, update `<Filename>` and `<Title>` |
   | `gui/MyProject_gui.lpr` | Rename to `<YourName>_gui.lpr`, update `program` declaration |
   | `src/MyProjectUnit.pas` | Rename to your actual unit names |
   | `tools/midi_to_tab.lpr` | Replace with your actual helper tool |
   | `tools/step_editor/step_editor.lpi` | Replace with your actual helper GUI tool |
   | `installer/installer.iss` | Update `AppName`, source paths, and `GetPfDir` |
   | `README.md` | Update project name, description, and links |
   | `docs/index.html` | Update project name, description, and links |
   | `.github/workflows/ci.yml` | Update artifact names |
   | `build_all.bat` | Update `APP_NAME` default and target list if needed |

3. **Set your version.** Edit `Assets/version.txt` (e.g. `1.0.0`).

4. **Set your license.** Replace `LICENSE` with your chosen license. The build
   script extracts the company name from the `Copyright` line.

5. **Build.**

   ```bash
   ./build_all.bat --check    # verify toolchain
   ./build_all.bat            # build all 5 targets
   ```

6. **Push to GitHub.** The workflow in `.github/workflows/ci.yml` will build all
   targets on a Windows runner when you trigger it manually.

## What's included

| File / directory | Purpose |
|---|---|
| `NAME` | Project name (read by `build_all.bat`) |
| `LICENSE` | MIT license (build script extracts company name from it) |
| `CONTRIBUTING.md` | Contribution guidelines |
| `AGENTS.md` | Working principles for AI agents (from real sessions) |
| `README.md` | Project overview with build instructions |
| `build_all.bat` | Multi-platform build script (5 targets, packaging, installer) |
| `.gitignore` | Ignores build artifacts, `dist/`, `Deploy/`, etc. |
| `.github/workflows/ci.yml` | GitHub Actions CI (Windows runner, fpcup, all targets) |
| `Assets/version.txt` | Version number (major.minor.patch) |
| `src/` | Pascal source files (shared units) |
| `gui/` | Lazarus GUI project (`.lpi`, `.lpr`) |
| `tools/zip_app.py` | macOS `.app` zip with correct Unix exec bits |
| `tools/midi_to_tab.lpr` | Example CLI helper tool |
| `tools/step_editor/` | Example GUI helper tool |
| `installer/installer.iss` | Inno Setup script (Windows installer) |
| `config/` | Runtime configuration files |
| `docs/index.html` | GitHub Pages landing page |
| `dist/` | Build output (gitignored) |
| `Deploy/` | Release artifacts (gitignored) |

## Targets built by default

| Target | OS | CPU | Widgetset | Cross-compiler | XP prefix |
|---|---|---|---|---|---|
| `win64` | win64 | x86_64 | win32 | `ppcrossx64` | (none) |
| `macos-intel` | darwin | x86_64 | cocoa | `ppcrossx64` | `x86_64-apple-darwin19-` |
| `macos-aarch64` | darwin | aarch64 | cocoa | `ppcrossa64` | `aarch64-apple-darwin19-` |
| `linux-x64` | linux | x86_64 | gtk2 | `ppcrossx64` | `x86_64-linux-gnu-` |
| `linux-arm` | linux | arm | gtk2 | `ppcrossarm` | `arm-linux-gnueabihf-` |

To add or remove targets, edit the `call :do_target` lines in `build_all.bat`
and the target list in `:print_summary`.

## Prerequisites for local builds

- **FPC 3.2.2+** and **Lazarus 3.0+** (via [fpcupdeluxe](https://github.com/LongDirtyAnimAlf/fpcupdeluxe))
- **Cross-compilers**: `ppcrossx64`, `ppcrossa64`, `ppcrossarm` (installed by fpcupdeluxe)
- **Inno Setup 6** (for the Windows installer)
- **Python 3** (for `tools/zip_app.py`)
- **Git Bash** or WSL (for the Linux `tar` packaging steps)

## CI workflow

The GitHub Actions workflow (`.github/workflows/ci.yml`) runs on a
**Windows runner** and:

1. Installs a bootstrap FPC from the official installer
2. Builds the `fpcup` CLI tool from the fpcupdeluxe repository
3. Uses `fpcup` to install FPC, Lazarus, and cross-compilers for
   `x86_64-darwin`, `aarch64-darwin`, and `arm-linux` (including the
   macOS SDK via `--autotools`)
4. Runs `build_all.bat` to build and package all targets
5. Uploads all artifacts

Trigger it manually via **Actions → CI / Cross-Platform Build → Run workflow**.

## Key design decisions (from AGENTS.md)

- **Platform-independent Pascal source** — never hardcode `.exe`, use `{$IFDEF MSWINDOWS}`
- **Guard Windows-only resource includes** — `{$R *.res}` must be wrapped in `{$IFDEF MSWINDOWS}`
- **macOS `.app` zips need Unix exec bits** — use `tools/zip_app.py`, not `Compress-Archive`
- **Linux tarballs need exec bits forced** — two-pass tar with `--mode='u=rwx,go=rx'`
- **Batch files are CRLF** — LF-only batch files fail in confusing ways
- **Never read `%VAR%` in the same block that sets it** — use `!VAR!` with delayed expansion
- **One source of truth per asset** — no duplicate config directories

## License

This template is released under the MIT License (see `LICENSE`). Use it,
modify it, and ship it in your own projects.