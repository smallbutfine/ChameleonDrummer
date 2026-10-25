"""Writes config/fills/<drummer>.tab from the MakeTabFill calls in the drummer
units, so the files start out identical to the built-in fills.

Usage (project root):  python tools/export_fills.py

The file name is the name the drummer has on the command line (the key it is
registered under in DrumGenerator.LoadPlugins), e.g. doom_blues.pas ->
doomblues.tab.
"""
import os
import re

SRC = 'src'
OUT = os.path.join('config', 'fills')

# unit file -> command-line name (registered key)
DRUMMERS = {
    'bonham': 'bonham', 'porcaro': 'porcaro', 'weckl': 'weckl',
    'chambers': 'chambers', 'roeder': 'roeder', 'dee': 'dee',
    'hoglan': 'hoglan', 'peart': 'peart', 'rich': 'rich',
    'copeland': 'copeland', 'carey': 'carey', 'smith': 'smith',
    'moon': 'moon', 'watts': 'watts', 'haake': 'haake',
    'halpern': 'halpern', 'doom_blues': 'doomblues',
}

CALL = re.compile(
    r"MakeTabFill\(\s*'([^']+)'\s*,\s*([0-9.]+)\s*,\s*\[(.*?)\]\s*\)\s*\)",
    re.S)
LINE = re.compile(r"'([^']*)'")

HEADER = """# {name}'s fills, one bar each.
#
# One block per fill:  [name energy=0.3]
#   energy  the bar intensity (0-1) the fill suits best: a short fill about 0.3, a big one about 0.9
# Then one line per instrument:  <instrument>[@min complexity] <bar 1> | <bar 2> ...
#   instruments  K S RS SS H HO HP R RB C C2 CH SP T1 T2 T3 T4
#   steps        . rest   x hit   X accent   o soft   g ghost
#   a bar has 4, 8, 12, 16, 24 or 32 steps; spaces inside a bar are ignored
# Add a block to give this drummer another fill; the composer picks among the
# fills by how well their energy matches the bar. Keep to one drummer's limbs:
# snare, crash and toms 1/3 right hand; hi-hat, ride, tom 2 left hand; kick and
# hi-hat pedal feet; at most 3 hits on one step.
"""


def main():
    os.makedirs(OUT, exist_ok=True)
    for unit, key in DRUMMERS.items():
        text = open(os.path.join(SRC, unit + '.pas'), encoding='utf-8-sig').read()
        calls = CALL.findall(text)
        if not calls:
            raise SystemExit('no MakeTabFill calls found in ' + unit + '.pas')
        out = [HEADER.format(name=key.capitalize())]
        for name, energy, body in calls:
            out.append('')
            out.append('[%s energy=%s]' % (name, energy))
            for line in LINE.findall(body):
                out.append(line)
        with open(os.path.join(OUT, key + '.tab'), 'w', encoding='utf-8', newline='\r\n') as f:
            f.write('\n'.join(out) + '\n')
        print('wrote %s.tab (%d fills)' % (key, len(calls)))


if __name__ == '__main__':
    main()
