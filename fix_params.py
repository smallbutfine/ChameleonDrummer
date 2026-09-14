#!/usr/bin/env python3
"""Fix remaining ComposerV2.pas API mismatches."""

filepath = "src/ComposerV2.pas"

with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Fix Params.DrummerName -> Params.Drummer
new_lines = []
for line in lines:
    new_lines.append(line.replace('Params.FDrummerName', 'Params.Drummer').replace('Params.DrummerName', 'Params.Drummer'))

# Remove corrupted comment level warnings
lines = new_lines

with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("Fixed Params.FDrummerName -> Params.Drummer")
