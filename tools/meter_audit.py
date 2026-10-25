"""Reads the odd-meter blocks of config/grooves/*.tab and lays each one out as
a drummer would read it: one column per unit of the bar, beat groups separated
by '|', the instruments stacked by limb. It flags what is probably a mistake:

  * kick and snare on the same unit (idiomatic in electronic music, a slip
    elsewhere),
  * no kick (or crash) on the one,
  * a snare on the one,
  * snare, crash and toms 1/3 (right hand) on the same unit with ride/hat
    patterns that need the left hand somewhere else is the limb engine's job,
    not checked here.

Usage: python tools/meter_audit.py [genre ...]      (default: all genres)
Exit code 1 when something is flagged. Pure Python, reads the text files only.
"""
import glob
import os
from fractions import Fraction
import re
import sys

KICK = {'K'}
SNARE = {'S', 'RS', 'SS'}
CRASH = {'C', 'C2', 'CH', 'SP'}


def groups(num, den):
    if den in (2, 4) and num <= 4:
        return [1] * num
    threes, rest = divmod(num, 3)
    if rest == 1:
        return [3] * (threes - 1) + [2, 2]
    return [3] * threes + ([2] if rest == 2 else [])


def blocks(path):
    cur = None
    for n, raw in enumerate(open(path, encoding='utf-8-sig').read().splitlines(), 1):
        line = raw.strip()
        if not line or line[0] in '#;':
            continue
        if line[0] == '[':
            if cur:
                yield cur
            words = line[1:-1].split()
            meter = [w for w in words if '/' in w]
            cur = {'line': n, 'words': [w for w in words if '/' not in w and '=' not in w],
                   'meter': meter[0] if meter else '4/4', 'rows': [],
                   'band': next((w for w in words if w.startswith('intensity=')), '')}
        elif cur is not None:
            inst, _, steps = line.partition(' ')
            cur['rows'].append((inst.split('@')[0].upper(), re.sub(r'[ |]', '', steps)))
    if cur:
        yield cur


def audit(path, genre):
    problems = 0
    for b in blocks(path):
        if b['meter'] == '4/4':
            continue
        num, den = map(int, b['meter'].split('/'))
        g = groups(num, den)
        label = '%s %s %s' % (genre, ' '.join(b['words']), b['meter'])
        per_unit = {}      # unit -> instruments (for the picture)
        per_pos = {}       # exact position in the bar -> instruments (for the checks)
        notes = []
        for inst, steps in b['rows']:
            if len(steps) % num:
                notes.append('%s has %d steps, not a multiple of %d' % (inst, len(steps), num))
                continue
            k = len(steps) // num
            for i, c in enumerate(steps):
                if c not in '.-':
                    # a ghost note is a quiet filler, not a backbeat
                    if c == 'g' and inst in SNARE:
                        continue
                    per_unit.setdefault(i // k, set()).add(inst)
                    per_pos.setdefault(Fraction(i, len(steps)), set()).add(inst)
        both = sorted(p for p, s in per_pos.items() if s & KICK and s & SNARE)
        if both and genre not in ('electronic', 'metal'):
            notes.append('kick and snare on the same step, at %s of the bar' %
                         ', '.join('%.2f' % float(p) for p in both))
        first = per_unit.get(0, set())
        if not (first & KICK or first & CRASH):
            notes.append('nothing marks the one (no kick or crash on unit 1)')
        if first & SNARE:
            notes.append('snare on the one')
        cols, u = [], 0
        for size in g:
            for _ in range(size):
                cols.append('%-7s' % '+'.join(sorted(per_unit.get(u, []))) if u in per_unit else '.      ')
                u += 1
            cols.append('|')
        print('%-34s %s %s' % (label, b['band'] or '', ''.join(cols).rstrip('|').rstrip()))
        for n in notes:
            print('      !! ' + n)
            problems += 1
    return problems


def main():
    wanted = set(sys.argv[1:])
    total = 0
    for path in sorted(glob.glob(os.path.join('config', 'grooves', '*.tab'))):
        genre = os.path.basename(path)[:-4]
        if wanted and genre not in wanted:
            continue
        total += audit(path, genre)
    print('\n%d thing(s) flagged' % total)
    raise SystemExit(1 if total else 0)


if __name__ == '__main__':
    main()
