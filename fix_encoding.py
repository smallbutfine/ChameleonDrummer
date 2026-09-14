#!/usr/bin/env python3
"""Fix corrupted UTF-8 characters in Pascal files."""
import os

files = [
    "src/ComposerV2.pas",
]

for fpath in files:
    if not os.path.exists(fpath):
        print(f"File not found: {fpath}")
        continue
    
    with open(fpath, 'rb') as f:
        content = f.read()
    
    # Fix common corruption patterns (the box-drawing chars that got mangled)
    corrupt = [
        b'\xc3\xa2\xe2\x80\x9a\xc2\xac',  # â€" (UTF-8 mangled)
        b'\xe2\x80\x94',  # em-dash —
        b'\xe2\x94\x80',  # box-drawing ─
    ]
    
    for c in corrupt:
        content = content.replace(c, b'-')
    
    with open(fpath, 'wb') as f:
        f.write(content)
    
    print(f"Fixed: {fpath}")
