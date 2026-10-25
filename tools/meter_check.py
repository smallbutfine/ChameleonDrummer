"""Checks the meter of a generated MIDI file against what was asked for.

Usage: python tools/meter_check.py song.mid [NUM/DEN]

Reads the time-signature meta events itself (no engine code), walks the bars
and reports, per time-signature region: the meter, the bar length in ticks,
the number of bars, the notes per bar, and any note that sits off the grid of
sixteenths of a unit (a sign that a position was computed with the wrong bar
length). With NUM/DEN it also fails (exit 1) when the first meter differs.

Also prints the first bars of the region as a step diagram: one column per
1/DEN unit, so "K . S ." style patterns can be read against the beat groups.
Pure Python.
"""
import struct
import sys

from note_overlap import read_vlq

NAMES = {35: 'K', 36: 'K', 38: 'S', 40: 'S', 37: 'r', 42: 'H', 44: 'p', 46: 'O',
         49: 'C', 57: 'C', 51: 'R', 53: 'B', 59: 'R', 41: 't', 43: 't', 45: 't',
         47: 't', 48: 't', 50: 't', 55: 'C', 52: 'C'}


def parse(path):
    data = open(path, 'rb').read()
    _, ntrks, ppq = struct.unpack('>HHH', data[8:14])
    pos = 14
    sigs, notes = [], []
    for _ in range(ntrks):
        length = struct.unpack('>I', data[pos + 4:pos + 8])[0]
        p, end = pos + 8, pos + 8 + length
        t, status = 0, 0
        while p < end:
            delta, p = read_vlq(data, p)
            t += delta
            b = data[p]
            if b == 0xFF:
                kind, ln = data[p + 1], data[p + 2]
                body = data[p + 3:p + 3 + ln]
                if kind == 0x58:
                    sigs.append((t, body[0], 1 << body[1]))
                p += 3 + ln
                continue
            if b & 0x80:
                status = b
                p += 1
            hi = status & 0xF0
            if hi in (0x80, 0x90, 0xA0, 0xB0, 0xE0):
                d1, d2 = data[p], data[p + 1]
                p += 2
                if hi == 0x90 and d2 > 0:
                    notes.append((t, d1))
            elif hi in (0xC0, 0xD0):
                p += 1
            else:
                p += 1
        pos = end
    return ppq, sorted(sigs), sorted(notes)


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    ppq, sigs, notes = parse(sys.argv[1])
    expect = sys.argv[2] if len(sys.argv) > 2 else None
    if not sigs:
        sigs = [(0, 4, 4)]
    last = max(t for t, _ in notes) if notes else 0
    ok = True
    for i, (start, num, den) in enumerate(sigs):
        end = sigs[i + 1][0] if i + 1 < len(sigs) else last + 1
        bar = ppq * 4 * num // den
        unit = ppq * 4 // den
        region = [(t, n) for t, n in notes if start <= t < end]
        bars = max(1, -(-(end - start) // bar))
        grid = max(unit // 4, 1)
        tol = 60   # ticks at 960 ppq: the drummers' own behind-the-beat feel is up to ~25 ms
        def dist(t):
            r = ((t - start) % bar) % grid
            return min(r, grid - r)
        off = [(t, n) for t, n in region if dist(t) > tol]
        print('%s: %d/%d from tick %d: bar = %d ticks (%d x 1/%d), %d bar(s), %d notes, %d more than %d ticks off the 1/%d grid'
              % (sys.argv[1], num, den, start, bar, num, den, bars, len(region),
                 len(off), tol, den * 4))
        if off:
            ok = False
            print('   first off-grid note at tick %d (bar %d, offset %d)'
                  % (off[0][0], (off[0][0] - start) // bar + 1, (off[0][0] - start) % bar))
        for b in range(min(2, bars)):
            row = []
            for u in range(num):
                names = sorted({NAMES.get(n, '?') for t, n in region
                                if (t - start) // bar == b and (t - start) % bar // unit == u
                                and ((t - start) % bar) % unit < unit // 2 + 1})
                row.append(''.join(names) or '.')
            print('   bar %d: %s' % (b + 1, ' '.join('%-3s' % c for c in row)))
        if i == 0 and expect and expect != '%d/%d' % (num, den):
            print('   EXPECTED %s' % expect)
            ok = False
    raise SystemExit(0 if ok else 1)


if __name__ == '__main__':
    main()
