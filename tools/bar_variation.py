"""Reports how much the bars of a generated MIDI file differ from each other.

Usage: python tools/bar_variation.py song.mid
Pure Python (no dependencies). Assumes 4/4 for bar splitting.
"""
import struct
import sys
from collections import defaultdict


def read_vlq(data, pos):
    value = 0
    while True:
        b = data[pos]
        pos += 1
        value = (value << 7) | (b & 0x7F)
        if not b & 0x80:
            return value, pos


def parse(path):
    data = open(path, 'rb').read()
    _, ntrks, ppq = struct.unpack('>HHH', data[8:14])
    pos = 14
    notes = []
    for _ in range(ntrks):
        assert data[pos:pos + 4] == b'MTrk'
        length = struct.unpack('>I', data[pos + 4:pos + 8])[0]
        p, end = pos + 8, pos + 8 + length
        t, status = 0, 0
        while p < end:
            delta, p = read_vlq(data, p)
            t += delta
            b = data[p]
            if b == 0xFF:
                ln, p = read_vlq(data, p + 2)
                p += ln
                continue
            if b & 0x80:
                status = b
                p += 1
            kind = status & 0xF0
            if kind in (0x90, 0x80, 0xA0, 0xB0, 0xE0):
                a, v = data[p], data[p + 1]
                p += 2
                if kind == 0x90 and v > 0:
                    notes.append((t, a, v))
            elif kind in (0xC0, 0xD0):
                p += 1
            elif status == 0xF0:
                ln, p = read_vlq(data, p)
                p += ln
        pos = end
    return ppq, notes


def main():
    ppq, notes = parse(sys.argv[1])
    bar_ticks = ppq * 4
    bars = defaultdict(list)
    for t, n, v in notes:
        # quantise to 1/16 so humanisation jitter does not hide equality
        grid = round((t % bar_ticks) / (ppq / 4))
        bars[t // bar_ticks].append((grid, n))
    sigs = {b: tuple(sorted(set(x))) for b, x in bars.items()}
    total = len(sigs)
    unique = len(set(sigs.values()))
    print(f'bars={total} distinct_bar_patterns={unique}')
    prev = None
    changes = 0
    for b in sorted(sigs):
        if prev is not None and sigs[b] != prev:
            changes += 1
        prev = sigs[b]
    print(f'bar-to-bar changes={changes} of {total - 1}')


if __name__ == '__main__':
    main()
