"""Appends hand-written odd-meter grooves to config/grooves/<genre>.tab.

Usage (project root):  python tools/write_meter_grooves.py

Each groove is written as a list of beat groups, so the step count of every
line is right by construction: a bar of N/D is N units; GROUPS says how the
units are counted (7/8 = 3+2+2). A row is one string per group, joined with
spaces for the reader; the engine ignores the spaces. Existing blocks with the
same header are replaced, everything else in the file is kept.
"""
import os
import re

GROOVES = os.path.join('config', 'grooves')


def block(style, kind, meter, band, rows):
    head = '[%s %s %s intensity=%s]' % (style, kind, meter, band)
    return head + '\n' + '\n'.join('%-3s %s' % (i, r) for i, r in rows) + '\n'


# 3/4: groups 1+1+1, eighths: 6 steps  (A = "a", the off-beat)
ROCK = [
    block('classic', 'verse', '3/4', '0.20-0.60', [
        ('K', 'x. .. x.'), ('S', '.. x. ..'), ('H', 'x. x. x.')]),
    block('classic', 'verse', '3/4', '0.40-0.80', [
        ('K', 'x. .. x.'), ('S', '.. x. .x'), ('H', 'x. x. x.'), ('C@0.7', 'X. .. ..')]),
    block('classic', 'chorus', '3/4', '0.40-1.00', [
        ('K', 'x. .x x.'), ('S', '.. x. .x'), ('R', 'x. x. x.'), ('C', 'X. .. ..')]),
    # 5/4 = 3+2 in quarters: eighths, 10 steps. Snare on quarter 4 (the second group).
    block('classic', 'verse', '5/4', '0.20-0.70', [
        ('K', 'x. .. .. x. ..'), ('S', '.. .. .. x. ..'), ('H', 'x. x. x. x. x.')]),
    block('classic', 'chorus', '5/4', '0.40-1.00', [
        ('K', 'x. .. x. x. ..'), ('S', '.. .. .. x. ..'), ('R', 'x. x. x. x. x.'),
        ('C', 'X. .. .. .. ..')]),
    # 7/8 = 3+2+2: 7 steps. Snare where the 2-groups start.
    block('classic', 'verse', '7/8', '0.20-0.60', [
        ('K', 'x.. .. ..'), ('S', '... x. x.'), ('H', 'xxx xx xx')]),
    block('classic', 'verse', '7/8', '0.40-0.80', [
        ('K', 'x.. .x ..'), ('S', '... x. x.'), ('H', 'x.x x. x.'), ('HP', '..x .x ..')]),
    block('classic', 'chorus', '7/8', '0.40-1.00', [
        ('K', 'x.. x. x.'), ('S', '... x. x.'), ('R', 'xxx xx xx'), ('C', 'X.. .. ..')]),
    # 9/8 = 3+3+3
    block('classic', 'verse', '9/8', '0.20-0.80', [
        ('K', 'x.. ... x..'), ('S', '... x.. ...'), ('H', 'x.x x.x x.x')]),
    block('classic', 'chorus', '9/8', '0.40-1.00', [
        ('K', 'x.. x.. x..'), ('S', '... x.. x..'), ('R', 'xxx xxx xxx'), ('C', 'X.. ... ...')]),
    # 11/8 = 3+3+3+2
    block('classic', 'verse', '11/8', '0.20-0.80', [
        ('K', 'x.. ... x.. ..'), ('S', '... x.. ... x.'), ('H', 'xxx xxx xxx xx')]),
    # 13/8 = 3+3+3+2+2
    block('classic', 'verse', '13/8', '0.20-0.80', [
        ('K', 'x.. ... x.. .. ..'), ('S', '... x.. ... x. x.'), ('H', 'xxx xxx xxx xx xx')]),
]

JAZZ = [
    # 3/4 jazz waltz: ride on every beat plus the skip note, 12 triplet steps would be
    # a 9/8 feel, so 6 eighths: ride 1 . 3 4 . 6? keep it a plain waltz ride.
    block('swing', 'verse', '3/4', '0.20-0.70', [
        ('R', 'x. xx xx'), ('HP', '.. x. x.'), ('K', 'x. .. ..'), ('S', '.. .. .x')]),
    block('swing', 'chorus', '3/4', '0.40-1.00', [
        ('R', 'x. xx xx'), ('HP', '.. x. x.'), ('K', 'x. .. x.'), ('S', '.. x. .x')]),
    # 5/4 (Take Five, 3+2): ride quarter + skip, pedal on 2 and 4
    block('swing', 'verse', '5/4', '0.20-0.70', [
        ('R', 'x. xx xx x. xx'), ('HP', '.. x. .. x. ..'), ('K', 'x. .. .. .. ..'),
        ('SS', '.. .. x. .. x.')]),
    # 7/8 = 2+2+3 is the classic jazz grouping for 7; the engine's default is 3+2+2,
    # so this one is written for the default grouping.
    block('swing', 'verse', '7/8', '0.20-0.70', [
        ('R', 'xx xx xxx'), ('HP', '.x .. .x.'), ('K', 'x. .. ...'), ('S', '.. .x ..x')]),
]

FUNK = [
    block('classic', 'verse', '7/8', '0.20-0.80', [
        ('K', 'x.. x. .x'), ('S', '... x. x.'), ('H', 'xxx xx xx'), ('S@0.7', '... .g .g')]),
    block('classic', 'verse', '5/4', '0.20-0.80', [
        ('K', 'x. .. .x x. ..'), ('S', '.. .. .. x. ..'), ('H', 'x. x. x. x. x.')]),
    block('classic', 'verse', '3/4', '0.20-0.80', [
        ('K', 'x. .. .x'), ('S', '.. x. ..'), ('H', 'xx xx xx')]),
]

METAL = [
    block('heavy', 'verse', '7/8', '0.20-0.80', [
        ('K', 'x.x xx xx'), ('S', '... x. x.'), ('H', 'x.x x. x.'), ('C', 'X.. .. ..')]),
    block('heavy', 'chorus', '7/8', '0.40-1.00', [
        ('K', 'xxx xx xx'), ('S', '... x. x.'), ('R', 'xxx xx xx'), ('C', 'X.. .. ..')]),
    block('heavy', 'verse', '5/4', '0.20-0.80', [
        ('K', 'x. .x x. x. ..'), ('S', '.. .. .. x. ..'), ('H', 'x. x. x. x. x.'),
        ('C', 'X. .. .. .. ..')]),
    block('doom', 'verse', '3/4', '0.10-0.60', [
        ('K', 'x. .. ..'), ('S', '.. .. x.'), ('R', 'x. x. x.'), ('C@0.5', 'X. .. ..')]),
]

ELECTRONIC = [
    block('house', 'verse', '7/8', '0.20-0.80', [
        ('K', 'x.. x. x.'), ('S', '... x. x.'), ('H', 'xxx xx xx')]),
    block('techno', 'verse', '5/4', '0.20-0.80', [
        ('K', 'x. x. x. x. x.'), ('RS', '.. .. .. x. ..'), ('H', '.x .x .x .x .x')]),
]

FILES = {'rock': ROCK, 'jazz': JAZZ, 'funk': FUNK, 'metal': METAL, 'electronic': ELECTRONIC}

MARK = '# ---- odd meters (hand written, tools/write_meter_grooves.py) ----'


def main():
    for genre, blocks in FILES.items():
        path = os.path.join(GROOVES, genre + '.tab')
        text = open(path, encoding='utf-8-sig').read().replace('\r\n', '\n')
        # drop an earlier run of this script
        if MARK in text:
            text = text[:text.index(MARK)].rstrip('\n') + '\n'
        text += '\n' + MARK + '\n# The step counts divide the bar: 7/8 takes 7, 14, 21 ... steps; spaces are only for reading.\n\n'
        text += '\n'.join(blocks)
        with open(path, 'w', encoding='utf-8', newline='\r\n') as f:
            f.write(text)
        print('%s.tab: %d meter grooves' % (genre, len(blocks)))


if __name__ == '__main__':
    main()
