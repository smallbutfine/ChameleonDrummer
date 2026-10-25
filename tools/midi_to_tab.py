#!/usr/bin/env python3
"""Convert a MIDI file to the ChameleonDrummer .tab groove/fill format.

Usage:
    python tools/midi_to_tab.py input.mid [output.tab]
    python tools/midi_to_tab.py input.mid --fill --name bonham_fill --energy 0.6
    python tools/midi_to_tab.py input.mid --meter 7/8 --resolution 16
    python tools/midi_to_tab.py input.mid --mapping mappings/gm.json

Reads MIDI notes (channel 10 / percussion zone), quantizes to a grid, groups
into bars, and writes [style kind intensity=...] or [name energy=...] blocks.
No external dependencies — pure Python.
"""
import struct
import sys
import os
import json
import re

# ------------------------------------------------------------------
# MIDI note -> tab instrument mapping (GM percussion zone, channel 10)
# ------------------------------------------------------------------
GM_MAP = {
    35: "K",   36: "K",
    37: "SS",  38: "S",  39: "S",  40: "RS",
    41: "T4",  42: "H",  43: "T3", 44: "HP",
    45: "T2",  46: "HO", 47: "T2", 48: "T3",
    49: "C",   50: "T1", 51: "R",  52: "CH",
    53: "RB",  54: "SP", 55: "SP", 56: "C2",
    57: "C2",  58: "T1", 59: "R",
    60: "T1",  61: "RB", 62: "C",  63: "C",
    64: "C",   65: "T4", 66: "T4", 67: "CH",
    68: "SP",  69: "C",  70: "C",  71: "C",
    72: "C",   73: "C",  74: "C",  75: "SP",
    76: "SP",  77: "SP", 78: "SP", 79: "SP",
    80: "SP",  81: "SP",
}

# Velocity thresholds for step characters
VEL_GHOST = 32    # below: ghost note 'g'
VEL_SOFT = 64     # below: soft 'o'
VEL_ACCENT = 96   # above: accent 'X'


# ------------------------------------------------------------------
# MIDI parser (pure Python, no external dependencies)
# ------------------------------------------------------------------

def read_vlq(data, pos):
    """Read a variable-length quantity from MIDI data."""
    value = 0
    while True:
        b = data[pos]
        pos += 1
        value = (value << 7) | (b & 0x7F)
        if not (b & 0x80):
            break
    return value, pos


def parse_midi(path):
    """Parse a MIDI file.

    Returns (ppq, tempo_changes, sig_changes, notes) where:
      ppq          : pulses per quarter note
      tempo_changes: list of (tick, bpm)
      sig_changes  : list of (tick, num, den)
      notes        : list of (tick_on, midi_note, velocity, duration_ticks)
    """
    data = open(path, 'rb').read()
    if len(data) < 14 or data[:4] != b'MThd':
        raise ValueError('Not a MIDI file: ' + path)
    _, ntrks, ppq = struct.unpack('>HHH', data[8:14])
    pos = 14
    tempos = []
    sigs = []
    notes = []
    for _ in range(ntrks):
        length = struct.unpack('>I', data[pos + 4:pos + 8])[0]
        p, end = pos + 8, pos + 8 + length
        t, status = 0, 0
        active = {}  # midi_note -> (tick_on, velocity)
        while p < end:
            delta, p = read_vlq(data, p)
            t += delta
            b = data[p]
            if b == 0xFF:
                typ = data[p + 1]
                ln, q = read_vlq(data, p + 2)
                if typ == 0x51 and ln == 3:
                    micros = int.from_bytes(data[q:q + 3], 'big')
                    bpm = round(60000000 / micros)
                    tempos.append((t, bpm))
                elif typ == 0x58 and ln >= 2:
                    sigs.append((t, data[q], 2 ** data[q + 1]))
                p = q + ln
                continue
            if b & 0x80:
                status = b
                p += 1
            kind = status & 0xF0
            if kind == 0x90:
                note = data[p]
                vel = data[p + 1]
                p += 2
                if vel > 0:
                    active[note] = (t, vel)
            elif kind == 0x80:
                note = data[p]
                p += 2
                if note in active:
                    tick_on, vel = active.pop(note)
                    notes.append((tick_on, note, vel, t - tick_on))
            elif kind in (0xA0, 0xB0, 0xE0):
                p += 2
            elif kind in (0xC0, 0xD0):
                p += 1
            else:
                p += 1
        # Close any remaining notes at end of track
        for note, (tick_on, vel) in active.items():
            notes.append((tick_on, note, vel, t - tick_on))
        pos = end
    return ppq, tempos, sigs, notes


# ------------------------------------------------------------------
# Mapping loader
# ------------------------------------------------------------------

def load_mapping(path):
    """Load a mapping JSON file and return {midi_note: instrument_abbr}."""
    mapping = {}
    if not path or not os.path.exists(path):
        return mapping
    try:
        data = json.load(open(path, 'r', encoding='utf-8'))
        for inst, info in data.get('instruments', {}).items():
            note = info.get('midi_note')
            if note is not None:
                abbr = instrument_abbr(inst)
                if abbr:
                    mapping[int(note)] = abbr
    except Exception:
        pass
    return mapping


def instrument_abbr(name):
    """Convert a mapping instrument name to a tab abbreviation."""
    n = name.lower()
    if 'kick' in n or 'bass_drum' in n:
        return 'K'
    if 'snare' in n and 'rim' not in n and 'side' not in n:
        return 'S'
    if 'rimshot' in n or 'rim_shot' in n:
        return 'RS'
    if 'side_stick' in n:
        return 'SS'
    if 'hihat_closed' in n or 'hihat_pedal_closed' in n:
        return 'H'
    if 'hihat_open' in n:
        return 'HO'
    if 'hihat_pedal' in n and 'open' not in n:
        return 'HP'
    if 'ride' in n and 'bell' in n:
        return 'RB'
    if 'ride' in n:
        return 'R'
    if 'crash' in n:
        return 'C'
    if 'china' in n:
        return 'CH'
    if 'splash' in n:
        return 'SP'
    if 'tom_1' in n or 'high_tom' in n:
        return 'T1'
    if 'tom_2' in n:
        return 'T2'
    if 'tom_3' in n or 'hi_mid_tom' in n:
        return 'T3'
    if 'tom_4' in n or 'low_floor_tom' in n:
        return 'T4'
    return None


# ------------------------------------------------------------------
# Velocity -> step character
# ------------------------------------------------------------------

def vel_to_char(vel):
    """Map a MIDI velocity (0-127) to a tab step character."""
    if vel < VEL_GHOST:
        return 'g'
    if vel < VEL_SOFT:
        return 'o'
    if vel >= VEL_ACCENT:
        return 'X'
    return 'x'


# ------------------------------------------------------------------
# Core conversion
# ------------------------------------------------------------------

def convert_midi_to_tab(notes, ppq, meter_num=4, meter_den=4, resolution=16,
                        mapping=None):
    """Convert MIDI note events to tab grid data.

    Returns (steps_per_bar, bar_grids) where bar_grids is a list of dicts:
      {instrument: [char_per_step]}
    """
    if mapping is None:
        mapping = GM_MAP
    else:
        full = dict(GM_MAP)
        full.update(mapping)
        mapping = full

    # Steps per bar: meter_num * resolution / meter_den
    steps_per_bar = meter_num * resolution // meter_den
    if steps_per_bar < 1:
        steps_per_bar = resolution

    # Step size in ticks
    step_ticks = ppq * 4.0 / resolution  # ticks per step

    # Bar length in ticks
    bar_ticks = steps_per_bar * step_ticks

    # Group notes into bars
    bar_grids = []
    for tick_on, midi_note, vel, dur in notes:
        abbr = mapping.get(midi_note)
        if abbr is None:
            continue
        # Quantize start to nearest step
        step = int(round(tick_on / step_ticks))
        bar_idx = step // steps_per_bar
        step_in_bar = step % steps_per_bar
        # Ensure bar grid exists
        while len(bar_grids) <= bar_idx:
            bar_grids.append({})
        grid = bar_grids[bar_idx]
        if abbr not in grid:
            grid[abbr] = ['.'] * steps_per_bar
        # If multiple notes on same step, keep the louder one
        c = vel_to_char(vel)
        existing = grid[abbr][step_in_bar]
        if existing == '.' or (c == 'X' and existing != 'X'):
            grid[abbr][step_in_bar] = c

    return steps_per_bar, bar_grids


# ------------------------------------------------------------------
# Tab writer
# ------------------------------------------------------------------

INST_ORDER = ['K', 'S', 'RS', 'SS', 'H', 'HO', 'HP', 'R', 'RB', 'C', 'C2', 'CH', 'SP', 'T1', 'T2', 'T3', 'T4']


def write_tab(bars, steps_per_bar, meter_num, meter_den, resolution,
              mode='groove', header_words=None, intensity_low=0.2,
              intensity_high=0.6, fill_name='fill', fill_energy=0.5):
    """Write tab blocks from bar grids.

    bars: list of dicts {instrument: [chars]}
    """
    lines = []

    # Build the header
    if mode == 'fill':
        header = '[%s energy=%.2f]' % (fill_name, fill_energy)
    else:
        words = header_words or ['midi', 'verse']
        header = '[%s intensity=%.2f-%.2f]' % (' '.join(words), intensity_low, intensity_high)
    lines.append(header)

    # Steps per beat unit for grouping (for readability)
    steps_per_unit = max(1, resolution // meter_den)

    # For each instrument, build the bar string
    for inst in INST_ORDER:
        # Collect this instrument's chars across all bars
        bar_strings = []
        for bar in bars:
            if inst in bar:
                chars = ''.join(bar[inst])
            else:
                chars = '.' * steps_per_bar
            # Group by beat units for readability
            grouped = []
            for i in range(0, steps_per_bar, steps_per_unit):
                grouped.append(chars[i:i + steps_per_unit])
            bar_strings.append(' '.join(grouped))
        # Join bars with |
        bar_text = ' | '.join(bar_strings)
        lines.append('%s  %s' % (inst, bar_text))

    return '\n'.join(lines) + '\n'


# ------------------------------------------------------------------
# CLI
# ------------------------------------------------------------------

def main():
    args = sys.argv[1:]
    if not args or args[0] in ('-h', '--help', '-?'):
        print(__doc__)
        sys.exit(0)

    input_path = args[0]
    output_path = None
    mode = 'groove'
    meter_str = None
    resolution = 16
    mapping_path = None
    header_words = None
    intensity_low = 0.2
    intensity_high = 0.6
    fill_name = 'fill'
    fill_energy = 0.5

    i = 1
    while i < len(args):
        a = args[i]
        if a == '--fill':
            mode = 'fill'
        elif a == '--name':
            i += 1
            fill_name = args[i] if i < len(args) else 'fill'
        elif a == '--energy':
            i += 1
            fill_energy = float(args[i]) if i < len(args) else 0.5
        elif a == '--meter':
            i += 1
            meter_str = args[i] if i < len(args) else '4/4'
        elif a == '--resolution':
            i += 1
            resolution = int(args[i]) if i < len(args) else 16
        elif a == '--mapping':
            i += 1
            mapping_path = args[i] if i < len(args) else None
        elif a == '--style':
            i += 1
            header_words = [args[i]] if i < len(args) else ['midi']
        elif a == '--kind':
            i += 1
            kind = args[i] if i < len(args) else 'verse'
            header_words = (header_words or ['midi']) + [kind]
        elif a == '--intensity':
            i += 1
            intensity_str = args[i] if i < len(args) else '0.2-0.6'
            parts = intensity_str.split('-')
            intensity_low = float(parts[0])
            intensity_high = float(parts[1]) if len(parts) > 1 else intensity_low
        elif a.startswith('-'):
            pass  # skip unknown flags
        else:
            output_path = a
        i += 1

    # Determine meter
    meter_num, meter_den = 4, 4
    if meter_str:
        m = re.match(r'(\d+)/(\d+)', meter_str)
        if m:
            meter_num, meter_den = int(m.group(1)), int(m.group(2))

    # Load MIDI
    ppq, tempos, sigs, notes = parse_midi(input_path)

    # Use MIDI time signature if available and no override
    if sigs and not meter_str:
        _, meter_num, meter_den = sigs[0]

    # Filter to percussion zone (GM notes 35-81)
    notes = [(t, n, v, d) for t, n, v, d in notes if 35 <= n <= 81]

    # Load mapping
    mapping = None
    if mapping_path:
        mapping = load_mapping(mapping_path)

    # Convert
    steps_per_bar, bar_grids = convert_midi_to_tab(
        notes, ppq, meter_num=meter_num, meter_den=meter_den,
        resolution=resolution, mapping=mapping
    )

    # Write output
    result = write_tab(
        bar_grids, steps_per_bar, meter_num, meter_den, resolution,
        mode=mode, header_words=header_words,
        intensity_low=intensity_low, intensity_high=intensity_high,
        fill_name=fill_name, fill_energy=fill_energy
    )

    if output_path:
        with open(output_path, 'w', encoding='utf-8', newline='\r\n') as f:
            f.write(result)
        print('Wrote %s (%d notes -> %d bars, %d/%d, %d steps/bar, %d instruments)' % (
            output_path, len(notes), len(bar_grids), meter_num, meter_den,
            steps_per_bar, sum(1 for b in bar_grids if b)))
    else:
        print(result)


if __name__ == '__main__':
    main()