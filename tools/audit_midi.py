"""Deterministic-ish MIDI analysis harness for ChameleonDrummer.

Usage: python tools/audit_midi.py <file.mid> [...]
Reports note histogram, velocity stats per drum role, and timing spread.
"""
import sys, struct, collections

GM = {35: 'kick', 36: 'kick2', 38: 'snare', 39: 'rimshot', 40: 'snare2',
      42: 'hh_closed', 44: 'hh_pedal', 45: 'tom2', 47: 'tom3', 48: 'tom4',
      49: 'crash', 51: 'ride', 57: 'crash2', 22: 'hh_open', 46: 'hh_open2'}


def read_midi(path):
    d = open(path, 'rb').read()
    assert d[0:4] == b'MThd', 'not a MIDI file'
    hlen = struct.unpack('>I', d[4:8])[0]
    fmt, ntrk, div = struct.unpack('>HHH', d[8:14])
    pos = 8 + hlen
    notes = []
    for _ in range(ntrk):
        assert d[pos:pos+4] == b'MTrk', 'bad track chunk'
        tlen = struct.unpack('>I', d[pos+4:pos+8])[0]
        end = pos + 8 + tlen
        p = pos + 8
        tick = 0
        status = 0
        while p < end:
            dt = 0
            while True:
                b = d[p]; p += 1
                dt = (dt << 7) | (b & 0x7f)
                if not (b & 0x80):
                    break
            tick += dt
            b = d[p]
            if b < 0x80:
                if status == 0:
                    break
                b = status
            else:
                p += 1
                if b < 0xf0:
                    status = b
                else:
                    status = 0
            if b == 0xff:
                p += 1
                ln = 0
                while True:
                    bb = d[p]; p += 1
                    ln = (ln << 7) | (bb & 0x7f)
                    if not (bb & 0x80):
                        break
                p += ln
            elif b in (0xf0, 0xf7):
                ln = struct.unpack('>I', d[p:p+4])[0]; p += 4 + ln
            else:
                hi = b & 0xf0
                v1 = d[p]; p += 1
                v2 = 0
                if hi not in (0xc0, 0xd0):
                    v2 = d[p]; p += 1
                if hi == 0x90 and v2 > 0:
                    notes.append((tick, v1, v2))
        pos = end
    return notes, div


def main(paths):
    for path in paths:
        notes, div = read_midi(path)
        per = collections.defaultdict(list)
        for tick, n, v in notes:
            per[n].append((tick, v))
        print(f"=== {path}  ppq={div} noteons={len(notes)} ===")
        for n in sorted(per):
            vs = [v for _, v in per[n]]
            print(f"  {n:3d} {GM.get(n,'?'):10s} n={len(vs):5d} "
                  f"vmin={min(vs):3d} vmax={max(vs):3d} vavg={sum(vs)/len(vs):6.1f}")
        # duplicate (tick,note) pairs -> would collide in playback
        seen = collections.Counter((t, n) for t, n, v in notes)
        dupes = {k: c for k, c in seen.items() if c > 1}
        if dupes:
            print(f"  !! {len(dupes)} duplicated (tick,note) pairs")
        return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
