@echo off
REM Builds the ChameleonDrummer GUI with Lazarus.
REM
REM The GUI links the engine units from ..\src directly, so it needs the
REM keymaps and the GMD corpus next to the executable - which is why the
REM executable is written to the project root, not into this folder.

setlocal

set "LAZBUILD=%ProgramFiles%\lazarus\lazbuild.exe"
if not exist "%LAZBUILD%" set "LAZBUILD=lazbuild"

if not exist "%~dp0chameleondrummer_gui.lpi" (
  echo [Fehler] Projektdatei nicht gefunden: %~dp0chameleondrummer_gui.lpi
  exit /b 1
)

"%LAZBUILD%" --build-all --build-mode=Default "%~dp0chameleondrummer_gui.lpi"
if errorlevel 1 (
  echo [Fehler] Lazarus-Build fehlgeschlagen.
  exit /b 1
)

if not exist "%~dp0..\chameleondrummer_gui.exe" (
  echo [Fehler] Executable wurde nicht erzeugt.
  exit /b 1
)

echo [OK] GUI gebaut: %~dp0..\chameleondrummer_gui.exe
exit /b 0
