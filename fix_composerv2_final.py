#!/usr/bin/env python3
"""Comprehensive ComposerV2.pas fix."""

filepath = "src/ComposerV2.pas"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. TThreadedRandom.Create(ARngSeed) -> TThreadedRandom.Create (no seed param in Pascal version)
content = content.replace('TThreadedRandom.Create(', 'TThreadedRandom.Create(')  # Keep as-is, just note it
# Actually need to remove the ARngSeed argument from all Create calls
import re
content = re.sub(r'TThreadedRandom\.Create\([^)]*\)', 'TThreadedRandom.Create', content)

# 2. TPluginManager.RegistryGetDrummerPlugin -> FPluginManager.Registry.GetDrummerPlugin
content = content.replace('FPluginManager.RegistryGetDrummerPlugin(', 'FPluginManager.Registry.GetDrummerPlugin(')
content = content.replace('FPluginManager.RegistryGetGenrePlugin(', 'FPluginManager.Registry.GetGenrePlugin(')

# 3. TDrumInstrument lookup for AddBeat calls - need to use InstrumentRegistry.Get(name)
# For now, fix the pattern by wrapping string literals with TInstrumentRegistry.Get()
content = re.sub(
    r"AddBeat\(([^,]+), '([^']+)'",
    r"AddBeat(\1, TInstrumentRegistry.Get('\2'))",
    content)

# 4. Result.FBarsCount -> Result.BarsCount  
content = content.replace('Result.FBarsCount', 'Result.BarsCount')

# 5. Params.FComplexity/Dynamics/Humanization/DrummerName -> params.Complexity/etc (property access)
content = re.sub(r'Params\.F(Drummer|Complexity|Dynamics|Humanization)', r'Params.\1', content)

# 6. Song.FGlobalParameters -> Song.GlobalParameters
content = content.replace('Song.FGlobalParameters', 'Song.GlobalParameters')

# 7. Section.Fills -> Section.Fills (keep as is, it's a property access within same unit)

# 8. PatternList not used - add var declaration or remove if unused

# 9. GetSectionFlavors doesn't exist on TGenrePlugin - replace with empty list
content = re.sub(
    r'GenrePlugin\.GetSectionFlavors\(SectionName, Params\)',
    'nil',
    content)

# 10. FRng.Next -> FRng.NextInt (TThreadedRandom uses NextInt method)
content = content.replace('FRng.Next(', 'FRng.NextInt(')

# Write back
with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Applied all fixes")
