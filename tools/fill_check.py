"""Checks the fill bars of generated songs.

Usage: python tools/fill_check.py song.mid [song2.mid ...]

A fill bar is a bar followed by a crash on the next downbeat, or a bar that
holds at least two tom hits. For each one the tool reports how many hi-hat /
ride timekeeping hits survive after the fill starts (they should be cut) and
prints the bar. Pure Python.
"""
import sys

from bar_variation import parse

TOMS = {41, 43, 45, 47, 48, 50}
TIME = {42, 44, 46, 51, 53, 59}
CRASH = {49, 55, 57}


def main():
    total = cut_ok = 0
    for path in sys.argv[1:]:
        ppq, notes = parse(path)
        bar = ppq * 4
        step = ppq / 4
        by = {}
        for t, n, v in notes:
            by.setdefault(t // bar, []).append((t % bar, n))
        last = max(by) if by else 0
        for b in sorted(by):
            ns = by[b]
            tom_hits = [x for x in ns if x[1] in TOMS]
            nxt = by.get(b + 1, [])
            crash_next = any(n in CRASH and t < step for t, n in nxt)
            if len(tom_hits) < 2 and not crash_next:
                continue
            first = min([t for t, n in ns if n in TOMS] or [bar])
            late_time = [x for x in ns if x[1] in TIME and x[0] > first + step]
            total += 1
            if not late_time:
                cut_ok += 1
            else:
                print('%s bar %d: %d timekeeping hits after the fill started' %
                      (path, b, len(late_time)))
    print('fill bars=%d groove cut cleanly=%d' % (total, cut_ok))


if __name__ == '__main__':
    main()
