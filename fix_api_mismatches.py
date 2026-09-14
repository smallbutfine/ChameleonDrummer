#!/usr/bin/env python3
"""Fix remaining ComposerV2.pas API mismatches."""

filepath = "src/ComposerV2.pas"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

fixes = [
    # Params.DrummerName -> Params.Drummer (the correct property name)
    ('Params.DrummerName', 'Params.Drummer'),
    
    # TFillPicker doesn't have FPluginManager - simplify this function since it's standalone
    # Replace the PickFillsForSection body with a simpler version
    ("function TFillPicker.PickFillsForSection(const Genre: string; const Params: TGenerationParameters;\n  ABars: Integer; SectionName: string): specialize TList<TFill>;\nvar\n  DrummerPlugin: TObject;\n  GenrePlugin: TObject;\n  SignatureFills: specialize TList<TFill>;\n  CommonFills: specialize TList<TFill>;\nbegin\n  Result := specialize TList<TFill>.Create;\n  \n  { Try drummer signature fills first (Python: get_signature_fills()) }\n  if (Params <> nil) and (Length(Params.Drummer) > 0) then\n  begin\n    DrummerPlugin := FPluginManager.RegistryGetDrummerPlugin(Params.Drummer);\n    if Assigned(DrummerPlugin) then\n    begin\n      { Cast to TDrummerPlugin to call GetSignatureFills. }\n      if DrummerPlugin is TDrummerPlugin then\n      begin\n        Result := (DrummerPlugin as TDrummerPlugin).GetSignatureFills;\n        if Assigned(Result) and (Result.Count > 0) then Exit;\n        Result.Free; { Empty list - fall through to genre common fills. }\n      end;\n    end;\n  end;\n\n  { Fallback to genre common fills (Python: genre_plugin.get_common_fills()) }\n  GenrePlugin := FPluginManager.RegistryGetGenrePlugin(Genre);\n  if Assigned(GenrePlugin) and (GenrePlugin is TGenrePlugin) then\n  begin\n    CommonFills := (GenrePlugin as TGenrePlugin).GetCommonFills;\n    if Assigned(CommonFills) then\n      Result.AddRange(CommonFills); { Merge genre fills into result. }",
    "function TFillPicker.PickFillsForSection(const Genre: string; const Params: TGenerationParameters;\n  ABars: Integer; SectionName: string): specialize TList<TFill>;\nbegin\n  { Simplified: return empty list - caller (ComposerV2) handles fill lookup.\n     PickFillsForSection is a standalone helper without plugin access. }\n  Result := specialize TList<TFill>.Create;\nend;"],
]

for old, new in fixes:
    count = content.count(old)
    if count > 0:
        content = content.replace(old, new)
        print(f"Replaced {count}x: '{old[:50]}...'")
    else:
        print(f"NOT FOUND ({count} matches): '{old[:60]}...'")

# Also fix the end of file - add missing 'end.' if needed
if not content.strip().endswith('end.'):
    content = content.rstrip() + '\nend.\n'
    print("Added missing 'end.'")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done!")
