#!/usr/bin/env python3
"""Fix ComposerV2.pas implementation - inline vars, private fields, types."""

filepath = "src/ComposerV2.pas"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

fixes = [
    # ApplyIntensityModifications implementation signature
    ('function TBarSelector.ApplyIntensityModifications(APattern: TPattern; IntensityPt: float): TPattern;',
     'function TBarSelector.ApplyIntensityModifications(APattern: TPattern; IntensityPt: Double): TPattern;\nvar\n  PowerBoost: Integer;\n  IBeat: Integer;\n  InstName: AnsiString;'),
    
    # Inline var declarations in ApplyIntensityModifications
    ('  if IntensityPt > 0.7 then\n  begin\n    var PowerBoost := Round((IntensityPt - 0.5) * 20);\n    for var Beat in Result.FBeats do\n    begin\n      if Assigned(Beat.FInstrument) then\n      begin\n        var InstName := Beat.FInstrument.Name;\n        if SameText(InstName, \'kick\') or SameText(InstName, \'snare_open_hit_open_lateral_hit\') then\n          Beat.FVelocity := Max(1, Min(127, Beat.FVelocity + PowerBoost));',
     '  if IntensityPt > 0.7 then\n  begin\n    PowerBoost := Round((IntensityPt - 0.5) * 20);\n    for IBeat := 0 to Result.Beats.Count - 1 do\n    begin\n      if Assigned(Result.Beats[IBEat].Instrument) then\n      begin\n        InstName := Result.Beats[IBEat].Instrument.Name;\n        if SameText(InstName, \'kick\') or SameText(InstName, \'snare_open_hit_open_lateral_hit\') then\n          Result.Beats[IBEat].Velocity := Max(1, Min(127, Result.Beats[IBEat].Velocity + PowerBoost));'),
]

for old, new in fixes:
    count = content.count(old)
    if count > 0:
        content = content.replace(old, new)
        print(f"Replaced {count}x")
    else:
        print(f"NOT FOUND ({count} matches): '{old[:60]}...'")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done!")
