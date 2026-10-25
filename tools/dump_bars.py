"""Prints the notes of a bar range of a generated MIDI file.

Usage: python tools/dump_bars.py song.mid FIRST_BAR LAST_BAR
Notes are listed per 16th-note step as GM drum note numbers
(36 kick, 38 snare, 42/46 hi-hat, 49/57 crash, 51 ride, 41-50 toms).
"""
import sys
from collections import defaultdict

from bar_variation import parse

NAMES = {35: 'K', 36: 'K', 38: 'S', 40: 'S', 37: 'SS', 42: 'H', 44: 'HP', 46: 'HO',
         49: 'C', 57: 'C', 51: 'R', 59: 'R', 53: 'RB', 41: 'T4', 43: 'T3',
         45: 'T2', 47: 'T2', 48: 'T1', 50: 'T1'}


def main():
    ppq, notes = parse(sys.argv[1])
    first, last = int(sys.argv[2]), int(sys.argv[3])
    bar = ppq * 4
    step = ppq / 4
    for b in range(first, last + 1):
        grid = defaultdict(list)
        for t, n, v in notes:
            if t // bar == b:
                grid[round((t % bar) / step)].append(NAMES.get(n, str(n)))
        row = ' '.join('%s' % '+'.join(sorted(grid[s])) if grid[s] else '.' for s in range(16))
        print('bar %3d | %s' % (b, row))


if __name__ == '__main__':
    main()
