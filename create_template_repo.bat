@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM create_template_repo.bat
REM Copies the template folder to a new directory, renames
REM TEMPLATE_README.md to README.md, initializes git, and
REM pushes to a new GitHub repo.
REM ============================================================

REM --- Configuration ---
set "TEMPLATE_DIR=%~dp0template"
set "GITHUB_USER=smallbutfine"
set "REPO_NAME=fpc-lazarus-multiplatform-template"
set "NEW_DIR=%~dp0..\%REPO_NAME%"

echo.
echo ==================================================
echo  Create Template Repository
echo ==================================================
echo.
echo  Template source:  %TEMPLATE_DIR%
echo  New directory:    %NEW_DIR%
echo  GitHub user:      %GITHUB_USER%
echo  Repo name:        %REPO_NAME%
echo.

REM --- Verify template exists ---
if not exist "%TEMPLATE_DIR%" (
    echo ERROR: Template directory not found: %TEMPLATE_DIR%
    echo   Run this script from the ChameleonDrummer repo root.
    exit /b 1
)

REM --- Verify new directory does not already exist ---
if exist "%NEW_DIR%" (
    echo ERROR: Directory already exists: %NEW_DIR%
    echo   Delete it first or choose a different repo name.
    exit /b 1
)

REM --- Copy template ---
echo [1/5] Copying template...
xcopy /y /e /i "%TEMPLATE_DIR%" "%NEW_DIR%" >nul
if errorlevel 1 (
    echo   ERROR: Copy failed
    exit /b 1
)
echo   OK

REM --- Rename TEMPLATE_README.md to README.md ---
echo [2/5] Renaming TEMPLATE_README.md -^> README.md...
if exist "%NEW_DIR%\TEMPLATE_README.md" (
    move /y "%NEW_DIR%\TEMPLATE_README.md" "%NEW_DIR%\README.md" >nul
    echo   OK
) else (
    echo   WARNING: TEMPLATE_README.md not found, skipping
)

REM --- Init git ---
echo [3/5] Initializing git...
cd /d "%NEW_DIR%"
git init
if errorlevel 1 (
    echo   ERROR: git init failed
    exit /b 1
)
git add .
git commit -m "Initial template"
if errorlevel 1 (
    echo   ERROR: git commit failed
    exit /b 1
)
git branch -M main
echo   OK

REM --- Add remote ---
echo [4/5] Adding remote...
git remote add origin "https://github.com/%GITHUB_USER%/%REPO_NAME%.git"
if errorlevel 1 (
    echo   ERROR: git remote add failed
    exit /b 1
)
echo   OK

REM --- Push ---
echo [5/5] Pushing to GitHub...
git push -u origin main
if errorlevel 1 (
    echo.
    echo   ERROR: Push failed.
    echo   Create the repo on GitHub first: https://github.com/new
    echo   Then re-run this script.
    exit /b 1
)
echo   OK

echo.
echo ==================================================
echo  DONE
echo ==================================================
echo.
echo  Repository created at: %NEW_DIR%
echo  GitHub: https://github.com/%GITHUB_USER%/%REPO_NAME%
echo.
echo  Next step: On GitHub, go to
echo  Settings -^> General -^> Template repository
echo  and check "Template repository" to enable the
echo  "Use this template" button.
echo.
pause