# Step Editor Block Meter Fix Plan

## Problem
When editing a block in the ChameleonDrummer step editor, the header line
built by `BuildBlockText` (MainFrm.pas:1616) emits only:
    `[style kind intensity=low-high]`
It does NOT emit the meter. The main app (TabFiles.pas) accepts a bare meter
token like `7/8` or `7/8T` in the header (parsed at TabFiles.pas:174-195).
So block meter is silently lost on save.

Additionally `ParseHeader` (MainFrm.pas:532) never parses the meter token back
into `ABlock.Meter`, so even if a header had a meter, the block editor would
not show or preserve it.

## Root Cause
- `BuildBlockText` omits meter token.
- `ParseHeader` does not extract a bare `N/D` (optionally `T`) meter token.
- Block edit UI has no meter control (only Style, Kind, Intensity).

## Fix (minimal, surgical)
1. `ParseHeader`: after extracting style/kind, scan tokens for a bare meter
   (contains '/', parses as N/D optionally trailing T) and store in ABlock.Meter.
2. `BuildBlockText`: append the meter token (ABlock.Meter) to the header when
   non-empty, matching main-app syntax `[style kind intensity=.. .. meter]`.
3. Add a block meter combo `cbBlockMeter` to the block-edit UI (.lfm + .pas),
   populated like cbMeter, shown/hidden with the other block controls, and read
   in SurgicalSaveBlock; set in UpdateHeaderFields.
4. Keep `UpdateHeaderPreview` consistent (it already shows meter= for the
   pattern-save path; leave as-is, that path is separate).

## Verification
- Build step_editor via build_all.bat (or lazbuild) and confirm no errors.
- Confirm a block with meter round-trips (load -> save preserves meter token).

## Notes
- This is the ChameleonDrummer project. Do NOT touch other repos.
- Keep changes minimal and consistent with existing code style.