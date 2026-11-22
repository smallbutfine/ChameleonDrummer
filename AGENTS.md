# AGENTS.md — Working Principles

General rules for any agent (human or AI) working in this repository. These were
distilled from real sessions and each rule exists because something actually broke
without it. Read this before making changes.

---

## 1. Verify, never assume

**Never claim something works without seeing output that proves it.**

- Read a file before referencing its contents, symbols, or line numbers. Do not
  guess paths, APIs, or config keys.
- After a change, run the build/test and read the actual output. "It should work"
  is not verification.
- Quote exact evidence (file lines, stack traces, terminal output) when diagnosing.
- If you cannot verify something, say so explicitly and name what you would check.

**Why:** In this repo, `build_all.bat` reported success for months while silently
producing broken artifacts. Assumptions about `.lpi` output paths, `echo` escaping,
and batch variable expansion each caused real bugs that only surfaced by testing.

---

## 2. Fix root causes, not symptoms

- When a build produces a wrong artifact, find *why* before patching the artifact.
- Prefer a fix at the source (the script, the `.lpi`, the Pascal) over a workaround
  in the packaging step.
- If a fix reveals a second, deeper bug, fix that too — don't stop at the first
  green light.

**Why:** An empty `step_editor.app` was "fixed" by copying a file into it; the real
cause was `lazbuild` never emitting a `.app` for darwin plus a stale directory
winning a `move`. The real fix was two lines in the build script.

---

## 3. Batch / cmd.exe rules (this project builds on Windows)

- **`.bat` files are CRLF.** When generating or editing them from a POSIX shell,
  write `\r\n` line endings. LF-only batch files fail in confusing ways.
- **Never read a variable with `%VAR%` in the same parenthesized block that sets
  it.** `%VAR%` expands at parse time, so it holds the value from the *previous*
  iteration. Use `!VAR!` (requires `setlocal enabledelayedexpansion`).
  This exact bug put aarch64 binaries into the x86_64 bundle.
- **`echo` mangles special characters.** `!DOCTYPE` loses its `!` under delayed
  expansion, and `//` in URLs triggers path mangling. Wrap such writes in
  `setlocal disabledelayedexpansion` and use `%VAR%`.
- **`xcopy` merges, it does not replace.** A destination from an earlier build
  keeps deleted files. `rmdir /s /q` the version-stamped destination first.
- **`del` cannot remove a directory** — use `rmdir /s /q`.
- **`exit /b N` inside a `call`ed subroutine** exits the whole script, not just the
  subroutine. Prefer `goto :label` + `goto :eof`.
- **`pushd ... || (exit /b 1)`** kills the entire build. Use `if errorlevel 1`.
- **Quote paths and pass them unquoted into `cmd`.** Ampersands and spaces in a
  project path (`C:\a & b`) break naive `-Fu"%ROOT%\src"` string concatenation.
  Append such flags at the call site so `%ROOT%` expands normally.

---

## 4. Pascal / Free Pascal rules

- **The source must be platform-independent.** Never hardcode `.exe`.
  Use the conditional pattern already established in `gui/CliLookup.pas`:

  ```pascal
  Result := ExtractFilePath(ParamStr(0)) + 'tool' +
    {$IFDEF MSWINDOWS}'.exe'{$ELSE}''{$ENDIF};
  ```

- **Guard Windows-only resource includes.** `{$R *.res}` must be wrapped in
  `{$IFDEF MSWINDOWS}` ... `{$ENDIF}`. `build_all.bat` only runs `windres` for
  `win64`, so an unguarded include fails on darwin/linux with
  `Can't open resource file`. A stale `.res` on disk hides this bug — test clean.
- **Tool binaries are siblings, not app bundles.** `step_editor` and
  `midi_to_tab` are plain executables in `tools/`, launched by the main GUI via
  `TProcess`. Do not wrap them in `.app` bundles.
- **Executable naming follows the platform:** `tool.exe` on Windows, `tool` with
  no extension on macOS and Linux.
- **Never zip the macOS bundles with `Compress-Archive` or `bsdtar`.** Windows/NTFS
  has no executable bit, so both store the binaries as `0644`/`0666` and they will
  not run after extraction on macOS. Use `tools/zip_app.py`, which writes explicit
  Unix modes (`0755` for `Contents/MacOS/*` and `Contents/Resources/tools/*`).

---

## 5. Build script invariants

- **One source of truth per asset.** `mappings/` at the repo root is canonical;
  `installer.iss` and `build_all.bat` must both point at it. Do not reintroduce
  duplicates (the old `src/mappings/` had silently diverged).
- **Version-stamped artifacts must never collide.** The patch level bumps per build
  by default; `NO_VERSION_BUMP=1` builds the current version without rewriting it.
- **Every target's failure must be visible.** Failures route to `:target_failed`,
  set `RESULT_<target>=FAIL`, and make the script exit non-zero. Never let a failed
  target be reported as success.
- **`--check` must not build.** It verifies the toolchain and exits.
- **CI must never hang.** `pause` is skipped when `CI` or `NO_PAUSE` is defined.

---

## 6. Verification checklist for any build change

Run these before declaring a build change done:

1. `CI=true ./build_all.bat --check` — toolchain resolves, exit 0.
2. `CI=true ./build_all.bat` — all targets `[OK]`, exit 0, zero warnings.
3. Confirm artifact **names** per target (`.exe` vs no extension).
4. Confirm artifact **contents** are correct — `file` each binary to check the
   architecture matches the target (x86_64 vs arm64).
5. Confirm no stale files survived (`find ... -name '*.app' -o -name '*.exe'`).
6. Confirm checksums of copied assets match the canonical source.
7. Run the CLI once and confirm it produces a valid MIDI file (`MThd` header).

**Why:** Every bug in this repo's build was invisible to "did it exit 0?" alone.

---

## 7. Git and scope discipline

- **Do not commit or push unless explicitly asked.** Push only on request.
- **Preserve the user's uncommitted work.** Never revert or overwrite changes you
  did not make. Check `git status` and `git diff` before editing.
- **Keep changes minimal and focused.** Do not refactor unrelated code, rename
  things cosmetically, or "clean up" files that are not part of the task.
- **One logical change per commit.** Write a short imperative subject line
  (<= 50 chars), no trailing punctuation; add a body only when it adds real
  information.
- **Leave the working tree clean** apart from the user's own pre-existing changes.
- **Do not delete tracked files** as a side effect of a build fix without asking.

---

## 8. Communication

- Be concise and direct. Lead with the answer.
- Distinguish clearly between what you verified and what you inferred.
- When you find a bug you caused, say so plainly, fix it, and move on — no
  over-apologizing.
- When a task is ambiguous, ask rather than guess. When a task is clear, just do it.
- Report what you did **not** do (e.g. "did not push", "left the `.o` clutter
  alone") so the user can decide.

---

## 9. Environment notes

- Windows host, but a POSIX shell (Git Bash) is available and `./build_all.bat`
  works from it.
- Toolchain defaults live at `C:\fpcupdeluxe\...` (FPC 3.2.4, Lazarus), overridable
  via the `FPC_DIR`, `LAZBUILD`, `CROSS_BIN_DIR`, `ISCC`, `TAR` environment
  variables. Inno Setup 6 at `C:\Program Files (x86)\Inno Setup 6\ISCC.exe`.
  GNU tar 1.35.
- Native Windows Python cannot read `/tmp` paths — use project-local temp dirs
  when a script needs to exchange files with Python.
- `core.autocrlf=true` is set; expect LF→CRLF warnings on checkout.