#!/usr/bin/env python3
"""Fix ComposerV2.pas implementation section."""

filepath = "src/ComposerV2.pas"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

fixes = [
    # GenerateForBar signature
    ('IntensityPt: float; const ADrummer: string; PreviousBars: TObjecspecialize TList<TPattern>): TPattern;',
     'IntensityPt: Double; const ADrummer: string; PreviousBars: specialize TList<TPattern>): TPattern;'),
    
    # PickFillsForSection return type
    ('ABars: Integer; SectionName: string): TObjecspecialize TList<TFill>;',
     'ABars: Integer; SectionName: string): specialize TList<TFill>;'),
    
    # Implementation section fixes - multiple occurrences
    ('Result := TObjecspecialize TList<TFill>.Create(true);',
     'Result := specialize TList<TFill>.Create;'),
    
    ('SignatureFills: TObjecspecialize TList<TFill>;',
     'SignatureFills: specialize TList<TFill>;'),
    
    ('CommonFills: TObjecspecialize TList<TFill>;',
     'CommonFills: specialize TList<TFill>;'),
]

for old, new in fixes:
    count = content.count(old)
    if count > 0:
        content = content.replace(old, new)
        print(f"Replaced {count}x: '{old[:50]}...'")
    else:
        print(f"NOT FOUND: '{old[:50]}...'")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done!")
