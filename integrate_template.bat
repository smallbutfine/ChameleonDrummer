@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM integrate_template.bat
REM Integrates the multi-platform build workflow into an
REM existing FreePascal/Lazarus project.
REM
REM Usage:
REM   integrate_template.bat [target_directory]
REM
REM If no directory is given, you will be prompted for one.
REM ============================================================

REM --- Configuration ---
set "TEMPLATE_DIR=%~dp0template"

REM --- Get target directory ---
if "%~1"=="" (
    echo.
    echo Enter the path to your project directory:
    echo e.g. B:\dev\github\MyOtherProject
    echo.
    set /p "TARGET_DIR="
) else (
    set "TARGET_DIR=%~1"
)

REM --- Normalize path (remove quotes, trailing backslash) ---
set "TARGET_DIR=%TARGET_DIR:"=%"
if "%TARGET_DIR:~-1%"=="\" set "TARGET_DIR=%TARGET_DIR:~0,-1%"

REM --- Verify template exists ---
if not exist "%TEMPLATE_DIR%" (
    echo ERROR: Template directory not found: %TEMPLATE_DIR%
    echo   Run this script from the ChameleonDrummer repo root.
    exit /b 1
)

REM --- Verify target directory exists ---
if not exist "%TARGET_DIR%" (
    echo ERROR: Target directory not found: %TARGET_DIR%
    exit /b 1
)

REM --- Detect project name from directory name ---
for %%i in ("%TARGET_DIR%") do set "PROJECT_NAME=%%~nxi"

REM --- Convert to lowercase for CI artifact names ---
for %%i in ("%TARGET_DIR%") do set "PROJECT_NAME_LOWER=%%~nxi"
for /f "delims=" %%L in ('powershell -Command "%PROJECT_NAME_LOWER".ToLower()') do set "PROJECT_NAME_LOWER=%%L"

echo.
echo ==================================================
echo  Integrate Template into Existing Project
echo ==================================================
echo.
echo  Template:  %TEMPLATE_DIR%
echo  Target:    %TARGET_DIR%
echo  Project:   %PROJECT_NAME%
echo.

REM --- Track what was done ---
set "COPIED=0"
set "SKIPPED=0"
set "CREATED=0"

REM ============================================================
REM 1. Copy build_all.bat (with name replacement)
REM ============================================================
echo [1/7] build_all.bat...
if exist "%TARGET_DIR%\build_all.bat" (
    echo   SKIP: already exists (delete it first to re-copy)
    set /a SKIPPED+=1
) else (
    powershell -Command "(Get-Content '%TEMPLATE_DIR%\build_all.bat') -replace 'MyProject', '%PROJECT_NAME%' | Set-Content '%TARGET_DIR%\build_all.bat'"
    if errorlevel 1 (
        echo   ERROR: copy failed
        exit /b 1
    )
    echo   OK: copied and adapted for %PROJECT_NAME%
    set /a COPIED+=1
)

REM ============================================================
REM 2. Copy .github/workflows/ci.yml (with name replacement)
REM ============================================================
echo [2/7] .github/workflows/ci.yml...
if not exist "%TARGET_DIR%\.github\workflows" mkdir "%TARGET_DIR%\.github\workflows"
if exist "%TARGET_DIR%\.github\workflows\ci.yml" (
    echo   SKIP: already exists (delete it first to re-copy)
    set /a SKIPPED+=1
) else (
    powershell -Command "(Get-Content '%TEMPLATE_DIR%\.github\workflows\ci.yml') -replace 'myproject', '%PROJECT_NAME_LOWER%' | Set-Content '%TARGET_DIR%\.github\workflows\ci.yml'"
    if errorlevel 1 (
        echo   ERROR: copy failed
        exit /b 1
    )
    echo   OK: copied and adapted for %PROJECT_NAME_LOWER%
    set /a COPIED+=1
)

REM ============================================================
REM 3. Copy tools/zip_app.py (no changes needed)
REM ============================================================
echo [3/7] tools/zip_app.py...
if not exist "%TARGET_DIR%\tools" mkdir "%TARGET_DIR%\tools"
if exist "%TARGET_DIR%\tools\zip_app.py" (
    echo   SKIP: already exists
    set /a SKIPPED+=1
) else (
    copy /y "%TEMPLATE_DIR%\tools\zip_app.py" "%TARGET_DIR%\tools\zip_app.py" >nul
    if errorlevel 1 (
        echo   ERROR: copy failed
        exit /b 1
    )
    echo   OK: copied
    set /a COPIED+=1
)

REM ============================================================
REM 4. Copy AGENTS.md (no changes needed)
REM ============================================================
echo [4/7] AGENTS.md...
if exist "%TARGET_DIR%\AGENTS.md" (
    echo   SKIP: already exists
    set /a SKIPPED+=1
) else (
    copy /y "%TEMPLATE_DIR%\AGENTS.md" "%TARGET_DIR%\AGENTS.md" >nul
    if errorlevel 1 (
        echo   ERROR: copy failed
        exit /b 1
    )
    echo   OK: copied
    set /a COPIED+=1
)

REM ============================================================
REM 5. Copy installer/installer.iss (with name replacement)
REM ============================================================
echo [5/7] installer/installer.iss...
if not exist "%TARGET_DIR%\installer" mkdir "%TARGET_DIR%\installer"
if exist "%TARGET_DIR%\installer\installer.iss" (
    echo   SKIP: already exists (delete it first to re-copy)
    set /a SKIPPED+=1
) else (
    powershell -Command "(Get-Content '%TEMPLATE_DIR%\installer\installer.iss') -replace 'MyProject', '%PROJECT_NAME%' | Set-Content '%TARGET_DIR%\installer\installer.iss'"
    if errorlevel 1 (
        echo   ERROR: copy failed
        exit /b 1
    )
    echo   OK: copied and adapted for %PROJECT_NAME%
    set /a COPIED+=1
)

REM ============================================================
REM 6. Create NAME file
REM ============================================================
echo [6/7] NAME file...
if exist "%TARGET_DIR%\NAME" (
    echo   SKIP: already exists
    set /a SKIPPED+=1
) else (
    echo %PROJECT_NAME%>"%TARGET_DIR%\NAME"
    echo   OK: created with value "%PROJECT_NAME%"
    set /a CREATED+=1
)

REM ============================================================
REM 7. Create Assets/version.txt
REM ============================================================
echo [7/7] Assets/version.txt...
if not exist "%TARGET_DIR%\Assets" mkdir "%TARGET_DIR%\Assets"
if exist "%TARGET_DIR%\Assets\version.txt" (
    echo   SKIP: already exists
    set /a SKIPPED+=1
) else (
    echo 1.0.0>"%TARGET_DIR%\Assets\version.txt"
    echo   OK: created with value "1.0.0"
    set /a CREATED+=1
)

REM ============================================================
REM Summary
REM ============================================================
echo.
echo ==================================================
echo  Integration Complete
echo ==================================================
echo.
echo   Copied:  !COPIED!
echo   Created: !CREATED!
echo   Skipped: !SKIPPED! (already existed)
echo.
echo  ==================================================
echo  MANUAL STEPS REMAINING
echo  ==================================================
echo.
echo  1. Review build_all.bat:
echo     - Adjust the 'call :do_target' lines if you need
echo       different targets (default: win64, macos-intel,
echo       macos-aarch64, linux-x64, linux-arm)
echo     - Remove or adapt the midi_to_tab and step_editor
echo       sections if your project doesn't have those tools
echo     - Adjust the support file copy section at the bottom
echo       to match your project's assets
echo.
echo  2. Review installer/installer.iss:
echo     - Adjust the [Files] section to match your project's
echo       executables and assets
echo     - Adjust the [Icons] section
echo.
echo  3. Review .github/workflows/ci.yml:
echo     - The artifact upload name is set to your project name
echo     - Adjust the build steps if your project has a
echo       different structure
echo.
echo  4. Test the build:
echo     cd "%TARGET_DIR%"
echo     build_all.bat --check
echo     build_all.bat
echo.
echo  5. Commit and push:
echo     git add build_all.bat .github/ tools/zip_app.py AGENTS.md NAME Assets/version.txt installer/installer.iss
echo     git commit -m "Add multi-platform build workflow"
echo     git push
echo.
pause