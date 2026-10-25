"""Reports note-on/note-off timing problems in a generated MIDI file.

Usage: python tools/note_overlap.py song.mid [song2.mid ...]

For every drum note it checks whether the note-off of one hit arrives after
the note-on of the next hit of the SAME pitch (an overlap: a sampler that
honours note-off can cut the second hit short) and prints the note length
statistics in ticks and milliseconds at the file's first tempo. Pure Python.
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


def parse_events(path):
    data = open(path, 'rb').read()
    _, ntrks, ppq = struct.unpack('>HHH', data[8:14])
    pos = 14
    events = []  # (tick, kind, note) kind: 'on' / 'off'
    tempo = 500000
    for _ in range(ntrks):
        length = struct.unpack('>I', data[pos + 4:pos + 8])[0]
        p, end = pos + 8, pos + 8 + length
        t, status = 0, 0
        while p < end:
            delta, p = read_vlq(data, p)
            t += delta
            b = data[p]
            if b == 0xFF:
                typ = data[p + 1]
                ln, q = read_vlq(data, p + 2)
                if typ == 0x51 and ln == 3:
                    tempo = int.from_bytes(data[q:q + 3], 'big')
                p = q + ln
                continue
            if b & 0x80:
                status = b
                p += 1
            kind = status & 0xF0
            if kind in (0x90, 0x80):
                note, vel = data[p], data[p + 1]
                p += 2
                events.append((t, 'on' if (kind == 0x90 and vel > 0) else 'off', note))
            elif kind in (0xA0, 0xB0, 0xE0):
                p += 2
            elif kind in (0xC0, 0xD0):
                p += 1
        pos = end
    return ppq, tempo, events


def main():
    for path in sys.argv[1:]:
        ppq, tempo, events = parse_events(path)
        ms_per_tick = tempo / 1000.0 / ppq
        by_note = defaultdict(list)
        for tick, kind, note in events:
            by_note[note].append((tick, kind))
        overlaps = total = 0
        lengths = []
        for note, evs in by_note.items():
            evs.sort(key=lambda e: (e[0], 0 if e[1] == 'off' else 1))
            open_at = None
            for tick, kind in evs:
                if kind == 'on':
                    if open_at is not None:
                        overlaps += 1
                    open_at = tick
                    total += 1
                elif open_at is not None:
                    lengths.append(tick - open_at)
                    open_at = None
        if lengths:
            lengths.sort()
            med = lengths[len(lengths) // 2]
            print('%s: ppq=%d notes=%d overlapping same-pitch hits=%d '
                  'length median=%d ticks (%.0f ms) min=%d max=%d' %
                  (path, ppq, total, overlaps, med, med * ms_per_tick,
                   lengths[0], lengths[-1]))


if __name__ == '__main__':
    main()
