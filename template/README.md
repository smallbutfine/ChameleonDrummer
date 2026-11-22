# MyProject

**One-line description of your project** — a FreePascal/Lazarus application
that does something useful.

## What it does

- **Feature 1** — description
- **Feature 2** — description
- **Cross-platform** — Windows (x86_64), macOS (Intel + Apple Silicon) and
  Linux (x86_64 + ARM)

## Downloads

Prebuilt binaries are attached to every
[GitHub Release](https://github.com/yourname/MyProject/releases):

| Platform | Artifact |
|---|---|
| Windows 64-bit | `MyProject_<version>_Setup.exe` (installer) |
| macOS Intel | `MyProject_gui<version>-macos-intel.zip` |
| macOS Apple Silicon | `MyProject_gui<version>-macos-aarch64.zip` |
| Linux x86_64 | `MyProject<version>-linux-x64.tar.gz` |
| Linux ARM | `MyProject<version>-linux-arm.tar.gz` |

Unzip the macOS archive and drag `MyProject_gui.app` to `/Applications`.
The app is not code-signed, so on first launch use **right-click → Open**
(or `xattr -dr com.apple.quarantine` on the terminal).

## Installation / Build

### Prerequisites

- FreePascal Compiler (FPC) 3.2.2+ or Lazarus IDE 3.0+
- Lazarus/LCL for the GUI
- For a full multi-platform build: the FPC cross-compilers
  (`ppcrossx64`, `ppcrossa64`, `ppcrossarm`) and Inno Setup 6
- Python 3 (for `tools/zip_app.py` — macOS bundle zipping with correct Unix modes)

### Build everything (all platforms)

From the repository root, in Git Bash or `cmd.exe`:

```bash
./build_all.bat            # all 5 targets + packages into Deploy/
./build_all.bat --check    # verify the toolchain only, build nothing
```

The script builds every target, then writes the release artifacts to
`Deploy/`. It exits non-zero if any target fails and prints a summary.

Useful environment variables:

| Variable | Effect |
|---|---|
| `FPC_DIR`, `LAZBUILD`, `CROSS_BIN_DIR`, `ISCC`, `TAR` | override the toolchain paths |
| `NO_VERSION_BUMP=1` | build the version already in `Assets/version.txt` without incrementing it |
| `CI=true` or `NO_PAUSE=1` | never pause at the end |

### Build a single program

```bash
# CLI
fpc -O2 -Fusrc -Sg -Sc MyProject.lpr

# GUI
lazbuild --build-all gui/MyProject_gui.lpi
```

### Cross-compile for a specific target

```bash
# macOS Intel (x86_64)
ppcrossx64 -Tdarwin -Px86_64 -O2 -XPx86_64-apple-darwin19- -Fusrc -FEdist/macos-intel MyProject.lpr

# macOS Apple Silicon (aarch64)
ppcrossa64 -Tdarwin -Paarch64 -O2 -XPaarch64-apple-darwin19- -Fusrc -FEdist/macos-aarch64 MyProject.lpr

# Linux x86_64
ppcrossx64 -Tlinux -Px86_64 -O2 -XPx86_64-linux-gnu- -Fusrc -FEdist/linux-x64 MyProject.lpr

# Linux ARM
ppcrossarm -Tlinux -Parm -O2 -CaEABIHF -XParm-linux-gnueabihf- -Fusrc -FEdist/linux-arm MyProject.lpr
```

## Project structure

```
MyProject/
├── NAME                        # Project name (read by build_all.bat)
├── LICENSE                     # MIT license
├── CONTRIBUTING.md             # Contribution guidelines
├── AGENTS.md                   # Working principles for AI agents
├── README.md                   # This file
├── build_all.bat               # Multi-platform build script
├── .gitignore
├── .github/workflows/ci.yml    # GitHub Actions CI
├── Assets/
│   └── version.txt             # Version number (major.minor.patch)
├── src/                        # Pascal source files (shared units)
├── gui/                        # Lazarus GUI project (.lpi, .lpr, forms)
├── tools/                      # Helper tools and scripts
│   ├── zip_app.py              # macOS .app zip with correct Unix modes
│   ├── midi_to_tab.lpr         # Example helper tool (CLI)
│   └── step_editor/            # Example helper tool (GUI)
├── installer/
│   └── installer.iss           # Inno Setup script (Windows installer)
├── config/                     # Runtime configuration files
├── docs/                       # GitHub Pages site
├── dist/                       # Build output (gitignored)
└── Deploy/                     # Release artifacts (gitignored)
```

## GitHub Actions CI

The workflow in `.github/workflows/ci.yml` builds all five targets on a
Windows runner:

1. Installs a bootstrap FPC from the official installer
2. Builds the `fpcup` CLI tool from the fpcupdeluxe repository
3. Uses `fpcup` to install FPC, Lazarus, and cross-compilers for
   `x86_64-darwin`, `aarch64-darwin`, and `arm-linux` (including the
   macOS SDK via `--autotools`)
4. Runs `build_all.bat` to build and package all targets
5. Uploads all artifacts

Trigger it manually via **Actions → CI / Cross-Platform Build → Run workflow**.

## License

MIT — see [LICENSE](LICENSE).