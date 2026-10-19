@echo off

REM Full path to midi-drums executable in venv
set "MIDDRUMS=ChameleonDrummer.exe"
set "FAILED=0"
set "TOTAL=0"

if not exist "reaper_test" mkdir reaper_test

echo ========================================
echo Regenerating all complete songs
echo Using midi-drums CLI defaults (no overrides)
echo ========================================
echo.

set DRUMMERS=bonham porcaro weckl chambers carey dee roeder hoglan rich copeland smith haake halpern peart moon watts

REM Metal - 7 styles x 16 drummers = 112 combinations
echo Metal
for %%G in (doom death heavy power progressive thrash breakdown) do (
    for %%D in (%DRUMMERS%) do (
        call :run --song --genre metal --style %%G --drummer %%D --output "reaper_test\metal_%%G_%%D_gm.mid"
        call :run --song --genre metal --style %%G --drummer %%D --output "reaper_test\metal_%%G_%%D_ad2.mid" --mapping ad2
        call :run reaper export --genre metal --style %%G --drummer %%D --output "reaper_test\metal_%%G_%%D.rpp" --preset-only

    )
)

REM Rock - 7 styles x 16 drummers = 112 combinations
echo Rock
for %%G in (classic blues alternative progressive punk hard pop) do (
    for %%D in (%DRUMMERS%) do (
        call :run --song --genre rock --style %%G --drummer %%D --output "reaper_test\rock_%%G_%%D_gm.mid"
        call :run --song --genre rock --style %%G --drummer %%D --output "reaper_test\rock_%%G_%%D_ad2.mid" --mapping ad2
        call :run reaper export --genre rock --style %%G --drummer %%D --output "reaper_test\rock_%%G_%%D.rpp" --preset-only

    )
)

REM Jazz - 7 styles x 16 drummers = 112 combinations
echo Jazz
for %%G in (swing bebop fusion latin ballad hard_bop contemporary) do (
    for %%D in (%DRUMMERS%) do (
        call :run --song --genre jazz --style %%G --drummer %%D --output "reaper_test\jazz_%%G_%%D_gm.mid"
        call :run --song --genre jazz --style %%G --drummer %%D --output "reaper_test\jazz_%%G_%%D_ad2.mid" --mapping ad2
        call :run reaper export --genre jazz --style %%G --drummer %%D --output "reaper_test\jazz_%%G_%%D.rpp" --preset-only

    )
)

REM Funk - 7 styles x 16 drummers = 112 combinations
echo Funk
for %%G in (classic pfunk shuffle new_orleans fusion minimal heavy) do (
    for %%D in (%DRUMMERS%) do (
        call :run --song --genre funk --style %%G --drummer %%D --output "reaper_test\funk_%%G_%%D_gm.mid"
        call :run --song --genre funk --style %%G --drummer %%D --output "reaper_test\funk_%%G_%%D_ad2.mid" --mapping ad2
        call :run reaper export --genre funk --style %%G --drummer %%D --output "reaper_test\funk_%%G_%%D.rpp" --preset-only

    )
)

REM Electronic - 4 styles x 16 drummers = 64 combinations
echo Electronic
for %%G in (house techno drum_and_bass dubstep) do (
    for %%D in (%DRUMMERS%) do (
        call :run --song --genre electronic --style %%G --drummer %%D --output "reaper_test\elec_%%G_%%D_gm.mid"
        call :run --song --genre electronic --style %%G --drummer %%D --output "reaper_test\elec_%%G_%%D_ad2.mid" --mapping ad2
        call :run reaper export --genre electronic --style %%G --drummer %%D --output "reaper_test\elec_%%G_%%D.rpp" --preset-only
    )
)

echo.
echo ========================================
if not "%FAILED%"=="0" (
    echo FAILED - %FAILED% of %TOTAL% commands failed.
    exit /b 1
)
echo COMPLETE - 16 drummers x 32 styles = 512 combinations.
echo %TOTAL% commands completed successfully.
echo ========================================
exit /b 0

:run
set /a TOTAL+=1
%MIDDRUMS% %*
if errorlevel 1 (
    set /a FAILED+=1
    echo [FAIL] %*
)
exit /b 0
