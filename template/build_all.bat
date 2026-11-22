@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM MyProject - Complete Multi-Target Build Script
REM Builds all programs + support files for Windows, macOS, Linux
REM Output goes to dist\<target>\
REM ============================================================

REM ============================================================
REM TEMPLATE: Replace "MyProject" with your actual project name.
REM The name is read from the NAME file in the repo root.
REM ============================================================

set "ROOT=%CD%"

REM --- Toolchain paths (override via environment variables if needed) ---
if not defined FPC_DIR set "FPC_DIR=C:\fpcupdeluxe\fpc\bin\i386-win32"
if not defined LAZBUILD set "LAZBUILD=C:\fpcupdeluxe\lazarus\lazbuild.exe"
if not defined CROSS_BIN_DIR set "CROSS_BIN_DIR=C:\fpcupdeluxe\cross\bin"
set "FPC=%FPC_DIR%\fpc.exe"
set "OUT_ROOT=%ROOT%\dist"
if not defined ISCC (
    set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
    if not exist "!ISCC!" set "ISCC=%ProgramFiles%\Inno Setup 6\ISCC.exe"
)
if not defined TAR set "TAR=tar"
set "APP_NAME=MyProject"
set "EXE_FILE=MyProject.exe"

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

REM --- Read version from Assets/version.txt and increment build counter ---
REM The patch level is bumped on every build so that version-stamped artifacts
REM (installer, tarballs, bundles) never collide. Set NO_VERSION_BUMP=1 to build
REM the version currently in version.txt without rewriting it (idempotent builds).

set "DETECTED_VERSION=1.0.0"

set "MAJOR=1"

set "MINOR=0"

set "PATCH=0"

if exist "%ROOT%\Assets\version.txt" (

    for /f "usebackq tokens=1,2,3 delims=." %%a in ("%ROOT%\Assets\version.txt") do (

        set "MAJOR=%%a"

        set "MINOR=%%b"

        set "PATCH=%%c"

    )

)

if not defined NO_VERSION_BUMP set /a PATCH=%PATCH% + 1

set "DETECTED_VERSION=!MAJOR!.!MINOR!.!PATCH!"

set "VERSION_COMMAS=!MAJOR!,!MINOR!,!PATCH!"

REM --- Clean previous output directory (del cannot remove a directory) ---
if exist "%ROOT%\dist" rmdir /s /q "%ROOT%\dist"

if not defined NO_VERSION_BUMP echo !MAJOR!.!MINOR!.!PATCH!>"%ROOT%\Assets\version.txt"

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

REM --- Determine build year (used in the VERSIONINFO LegalCopyright string) ---
set "BUILD_YEAR="
for /f "tokens=2 delims==" %%Y in ('wmic OS get LocalDateTime /format:list 2^>nul') do if not defined BUILD_YEAR set "BUILD_YEAR=%%Y"
if defined BUILD_YEAR set "BUILD_YEAR=!BUILD_YEAR:~0,4!"
if not defined BUILD_YEAR set "BUILD_YEAR=%DATE:~-4%"

REM --- Generate VERSIONINFO resource file (simplified) ---
echo 1 VERSIONINFO > "%ROOT%\%APP_NAME%.rc"
echo FILEVERSION !VERSION_COMMAS!,0 >> "%ROOT%\%APP_NAME%.rc"
echo PRODUCTVERSION !VERSION_COMMAS!,0 >> "%ROOT%\%APP_NAME%.rc"
echo FILEFLAGSMASK 0x3fL >> "%ROOT%\%APP_NAME%.rc"
echo FILEFLAGS 0x0L >> "%ROOT%\%APP_NAME%.rc"
echo FILEOS 0x40004L >> "%ROOT%\%APP_NAME%.rc"
echo FILETYPE 0x2L >> "%ROOT%\%APP_NAME%.rc"
echo FILESUBTYPE 0x0L >> "%ROOT%\%APP_NAME%.rc"
echo BEGIN >> "%ROOT%\%APP_NAME%.rc"
echo     BLOCK "StringFileInfo" >> "%ROOT%\%APP_NAME%.rc"
echo     BEGIN >> "%ROOT%\%APP_NAME%.rc"
echo         BLOCK "040904b0" >> "%ROOT%\%APP_NAME%.rc"
echo         BEGIN >> "%ROOT%\%APP_NAME%.rc"
echo             VALUE "CompanyName", "!EXTRACTED_COMPANY!" >> "%ROOT%\%APP_NAME%.rc"
echo             VALUE "FileDescription", "%APP_NAME%" >> "%ROOT%\%APP_NAME%.rc"
echo             VALUE "FileVersion", "!DETECTED_VERSION!" >> "%ROOT%\%APP_NAME%.rc"
echo             VALUE "InternalName", "%APP_NAME%" >> "%ROOT%\%APP_NAME%.rc"
echo             VALUE "LegalCopyright", "Copyright !BUILD_YEAR! !EXTRACTED_COMPANY!" >> "%ROOT%\%APP_NAME%.rc"
echo             VALUE "OriginalFilename", "%EXE_FILE%" >> "%ROOT%\%APP_NAME%.rc"
echo             VALUE "ProductName", "%APP_NAME%" >> "%ROOT%\%APP_NAME%.rc"
echo             VALUE "ProductVersion", "!DETECTED_VERSION!" >> "%ROOT%\%APP_NAME%.rc"
echo         END >> "%ROOT%\%APP_NAME%.rc"
    echo     END >> "%ROOT%\%APP_NAME%.rc"
    echo     BLOCK "VarFileInfo" >> "%ROOT%\%APP_NAME%.rc"
    echo     BEGIN >> "%ROOT%\%APP_NAME%.rc"
    echo         VALUE "Translation", 0x409, 1200 >> "%ROOT%\%APP_NAME%.rc"
    echo     END >> "%ROOT%\%APP_NAME%.rc"
    echo END >> "%ROOT%\%APP_NAME%.rc"

REM --- Compile resource file ---
if exist "%FPC_DIR%\windres.exe" (
    "%FPC_DIR%\windres.exe" --preprocessor="type" -i "%ROOT%\%APP_NAME%.rc" -o "%ROOT%\%APP_NAME%.res"
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

REM --- Verify tools (also used by --check) ---
call :verify_tools
if errorlevel 1 exit /b 1

REM --- --check: report readiness and exit without building ---
if /i "%~1"=="--check" (
    echo.
    echo All required tools found - ready to build.
    exit /b 0
)

if not exist "%OUT_ROOT%" mkdir "%OUT_ROOT%"

REM ============================================================
REM Target definitions: NAME|OS|CPU|WS|COMPILER|EXTRA_FLAGS|XP_PREFIX
REM COMPILER: "native" = fpc.exe, "cross" = ppcross*.exe
REM XP_PREFIX: cross-linker prefix for -XP (empty for win64)
REM ============================================================
REM TEMPLATE: Adjust the target list to match your project's needs.
REM Each line calls :do_target with 7 arguments.
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

REM Copy Linux tar.gz packages (packaging writes version-stamped names)
if exist "%OUT_ROOT%\%APP_NAME%!DETECTED_VERSION!-linux-x64.tar.gz" (
    copy /y "%OUT_ROOT%\%APP_NAME%!DETECTED_VERSION!-linux-x64.tar.gz" "%ROOT%\Deploy\%APP_NAME%!DETECTED_VERSION!-linux-x64.tar.gz" >nul
    echo   OK: %APP_NAME%!DETECTED_VERSION!-linux-x64.tar.gz
)
if exist "%OUT_ROOT%\%APP_NAME%!DETECTED_VERSION!-linux-arm.tar.gz" (
    copy /y "%OUT_ROOT%\%APP_NAME%!DETECTED_VERSION!-linux-arm.tar.gz" "%ROOT%\Deploy\%APP_NAME%!DETECTED_VERSION!-linux-arm.tar.gz" >nul
    echo   OK: %APP_NAME%!DETECTED_VERSION!-linux-arm.tar.gz
)

REM Copy macOS .app bundles
REM xcopy merges into an existing directory, so a bundle from an earlier build
REM would keep files that no longer exist. Clear the version-stamped destination
REM first so the deployed bundle is exact.
if exist "%OUT_ROOT%\macos-intel\%APP_NAME%_gui.app" (
    if exist "%ROOT%\Deploy\%APP_NAME%_gui!DETECTED_VERSION!-macos-intel.app" rmdir /s /q "%ROOT%\Deploy\%APP_NAME%_gui!DETECTED_VERSION!-macos-intel.app"
    xcopy /y /e /i "%OUT_ROOT%\macos-intel\%APP_NAME%_gui.app" "%ROOT%\Deploy\%APP_NAME%_gui!DETECTED_VERSION!-macos-intel.app" >nul
    echo   OK: %APP_NAME%_gui-macos-intel.app
)
if exist "%OUT_ROOT%\macos-aarch64\%APP_NAME%_gui.app" (
    if exist "%ROOT%\Deploy\%APP_NAME%_gui!DETECTED_VERSION!-macos-aarch64.app" rmdir /s /q "%ROOT%\Deploy\%APP_NAME%_gui!DETECTED_VERSION!-macos-aarch64.app"
    xcopy /y /e /i "%OUT_ROOT%\macos-aarch64\%APP_NAME%_gui.app" "%ROOT%\Deploy\%APP_NAME%_gui!DETECTED_VERSION!-macos-aarch64.app" >nul
    echo   OK: %APP_NAME%_gui-macos-aarch64.app
)

REM Zip the macOS bundles for GitHub Releases.
REM Do NOT use Compress-Archive or bsdtar here: Windows/NTFS has no executable
REM bit, so both would store the binaries as 0644 and they would not run after
REM extraction on macOS. tools/zip_app.py writes explicit Unix modes instead
REM (0755 for Contents/MacOS and Contents/Resources/tools, 0644 otherwise).
if exist "%ROOT%\Deploy\%APP_NAME%_gui!DETECTED_VERSION!-macos-intel.app" (
    python "%ROOT%\tools\zip_app.py" "%ROOT%\Deploy\%APP_NAME%_gui!DETECTED_VERSION!-macos-intel.app" "%ROOT%\Deploy\%APP_NAME%_gui!DETECTED_VERSION!-macos-intel.zip"
    if errorlevel 1 (
        echo   WARNING: failed to zip macos-intel bundle
    ) else (
        echo   OK: %APP_NAME%_gui!DETECTED_VERSION!-macos-intel.zip
    )
)
if exist "%ROOT%\Deploy\%APP_NAME%_gui!DETECTED_VERSION!-macos-aarch64.app" (
    python "%ROOT%\tools\zip_app.py" "%ROOT%\Deploy\%APP_NAME%_gui!DETECTED_VERSION!-macos-aarch64.app" "%ROOT%\Deploy\%APP_NAME%_gui!DETECTED_VERSION!-macos-aarch64.zip"
    if errorlevel 1 (
        echo   WARNING: failed to zip macos-aarch64 bundle
    ) else (
        echo   OK: %APP_NAME%_gui!DETECTED_VERSION!-macos-aarch64.zip
    )
)

echo.
echo   All packages copied to %ROOT%\Deploy\
echo.

REM --- Build summary + exit code ---
call :print_summary
echo.
if !SUMMARY_FAIL! GTR 0 (
    echo Build finished with !SUMMARY_FAIL! failed target^(s^).
    exit /b 1
)
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

REM --- Clean previous build artifacts ---
echo [Clean] Removing previous build artifacts...
del /q "%ROOT%\*.o" "%ROOT%\*.ppu" "%ROOT%\*.exe" "%ROOT%\*.res" 2>nul
rmdir /s /q "%ROOT%\%APP_NAME%_gui.app" 2>nul
del /q "%ROOT%\gui\*.o" "%ROOT%\gui\*.ppu" "%ROOT%\gui\*.exe" "%ROOT%\gui\*.res" 2>nul
del /q "%ROOT%\gui\lib\*.o" "%ROOT%\gui\lib\*.ppu" 2>nul
del /q "%ROOT%\src\*.o" "%ROOT%\src\*.ppu" 2>nul

REM --- Select compiler ---
REM NOTE: CC_FLAGS intentionally holds no filesystem paths. The -Fu"%ROOT%\src"
REM include path is appended at each compile call site so that ROOT is expanded
REM normally (not stored in a variable), which keeps special characters such as
REM '&' intact.
if "%COMPILER%"=="native" (
    set "CC=%FPC%"
    set "CC_FLAGS=-O2"
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
    set "CC_FLAGS=-T%T_OS% -P%T_CPU% -O2 %XP_PREFIX% %EXTRA_FLAGS%"
    if "%T_OS%"=="darwin" set "PATH=%CROSS_BIN_DIR%\all-apple\bin;%PATH%"
    if "%T_OS%"=="linux" set "PATH=%CROSS_BIN_DIR%\%T_OS%-%T_CPU%;%PATH%"
)

REM --- Compile resource file for Windows targets ---
if "%T_OS%"=="win64" (
    echo [Res] Compiling resource file...
    "%FPC_DIR%\windres.exe" --preprocessor="type" -i "%ROOT%\%APP_NAME%.rc" -o "%ROOT%\%APP_NAME%.res" --target=pe-x86-64
    if errorlevel 1 (
        echo   ERROR: Resource compilation failed
        goto :target_failed
    )
    echo   OK
    echo [Res] Compiling %APP_NAME%_gui resource file...
    "%FPC_DIR%\windres.exe" --preprocessor="type" -i "%ROOT%\gui\%APP_NAME%_gui.rc" -o "%ROOT%\gui\%APP_NAME%_gui.res" --target=pe-x86-64
    if errorlevel 1 (
        echo   ERROR: %APP_NAME%_gui resource compilation failed
        goto :target_failed
    )
    echo   OK
)

REM --- CLI: %APP_NAME% ---
echo.
echo [CLI] %APP_NAME%...
pushd "%ROOT%"
if errorlevel 1 (
    echo   ERROR: pushd failed
    goto :target_failed
)
"%CC%" %CC_FLAGS% -Fu"%ROOT%\src" -FE"%TD%" %APP_NAME%.lpr
if errorlevel 1 (
    echo   ERROR: %APP_NAME% CLI build failed
    popd
    goto :target_failed
)
popd
echo   OK

REM --- GUI: %APP_NAME%_gui ---
echo.
echo [GUI] %APP_NAME%_gui...
"%LAZBUILD%" --os=%T_OS% --cpu=%T_CPU% --ws=%T_WS% --build-all "%ROOT%\gui\%APP_NAME%_gui.lpi"
if errorlevel 1 (
    echo   ERROR: %APP_NAME%_gui build failed
    goto :target_failed
)
echo   OK

REM --- Move GUI executables into target dir ---
echo.
echo [GUI] Moving GUI executables...

REM %APP_NAME%_gui.lpi target is ../%APP_NAME%_gui -> project root
if "%T_OS%"=="darwin" (
    if exist "%ROOT%\%APP_NAME%_gui.app" (
        move /y "%ROOT%\%APP_NAME%_gui.app" "%TD%\" >nul 2>&1
        echo   moved %APP_NAME%_gui.app
    ) else (
        echo   WARNING: %APP_NAME%_gui.app not found at expected locations
    )
) else if exist "%ROOT%\%APP_NAME%_gui.exe" (
    move /y "%ROOT%\%APP_NAME%_gui.exe" "%TD%\" >nul 2>&1
    echo   moved %APP_NAME%_gui.exe
) else if exist "%ROOT%\gui\%APP_NAME%_gui.exe" (
    move /y "%ROOT%\gui\%APP_NAME%_gui.exe" "%TD%\" >nul 2>&1
    echo   moved gui\%APP_NAME%_gui.exe
) else if exist "%ROOT%\gui\%APP_NAME%_gui" (
    move /y "%ROOT%\gui\%APP_NAME%_gui" "%TD%\" >nul 2>&1
    echo   moved gui\%APP_NAME%_gui
) else if exist "%ROOT%\%APP_NAME%_gui" (
    move /y "%ROOT%\%APP_NAME%_gui" "%TD%\" >nul 2>&1
    echo   moved %APP_NAME%_gui
) else (
    echo   WARNING: %APP_NAME%_gui not found at expected locations
)

REM ============================================================
REM TEMPLATE: If your project has helper tools (CLI or GUI) that
REM should be built alongside the main programs, add their build
REM and move sections here. Follow the same pattern as the main
REM CLI and GUI builds above.
REM ============================================================

REM --- Copy support files (matches installer.iss expectations) ---
echo.
echo [Files] Copying support files...

REM TEMPLATE: Adjust these copy commands to match your project's
REM assets. The examples below cover common directories.
REM Remove or add lines as needed.

REM Assets
if not exist "%TD%\Assets" mkdir "%TD%\Assets"
call :copy_glob "%ROOT%\Assets\*" "%TD%\Assets\" "Assets"

REM Config
if not exist "%TD%\config" mkdir "%TD%\config"
call :copy_glob "%ROOT%\config\*.ini" "%TD%\config\" "config/*.ini"
call :copy_glob "%ROOT%\config\*.json" "%TD%\config\" "config/*.json"
call :copy_glob "%ROOT%\config\*.txt" "%TD%\config\" "config/*.txt"

REM Root docs
call :copy_glob "%ROOT%\LICENSE" "%TD%\" "LICENSE"
call :copy_glob "%ROOT%\README.md" "%TD%\" "README.md"
call :copy_glob "%ROOT%\CONTRIBUTING.md" "%TD%\" "CONTRIBUTING.md"
call :copy_glob "%ROOT%\NAME" "%TD%\" "NAME"
set "TD=%OUT_ROOT%\%T_NAME%"

if "%T_OS%"=="darwin" (
    echo [Pkg] Creating macOS .app bundles...
    REM The CLI is built into %TD% (not into the bundle), so stage it where
    REM :make_app_bundle expects to find it before building the GUI bundle.
    if exist "%TD%\%APP_NAME%" (
        copy /y "%TD%\%APP_NAME%" "%TD%\%APP_NAME%_gui" >nul 2>&1
    ) else if exist "%TD%\%APP_NAME%.exe" (
        copy /y "%TD%\%APP_NAME%.exe" "%TD%\%APP_NAME%_gui" >nul 2>&1
    )
    call :make_app_bundle "%TD%" "%APP_NAME%_gui" "%APP_NAME%"
) else if "%T_OS%"=="linux" (
    echo [Pkg] Creating Linux .tar.gz package...
    pushd "%OUT_ROOT%"
    if errorlevel 1 (
        echo   ERROR: pushd failed
        goto :target_failed
    )
    REM Windows/NTFS has no executable bit, so a plain tar stores every binary as
    REM 0644 and the programs will not run after extraction on Linux. Build the
    REM archive in two passes over an uncompressed tar: everything first, then the
    REM executables with --mode=u+x. (GNU tar cannot append to a .tar.gz.)
    set "PKG=%APP_NAME%!DETECTED_VERSION!-%T_NAME%.tar.gz"
    REM NOTE: use a POSIX-style temp path. GNU tar (first on PATH in Git Bash)
    REM reads "C:/..." as a remote host and fails with "Cannot connect to C:".
    set "TARBALL=/tmp/mytmp_%T_NAME%.tar"
    tar -cf "!TARBALL!" --exclude="%T_NAME%/%APP_NAME%" --exclude="%T_NAME%/%APP_NAME%_gui" "%T_NAME%"
    if errorlevel 1 (
        echo   ERROR: tar packaging failed
        popd
        goto :target_failed
    )
    tar -rf "!TARBALL!" --mode='u=rwx,go=rx' "%T_NAME%/%APP_NAME%" "%T_NAME%/%APP_NAME%_gui"
    if errorlevel 1 (
        echo   ERROR: tar packaging failed
        rm -f "!TARBALL!"
        popd
        goto :target_failed
    )
    gzip -f "!TARBALL!"
    if errorlevel 1 (
        echo   ERROR: tar packaging failed
        rm -f "!TARBALL!.gz"
        popd
        goto :target_failed
    )
    REM Use cp (Git Bash), not move: cmd.exe's move cannot handle POSIX /tmp paths.
    cp -f "!TARBALL!.gz" "!PKG!"
    if errorlevel 1 (
        echo   ERROR: tar packaging failed
        rm -f "!TARBALL!.gz"
        popd
        goto :target_failed
    )
    rm -f "!TARBALL!.gz"
    popd
    echo   OK: !PKG!
) else if "%T_OS%"=="win64" (
    echo [Pkg] Windows installer...
    if exist "%ISCC%" (
        echo   Copying executables to project root for installer...
        copy /y "%TD%\%APP_NAME%.exe" "%ROOT%\%APP_NAME%.exe" >nul 2>&1
        copy /y "%TD%\%APP_NAME%_gui.exe" "%ROOT%\%APP_NAME%_gui.exe" >nul 2>&1
        echo   Running Inno Setup compiler...
        pushd "%ROOT%\installer"
        if errorlevel 1 (
            echo   ERROR: pushd failed
            popd
            goto :target_failed
        )
        "%ISCC%" /Q /dMyAppId="%NEW_GUID%" /dMyAppName="%APP_NAME%" /dMyAppVersion="!DETECTED_VERSION!" /dMyExeName="%EXE_FILE%" /dMyAppPublisher="!EXTRACTED_COMPANY!" installer.iss
        if errorlevel 1 (
            echo   ERROR: Inno Setup compiler returned error
            popd
            goto :target_failed
        )
        echo   OK: Installer created
        if not exist "%ROOT%\Deploy" mkdir "%ROOT%\Deploy"
        copy /y "%ROOT%\%APP_NAME%_Setup_!DETECTED_VERSION!.exe" "%ROOT%\Deploy\%APP_NAME%_Setup_!DETECTED_VERSION!.exe" >nul 2>&1
        del /q "%ROOT%\%APP_NAME%_Setup_!DETECTED_VERSION!.exe" 2>nul
        popd
    ) else (
        echo   SKIP: Inno Setup compiler not found
        echo   Install Inno Setup to create Windows setup.exe
    )
)

echo.
echo [%T_NAME%] complete.
set "RESULT_%T_NAME%=OK"
goto :target_done

:target_failed
echo.
echo *** TARGET %T_NAME% FAILED ***
set "RESULT_%T_NAME%=FAIL"
popd 2>nul
goto :eof

:target_done
popd 2>nul
goto :eof

REM ============================================================
REM :make_app_bundle - creates a macOS .app bundle
REM Args: %1 = bundle directory, %2 = executable name, %3 = bundle display name
REM ============================================================
:make_app_bundle
set "BUNDLE_DIR=%~1"
set "BUNDLE_EXE=%~2"
set "DISPLAY_NAME=%~3"

set "APP_BUNDLE=%BUNDLE_DIR%\%BUNDLE_EXE%.app"
set "MACOS_DIR=%APP_BUNDLE%\Contents\MacOS"
set "RES_DIR=%APP_BUNDLE%\Contents\Resources"

if not exist "%MACOS_DIR%" mkdir "%MACOS_DIR%"
if not exist "%RES_DIR%" mkdir "%RES_DIR%"

REM Copy GUI executable into MacOS folder
if exist "%BUNDLE_DIR%\%BUNDLE_EXE%" (
    copy /y "%BUNDLE_DIR%\%BUNDLE_EXE%" "%MACOS_DIR%\%BUNDLE_EXE%" 2>nul
) else if exist "%BUNDLE_DIR%\%BUNDLE_EXE%.exe" (
    copy /y "%BUNDLE_DIR%\%BUNDLE_EXE%.exe" "%MACOS_DIR%\%BUNDLE_EXE%" 2>nul
)

REM Copy CLI executable into MacOS folder (if present)
if exist "%BUNDLE_DIR%\%APP_NAME%" (
    copy /y "%BUNDLE_DIR%\%APP_NAME%" "%MACOS_DIR%\%APP_NAME%" 2>nul
) else if exist "%BUNDLE_DIR%\%APP_NAME%.exe" (
    copy /y "%BUNDLE_DIR%\%APP_NAME%.exe" "%MACOS_DIR%\%APP_NAME%" 2>nul
)

REM Copy support files into Resources
xcopy /y /e /i "%BUNDLE_DIR%\Assets" "%RES_DIR%\Assets" >nul 2>nul
xcopy /y /e /i "%BUNDLE_DIR%\config" "%RES_DIR%\config" >nul 2>nul
copy /y "%BUNDLE_DIR%\LICENSE" "%RES_DIR%\LICENSE" >nul 2>nul
copy /y "%BUNDLE_DIR%\README.md" "%RES_DIR%\README.md" >nul 2>nul
copy /y "%BUNDLE_DIR%\CONTRIBUTING.md" "%RES_DIR%\CONTRIBUTING.md" >nul 2>nul
copy /y "%BUNDLE_DIR%\NAME" "%RES_DIR%\NAME" >nul 2>nul

REM Create PkgInfo
echo APPL???? > "%APP_BUNDLE%\Contents\PkgInfo"

REM The plist is written with delayed expansion DISABLED on purpose: with it
REM enabled, the "!DOCTYPE" sequence has its "!" swallowed and the "//" in the
REM DTD URL gets mangled, producing a malformed Info.plist.
set "PLIST_FILE=%APP_BUNDLE%\Contents\Info.plist"
setlocal disabledelayedexpansion
(
    echo ^<?xml version="1.0" encoding="UTF-8"?^>
    echo ^<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://apple.com"^>
    echo ^<plist version="1.0"^>
    echo ^<dict^>
    echo   ^<key^>CFBundleName^</key^>
    echo   ^<string^>%DISPLAY_NAME%^</string^>
    echo   ^<key^>CFBundleExecutable^</key^>
    echo   ^<string^>%BUNDLE_EXE%^</string^>
    echo   ^<key^>CFBundleIdentifier^</key^>
    echo   ^<string^>com.yourname.%BUNDLE_EXE%^</string^>
    echo   ^<key^>CFBundleInfoDictionaryVersion^</key^>
    echo   ^<string^>6.0^</string^>
    echo   ^<key^>CFBundlePackageType^</key^>
    echo   ^<string^>APPL^</string^>
    echo   ^<key^>CFBundleSignature^</key^>
    echo   ^<string^>????^</string^>
    echo   ^<key^>CFBundleShortVersionString^</key^>
    echo   ^<string^>%DETECTED_VERSION%^</string^>
    echo   ^<key^>CFBundleVersion^</key^>
    echo   ^<string^>%DETECTED_VERSION%^</string^>
    echo   ^<key^>LSMinimumSystemVersion^</key^>
    echo   ^<string^>10.13^</string^>
    echo   ^<key^>LSRequiresCarbon^</key^>
    echo   ^<false/^>
    echo   ^<key^>NSHighResolutionCapable^</key^>
    echo   ^<true/^>
    echo   ^<key^>NSPrincipalClass^</key^>
    echo   ^<string^>NSApplication^</string^>
    echo ^</dict^>
    echo ^</plist^>
) > "%PLIST_FILE%"
endlocal

echo   OK: %BUNDLE_EXE%.app
goto :eof

REM ============================================================
REM Helper: verify the toolchain is present
REM Returns 1 if any required tool is missing.
REM ============================================================
:verify_tools
set "TOOLS_OK=1"
if not exist "%FPC%" (
    echo ERROR: fpc.exe not found at %FPC%
    echo   Install fpcupdeluxe cross-compilers first.
    set "TOOLS_OK=0"
)
if not exist "%LAZBUILD%" (
    echo ERROR: lazbuild.exe not found at %LAZBUILD%
    set "TOOLS_OK=0"
)
if not exist "%FPC_DIR%\ppcrossx64.exe" (
    echo ERROR: ppcrossx64.exe not found - x86_64 cross-compiler missing
    set "TOOLS_OK=0"
)
if not exist "%FPC_DIR%\ppcrossa64.exe" (
    echo ERROR: ppcrossa64.exe not found - aarch64 cross-compiler missing
    set "TOOLS_OK=0"
)
if not exist "%FPC_DIR%\ppcrossarm.exe" (
    echo ERROR: ppcrossarm.exe not found - arm cross-compiler missing
    set "TOOLS_OK=0"
)
if not exist "%FPC_DIR%\windres.exe" (
    echo ERROR: windres.exe not found at %FPC_DIR%\windres.exe
    set "TOOLS_OK=0"
)
if "%TOOLS_OK%"=="1" (
    echo Tools OK: fpc, lazbuild, ppcrossx64, ppcrossa64, ppcrossarm, windres
    exit /b 0
)
exit /b 1

REM ============================================================
REM Helper: copy a file/glob, warning instead of failing silently
REM Args: %1 = source (file or glob), %2 = destination dir, %3 = label
REM ============================================================
:copy_glob
set "SRC=%~1"
set "DST=%~2"
set "LABEL=%~3"
if not exist "%SRC%" (
    echo   WARNING: missing %LABEL% - no files matched "%SRC%"
    goto :eof
)
copy /y "%SRC%" "%DST%" >nul
if errorlevel 1 (
    echo   WARNING: failed to copy %LABEL% from "%SRC%"
) else (
    echo   OK: %LABEL%
)
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
set "SUMMARY_FAIL=!FAIL!"
echo.
echo   Passed: !PASS!
echo   Failed: !FAIL!
echo   Skipped: !SKIP!
echo ==================================================

REM Only pause when running interactively (never in CI).
if not defined CI if not defined NO_PAUSE pause
goto :eof