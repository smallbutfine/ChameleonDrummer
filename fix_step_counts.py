#!/usr/bin/env python3
"""Fix invalid step counts in .tab files while preserving formatting."""

import os
import re

VALID_STEPS = {
    '7/8': [7, 14, 21, 28, 42, 56],
    '5/4': [5, 10, 15, 20, 30, 40],
    '3/4': [3, 6, 9, 12, 18, 24],
    '2/4': [2, 4, 6, 8, 12, 16],
    '6/8': [6, 12, 18, 24, 36, 48],
}


def get_time_sig(title):
    """Extract explicit time signature from block header. Returns None if unspecified."""
    m = re.match(r'^\[([^\]]+)\]', title)
    if not m:
        return None
    
    content = m.group(1)
    
    # Explicit time sig like '7/8', '5/4' in the header text itself
    for sig in ['7/8', '5/4', '3/4', '2/4', '6/8']:
        if sig in content:
            return sig
    
    # Pattern like 'odd_7_8' in name -> 7/8
    m2 = re.search(r'(\d+)_(\d+)', content)
    if m2:
        numer, denom = int(m2.group(1)), int(m2.group(2))
        return f'{numer}/{denom}'
    
    # Pattern like '7/8' or '5/4' anywhere in block name
    m3 = re.search(r'(\d+)/(\d+)', content)
    if m3:
        return f'{m3.group(1)}/{m3.group(2)}'
    
    return None


def get_valid_steps(time_sig):
    """Return valid step counts for a time signature. Returns None if unknown."""
    return VALID_STEPS.get(time_sig)


def count_steps(bar_str):
    """Count actual drum steps in a bar string (non-space characters only)."""
    return len(bar_str.replace(' ', ''))


def fix_bar_to_target(bar_str, target_steps):
    """Pad or truncate a single bar to have exactly target_steps drum characters.
    
    Preserves the original spacing structure of the bar — only adjusts step count.
    - If too few steps: pad with '.' at the end
    - If too many steps: remove non-space characters from the right
    """
    current = count_steps(bar_str)
    
    if current == target_steps:
        return bar_str  # No change needed
    
    if current < target_steps:
        # Pad with dots at the end (preserves all internal spacing exactly)
        return bar_str + '.' * (target_steps - current)
    else:
        # Truncate: remove non-space characters from right only, keeping spacing intact
        result = list(bar_str)
        steps_to_remove = current - target_steps
        
        for i in range(len(result) - 1, -1, -1):
            if steps_to_remove <= 0:
                break
            if result[i] != ' ':  # Only remove non-space characters
                result[i] = ''      # Mark as removed (replace with empty string)
                steps_to_remove -= 1
        
        return ''.join(result).rstrip()


def fix_groove_block(lines, block_start):
    """Fix all instrument lines in a groove block. Returns number of lines fixed."""
    title_line = lines[block_start].strip()
    time_sig = get_time_sig(title_line)
    valid_steps = get_valid_steps(time_sig)
    
    # Skip blocks with no explicit time signature (meter not specified)
    if valid_steps is None:
        return 0
    
    # Find end of block
    end = block_start + 1
    while end < len(lines):
        if re.match(r'^\[.+\]$', lines[end].strip()):
            break
        end += 1
    
    count = 0
    
    # Process each line in the block
    for i in range(block_start + 1, end):
        original_line = lines[i]
        line = original_line.rstrip('\n\r')
        
        if not line or line.startswith('#'):
            continue
        
        # Split into instrument token and pattern content (preserve everything after first space)
        parts = line.split(None, 1)
        if len(parts) < 2:
            continue
        
        instr_token = parts[0]
        pattern_content = parts[1]
        
        # Check for multiple bars separated by |
        # Each bar between | is an independent measure
        bar_parts = [b.strip() for b in pattern_content.split('|')]
        
        fixed_bars = []
        block_changed = False
        
        for bar in bar_parts:
            steps = count_steps(bar)
            
            if steps not in valid_steps:
                target = min(valid_steps, key=lambda x: abs(x - steps))
                fixed_bar = fix_bar_to_target(bar, target)
                fixed_bars.append(fixed_bar)
                block_changed = True
            else:
                fixed_bars.append(bar)
        
        if block_changed:
            # Find where instrument name ends and content begins
            match_start = original_line.index(pattern_content)
            prefix = original_line[:match_start]  # Everything before pattern content
            
            # Reconstruct with fixed bar lengths but preserve ALL original spacing
            new_content = ' | '.join(fixed_bars)
            
            lines[i] = prefix + new_content + '\n'
            count += 1
    
    return count


def fix_fill_block(lines, block_start):
    """Fix all instrument lines in a fill block. Returns number of lines fixed."""
    title_line = lines[block_start].strip()
    time_sig = get_time_sig(title_line)
    
    if not time_sig:
        content = re.match(r'^\[([^\]]+)\]', title_line).group(1) if re.match(r'^\[([^\]]+)\]', title_line) else ''
        m = re.search(r'(\d+)_(\d+)', content)
        if m:
            numer, denom = int(m.group(1)), int(m.group(2))
            time_sig = f'{numer}/{denom}'
    
    valid_steps = get_valid_steps(time_sig) if time_sig else None
    
    # Skip blocks with no explicit time signature (meter not specified)
    if valid_steps is None:
        return 0
    
    # Find end of block
    end = block_start + 1
    while end < len(lines):
        if re.match(r'^\[.+\]$', lines[end].strip()):
            break
        end += 1
    
    count = 0
    
    # For fills, each line is one measure - total characters = step count
    for i in range(block_start + 1, end):
        original_line = lines[i]
        line = original_line.rstrip('\n\r')
        
        if not line or line.startswith('#'):
            continue
        
        parts = line.split(None, 1)
        if len(parts) < 2:
            continue
        
        instr_token = parts[0]
        pattern_content = parts[1]
        
        # Count non-space characters as steps
        steps = count_steps(pattern_content)
        
        if steps not in valid_steps:
            target = min(valid_steps, key=lambda x: abs(x - steps))
            fixed_pattern = fix_bar_to_target(pattern_content, target)
            
            # Preserve all original spacing — only replace the pattern content part
            match_start = original_line.index(pattern_content)
            prefix = original_line[:match_start]
            
            lines[i] = prefix + fixed_pattern + '\n'
            count += 1
    
    return count


def process_file(filepath, is_groove=True):
    """Process a single .tab file and return (number of lines fixed, modified lines)."""
    with open(filepath, encoding='utf-8') as f:
        lines = f.readlines()
    
    block_starts = []
    for i, line in enumerate(lines):
        if re.match(r'^\[.+\]$', line.strip()):
            block_starts.append(i)
    
    total_fixed = 0
    
    for idx, block_start in enumerate(block_starts):
        if is_groove:
            fixed = fix_groove_block(lines, block_start)
        else:
            fixed = fix_fill_block(lines, block_start)
        
        total_fixed += fixed
    
    return total_fixed, lines


def main():
    """Main function to fix all .tab files."""
    base_dir = os.path.dirname(os.path.abspath(__file__))
    groove_dir = os.path.join(base_dir, 'config', 'grooves')
    fill_dir = os.path.join(base_dir, 'config', 'fills')
    
    print('Scanning and fixing .tab files...\n')
    
    # Process groove tabs
    print('Processing groove tabs:')
    groove_fixes = 0
    for fpath in sorted(os.listdir(groove_dir)):
        if not fpath.endswith('.tab'):
            continue
        
        full_path = os.path.join(groove_dir, fpath)
        count, modified_lines = process_file(full_path, is_groove=True)
        
        if count > 0:
            with open(full_path, 'w', encoding='utf-8') as f:
                f.writelines(modified_lines)
            print(f'  {fpath}: {count} lines fixed')
        
        groove_fixes += count
    
    print()
    
    # Process fill tabs
    print('Processing fill tabs:')
    fill_fixes = 0
    for fpath in sorted(os.listdir(fill_dir)):
        if not fpath.endswith('.tab'):
            continue
        
        full_path = os.path.join(fill_dir, fpath)
        count, modified_lines = process_file(full_path, is_groove=False)
        
        if count > 0:
            with open(full_path, 'w', encoding='utf-8') as f:
                f.writelines(modified_lines)
            print(f'  {fpath}: {count} lines fixed')
        
        fill_fixes += count
    
    print(f'\nTotal fixes: {groove_fixes} groove + {fill_fixes} fill = {groove_fixes + fill_fixes} total')


if __name__ == '__main__':
    main()