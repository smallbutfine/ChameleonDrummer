"""Measures the groove of generated songs, so a change of feel is a number.

Usage: python tools/feel_stats.py GENRE STYLE METER [SONGS] [DRUMMER]

Generates SONGS songs (default 20) of 8 bars of verse and 8 of chorus without
humanization, then reports for the meter:
  * where the snare falls in a bar (share of bars, by position in quarter notes),
    compared with the beat groups of the meter,
  * how many bars come from a recorded (off-grid) pattern and how many from the
    written grooves,
  * how often two neighbouring bars count the bar differently (a snare pattern
    that moves from one group layout to another from bar to bar).
Pure Python on the MIDI files; needs ChameleonDrummer.exe in the project root.
"""
import collections
import subprocess
import sys

from meter_check import parse

SNARE = {38, 40, 37}


def groups(num, den):
    if den in (2, 4) and num <= 4:
        return [1] * num
    threes, rest = divmod(num, 3)
    if rest == 1:
        return [3] * (threes - 1) + [2, 2]
    return [3] * threes + ([2] if rest == 2 else [])


def main():
    genre, style, meter = sys.argv[1:4]
    songs = int(sys.argv[4]) if len(sys.argv) > 4 else 20
    drummer = sys.argv[5] if len(sys.argv) > 5 else 'bonham'
    num, den = map(int, meter.split('/'))
    g = groups(num, den)
    starts, acc = [], 0
    for x in g[:-1]:
        acc += x
        starts.append(acc * 4 / den)
    snare_at = collections.Counter()
    layouts = collections.Counter()
    bars = recorded = switches = 0
    for i in range(songs):
        out = 'tests/out/m/feel.mid'
        r = subprocess.run(['./ChameleonDrummer.exe', 'generate', '--genre', genre, '--style', style,
                            '--time-sig', meter, '--section', 'verse:8', '--section', 'chorus:8',
                            '--drummer', drummer, '--humanization', '0', '--output', out],
                           capture_output=True, text=True)
        ppq, sigs, notes = parse(out)
        unit = ppq * 4 // den
        bar = unit * num
        prev = None
        for b in range(16):
            ns = [(t - b * bar, n) for t, n in notes if b * bar <= t < (b + 1) * bar]
            if not ns:
                continue
            bars += 1
            off = sum(1 for t, n in ns if min(t % (ppq // 4), ppq // 4 - t % (ppq // 4)) > 60)
            if off > 3:
                recorded += 1
            sn = sorted({round(t / ppq * 2) / 2 for t, n in ns if n in SNARE and off <= 3})
            for p in sn:
                snare_at[p] += 1
            layout = tuple(sn)
            if prev is not None and layout and prev and layout != prev:
                switches += 1
            if layout:
                prev = layout
                layouts[layout] += 1
    print('%s %s %s: %d songs, %d bars' % (genre, style, meter, songs, bars))
    print('  beat group starts (where a drummer snares):', starts or '(every beat)')
    print('  bars from recorded patterns: %d (%d%%)' % (recorded, 100 * recorded // max(bars, 1)))
    print('  snare by position (quarters): ' +
          ', '.join('%g:%d%%' % (p, 100 * c // max(bars, 1)) for p, c in sorted(snare_at.items())))
    print('  most common snare layouts per bar:')
    for lay, c in layouts.most_common(4):
        print('    %-40s %d%%' % (list(lay), 100 * c // max(bars, 1)))
    print('  bars whose snare layout differs from the previous bar: %d%%' % (100 * switches // max(bars, 1)))


if __name__ == '__main__':
    main()
