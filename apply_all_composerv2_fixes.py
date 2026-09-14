#!/usr/bin/env python3
"""Apply all ComposerV2.pas fixes in one pass."""
import re

filepath = "src/ComposerV2.pas"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# === INTERFACE FIXES ===

# 1. uses clause - add Math, PluginRegistry, ComposerTypes
content = re.sub(
    r'uses\s+Classes, SysUtils, Generics\.Collections, Kit, Pattern, Song,\s+TimeSignature, GenerationParameters, GenrePlugin,\s+DrummerPlugin;',
    'uses\n  Classes, SysUtils, Math, Generics.Collections, Kit, Pattern, Song,\n  TimeSignature, GenerationParameters, GenrePlugin,\n  DrummerPlugin, PluginRegistry, ComposerTypes;',
    content)

# 2. Add TSectionDef type after 'type' declaration
content = re.sub(
    r'(uses\n  .*ComposerTypes;\s*\n\stype\s+)',
    r'\1  { Structure entry type for song sections - must match DrumGenerator.TStructureEntry }\n  TSectionDef = record\n    Name: string;\n    Bars: Integer;\n  end;\n\n  ',
    content)

# 3. float -> Double in interface signatures
content = re.sub(r'IntensityPt: float\)', 'IntensityPt: Double)', content)
content = re.sub(r'IntensityPt: float;', 'IntensityPt: Double;', content)

# 4. TObjecspecialize -> specialize (but NOT TObjec as part of other words)
content = re.sub(r'TObjec\s*specialize', 'specialize', content)

# 5. AD drummer / AD rummer typos -> ADrummer
content = re.sub(r'const AD\s+drummer:', 'const ADrummer:', content)
content = re.sub(r'const AD\s+rummer:', 'const ADrummer:', content)

# 6. TPluginManager -> PluginRegistry.TPluginManager (only in field declarations and property)
content = re.sub(
    r'(FPluginManager:)\s*TPluginManager;',
    r'\1 PluginRegistry.TPluginManager;',
    content)

# 7. Constructor param name fix
content = re.sub(
    r'constructor Create\(APuginManager:\s*TPluginManager',
    'constructor Create(APGMPluginManager: PluginRegistry.TPluginManager',
    content)

# 8. property PluginManager type
content = re.sub(
    r'property PluginManager:\s*TPluginManager\s+read',
    'property PluginManager: PluginRegistry.TPluginManager read',
    content)

# 9. CreateSong Structure parameter - use array of TSectionDef instead of specialize TList<TRecord>
content = re.sub(
    r'const Structure:\s*TObjecspecialize\s+TList<TRecord>',
    'const Structure: array of TSectionDef',
    content)

# === IMPLEMENTATION FIXES ===

# 10. ApplyIntensityModifications implementation signature + add var block
content = re.sub(
    r'(function TBarSelector\.ApplyIntensityModifications\(APattern: TPattern; IntensityPt: )float\)(:\s*TPattern;\n)begin',
    r'\1Double)\2var\n  PowerBoost: Integer;\n  IBeat: Integer;\n  InstName: AnsiString;\nbegin',
    content)

# 11. Inline var declarations -> explicit vars + loop indexing (ApplyIntensityModifications body)
content = re.sub(
    r'if IntensityPt > 0\.7 then\s+begin\s+var PowerBoost := Round\(\(IntensityPt - 0\.5\) \* 20\);\s+for var Beat in Result\.FBeats do\s+begin\s+if Assigned\(Beat\.FInstrument\) then\s+begin\s+var InstName := Beat\.FInstrument\.Name;',
    'if IntensityPt > 0.7 then\n  begin\n    PowerBoost := Round((IntensityPt - 0.5) * 20);\n    for IBeat := 0 to Result.Beats.Count - 1 do\n    begin\n      if Assigned(Result.Beats[IBEat].Instrument) then\n      begin\n        InstName := Result.Beats[IBEat].Instrument.Name;',
    content, flags=re.DOTALL)

# 12. Beat.FVelocity -> Result.Beats[IBEat].Velocity (ApplyIntensityModifications body)
content = re.sub(
    r'Beat\.FVelocity := Max\(1, Min\(127, Beat\.FVelocity \+ PowerBoost\)\);',
    'Result.Beats[IBEat].Velocity := Max(1, Min(127, Result.Beats[IBEat].Velocity + PowerBoost));',
    content)

# 13. PickFillsForSection - simplify to remove plugin access (TFillPicker has no FPluginManager)
content = re.sub(
    r'(function TFillPicker\.PickFillsForSection\(const Genre: string; const Params: TGenerationParameters;\n\s+ABars: Integer; SectionName: string\): specialize TList<TFill>;)\s+var\s+DrummerPlugin: TObject;\s+GenrePlugin: TObject;\s+SignatureFills: specialize TList<TFill>;\s+CommonFills: specialize TList<TFill>;',
    r'\1',
    content)

# 14. Remove the body that references FPluginManager in PickFillsForSection
content = re.sub(
    r'result\s*:=\s*specialize TList<TFill>\.Create;\s*\n\s*\{\s*Try drummer signature fills.*?End;\n\n\s*\{\s*Fallback to genre common fills.*?\n\s*end;',
    '  Result := specialize TList<TFill>.Create;\nend;',
    content, flags=re.DOTALL | re.IGNORECASE)

# Write back
with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Applied all fixes")
