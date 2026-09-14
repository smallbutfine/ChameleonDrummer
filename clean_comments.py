#!/usr/bin/env python3
"""Clean corrupted comments and fix remaining issues in ComposerV2.pas."""

filepath = "src/ComposerV2.pas"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Clean corrupted comment patterns
content = content.replace('â€"', '-')
content = content.replace('{ */', '{')
content = content.replace('{*', '{')
content = content.replace('*}', '}')
content = content.replace('*/\n', '\n')

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed corrupted comments")
