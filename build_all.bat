@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM ChameleonDrummer - Complete Multi-Target Build Script
REM Builds all 4 programs + support files for Windows, macOS, Linux
REM Does NOT modify existing build batches or source code
REM Output goes to dist\<target>\
REM ============================================================

set "ROOT=%CD%"
set "FPC_DIR=C:\fpcupdeluxe\fpc\bin\i386-win32"
set "LAZBUILD=C:\fpcupdeluxe\lazarus\lazbuild.exe"
set "FPC=%FPC_DIR%\fpc.exe"
set "OUT_ROOT=%ROOT%\dist"
set "CROSS_BIN_DIR=C:\fpcupdeluxe\cross\bin"
set "ISCC=%ProgramFiles(x86)%\\Inno Setup 6\\ISCC.exe"
if not exist "%ISCC%" set "ISCC=%ProgramFiles%\\Inno Setup 6\\ISCC.exe"
set "TAR=tar"
set "APP_NAME=ChameleonDrummer"
set "EXE_FILE=ChameleonDrummer.exe"

REM --- Read project name from NAME file ---
set "APP_NAME_FROM_FILE="
if exist "%ROOT%\NAME" (
    set /p APP_NAME_FROM_FILE=< "%ROOT%\NAME"
)
if not "%APP_NAME_FROM_FILE%"=="" (
    set "APP_NAME=%APP_NAME_FROM_FILE: =%"
    set "EXE_FILE=%APP_NAME%.exe"
    set "LPR_FILE=%APP_NAME%.lpr"
)

REM --- Read version from assets/version.txt and increment build counter ---

set "DETECTED_VERSION=1.1.0"

set "MAJOR=1"

set "MINOR=1"

set "PATCH=0"

if exist "%ROOT%\Assets\version.txt" (

    for /f "usebackq tokens=1,2,3 delims=." %%a in ("%ROOT%\Assets\version.txt") do (

        set "MAJOR=%%a"

        set "MINOR=%%b"

        set "PATCH=%%c"

    )

)

set /a PATCH=%PATCH% + 1

set "DETECTED_VERSION=!MAJOR!.!MINOR!.!PATCH!"
set "VERSION_COMMAS=!MAJOR!,!MINOR!,!PATCH!"

echo !MAJOR!.!MINOR!.!PATCH! > "%ROOT%\Assets\version.txt"

echo Build version: !DETECTED_VERSION!

REM --- Extract company from LICENSE file ---
set "EXTRACTED_COMPANY="
if exist "%ROOT%\LICENSE" (
    for /f "usebackq delims=:" %%L in (`type "%ROOT%\LICENSE" ^| findstr /i "Copyright"`) do (
        if !errorlevel! equ 0 (
            for /f "tokens=3* delims= " %%x in ("%%L") do set "EXTRACTED_COMPANY=%%y"
            goto :foundCopyright
        )
    )
)
:foundCopyright
if "%EXTRACTED_COMPANY%"=="" set "EXTRACTED_COMPANY=Independent Developer"

REM --- Generate VERSIONINFO resource file (simplified) ---
echo 1 VERSIONINFO > "%ROOT%\ChameleonDrummer.rc"
echo FILEVERSION !VERSION_COMMAS!,0 >> "%ROOT%\ChameleonDrummer.rc"
echo PRODUCTVERSION !VERSION_COMMAS!,0 >> "%ROOT%\ChameleonDrummer.rc"
echo FILEFLAGSMASK 0x3fL >> "%ROOT%\ChameleonDrummer.rc"
echo FILEFLAGS 0x0L >> "%ROOT%\ChameleonDrummer.rc"
echo FILEOS 0x40004L >> "%ROOT%\ChameleonDrummer.rc"
echo FILETYPE 0x2L >> "%ROOT%\ChameleonDrummer.rc"
echo FILESUBTYPE 0x0L >> "%ROOT%\ChameleonDrummer.rc"
echo BEGIN >> "%ROOT%\ChameleonDrummer.rc"
echo     BLOCK "StringFileInfo" >> "%ROOT%\ChameleonDrummer.rc"
echo     BEGIN >> "%ROOT%\ChameleonDrummer.rc"
echo         BLOCK "040904b0" >> "%ROOT%\ChameleonDrummer.rc"
echo         BEGIN >> "%ROOT%\ChameleonDrummer.rc"
echo             VALUE "CompanyName", "!EXTRACTED_COMPANY!" >> "%ROOT%\ChameleonDrummer.rc"
echo             VALUE "FileDescription", "%APP_NAME%" >> "%ROOT%\ChameleonDrummer.rc"
echo             VALUE "FileVersion", "!DETECTED_VERSION!" >> "%ROOT%\ChameleonDrummer.rc"
echo             VALUE "InternalName", "%APP_NAME%" >> "%ROOT%\ChameleonDrummer.rc"
echo             VALUE "LegalCopyright", "Copyright !BUILD_YEAR! !EXTRACTED_COMPANY!" >> "%ROOT%\ChameleonDrummer.rc"
echo             VALUE "OriginalFilename", "%EXE_FILE%" >> "%ROOT%\ChameleonDrummer.rc"
echo             VALUE "ProductName", "%APP_NAME%" >> "%ROOT%\ChameleonDrummer.rc"
echo             VALUE "ProductVersion", "!DETECTED_VERSION!" >> "%ROOT%\ChameleonDrummer.rc"
echo         END >> "%ROOT%\ChameleonDrummer.rc"
    echo     END >> "%ROOT%\ChameleonDrummer.rc"
    echo     BLOCK "VarFileInfo" >> "%ROOT%\ChameleonDrummer.rc"
    echo     BEGIN >> "%ROOT%\ChameleonDrummer.rc"
    echo         VALUE "Translation", 0x409, 1200 >> "%ROOT%\ChameleonDrummer.rc"
    echo     END >> "%ROOT%\ChameleonDrummer.rc"
    echo END >> "%ROOT%\ChameleonDrummer.rc"

REM --- Compile resource file ---
if exist "%FPC_DIR%\windres.exe" (
    "%FPC_DIR%\windres.exe" --preprocessor="type" -i "%ROOT%\ChameleonDrummer.rc" -o "%ROOT%\ChameleonDrummer.res"
    if errorlevel 1 (
        echo   WARNING: Resource compilation failed
    )
)

REM --- Generate GUID for Inno Setup ---
set "VBS_GUID=%TEMP%\get_guid.vbs"
(
    echo Set TypeLib = CreateObject("Scriptlet.TypeLib"^)
    echo WScript.Echo TypeLib.Guid
) > "%VBS_GUID%"
for /f "tokens=*" %%i in ('cscript //nologo "%VBS_GUID%"') do set "NEW_GUID=%%i"
del "%VBS_GUID%" >nul 2>&1
set "NEW_GUID=%NEW_GUID:~0,38%"

REM --- Verify tools ---
if not exist "%FPC%" (
    echo ERROR: fpc.exe not found at %FPC%
    echo   Install fpcupdeluxe cross-compilers first.
    exit /b 1
)
if not exist "%LAZBUILD%" (
    echo ERROR: lazbuild.exe not found at %LAZBUILD%
    exit /b 1
)
if not exist "%FPC_DIR%\ppcrossx64.exe" (
    echo ERROR: ppcrossx64.exe not found - x86_64 cross-compiler missing
    exit /b 1
)
if not exist "%FPC_DIR%\ppcrossa64.exe" (
    echo ERROR: ppcrossa64.exe not found - aarch64 cross-compiler missing
    exit /b 1
)
if not exist "%FPC_DIR%\ppcrossarm.exe" (
    echo ERROR: ppcrossarm.exe not found - arm cross-compiler missing
    exit /b 1
)

if not exist "%OUT_ROOT%" mkdir "%OUT_ROOT%"

REM ============================================================
REM Target definitions: NAME|OS|CPU|WS|COMPILER|EXTRA_FLAGS|XP_PREFIX
REM COMPILER: "native" = fpc.exe, "cross" = ppcross*.exe
REM XP_PREFIX: cross-linker prefix for -XP (empty for win64)
REM ============================================================
call :do_target "win64"      "win64"  "x86_64" "win32"  "cross"  ""           ""
call :do_target "macos-intel" "darwin" "x86_64" "cocoa"   "cross"  ""         "-XPx86_64-apple-darwin19-"
call :do_target "macos-aarch64" "darwin" "aarch64" "cocoa"  "cross"  ""         "-XPaarch64-apple-darwin19-"
call :do_target "linux-x64"  "linux"  "x86_64" "gtk2"   "cross"  ""         "-XPx86_64-linux-gnu-"
call :do_target "linux-arm"  "linux"  "arm"    "gtk2"   "cross"  "-CaEABIHF"  "-XParm-linux-gnueabihf-"

echo.
echo ==================================================
echo  ALL BUILD ATTEMPTS COMPLETE
==================================================
echo Output root: %OUT_ROOT%
echo.

REM --- Copy all installation packages to Deploy folder ---
echo.
echo [Deploy] Creating Deploy folder...
if not exist "%ROOT%\Deploy" mkdir "%ROOT%\Deploy"

REM Copy Linux tar.gz packages
if exist "%OUT_ROOT%\ChameleonDrummer-linux-x64.tar.gz" (
    copy /y "%OUT_ROOT%\ChameleonDrummer-linux-x64.tar.gz" "%ROOT%\Deploy\ChameleonDrummer-linux-x64.tar.gz" >nul
    echo   OK: ChameleonDrummer-linux-x64.tar.gz
)
if exist "%OUT_ROOT%\ChameleonDrummer-linux-arm.tar.gz" (
    copy /y "%OUT_ROOT%\ChameleonDrummer-linux-arm.tar.gz" "%ROOT%\Deploy\ChameleonDrummer-linux-arm.tar.gz" >nul
    echo   OK: ChameleonDrummer-linux-arm.tar.gz
)

REM Copy macOS .app bundles
if exist "%OUT_ROOT%\macos-intel\chameleondrummer_gui.app" (
    xcopy /y /e /i "%OUT_ROOT%\macos-intel\chameleondrummer_gui.app" "%ROOT%\Deploy\chameleondrummer_gui-macos-intel.app" >nul
    echo   OK: chameleondrummer_gui-macos-intel.app
)
if exist "%OUT_ROOT%\macos-aarch64\chameleondrummer_gui.app" (
    xcopy /y /e /i "%OUT_ROOT%\macos-aarch64\chameleondrummer_gui.app" "%ROOT%\Deploy\chameleondrummer_gui-macos-aarch64.app" >nul
    echo   OK: chameleondrummer_gui-macos-aarch64.app
)

echo.
echo   All packages copied to %ROOT%\Deploy\
echo.
exit /b 0

REM ============================================================
REM :do_target - builds one target
REM ============================================================
:do_target
set "T_NAME=%~1"
set "T_OS=%~2"
set "T_CPU=%~3"
set "T_WS=%~4"
set "COMPILER=%~5"
set "EXTRA_FLAGS=%~6"
set "XP_PREFIX=%~7"

set "TD=%OUT_ROOT%\%T_NAME%"

REM Normalize path separator (forward slash -> backslash)
if "%TD:~0,1%"=="/" set "TD=%TD:/=\%"

echo.
echo ==================================================
echo  Target: %T_NAME%  (%T_OS% %T_CPU% %T_WS%)
echo ==================================================

if not exist "%TD%" mkdir "%TD%"
if not exist "%TD%\tools" mkdir "%TD%\tools"

REM --- Clean previous build artifacts ---
echo [Clean] Removing previous build artifacts...
del /q "%ROOT%\*.o" "%ROOT%\*.ppu" "%ROOT%\*.exe" 2>nul
rmdir /s /q "%ROOT%\chameleondrummer_gui.app" 2>nul
del /q "%ROOT%\gui\*.o" "%ROOT%\gui\*.ppu" "%ROOT%\gui\*.exe" 2>nul
del /q "%ROOT%\gui\lib\*.o" "%ROOT%\gui\lib\*.ppu" 2>nul
del /q "%ROOT%\tools\*.o" "%ROOT%\tools\*.ppu" "%ROOT%\tools\*.exe" 2>nul
del /q "%ROOT%\tools\step_editor\*.o" "%ROOT%\tools\step_editor\*.ppu" "%ROOT%\tools\step_editor\*.exe" 2>nul
del /q "%ROOT%\tools\step_editor\lib\*.o" "%ROOT%\tools\step_editor\lib\*.ppu" 2>nul
del /q "%ROOT%\src\*.o" "%ROOT%\src\*.ppu" 2>nul

REM --- Select compiler ---
if "%COMPILER%"=="native" (
    set "CC=%FPC%"
    set "CC_FLAGS=-O2 -Fu"%ROOT%\src""
) else (
    if "%T_CPU%"=="x86_64" (
        set "CC=%FPC_DIR%\ppcrossx64.exe"
    ) else if "%T_CPU%"=="aarch64" (
        set "CC=%FPC_DIR%\ppcrossa64.exe"
    ) else if "%T_CPU%"=="arm" (
        set "CC=%FPC_DIR%\ppcrossarm.exe"
    ) else (
        set "CC=%FPC_DIR%\ppcross%T_CPU%.exe"
    )
    set "CC_FLAGS=-T%T_OS% -P%T_CPU% -O2 -Fu"%ROOT%\src" %XP_PREFIX% %EXTRA_FLAGS%"
    if "%T_OS%"=="darwin" set "PATH=%CROSS_BIN_DIR%\all-apple\bin;%PATH%"
    if "%T_OS%"=="linux" set "PATH=%CROSS_BIN_DIR%\%T_OS%-%T_CPU%;%PATH%"
)

REM --- Compile resource file for Windows targets ---
if "%T_OS%"=="win64" (
    echo [Res] Compiling resource file...
    "%FPC_DIR%\windres.exe" --preprocessor="type" -i "%ROOT%\ChameleonDrummer.rc" -o "%ROOT%\ChameleonDrummer.res" --target=pe-x86-64
    if errorlevel 1 (
        echo   ERROR: Resource compilation failed
        goto :target_done
    )
    echo   OK
    echo [Res] Compiling midi_to_tab resource file...
    "%FPC_DIR%\windres.exe" --preprocessor="type" -i "%ROOT%\tools\midi_to_tab.rc" -o "%ROOT%\tools\midi_to_tab.res" --target=pe-x86-64
    if errorlevel 1 (
        echo   ERROR: midi_to_tab resource compilation failed
        goto :target_done
    )
    echo   OK
    echo [Res] Compiling chameleondrummer_gui resource file...
    "%FPC_DIR%\windres.exe" --preprocessor="type" -i "%ROOT%\gui\chameleondrummer_gui.rc" -o "%ROOT%\gui\chameleondrummer_gui.res" --target=pe-x86-64
    if errorlevel 1 (
        echo   ERROR: chameleondrummer_gui resource compilation failed
        goto :target_done
    )
    echo   OK
    echo [Res] Compiling step_editor resource file...
    "%FPC_DIR%\windres.exe" --preprocessor="type" -i "%ROOT%\tools\step_editor\step_editor.rc" -o "%ROOT%\tools\step_editor\step_editor.res" --target=pe-x86-64
    if errorlevel 1 (
        echo   ERROR: step_editor resource compilation failed
        goto :target_done
    )
    echo   OK
)

REM --- CLI: ChameleonDrummer ---
echo.
echo [CLI] ChameleonDrummer...
pushd "%ROOT%" || (echo ERROR: pushd failed & exit /b 1)
"%CC%" %CC_FLAGS% -FE"%TD%" ChameleonDrummer.lpr
if errorlevel 1 (
    echo   ERROR: ChameleonDrummer CLI build failed
    popd
    goto :target_done
)
popd
echo   OK

REM --- CLI: midi_to_tab ---
echo.
echo [CLI] midi_to_tab...
if not exist "%TD%\tools" mkdir "%TD%\tools"
pushd "%ROOT%" || (echo ERROR: pushd failed & exit /b 1)
"%CC%" %CC_FLAGS% -FE"%TD%\tools" "tools\midi_to_tab.lpr"
if errorlevel 1 (
    echo   ERROR: midi_to_tab CLI build failed
    popd
    goto :target_done
)
popd
echo   OK

REM --- GUI: chameleondrummer_gui ---
echo.
echo [GUI] chameleondrummer_gui...
"%LAZBUILD%" --os=%T_OS% --cpu=%T_CPU% --ws=%T_WS% --build-all "%ROOT%\gui\chameleondrummer_gui.lpi"
if errorlevel 1 (
    echo   ERROR: chameleondrummer_gui build failed
    goto :target_done
)
echo   OK

REM --- GUI: step_editor ---
echo.
echo [GUI] step_editor...
"%LAZBUILD%" --os=%T_OS% --cpu=%T_CPU% --ws=%T_WS% --build-all "%ROOT%\tools\step_editor\step_editor.lpi"
if errorlevel 1 (
    echo   ERROR: step_editor build failed
    goto :target_done
)
echo   OK

REM --- Move GUI executables into target dir ---
echo.
echo [GUI] Moving GUI executables...

REM chameleondrummer_gui.lpi target is ../chameleondrummer_gui -> project root
if "%T_OS%"=="darwin" (
    if exist "%ROOT%\chameleondrummer_gui.app" (
        move /y "%ROOT%\chameleondrummer_gui.app" "%TD%\" >&1
        echo   moved chameleondrummer_gui.app
    ) else (
        echo   WARNING: chameleondrummer_gui.app not found at expected locations
    )
) else if exist "%ROOT%\chameleondrummer_gui.exe" (
    move /y "%ROOT%\chameleondrummer_gui.exe" "%TD%\" >&1
    echo   moved chameleondrummer_gui.exe
) else if exist "%ROOT%\gui\chameleondrummer_gui.exe" (
    move /y "%ROOT%\gui\chameleondrummer_gui.exe" "%TD%\" >&1
    echo   moved gui\chameleondrummer_gui.exe
) else if exist "%ROOT%\gui\chameleondrummer_gui" (
    move /y "%ROOT%\gui\chameleondrummer_gui" "%TD%\" >&1
    echo   moved gui\chameleondrummer_gui
) else if exist "%ROOT%\chameleondrummer_gui" (
    move /y "%ROOT%\chameleondrummer_gui" "%TD%\" >&1
    echo   moved chameleondrummer_gui
) else (
    echo   WARNING: chameleondrummer_gui not found at expected locations
)

REM step_editor.lpi target is ../step_editor relative to tools/step_editor/
if "%T_OS%"=="darwin" (
    if exist "%ROOT%\tools\step_editor\step_editor.app" (
        move /y "%ROOT%\tools\step_editor\step_editor.app" "%TD%\tools\" >&1
        echo   moved tools\step_editor\step_editor.app
    ) else (
        echo   WARNING: step_editor.app not found at expected locations
    )
) else if exist "%ROOT%\tools\step_editor\step_editor.exe" (
    move /y "%ROOT%\tools\step_editor\step_editor.exe" "%TD%\tools\" >&1
    echo   moved tools\step_editor\step_editor.exe
) else if exist "%ROOT%\tools\step_editor\step_editor" (
    move /y "%ROOT%\tools\step_editor\step_editor" "%TD%\tools\" >&1
    echo   moved tools\step_editor\step_editor
) else if exist "%ROOT%\tools\step_editor.exe" (
    move /y "%ROOT%\tools\step_editor.exe" "%TD%\tools\" >&1
    echo   moved tools\step_editor.exe
) else if exist "%ROOT%\step_editor.exe" (
    move /y "%ROOT%\step_editor.exe" "%TD%\tools\" >&1
    echo   moved step_editor.exe
) else if exist "%ROOT%\step_editor" (
    move /y "%ROOT%\step_editor" "%TD%\tools\" >&1
    echo   moved step_editor
) else (
    echo   WARNING: step_editor not found at expected locations
)

REM --- Copy support files (matches installer.iss expectations) ---
echo.
echo [Files] Copying support files...

REM mappings (project root, not src/)
if not exist "%TD%\mappings" mkdir "%TD%\mappings"
copy /y "%ROOT%\mappings\*.json" "%TD%\mappings\"

REM Assets/GMD
if not exist "%TD%\Assets\GMD" mkdir "%TD%\Assets\GMD"
copy /y "%ROOT%\Assets\GMD\*" "%TD%\Assets\GMD\"

REM Ardour lua
if not exist "%TD%\ardour" mkdir "%TD%\ardour"
copy /y "%ROOT%\ardour\*.lua" "%TD%\ardour\"

REM Config root
if not exist "%TD%\config" mkdir "%TD%\config"
copy /y "%ROOT%\config\*.ini" "%TD%\config\"
copy /y "%ROOT%\config\*.json" "%TD%\config\"
copy /y "%ROOT%\config\*.txt" "%TD%\config\"

REM Config subdirs
if not exist "%TD%\config\grooves" mkdir "%TD%\config\grooves"
copy /y "%ROOT%\config\grooves\*.tab" "%TD%\config\grooves\"

if not exist "%TD%\config\fills" mkdir "%TD%\config\fills"
copy /y "%ROOT%\config\fills\*.tab" "%TD%\config\fills\"

if not exist "%TD%\config\defaults" mkdir "%TD%\config\defaults"
copy /y "%ROOT%\config\defaults\*.ini" "%TD%\config\defaults\"

if not exist "%TD%\config\sections" mkdir "%TD%\config\sections"
copy /y "%ROOT%\config\sections\*.json" "%TD%\config\sections\"

REM Root docs
copy /y "%ROOT%\LICENSE" "%TD%\"
copy /y "%ROOT%\README.md" "%TD%\"
copy /y "%ROOT%\CONTRIBUTING.md" "%TD%\"
copy /y "%ROOT%\NAME" "%TD%\"
set "TD=%OUT_ROOT%\%T_NAME%"

if "%T_OS%"=="darwin" (
    echo [Pkg] Creating macOS .app bundles...
    call :make_app_bundle "%TD%" "chameleondrummer_gui" "ChameleonDrummer"
    call :make_app_bundle "%TD%\\tools" "step_editor" "StepEditor"
) else if "%T_OS%"=="linux" (
    echo [Pkg] Creating Linux .tar.gz package...
    pushd "%OUT_ROOT%" || (echo ERROR: pushd failed & exit /b 1)
    "%TAR%" -czf "ChameleonDrummer-%T_NAME%.tar.gz" "%T_NAME%"
    popd
    echo   OK: ChameleonDrummer-%T_NAME%.tar.gz
) else if "%T_OS%"=="win64" (
    echo [Pkg] Windows installer...
    if exist "%ISCC%" (
        echo   Copying executables to project root for installer...
        copy /y "%TD%\ChameleonDrummer.exe" "%ROOT%\ChameleonDrummer.exe" >nul 2>&1
        copy /y "%TD%\chameleondrummer_gui.exe" "%ROOT%\chameleondrummer_gui.exe" >nul 2>&1
        copy /y "%TD%\tools\midi_to_tab.exe" "%ROOT%\tools\midi_to_tab.exe" >nul 2>&1
        copy /y "%TD%\tools\step_editor.exe" "%ROOT%\tools\step_editor.exe" >nul 2>&1
        echo   Running Inno Setup compiler...
        pushd "%ROOT%\\installer" || (echo ERROR: pushd failed & exit /b 1)
        "%ISCC%" /Q /dMyAppId="%NEW_GUID%" /dMyAppName="%APP_NAME%" /dMyAppVersion="!DETECTED_VERSION!" /dMyExeName="%EXE_FILE%" /dMyAppPublisher="!EXTRACTED_COMPANY!" installer.iss
        if errorlevel 1 (
            echo   WARNING: Inno Setup compiler returned error
        ) else (
            echo   OK: Installer created
            if not exist "%ROOT%\Deploy" mkdir "%ROOT%\Deploy"
            copy /y "%ROOT%\%APP_NAME%_Setup_!DETECTED_VERSION!.exe" "%ROOT%\Deploy\%APP_NAME%_Setup_!DETECTED_VERSION!.exe" >nul 2>&1
            del /q "%ROOT%\%APP_NAME%_Setup_!DETECTED_VERSION!.exe" 2>nul
        )
        popd
    ) else (
        echo   SKIP: Inno Setup compiler not found
        echo   Install Inno Setup to create Windows setup.exe
    )
)

echo.
echo [%T_NAME%] complete.
goto :target_done

:target_failed
echo.
echo *** TARGET %T_NAME% FAILED ***

:target_done
popd 2>nul
goto :eof

REM ============================================================
REM :make_app_bundle - creates a macOS .app bundle
REM Args: %1 = bundle directory, %2 = executable name, %3 = bundle display name
REM ============================================================
:make_app_bundle
set "BUNDLE_DIR=%~1"
set "APP_NAME=%~2"
set "DISPLAY_NAME=%~3"

set "APP_BUNDLE=%BUNDLE_DIR%\%APP_NAME%.app"
set "MACOS_DIR=%APP_BUNDLE%\Contents\MacOS"
set "RES_DIR=%APP_BUNDLE%\Contents\Resources"

if not exist "%MACOS_DIR%" mkdir "%MACOS_DIR%"
if not exist "%RES_DIR%" mkdir "%RES_DIR%"

REM Copy GUI executable into MacOS folder
if exist "%BUNDLE_DIR%\\%APP_NAME%" (
    copy /y "%BUNDLE_DIR%\\%APP_NAME%" "%MACOS_DIR%\\%APP_NAME%" 2>nul
) else if exist "%BUNDLE_DIR%\\%APP_NAME%.exe" (
    copy /y "%BUNDLE_DIR%\\%APP_NAME%.exe" "%MACOS_DIR%\\%APP_NAME%" 2>nul
)

REM Copy CLI executable into MacOS folder (if present)
if exist "%BUNDLE_DIR%\\ChameleonDrummer" (
    copy /y "%BUNDLE_DIR%\\ChameleonDrummer" "%MACOS_DIR%\\ChameleonDrummer" 2>nul
) else if exist "%BUNDLE_DIR%\\ChameleonDrummer.exe" (
    copy /y "%BUNDLE_DIR%\\ChameleonDrummer.exe" "%MACOS_DIR%\\ChameleonDrummer" 2>nul
)

REM Copy tools into Resources/tools
if not exist "%RES_DIR%\\tools" mkdir "%RES_DIR%\\tools"
if exist "%BUNDLE_DIR%\\tools\\midi_to_tab" (
    copy /y "%BUNDLE_DIR%\\tools\\midi_to_tab" "%RES_DIR%\\tools\\midi_to_tab" 2>nul
)
if exist "%BUNDLE_DIR%\\tools\\step_editor" (
    copy /y "%BUNDLE_DIR%\\tools\\step_editor" "%RES_DIR%\\tools\\step_editor" 2>nul
)

REM Copy support files into Resources
xcopy /y /e /i "%BUNDLE_DIR%\\mappings" "%RES_DIR%\\mappings" >nul 2>nul
xcopy /y /e /i "%BUNDLE_DIR%\\Assets" "%RES_DIR%\\Assets" >nul 2>nul
xcopy /y /e /i "%BUNDLE_DIR%\\ardour" "%RES_DIR%\\ardour" >nul 2>nul
xcopy /y /e /i "%BUNDLE_DIR%\\config" "%RES_DIR%\\config" >nul 2>nul
copy /y "%BUNDLE_DIR%\\LICENSE" "%RES_DIR%\\LICENSE" >nul 2>nul
copy /y "%BUNDLE_DIR%\\README.md" "%RES_DIR%\\README.md" >nul 2>nul
copy /y "%BUNDLE_DIR%\\CONTRIBUTING.md" "%RES_DIR%\\CONTRIBUTING.md" >nul 2>nul
copy /y "%BUNDLE_DIR%\\NAME" "%RES_DIR%\\NAME" >nul 2>nul

REM Create PkgInfo
echo APPL???? > "%APP_BUNDLE%\\Contents\\PkgInfo"

REM Create Info.plist
echo ^?xml version="1.0" encoding="UTF-8"?^> > "%APP_BUNDLE%\\Contents\\Info.plist"
echo ^<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"^> >> "%APP_BUNDLE%\\Contents\\Info.plist"
echo ^<plist version="1.0"^> >> "%APP_BUNDLE%\\Contents\\Info.plist"
echo ^<dict^> >> "%APP_BUNDLE%\\Contents\\Info.plist"
echo   ^<key^>CFBundleName^</key^> >> "%APP_BUNDLE%\\Contents\\Info.plist"
echo   ^<string^>%DISPLAY_NAME%</string^> >> "%APP_BUNDLE%\\Contents\\Info.plist"
echo   ^<key^>CFBundleExecutable^</key^> >> "%APP_BUNDLE%\\Contents\\Info.plist"
echo   ^<string^>%APP_NAME%</string^> >> "%APP_BUNDLE%\\Contents\\Info.plist"
echo   ^<key^>CFBundleIdentifier^</key^> >> "%APP_BUNDLE%\\Contents\\Info.plist"
echo   ^<string^>com.chameleondrummer.%APP_NAME%</string^> >> "%APP_BUNDLE%\\Contents\\Info.plist"
echo   ^<key^>CFBundleInfoDictionaryVersion^</key^> >> "%APP_BUNDLE%\\Contents\\Info.plist"
echo   ^<string^>6.0</string^> >> "%APP_BUNDLE%\\Contents\\Info.plist"
echo   ^<key^>CFBundlePackageType^</key^> >> "%APP_BUNDLE%\\Contents\\Info.plist"
echo   ^<string^>APPL</string^> >> "%APP_BUNDLE%\\Contents\\Info.plist"
echo   ^<key^>CFBundleSignature^</key^> >> "%APP_BUNDLE%\\Contents\\Info.plist"
echo   ^<string^>????</string^> >> "%APP_BUNDLE%\\Contents\\Info.plist"
echo   ^<key^>LSRequiresCarbon^</key^> >> "%APP_BUNDLE%\\Contents\\Info.plist"
echo   ^<false/^> >> "%APP_BUNDLE%\\Contents\\Info.plist"
echo   ^<key^>NSHighResolutionCapable^</key^> >> "%APP_BUNDLE%\\Contents\\Info.plist"
echo   ^<true/^> >> "%APP_BUNDLE%\\Contents\\Info.plist"
echo ^</dict^> >> "%APP_BUNDLE%\\Contents\\Info.plist"
echo ^</plist^> >> "%APP_BUNDLE%\\Contents\\Info.plist"

echo   OK: %APP_NAME%.app
goto :eof

REM ============================================================
REM Helper: run command with logging (cmd.exe compatible, no tee)
REM ============================================================
:run_logged
set "CMD=%*"
%CMD%
exit /b %errorlevel%

REM ============================================================
REM Helper: print build summary
REM ============================================================
:print_summary
echo.
echo ==================================================
echo  BUILD SUMMARY
echo ==================================================
set "PASS=0"
set "FAIL=0"
set "SKIP=0"
for %%T in (win64 macos-intel macos-aarch64 linux-x64 linux-arm) do (
    if defined RESULT_%%T (
        if "!RESULT_%%T!"=="OK" (
            echo   [OK]     %%T
            set /a PASS+=1
        ) else if "!RESULT_%%T!"=="FAIL" (
            echo   [FAIL]   %%T
            set /a FAIL+=1
        ) else (
            echo   [SKIP]   %%T
            set /a SKIP+=1
        )
    ) else (
        echo   [SKIP]   %%T
        set /a SKIP+=1
    )
)
echo.
echo   Passed: %PASS%
echo   Failed: %FAIL%
echo   Skipped: %SKIP%
echo ==================================================

pause
goto :eof
