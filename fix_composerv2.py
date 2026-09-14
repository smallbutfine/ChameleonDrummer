#!/usr/bin/env python3
"""Apply all ComposerV2.pas fixes."""

filepath = "src/ComposerV2.pas"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Apply all replacements (order matters for overlapping patterns)
replacements = [
    # uses clause - add Math, PluginRegistry, ComposerTypes
    ('  Classes, SysUtils, Generics.Collections, Kit, Pattern, Song,\n  TimeSignature, GenerationParameters, GenrePlugin,\n  DrummerPlugin;\n',
     '  Classes, SysUtils, Math, Generics.Collections, Kit, Pattern, Song,\n  TimeSignature, GenerationParameters, GenrePlugin,\n  DrummerPlugin, PluginRegistry, ComposerTypes;\n'),
    
    # float -> Double in TBarSelector interface
    ('function ApplyIntensityModifications(APattern: TPattern; IntensityPt: float): TPattern;',
     'function ApplyIntensityModifications(APattern: TPattern; IntensityPt: Double): TPattern;'),
    
    ('function SelectKickPattern(ABarIndex: Integer; IntensityPt: float): String;',
     'function SelectKickPattern(ABarIndex: Integer; IntensityPt: Double): String;'),
    
    # TObjecspecialize -> specialize in interface
    ('IntensityPt: float; const ADrummer: string; PreviousBars: TObjecspecialize TList<TPattern>): TPattern;',
     'IntensityPt: Double; const ADrummer: string; PreviousBars: specialize TList<TPattern>): TPattern;'),
    
    ('ABars: Integer; SectionName: string): TObjecspecialize TList<TFill>;',
     'ABars: Integer; SectionName: string): specialize TList<TFill>;'),
    
    # AD drummer / AD rummer typos
    ('function GetDrummerGrooveBias(const AD drummer: string): Single;',
     'function GetDrummerGrooveBias(const ADrummer: string): Single;'),
    
    # TGrooveEngine interface fixes
    ('function GetBarOffsetMs(ABarIndex: Integer; ATempo: Integer; IntensityPt: float;\n  const ASectionName: string; const AD rummer: string): Single;',
     'function GetBarOffsetMs(ABarIndex: Integer; ATempo: Integer; IntensityPt: Double;\n  const ASectionName: string; const ADrummer: string): Single;'),
    
    # TPluginManager -> PluginRegistry.TPluginManager  
    ('FPluginManager: TPluginManager;',
     'FPluginManager: PluginRegistry.TPluginManager;'),
    
    ('TComposerV2 = class(TObject)\nprivate\n  FPluginManager: TPluginManager;\n',
     'TComposerV2 = class(TObject)\nprivate\n  FPluginManager: PluginRegistry.TPluginManager;\n'),
    
    # CreateSong constructor parameter name fix
    ('constructor Create(APuginManager: TPluginManager; ARngSeed: Integer = 0);',
     'constructor Create(APGMPluginManager: PluginRegistry.TPluginManager; ARngSeed: Integer = 0);'),
    
    # property PluginManager type
    ('property PluginManager: TPluginManager read FPluginManager write FPluginManager;',
     'property PluginManager: PluginRegistry.TPluginManager read FPluginManager write FPluginManager;'),
]

for old, new in replacements:
    count = content.count(old)
    if count > 0:
        content = content.replace(old, new, 1)
        print(f"Replaced ({count} occurrence(s))")
    else:
        print(f"NOT FOUND: '{old[:60]}...'")

# Now handle the remaining TObjecspecialize patterns in helper methods
content = content.replace(
    'function GetSectionCurveMap(const Structure: TObjecspecialize TList<TRecord>): specialize TDictionary<string, Integer>;',
    'function GetSectionCurveMap(const Structure: specialize TList<TSong>): specialize TDictionary<string, Integer>;')

content = content.replace(
    'function SelectFlavor(const Available: TObjecspecialize TList<TPattern>; ABarIndex: Integer): TPattern;',
    'function SelectFlavor(const Available: specialize TList<TPattern>; ABarIndex: Integer): TPattern;')

content = content.replace(
    'procedure CombineBarPatterns(const GeneratedBars: TObjecspecialize TList<TPattern>; out Combined: TPattern);',
    'procedure CombineBarPatterns(const GeneratedBars: specialize TList<TPattern>; out Combined: TPattern);')

content = content.replace(
    'function GetIntensityPt(CurveMap: specialize TDictionary<string, Integer>; const SectionName: string;\n    ABarIndex, ABars: Integer): float;',
    'function GetIntensityPt(CurveMap: specialize TDictionary<string, Integer>; const SectionName: string;\n    ABarIndex, ABars: Integer): Double;')

content = content.replace(
    'const Structure: TObjecspecialize TList<TRecord>; ADrummer: string = \'\';',
    'const Structure: specialize TList<TSong>; ADrummer: string = \'\';')

content = content.replace(
    'AComplexity: float = 0.5; ADynamics: float = 0.6;',
    'AComplexity: Double = 0.5; ADynamics: Double = 0.6;')

content = content.replace(
    'AHumanization: float = 0.5): TSong;',
    'AHumanization: Double = 0.5): TSong;')

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done!")
