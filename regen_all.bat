@echo off

REM Full path to midi-drums executable in venv
set "MIDDRUMS=ChameleonDrummer.exe"

if not exist "reaper_test" mkdir reaper_test

echo ========================================
echo Regenerating all complete songs
echo Using midi-drums CLI defaults (no overrides)
echo ========================================
echo.

set DRUMMERS=bonham porcaro weckl chambers carey dee roeder hoglan rich copeland smith haake halpern peart moon watts

REM Metal - 7 styles x 14 drummers = 98 combinations
echo Metal
for %%G in (doom death heavy power progressive thrash breakdown) do (
    for %%D in (%DRUMMERS%) do (
        %MIDDRUMS% --song --genre metal --style %%G --drummer %%D --output "reaper_test\metal_%%G_%%D_gm.mid"
        %MIDDRUMS% --song --genre metal --style %%G --drummer %%D --output "reaper_test\metal_%%G_%%D_ad2.mid" --mapping ad2
        %MIDDRUMS% reaper export --genre metal --style %%G --drummer %%D --output "reaper_test\metal_%%G_%%D.rpp" --preset-only

    )
)

REM Rock - 7 styles x 14 drummers = 98 combinations
echo Rock
for %%G in (classic blues alternative progressive punk hard pop) do (
    for %%D in (%DRUMMERS%) do (
        %MIDDRUMS% --song --genre rock --style %%G --drummer %%D --output "reaper_test\rock_%%G_%%D_gm.mid"
        %MIDDRUMS% --song --genre rock --style %%G --drummer %%D --output "reaper_test\rock_%%G_%%D_ad2.mid" --mapping ad2
        %MIDDRUMS% reaper export --genre rock --style %%G --drummer %%D --output "reaper_test\rock_%%G_%%D.rpp" --preset-only

    )
)

REM Jazz - 7 styles x 14 drummers = 98 combinations
echo Jazz
for %%G in (swing bebop fusion latin ballad hard_bop contemporary) do (
    for %%D in (%DRUMMERS%) do (
        %MIDDRUMS% --song --genre jazz --style %%G --drummer %%D --output "reaper_test\jazz_%%G_%%D_gm.mid"
        %MIDDRUMS% --song --genre jazz --style %%G --drummer %%D --output "reaper_test\jazz_%%G_%%D_ad2.mid" --mapping ad2
        %MIDDRUMS% reaper export --genre jazz --style %%G --drummer %%D --output "reaper_test\jazz_%%G_%%D.rpp" --preset-only

    )
)

REM Funk - 7 styles x 14 drummers = 98 combinations
echo Funk
for %%G in (classic pfunk shuffle new_orleans fusion minimal heavy) do (
    for %%D in (%DRUMMERS%) do (
        %MIDDRUMS% --song --genre funk --style %%G --drummer %%D --output "reaper_test\funk_%%G_%%D_gm.mid"
        %MIDDRUMS% --song --genre funk --style %%G --drummer %%D --output "reaper_test\funk_%%G_%%D_ad2.mid" --mapping ad2
        %MIDDRUMS% reaper export --genre funk --style %%G --drummer %%D --output "reaper_test\funk_%%G_%%D.rpp" --preset-only

    )
)

REM Electronic - 4 styles x 14 drummers = 56 combinations
echo Electronic
for %%G in (house techno drum_and_bass dubstep) do (
    for %%D in (%DRUMMERS%) do (
        %MIDDRUMS% --song --genre electronic --style %%G --drummer %%D --output "reaper_test\elec_%%G_%%D_gm.mid"
        %MIDDRUMS% --song --genre electronic --style %%G --drummer %%D --output "reaper_test\elec_%%G_%%D_ad2.mid" --mapping ad2
        %MIDDRUMS% reaper export --genre electronic --style %%G --drummer %%D --output "reaper_test\elec_%%G_%%D.rpp" --preset-only
    )
)

echo.
echo ========================================
echo COMPLETE - All songs in reaper_test/
echo (14 drummers x 32 styles = 448 combos x 3 files = 1,344 total)
echo ========================================
