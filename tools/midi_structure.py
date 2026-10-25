"""Prints the bar count and the tempo / time-signature changes of a MIDI file.

Usage: python tools/midi_structure.py song.mid [song2.mid ...]

Output per file: total bars (from the last note, in the file's meter) and a
list of "bar N: tempo BPM" / "bar N: num/den" changes, so the structure that
was asked for with --section can be compared with what was written.
Pure Python.
"""
import struct
import sys

from note_overlap import read_vlq


def analyse(path):
    data = open(path, 'rb').read()
    _, ntrks, ppq = struct.unpack('>HHH', data[8:14])
    pos = 14
    tempos = []   # (tick, bpm)
    sigs = []     # (tick, num, den)
    last_note = 0
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
                    tempos.append((t, round(60000000 / int.from_bytes(data[q:q + 3], 'big'))))
                elif typ == 0x58 and ln >= 2:
                    sigs.append((t, data[q], 2 ** data[q + 1]))
                p = q + ln
                continue
            if b & 0x80:
                status = b
                p += 1
            kind = status & 0xF0
            if kind in (0x90, 0x80):
                if kind == 0x90 and data[p + 1] > 0:
                    last_note = max(last_note, t)
                p += 2
            elif kind in (0xA0, 0xB0, 0xE0):
                p += 2
            elif kind in (0xC0, 0xD0):
                p += 1
        pos = end
    return ppq, tempos, sigs, last_note


def bar_at(tick, ppq, sigs):
    """Bar number (0-based) a tick falls in, honouring time-signature changes."""
    bar, cursor = 0, 0
    sig = sigs[0] if sigs else (0, 4, 4)
    changes = sorted(sigs)
    cur_num, cur_den = 4, 4
    for i, (t, n, d) in enumerate(changes):
        if t > tick:
            break
        if t > cursor:
            bar += (t - cursor) / (ppq * cur_num * 4 / cur_den)
            cursor = t
        cur_num, cur_den = n, d
    bar += (tick - cursor) / (ppq * cur_num * 4 / cur_den)
    return bar


def main():
    for path in sys.argv[1:]:
        ppq, tempos, sigs, last_note = analyse(path)
        print('%s: ppq=%d, last note in bar %d' % (path, ppq, int(bar_at(last_note, ppq, sigs)) + 1))
        prev = None
        for t, bpm in tempos:
            if bpm != prev:
                print('   bar %6.2f: tempo %d BPM' % (bar_at(t, ppq, sigs) + 1, bpm))
                prev = bpm


if __name__ == '__main__':
    main()
