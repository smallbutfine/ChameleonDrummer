"""Measures the swing feel of a generated MIDI file.

Usage: python tools/swing_check.py song.mid [song2.mid ...]

For every closed hi-hat / ride hit that is neither on a beat nor on a
triplet position it reports where inside the beat the offbeat eighth lies
(0.50 = straight, 0.667 = classic 2:1 swing, 0.75 = 3:1). Pure Python.
"""
import sys
from collections import Counter

from bar_variation import parse

TIME = {42, 51, 59, 44}


def main():
    for path in sys.argv[1:]:
        ppq, notes = parse(path)
        fracs = Counter()
        for t, n, v in notes:
            if n not in TIME:
                continue
            f = (t % ppq) / ppq
            if 0.40 <= f <= 0.85:
                fracs[round(f, 2)] += 1
        total = sum(fracs.values())
        if not total:
            print('%s: no offbeat time-keeping hits' % path)
            continue
        mean = sum(k * c for k, c in fracs.items()) / total
        print('%s: offbeat hits=%d mean position in beat=%.3f  most common=%s' %
              (path, total, mean, fracs.most_common(3)))


if __name__ == '__main__':
    main()
