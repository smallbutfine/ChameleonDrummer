@echo off
REM Builds the ChameleonDrummer GUI with Lazarus.
REM
REM The GUI links the engine units from ..\src directly, so it needs the
REM keymaps and the GMD corpus next to the executable - which is why the
REM executable is written to the project root, not into this folder.
@echo off
chcp 65001
setlocal enabledelayedexpansion
cd /d "%~dp0..\..
if "%GITHUB_ACTIONS%"=="true" ( set "IS_CI=1" ) else ( set "IS_CI=0" )

:: Jahr automatisch ermitteln
for /f "tokens=2 delims==" %%Y in ('wmic OS get LocalDateTime /format:list 2^>nul') do if not defined BUILD_YEAR set "BUILD_YEAR=%%Y"
if not defined BUILD_YEAR set "BUILD_YEAR=%DATE:~-4%"
echo ==================================================
echo   1. Projektname aus Datei 'NAME' einlesen...
echo ==================================================
if not exist "NAME" ( echo [Fehler] NAME nicht gefunden! & if "!IS_CI!"=="0" pause & exit /b 1 )
set /p APP_NAME=<NAME
set "APP_NAME=%APP_NAME: =%"
if "%APP_NAME%"=="" ( echo [Fehler] NAME ist leer! & if "!IS_CI!"=="0" pause & exit /b 1 )
set "EXE_FILE=%APP_NAME%.exe"
set "LPR_FILE=%APP_NAME%.lpr"
echo Projektname festgelegt: %APP_NAME%

echo.
echo ==================================================
echo   2. Versionsnummer ermitteln...
echo ==================================================
set "DETECTED_VERSION="
if "!IS_CI!"=="1" (
    if defined GITHUB_REF_NAME (
        set "RAW_TAG=%GITHUB_REF_NAME%"
        if "!RAW_TAG:~0,1!"=="v" ( set "DETECTED_VERSION=!RAW_TAG:~1!" ) else ( set "DETECTED_VERSION=!RAW_TAG!" )
    )
)
if "!DETECTED_VERSION!"=="" (
    set "MAJOR=1" & set "MINOR=0" & set "PATCH=0"
    if exist "assets\version.txt" (
        for /f "tokens=1,2,3 delims=." %%a in (assets\version.txt) do (
            set "MAJOR=%%a" & set "MINOR=%%b" & set "PATCH=%%c"
        )
        set /a PATCH=!PATCH! + 1
    )
    set "DETECTED_VERSION=!MAJOR!.!MINOR!.!PATCH!"
    echo [Lokal] Version erhöht auf: !DETECTED_VERSION!
)
set "VERSION_COMMAS=!DETECTED_VERSION:.=,!"
echo.
echo ==================================================
echo   4. Entwicklername aus LICENSE auslesen...
echo ==================================================
if not exist "LICENSE" ( echo [Fehler] LICENSE nicht gefunden! & if "!IS_CI!"=="0" pause & exit /b 1 )

set "VBS_COMP=%TEMP%\get_company.vbs"
(
echo Set fso = CreateObject("Scripting.FileSystemObject"^)
echo Set file = fso.OpenTextFile("LICENSE", 1^)
echo Set regEx = New RegExp
echo regEx.IgnoreCase = True
echo regEx.Pattern = "^\s*Copyright\s+\(c\)\s+\d{4}\s+(.+)$"
echo Do Until file.AtEndOfStream
echo     line = file.ReadLine
echo     If regEx.Test(line^) Then
echo         WScript.Echo regEx.Replace(line, "$1"^)
echo         Exit Do
echo     End If
echo Loop
echo file.Close
) > "%VBS_COMP%"

for /f "tokens=*" %%C in ('cscript //nologo "%VBS_COMP%"') do set "EXTRACTED_COMPANY=%%C"
del "%VBS_COMP%" 2>&1
cd tools
cd step_editor

if "!EXTRACTED_COMPANY!"=="" ( set "EXTRACTED_COMPANY=Independent Developer" )
echo Name aus LICENSE: !EXTRACTED_COMPANY!

echo.
echo ==================================================
echo   5. Windows-Ressourcedatei (.rc) generieren...
echo ==================================================
(
echo 1 VERSIONINFO
echo FILEVERSION !VERSION_COMMAS!,0
echo PRODUCTVERSION !VERSION_COMMAS!,0
echo FILEFLAGSMASK 0x3fL
echo FILEFLAGS 0x0L
echo FILEOS 0x40004L
echo FILETYPE 0x2L
echo FILESUBTYPE 0x0L
echo BEGIN
echo     BLOCK "StringFileInfo"
echo     BEGIN
echo         BLOCK "040904b0"
echo         BEGIN
echo             VALUE "CompanyName", "!EXTRACTED_COMPANY!\0"
echo             VALUE "FileDescription", "%APP_NAME%\0"
echo             VALUE "FileVersion", "!DETECTED_VERSION!\0"
echo             VALUE "InternalName", "%APP_NAME%\0"
echo             VALUE "LegalCopyright", "Copyright \251 !BUILD_YEAR! !EXTRACTED_COMPANY!\0"
echo             VALUE "OriginalFilename", "%EXE_FILE%\0"
echo             VALUE "ProductName", "%APP_NAME%\0"
echo             VALUE "ProductVersion", "!DETECTED_VERSION!\0"
echo         END
echo     END
echo     BLOCK "VarFileInfo"
echo     BEGIN
echo         VALUE "Translation", 0x409, 1200
echo     END
echo END
) > step_editor.rc

set "FPC_BIN_DIR=%SystemDrive%\lazarus\fpc\3.2.2\bin\x86_64-win64"
if not exist "%FPC_BIN_DIR%\windres.exe" ( echo [Fehler] windres.exe fehlt! & exit /b 1 )
"%FPC_BIN_DIR%\windres.exe" --preprocessor="type" -i step_editor.rc -o step_editor.res
set "LAZBUILD=C:\lazarus\lazbuild.exe"
if not exist "%LAZBUILD%" set "LAZBUILD=lazbuild"

if not exist "%~dp0step_editor.lpi" (
  echo [Fehler] Projektdatei nicht gefunden: %~dp0step_editor.lpi
  pause
  exit /b 1
)

echo.
echo ==================================================
echo   6. Multi-Platform Compilation via lazbuild
echo ==================================================

REM --- 1. Windows Native Build ---
echo Building for Windows (x86_64)...
"%LAZBUILD%" --build-all --build-mode=Default "%~dp0step_editor.lpi"
if errorlevel 1 ( echo [Fehler] Windows-Build fehlgeschlagen. & pause & exit /b 1 )

REM --- 2. Linux Cross Build (GTK2) ---
echo Building for Linux (x86_64 GTK2)...
"%LAZBUILD%" -d --os=linux --cpu=x86_64 --ws=gtk2 --compiler="C:\lazarus\fpc\3.2.2\bin\x86_64-win64\ppcrossx64.exe" "%~dp0step_editor.lpi"
if errorlevel 1 ( echo [Fehler] Linux-Build fehlgeschlagen. & pause & exit /b 1 )

REM --- 3. macOS Cross Build (Cocoa Apple Silicon) ---
echo Building for macOS (aarch64 Cocoa)...
"%LAZBUILD%" -d --os=darwin --cpu=aarch64 --ws=cocoa --compiler="C:\lazarus\fpc\3.2.2\bin\x86_64-win64\ppcrossaarch64.exe" "%~dp0step_editor.lpi" --opt="-XRC:\SDKs\MacOSX11.3.sdk"
if errorlevel 1 ( echo [Fehler] macOS-Build fehlgeschlagen. & pause & exit /b 1 )

if errorlevel 1 (
  echo [Fehler] Lazarus-Build fehlgeschlagen.
  pause
  exit /b 1
)

if not exist "%~dp0..\step_editor.exe" (
  echo [Fehler] Executable wurde nicht erzeugt.
  pause
  exit /b 1
)

echo [OK] GUI gebaut: %~dp0..\step_editor.exe
REM Continue with the CLI build and the installer; they work from the project root.

cd /d "%~dp0.."
call build.bat
