@echo off
chcp 65001
setlocal enabledelayedexpansion

if "%GITHUB_ACTIONS%"=="true" ( set "IS_CI=1" ) else ( set "IS_CI=0" )

:: Jahr automatisch ermitteln
for /f "tokens=2 delims==" %%Y in ('wmic OS get LocalDateTime /format:list 2^>nul') do if not defined BUILD_YEAR set "BUILD_YEAR=%%Y"
if not defined BUILD_YEAR set "BUILD_YEAR=%DATE:~-4%"

:: Inno Setup Pfad
set "ISCC_PATH=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if not exist "%ISCC_PATH%" if exist "%ProgramFiles%\Inno Setup 6\ISCC.exe" set "ISCC_PATH=%ProgramFiles%\Inno Setup 6\ISCC.exe"

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
    echo !DETECTED_VERSION! > assets\version.txt
)
set "VERSION_COMMAS=!DETECTED_VERSION:.=,!"

echo.
echo ==================================================
echo   3. [Clean] Bereinige alte Compiler-Dateien...
echo ==================================================
del /q /s *.o *.ppu *.res 2>nul
echo Compiler-Cache bereinigt.

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
) > version.rc

set "FPC_BIN_DIR=%SystemDrive%\lazarus\fpc\3.2.2\bin\x86_64-win64"
if not exist "%FPC_BIN_DIR%\windres.exe" ( echo [Fehler] windres.exe fehlt! & exit /b 1 )
"%FPC_BIN_DIR%\windres.exe" --preprocessor="type" -i version.rc -o version.res

e
echo.
echo ==================================================
echo   7. Kompiliere mit FPC...
echo ==================================================
if not exist "%LPR_FILE%" ( echo [Fehler] %LPR_FILE% fehlt! & exit /b 1 )
"%FPC_BIN_DIR%\fpc.exe" -O2 -Fusrc -Sg -Sc %LPR_FILE%
if !ERRORLEVEL! NEQ 0 ( echo [Fehler] FPC fehlgeschlagen! & if "!IS_CI!"=="0" pause & exit /b 1 )

copy /Y "LICENSE" "assets\LICENSE.txt" >nul

echo.
echo ==================================================
echo   8. GUID generieren...
echo ==================================================
set "VBS_GUID=%TEMP%\get_guid.vbs"
(
    echo Set TypeLib = CreateObject("Scriptlet.TypeLib"^)
    echo WScript.Echo TypeLib.Guid
) > "%VBS_GUID%"
for /f "tokens=*" %%i in ('cscript //nologo "%VBS_GUID%"') do set "RAW_GUID=%%i"
del "%VBS_GUID%" >nul 2>&1
set "NEW_GUID=%RAW_GUID:~0,38%"

echo.
echo ==================================================
echo   9. Inno Setup Compiler...
echo ==================================================
"%ISCC_PATH%" /dMyAppId="%NEW_GUID%" /dMyAppName="%APP_NAME%" /dMyAppVersion="%DETECTED_VERSION%" /dMyExeName="%EXE_FILE%" /dMyAppPublisher="%EXTRACTED_COMPANY%" "installer\installer.iss"
if %ERRORLEVEL% NEQ 0 ( echo [Fehler] ISCC fehlgeschlagen! & if "!IS_CI!"=="0" pause & exit /b 1 )

set "SETUP_EXE=!APP_NAME!_Setup_!DETECTED_VERSION!.exe"
echo.
echo ==================================================
echo   10. Backup + Installation...
echo ==================================================

:: Backup falls 7-Zip da ist
if exist "%ProgramFiles%\7-Zip\7z.exe" (
    set "Z7=%ProgramFiles%\7-Zip\7z.exe"
) else if exist "%ProgramFiles(x86)%\7-Zip\7z.exe" (
    set "Z7=%ProgramFiles(x86)%\7-Zip\7z.exe"
) else (
    where /q 7z.exe 2>nul && set "Z7=7z" || set "Z7="
)

if defined Z7 (
    echo Erstelle Backup...
    "!Z7!" a -t7z "!APP_NAME!_v!DETECTED_VERSION!.7z" *.lpr *.bat *.iss *.rc *.res *.o *.ppu LICENSE NAME README.md CONTRIBUTING.md CREDITS.md .gitignore assets\ installer\ lv2\ src\ -mx=9 >nul 2>&1
    if exist "!APP_NAME!_v!DETECTED_VERSION!.7z" (
        echo [OK] Backup: !APP_NAME!_v!DETECTED_VERSION!.7z
    )
)
:: --- ARCHIVIERUNG MIT BAU-NUMMER ---
echo [*] Erstelle Tar-Archiv...

:: Bau-Nummer hochzählen
if exist "_build_counter.txt" (
    for /f "delims=" %%A in ('type _build_counter.txt') do set PREV_NUM=%%A
) else (
    set PREV_NUM=0
)
set /a BUILD_NUM=%PREV_NUM% + 1
echo %BUILD_NUM% > _build_counter.txt

:: Komplett-Backup aller Quellen als ZIP-Archiv im Parent-Verzeichnis
tar -z -c -f "..\\CameleonDrummer%BUILD_NUM%.tgz" --exclude="*.log" --exclude="*.tar.gz" --exclude="__pycache__" --exclude="ardour-source" .

if errorlevel 1 (
    echo [FEHLER] Die Archivierung ist fehlgeschlagen!
) else (
    echo [+] Archiv wurde erfolgreich erstellt.
)

:: Installation starten
if exist "!SETUP_EXE!" (
    echo Starte Installation...
    start /wait "" "!SETUP_EXE!" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
    echo [OK] Installation abgeschlossen.
) else (
    echo [Warnung] !SETUP_EXE! nicht gefunden!
)

echo.
if "!IS_CI!"=="0" pause
exit /b 0
