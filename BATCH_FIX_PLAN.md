# build_all.bat — Fix Plan

Status tracker for the `build_all.bat` remediation. Work top to bottom, one point
at a time: fix -> test that the specific issue is gone -> commit -> next.

Baseline: branch `main`, toolchain verified present at `C:\fpcupdeluxe\...`,
Inno Setup at `C:\Program Files (x86)\Inno Setup 6\ISCC.exe`, GNU tar 1.35.

Legend: `[ ]` todo, `[~]` in progress, `[x]` done + verified, `[-]` dropped (reason).

---

## Phase 1 — Correctness

- [x] **P1.1** Define `BUILD_YEAR` (L100 uses it, never set).
      Copy the `wmic` logic from `build_and_deploy.bat` L13-14.
      Verify: generated `.rc` contains a 4-digit year, not a double space.
      DONE: added `BUILD_YEAR` block after the LICENSE company extraction. Note the
      original `build_and_deploy.bat` snippet returns the full `wmic` timestamp
      (`20261122005310.180000+060`), so a `:~0,4` substring is required. Verified
      output: `Copyright 2026 Martin Haverland`.

- [x] **P1.2** `del /q "%ROOT%\Dist"` (L63) is invalid syntax and never cleans.
      Replace with `rmdir /s /q "%ROOT%\dist" 2>nul`.
      Verify: `dist\` is gone before a build and recreated empty.
      DONE: now `if exist "%ROOT%\dist" rmdir /s /q "%ROOT%\dist"`. Verified in a
      sandbox that a populated `dist\` (nested dirs + files) is fully removed.

- [x] **P1.3** Error routing: every failure does `goto :target_done`, so
      `:target_failed` (L474) is dead code and failures are reported as success.
      Route failures to `:target_failed`, set `RESULT_<T>=FAIL`, `goto :target_done`.
      Verify: forced failure prints `*** TARGET ... FAILED ***` and summary shows FAIL.
      DONE: all error blocks now `goto :target_failed`; success sets
      `RESULT_<T>=OK`. Also replaced the `pushd ... || (exit /b 1)` constructs
      (which killed the whole script) with `if errorlevel 1` + `goto :target_failed`.
      Verified with a forced `-Zbadflag`: prints `*** TARGET win64 FAILED ***` and
      `RESULT_win64=[FAIL]`.

- [x] **P1.4** `:target_failed` falls through into `:target_done` (L474-480).
      Give it its own `popd` + `goto :eof` so it does not re-run target_done logic.
      DONE: `:target_failed` now sets `RESULT_<T>=FAIL`, does its own `popd 2>nul`
      and `goto :eof`; `:target_done` is a separate label reached only on success.

## Phase 2 — Robustness

- [x] **P2.1** Hardcoded toolchain paths (L12-17). Allow env-var override with the
      current paths as defaults (`FPC_DIR`, `LAZBUILD`, `CROSS_BIN_DIR`, `ISCC`).
      Verify: override env var is honoured.
      DONE: each path is now `if not defined X set "X=..."`. The ISCC fallback is
      nested inside the `if not defined ISCC` block so a user-supplied ISCC is not
      clobbered. Verified: defaults resolve to the fpcupdeluxe/Inno paths; env
      overrides (`FPC_DIR`, `ISCC`) are honoured.

- [x] **P2.2** Unguarded `copy`/`xcopy` of support files (L398-431). Wrap each in
      `if exist` and warn on missing source.
      Verify: missing source produces a warning, not silent success.
      DONE: added a `:copy_glob SRC DST LABEL` helper; all support-file copies now
      `call :copy_glob`. Verified: existing sources print `OK: <label>` and copy;
      missing sources print `WARNING: missing <label> - no files matched "<path>"`.

- [x] **P2.3** Fragile quoting in `CC_FLAGS` (L242, L253):
      `set "CC_FLAGS=-O2 -Fu"%ROOT%\src""`. Rebuild quoting safely.
      Verify: build still succeeds with a ROOT containing spaces (simulate).
      DONE: `CC_FLAGS` no longer embeds any path; `-Fu"%ROOT%\src"` is appended at
      each compile call site so ROOT expands normally. Found and fixed a real bug:
      the old form truncated at `&` in ROOT (`C:\a & b` -> `-Fu"C:\a"`). Verified a
      full compile+link from `C:\a & b` (ampersand + space) -> `EXITCODE=0`.

- [x] **P2.4** Clean step (L230-237) does not remove `.res` files, which are
      generated at L114. Add `*.res` to the clean set.
      Verify: no stale `.res` survives a clean.
      DONE: added `*.res` to the root, `gui\`, `tools\` and `tools\step_editor\`
      clean lines. Verified in a sandbox: all `.res`/`.o`/`.exe` removed,
      unrelated files (`keep.txt`) untouched.

- [x] **P2.5** `:make_app_bundle` (L488) clobbers global `APP_NAME`.
      Use a local name (`BUNDLE_EXE`) instead.
      Verify: `APP_NAME` unchanged after bundle creation.
      DONE: `:make_app_bundle` now uses `BUNDLE_EXE` throughout (bundle dir, plist
      `CFBundleExecutable`, `CFBundleIdentifier`, final echo). Verified:
      `APP_NAME` stays `ChameleonDrummer` after both calls, and each bundle gets
      its own executable name.

## Phase 3 — Packaging correctness

- [x] **P3.1** macOS bundle incomplete:
      - CLI `ChameleonDrummer` is built to `%TD%`, never into the bundle, so the
        copy at L506-510 never fires.
      - `step_editor.app` is placed at `tools/step_editor.app` (invalid location).
      - `Info.plist` lacks `CFBundleVersion` / `LSMinimumSystemVersion`.
      Fix all three.
      Verify: bundle contains CLI + tools, plist has the keys.
      DONE: (a) CLI is staged into the bundle dir before `:make_app_bundle` so it
      lands in `Contents/MacOS/`; (b) `step_editor.app` is moved to the bundle root;
      (c) plist gains `CFBundleShortVersionString`, `CFBundleVersion`,
      `LSMinimumSystemVersion`, `NSPrincipalClass`.
      BONUS BUG FOUND: the plist was **malformed XML**. With delayed expansion on,
      `!DOCTYPE` loses its `!` and the `//` in the DTD URL is mangled, so `echo`
      emitted `<//apple.com">` as line 2. Fixed by wrapping the plist write in
      `setlocal disabledelayedexpansion` + `%VAR%` expansion. Verified the
      generated `Info.plist` parses as well-formed XML.
      BONUS BUG FOUND (via full build): macOS `step_editor.app` shipped with an
      EMPTY `Contents/MacOS`. `lazbuild` links `step_editor.exe` even for darwin
      (never a `.app`), but the clean step never removed a stale
      `tools\step_editor\step_editor.app`, so the darwin move branch grabbed the
      stale `.app` and left the fresh `.exe` to be deleted by the next clean.
      Fixed: clean removes the stale `.app`; darwin branch moves the `.exe`
      (keeping its name so `:make_app_bundle` renames it into `Contents/MacOS`);
      `step_editor.app` is now created INSIDE the main bundle at
      `Contents/Resources/tools/step_editor.app` (matching commit 2b184473).
      Verified: `step_editor.app/Contents/MacOS/step_editor` is a real 18 MB Mach-O.

- [x] **P3.2** `mappings\` vs `src\mappings\` duplication (script uses root,
      installer uses `src\`). Pick one source of truth and align both.
      Verify: script and installer.iss reference the same path.
      DONE: the two trees have **real content differences** (e.g. `ad2.json` has
      `snare_brushes_only_sweep_fast_bright_accent` at note 30 in `mappings/` vs 35
      in `src/mappings/`). `mappings/` is canonical: it is the newer tree (last
      touched 2026-10-21 vs 2026-09-15) and it is what `build_all.bat` ships and
      what the runtime loads (`ExtractFilePath(ParamStr(0)) + 'mappings'`).
      Changed `installer.iss` to `..\mappings\*.json`. Verified both now resolve to
      the same root `mappings\` directory.
      BONUS BUG FOUND (via full build): the Deploy step looked for the *unstamped*
      `ChameleonDrummer-linux-x64.tar.gz`, but packaging writes the *stamped*
      `ChameleonDrummer<ver>-linux-x64.tar.gz`, so Linux tarballs were silently
      never copied to `Deploy/`. Fixed both the source and destination names;
      verified `Deploy/ChameleonDrummer1.1.477-linux-{x64,arm}.tar.gz` now appear
      and their `mappings/*.json` checksums match the canonical root.
      FOLLOW-UP: `src/mappings/` was referenced by nothing after the installer
      change, so the stale duplicate was deleted (commit 9aae1243). Re-ran the
      full build: 5/5 OK, no mappings warnings, and the Linux/macOS/Windows
      artifacts all carry the canonical `mappings/` checksums.

- [x] **P3.3** `Assets\version.txt` is mutated on every build (L58-65), making
      builds non-idempotent and dirtying the working tree.
      Decide: keep mutation but make it explicit/optional, or move to a counter.
      Verify: build twice, behaviour is intentional and documented.
      DONE: the bump is intentional (artifacts are version-stamped, so it must stay
      monotonic), but it is now **opt-out**: `NO_VERSION_BUMP=1` builds the version
      already in `version.txt` without rewriting it. Also fixed a trailing space in
      the written file (`echo ... >file` -> `echo ...>file`). Verified: default run
      -> `1.1.476` with no trailing space; `NO_VERSION_BUMP=1` -> stays `1.1.475`
      and the file is byte-identical.

## Phase 4 — CI hygiene

- [x] **P4.1** `:print_summary` (L576-608) is never called and ends with `pause`
      (L607), which would block CI. Call it before the final exit; make `pause`
      conditional on an interactive/CI flag.
      Verify: summary prints; no hang when `CI=true`.
      DONE: `:print_summary` is now called before the final exit and sets
      `SUMMARY_FAIL`; the script exits 1 when any target failed, 0 otherwise.
      `pause` is skipped when `CI` or `NO_PAUSE` is defined. Verified: forced
      failure -> summary shows `[FAIL] win64`, `BATCH_EXIT=1`; success ->
      `[OK] win64`, `BATCH_EXIT=0`; `CI=true` does not hang.

- [x] **P4.2** Add a `--check` / dry-run mode that verifies toolchain presence
      and support files without building.
      Verify: `./build_all.bat --check` exits 0 with all tools found.
      DONE: tool checks moved into a reusable `:verify_tools` label (now also
      checks `windres.exe`); `--check` runs it and exits without building. Verified:
      all tools present -> exit 0; bogus `FPC_DIR` -> lists every missing tool and
      exits 1 without touching `dist\`.

---

## Final verification (full build, 2026-11-22)

`CI=true ./build_all.bat` -> **exit 0**, all 5 targets `[OK]`:

- `win64`: `ChameleonDrummer.exe`, `chameleondrummer_gui.exe`,
  `tools\midi_to_tab.exe`, `tools\step_editor.exe` + Inno Setup installer
  `Deploy\ChameleonDrummer_Setup_1.1.477.exe`.
- `macos-intel` / `macos-aarch64`: `chameleondrummer_gui.app` with
  `Contents/MacOS/{ChameleonDrummer,chameleondrummer_gui}` and
  `Contents/Resources/tools/{midi_to_tab,step_editor}` (plain sibling binaries,
  no `.app`, no `.exe`). Both `Info.plist` files parse as well-formed XML.
- `linux-x64` / `linux-arm`: version-stamped `.tar.gz` packages with
  `tools/{midi_to_tab,step_editor}` (no extension).

Binary formats confirmed: Mach-O x86_64, Mach-O arm64, ELF x86-64, ELF ARM EABI5.
Functional test: `dist\win64\ChameleonDrummer.exe generate --genre rock --style
classic --tempo 120` writes a valid MIDI file (`MThd` header, 14886 bytes).
`dist\win64\mappings\` checksums match the canonical root `mappings\` (P3.2).

`./build_all.bat --check` -> exit 0 with all tools found; bogus `FPC_DIR` ->
exit 1 listing every missing tool, without touching `dist\`.

## Follow-up: platform-independent tool names (2026-11-22)

User feedback: `step_editor` is **not** a separate program - it is a helper the
main GUI launches, and it must sit next to `midi_to_tab` in `tools/`. Two real
bugs were found and fixed:

1. **Pascal hardcoded `.exe`** - `gui/MainFrm.pas` looked for
   `tools/step_editor.exe` and `tools/step_editor/MainFrm.pas` for
   `midi_to_tab.exe`. Both now use the same conditional as `CliLookup.pas`:
   `{$IFDEF MSWINDOWS}'.exe'{$ELSE}''{$ENDIF}`. Verified per platform:
   win64 -> `step_editor.exe`, linux/darwin -> `step_editor`.
2. **`step_editor.app` was wrong** - an earlier fix of mine created a bogus
   `.app` bundle. `lazbuild` links `step_editor.exe` even for darwin, so the
   build now renames it to `step_editor` (no extension) and copies it beside
   `midi_to_tab` in `Contents/Resources/tools`. No `.app`, no `.exe` on macOS.
3. **Parse-time expansion bug** - `MAIN_RES_TOOLS` was set inside the
   `if "%T_OS%"=="darwin" (` block but read with `%MAIN_RES_TOOLS%`, which
   expands at parse time to the *previous* target's value. Result: the intel
   bundle received the aarch64 binaries. Fixed with `!MAIN_RES_TOOLS!`.
4. **Stale Deploy bundles** - `xcopy` merges, so a bundle from an earlier build
   kept deleted files. The version-stamped destination is now `rmdir`'d first.

Verified: intel bundle = x86_64, aarch64 = arm64, Linux tarballs carry
`tools/{midi_to_tab,step_editor}` with no extension, no stale `.app`/`.exe`
anywhere, and the Windows installer still ships `tools/*.exe`.

---

## Notes / decisions log

- Pre-existing uncommitted changes at start: `Assets/version.txt`,
  `build_all.bat` (version-stamped deploy names + `del /q Dist`),
  `tools/midi_to_tab.lpr`. These are the user's; preserve them.
- `build_and_deploy.bat` is a separate legacy script; not in scope except as a
  reference for `BUILD_YEAR` and `.res` cleaning.