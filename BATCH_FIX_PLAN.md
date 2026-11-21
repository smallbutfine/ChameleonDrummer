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

- [ ] **P1.2** `del /q "%ROOT%\Dist"` (L63) is invalid syntax and never cleans.
      Replace with `rmdir /s /q "%ROOT%\dist" 2>nul`.
      Verify: `dist\` is gone before a build and recreated empty.

- [ ] **P1.3** Error routing: every failure does `goto :target_done`, so
      `:target_failed` (L474) is dead code and failures are reported as success.
      Route failures to `:target_failed`, set `RESULT_<T>=FAIL`, `goto :target_done`.
      Verify: forced failure prints `*** TARGET ... FAILED ***` and summary shows FAIL.

- [ ] **P1.4** `:target_failed` falls through into `:target_done` (L474-480).
      Give it its own `popd` + `goto :eof` so it does not re-run target_done logic.

## Phase 2 — Robustness

- [ ] **P2.1** Hardcoded toolchain paths (L12-17). Allow env-var override with the
      current paths as defaults (`FPC_DIR`, `LAZBUILD`, `CROSS_BIN_DIR`, `ISCC`).
      Verify: override env var is honoured.

- [ ] **P2.2** Unguarded `copy`/`xcopy` of support files (L398-431). Wrap each in
      `if exist` and warn on missing source.
      Verify: missing source produces a warning, not silent success.

- [ ] **P2.3** Fragile quoting in `CC_FLAGS` (L242, L253):
      `set "CC_FLAGS=-O2 -Fu"%ROOT%\src""`. Rebuild quoting safely.
      Verify: build still succeeds with a ROOT containing spaces (simulate).

- [ ] **P2.4** Clean step (L230-237) does not remove `.res` files, which are
      generated at L114. Add `*.res` to the clean set.
      Verify: no stale `.res` survives a clean.

- [ ] **P2.5** `:make_app_bundle` (L488) clobbers global `APP_NAME`.
      Use a local name (`BUNDLE_EXE`) instead.
      Verify: `APP_NAME` unchanged after bundle creation.

## Phase 3 — Packaging correctness

- [ ] **P3.1** macOS bundle incomplete:
      - CLI `ChameleonDrummer` is built to `%TD%`, never into the bundle, so the
        copy at L506-510 never fires.
      - `step_editor.app` is placed at `tools/step_editor.app` (invalid location).
      - `Info.plist` lacks `CFBundleVersion` / `LSMinimumSystemVersion`.
      Fix all three.
      Verify: bundle contains CLI + tools, plist has the keys.

- [ ] **P3.2** `mappings\` vs `src\mappings\` duplication (script uses root,
      installer uses `src\`). Pick one source of truth and align both.
      Verify: script and installer.iss reference the same path.

- [ ] **P3.3** `Assets\version.txt` is mutated on every build (L58-65), making
      builds non-idempotent and dirtying the working tree.
      Decide: keep mutation but make it explicit/optional, or move to a counter.
      Verify: build twice, behaviour is intentional and documented.

## Phase 4 — CI hygiene

- [ ] **P4.1** `:print_summary` (L576-608) is never called and ends with `pause`
      (L607), which would block CI. Call it before the final exit; make `pause`
      conditional on an interactive/CI flag.
      Verify: summary prints; no hang when `CI=true`.

- [ ] **P4.2** Add a `--check` / dry-run mode that verifies toolchain presence
      and support files without building.
      Verify: `./build_all.bat --check` exits 0 with all tools found.

---

## Notes / decisions log

- Pre-existing uncommitted changes at start: `Assets/version.txt`,
  `build_all.bat` (version-stamped deploy names + `del /q Dist`),
  `tools/midi_to_tab.lpr`. These are the user's; preserve them.
- `build_and_deploy.bat` is a separate legacy script; not in scope except as a
  reference for `BUILD_YEAR` and `.res` cleaning.