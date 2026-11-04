@echo off
setlocal enabledelayedexpansion

echo ==================================================
echo   3. [Clean] Bereinige alte Compiler-Dateien...
echo ==================================================
del /q /s *.o *.ppu *.res 2>nul
echo Compiler-Cache bereinigt.
cd /d "%~dp0.."

for /f "tokens=2 delims==" %%Y in ('wmic OS get LocalDateTime /format:list 2^>nul') do if not defined BUILD_YEAR set "BUILD_YEAR=%%Y"
if not defined BUILD_YEAR set "BUILD_YEAR=%DATE:~-4%"

echo ==================================================
echo   1. Projektname aus Datei 'NAME' einlesen...
echo ==================================================
if not exist "NAME" (
    echo [Fehler] NAME nicht gefunden!
    pause
    exit /b 1
)
set /p APP_NAME=<NAME
set "APP_NAME=%APP_NAME: =%"
if "%APP_NAME%"=="" (
    echo [Fehler] NAME ist leer!
    pause
    exit /b 1
)
set "EXE_FILE=midi_to_tab.exe"
set "LPR_FILE=midi_to_tab.lpr"
echo Projektname festgelegt: %APP_NAME%

echo ==================================================
echo   2. Versionsnummer ermitteln...
echo ==================================================
set "DETECTED_VERSION="

if "!DETECTED_VERSION!"=="" (
    set "MAJOR=1"
    set "MINOR=0"
    set "PATCH=0"
    if exist "assets\version.txt" (
        for /f "tokens=1,2,3 delims=." %%a in (assets\version.txt) do (
            set "MAJOR=%%a"
            set "MINOR=%%b"
            set "PATCH=%%c"
        )
        set /a PATCH=!PATCH! + 1
    )
    set "DETECTED_VERSION=!MAJOR!.!MINOR!.!PATCH!"
    echo [Lokal] Version erhoeht auf: !DETECTED_VERSION!
)
set "VERSION_COMMAS=!DETECTED_VERSION:.=,!"

echo ==================================================
echo   4. Entwicklername aus LICENSE auslesen...
echo ==================================================
if not exist "LICENSE" (
    echo [Fehler] LICENSE nicht gefunden!
    pause
    exit /b 1
)

set "VBS_COMP=%TEMP%\get_company.vbs"
if exist "%VBS_COMP%" del "%VBS_COMP%"

echo Set fso = CreateObject("Scripting.FileSystemObject")>>"%VBS_COMP%"
echo Set file = fso.OpenTextFile("LICENSE", 1)>>"%VBS_COMP%"
echo Set regEx = New RegExp>>"%VBS_COMP%"
echo regEx.IgnoreCase = True>>"%VBS_COMP%"
echo regEx.Pattern = "^\s*Copyright\s+\(c\)\s+\d{4}\s+(.+)$">>"%VBS_COMP%"
echo Do Until file.AtEndOfStream>>"%VBS_COMP%"
echo     line = file.ReadLine>>"%VBS_COMP%"
echo     If regEx.Test(line) Then>>"%VBS_COMP%"
echo         WScript.Echo regEx.Replace(line, "$1")>>"%VBS_COMP%"
echo         Exit Do>>"%VBS_COMP%"
echo     End If>>"%VBS_COMP%"
echo Loop>>"%VBS_COMP%"
echo file.Close>>"%VBS_COMP%"

for /f "tokens=*" %%C in ('cscript //nologo "%VBS_COMP%"') do set "EXTRACTED_COMPANY=%%C"
if exist "%VBS_COMP%" del "%VBS_COMP%"
if "!EXTRACTED_COMPANY!"=="" set "EXTRACTED_COMPANY=Independent Developer"
echo Name aus LICENSE: !EXTRACTED_COMPANY!
cd /d "%~dp0"

echo ==================================================
echo   5. Windows-Ressourcedatei (.rc) generieren...
echo ==================================================
if exist midi_to_tab.rc del midi_to_tab.rc

echo 1 VERSIONINFO>>midi_to_tab.rc
echo FILEVERSION !VERSION_COMMAS!,0>>midi_to_tab.rc
echo PRODUCTVERSION !VERSION_COMMAS!,0>>midi_to_tab.rc
echo FILEFLAGSMASK 0x3fL>>midi_to_tab.rc
echo FILEFLAGS 0x0L>>midi_to_tab.rc
echo FILEOS 0x40004L>>midi_to_tab.rc
echo FILETYPE 0x2L>>midi_to_tab.rc
echo FILESUBTYPE 0x0L>>midi_to_tab.rc
echo BEGIN>>midi_to_tab.rc
echo     BLOCK "StringFileInfo">>midi_to_tab.rc
echo     BEGIN>>midi_to_tab.rc
echo         BLOCK "040904b0">>midi_to_tab.rc
echo         BEGIN>>midi_to_tab.rc
echo             VALUE "CompanyName", "!EXTRACTED_COMPANY!\0">>midi_to_tab.rc
echo             VALUE "FileDescription", "%APP_NAME%\0">>midi_to_tab.rc
echo             VALUE "FileVersion", "!DETECTED_VERSION!\0">>midi_to_tab.rc
echo             VALUE "InternalName", "%APP_NAME%\0">>midi_to_tab.rc
echo             VALUE "LegalCopyright", "Copyright \251 !BUILD_YEAR! !EXTRACTED_COMPANY!\0">>midi_to_tab.rc
echo             VALUE "OriginalFilename", "%EXE_FILE%\0">>midi_to_tab.rc
echo             VALUE "ProductName", "%APP_NAME%\0">>midi_to_tab.rc
echo             VALUE "ProductVersion", "!DETECTED_VERSION!\0">>midi_to_tab.rc
echo         END>>midi_to_tab.rc
echo     END>>midi_to_tab.rc
echo     BLOCK "VarFileInfo">>midi_to_tab.rc
echo     BEGIN>>midi_to_tab.rc
echo         VALUE "Translation", 0x409, 1200>>midi_to_tab.rc
echo     END>>midi_to_tab.rc
echo END>>midi_to_tab.rc

set "FPC_BIN_DIR=%SystemDrive%\lazarus\fpc\3.2.2\bin\x86_64-win64"
if not exist "%FPC_BIN_DIR%\windres.exe" (
    echo [Fehler] windres.exe fehlt!
    exit /b 1
)
"%FPC_BIN_DIR%\windres.exe" --preprocessor="type" -i midi_to_tab.rc -o midi_to_tab.res

echo ==================================================
echo   7. Kompiliere mit FPC...
echo ==================================================
if not exist "%LPR_FILE%" (
    echo [Fehler] %LPR_FILE% fehlt!
    exit /b 1
)
"%FPC_BIN_DIR%\fpc.exe" -O2 -Fusrc -Sg -Sc %LPR_FILE%
if !ERRORLEVEL! NEQ 0 (
    echo [Fehler] FPC fehlgeschlagen!
    exit /b 1
)
cd /d "%~dp0.."
