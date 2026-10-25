"""Appends hand-written odd-meter grooves to config/grooves/<genre>.tab.

Usage (project root):  python tools/write_meter_grooves.py
Check them with:       python tools/meter_audit.py

A row is written in the groups the drummer counts (spaces are only for
reading, the engine ignores them): 7/8 as 3+2+2 is 'xxx xx xx', as 2+2+3
'xx xx xxx'. A bar of N/D has N units; /4 meters here use eighths (2 steps per
quarter) or, for jazz, triplets (3 steps per quarter).

Rules the grooves follow, the same as the 4/4 ones:
  * the kick does not sit on the step of the backbeat snare (a drummer leaves
    the gap) - except in metal and electronic, where kick and snare together
    is the sound;
  * snare, crash and toms 1/3 are right hand, hi-hat/ride left: no crash under
    a snare;
  * three variants per style and kind, light to heavy, with overlapping bands.
Existing blocks are replaced, everything else in the file is kept.
"""
import os

GROOVES = os.path.join('config', 'grooves')
MARK = '# ---- odd meters (hand written, tools/write_meter_grooves.py) ----'


def block(style, kind, meter, band, rows):
    head = '[%s %s %s intensity=%s]' % (style, kind, meter, band)
    return head + '\n' + '\n'.join('%-5s %s' % (i, r) for i, r in rows) + '\n'


def blocks(style, meter, table):
    """table: {kind: [(band, [(inst, steps), ...]), ...]}"""
    out = []
    for kind in ('verse', 'chorus', 'bridge'):
        for band, rows in table.get(kind, []):
            out.append(block(style, kind, meter, band, rows))
    return out


# --------------------------------------------------------------------- rock
ROCK = []

# 3/4, eighths (6 steps). Waltz backbeat on 2 and 3; kick on 1 and the "and"s.
ROCK += blocks('classic', '3/4', {
    'verse': [
        ('0.20-0.60', [('K', 'x. .. .x'), ('S', '.. x. x.'), ('H', 'x. x. x.')]),
        ('0.40-0.80', [('K', 'x. .x .x'), ('S', '.. x. x.'), ('H', 'xx xx xx'), ('C@0.7', 'X. .. ..')]),
        ('0.60-1.00', [('K', 'xx .x .x'), ('S', '.. x. x.'), ('R', 'xx xx xx'), ('C', 'X. .. ..')]),
    ],
    'chorus': [
        ('0.40-0.80', [('K', 'x. .x ..'), ('S', '.. x. x.'), ('R', 'x. x. x.'), ('C', 'X. .. ..')]),
        ('0.60-1.00', [('K', 'x. .x .x'), ('S', '.. x. x.'), ('R', 'xx xx xx'), ('C', 'X. .. ..')]),
        ('0.75-1.00', [('K', 'xx .. .x'), ('S', '.. x. x.'), ('R', 'xx xx xx'), ('C', 'X. .. ..'),
                       ('S@0.9', '.. .g .g')]),
    ],
    'bridge': [
        ('0.10-0.50', [('K', 'x. .. ..'), ('S', '.. x. ..'), ('R', 'x. x. x.')]),
        ('0.30-0.70', [('K', 'x. .. .x'), ('S', '.. x. x.'), ('H', 'x. x. x.')]),
        ('0.50-0.90', [('K', 'x. .x .x'), ('S', '.. x. x.'), ('R', 'xx xx xx')]),
    ],
})

# 5/4, eighths (10 steps). Counted 3+2 (snare on beat 4) and 2+3 (snare on beat 3).
ROCK += blocks('classic', '5/4', {
    'verse': [
        ('0.20-0.60', [('K', 'x. .. .x .. ..'), ('S', '.. .. .. x. ..'), ('H', 'x. x. x. x. x.')]),
        ('0.40-0.80', [('K', 'x. .. x. .. x.'), ('S', '.. .. .. x. ..'), ('H', 'xx xx xx xx xx')]),
        ('0.60-1.00', [('K', 'x. .. .. .x .x'), ('S', '.. .. .. x. ..'), ('H', 'xx xx xx xx xx'),
                       ('C@0.7', 'X. .. .. .. ..'), ('S@0.8', '.. g. .. .. g.')]),
    ],
    'chorus': [
        ('0.40-0.80', [('K', 'x. .. .x .. x.'), ('S', '.. .. .. x. ..'), ('R', 'x. x. x. x. x.'),
                       ('C', 'X. .. .. .. ..')]),
        ('0.60-1.00', [('K', 'x. .x .. .. xx'), ('S', '.. .. .. x. ..'), ('R', 'xx xx xx xx xx'),
                       ('C', 'X. .. .. .. ..')]),
        ('0.75-1.00', [('K', 'x. .. .x .. .x'), ('S', '.. .. .. x. ..'), ('R', 'xx xx xx xx xx'),
                       ('S@0.9', '.. g. .. .. g.'),
                       ('C', 'X. .. .. .. ..')]),
    ],
    'bridge': [
        ('0.10-0.50', [('K', 'x. .. .. .. ..'), ('S', '.. .. .. x. ..'), ('R', 'x. x. x. x. x.')]),
        ('0.30-0.70', [('K', 'x. .. .x .. ..'), ('S', '.. .. .. x. ..'), ('H', 'x. x. x. x. x.')]),
        ('0.50-0.90', [('K', 'x. .. x. .x ..'), ('S', '.. .. .. x. ..'), ('R', 'xx xx xx xx xx')]),
    ],
})

# 7/8 (7 steps). 3+2+2: snare on the starts of the two 2-groups; 2+2+3: on beats 2 and 3.
ROCK += blocks('classic', '7/8', {
    'verse': [
        ('0.20-0.60', [('K', 'x.. .. .x'), ('S', '... x. x.'), ('H', 'xxx xx xx')]),
        ('0.40-0.80', [('K', 'x.. .x ..'), ('S', '... x. x.'), ('H', 'x.x x. x.')]),
        ('0.60-1.00', [('K', 'x.. .. .x'), ('S', '... x. x.'), ('H', 'xxx xx xx'), ('C@0.7', 'X.. .. ..'),
                       ('S@0.8', '.g. .. .g')]),
    ],
    'chorus': [
        ('0.40-0.80', [('K', 'x.. .. .x'), ('S', '... x. x.'), ('R', 'xxx xx xx'), ('C', 'X.. .. ..')]),
        ('0.60-1.00', [('K', 'x.x .. .x'), ('S', '... x. x.'), ('R', 'xxx xx xx'), ('C', 'X.. .. ..')]),
        ('0.75-1.00', [('K', 'x.. .x .x'), ('S', '... x. x.'), ('R', 'xxx xx xx'), ('C', 'X.. .. ..'),
                       ('S@0.9', '.g. .. .g')]),
    ],
    'bridge': [
        ('0.10-0.50', [('K', 'x.. .. ..'), ('S', '... x. ..'), ('R', 'x.x x. x.')]),
        ('0.30-0.70', [('K', 'x.. .. .x'), ('S', '... x. x.'), ('H', 'x.x x. x.')]),
        ('0.50-0.90', [('K', 'x.x .. .x'), ('S', '... x. x.'), ('R', 'xxx xx xx')]),
    ],
})

ROCK += blocks('classic', '9/8', {
    'verse': [
        ('0.20-0.60', [('K', 'x.. ... ..x'), ('S', '... x.. x..'), ('H', 'x.x x.x x.x')]),
        ('0.40-0.80', [('K', 'x.. ..x ..x'), ('S', '... x.. x..'), ('H', 'xxx xxx xxx')]),
        ('0.60-1.00', [('K', 'x.. .x. ..x'), ('S', '... x.. x..'), ('H', 'xxx xxx xxx'), ('S@0.8', '..g ..g ..g')]),
    ],
    'chorus': [
        ('0.40-0.80', [('K', 'x.. ..x ..x'), ('S', '... x.. x..'), ('R', 'xxx xxx xxx'), ('C', 'X.. ... ...')]),
        ('0.60-1.00', [('K', 'x.. .x. ..x'), ('S', '... x.. x..'), ('R', 'xxx xxx xxx'), ('C', 'X.. ... ...'),
                       ('S@0.8', '..g ..g ..g')]),
        ('0.75-1.00', [('K', 'x.x ..x .xx'), ('S', '... x.. x..'), ('R', 'xxx xxx xxx'), ('C', 'X.. ... ...')]),
    ],
    'bridge': [
        ('0.10-0.50', [('K', 'x.. ... ...'), ('S', '... ... x..'), ('R', 'x.x x.x x.x')]),
        ('0.30-0.70', [('K', 'x.. ... ..x'), ('S', '... x.. x..'), ('H', 'x.x x.x x.x')]),
        ('0.50-0.90', [('K', 'x.. ..x ..x'), ('S', '... x.. x..'), ('R', 'xxx xxx xxx')]),
    ],
})

# 11/8 as 3+3+3+2, 13/8 as 3+3+3+2+2.
ROCK += blocks('classic', '11/8', {
    'verse': [
        ('0.20-0.60', [('K', 'x.. ... x.. ..'), ('S', '... x.. ... x.'), ('H', 'x.x x.x x.x x.')]),
        ('0.40-0.80', [('K', 'x.. ..x ..x ..'), ('S', '... x.. ... x.'), ('H', 'xxx xxx xxx xx')]),
        ('0.60-1.00', [('K', 'x.. ..x ..x ..'), ('S', '... x.. x.. x.'), ('R', 'xxx xxx xxx xx'), ('C', 'X.. ... ... ..')]),
    ],
    'chorus': [
        ('0.40-0.80', [('K', 'x.. ..x ..x ..'), ('S', '... x.. x.. x.'), ('R', 'xxx xxx xxx xx'), ('C', 'X.. ... ... ..')]),
        ('0.60-1.00', [('K', 'x.x ..x .xx ..'), ('S', '... x.. x.. x.'), ('R', 'xxx xxx xxx xx'), ('C', 'X.. ... ... ..')]),
        ('0.75-1.00', [('K', 'xxx ..x .xx ..'), ('S', '... x.. x.. x.'), ('R', 'xxx xxx xxx xx'), ('C', 'X.. ... ... ..')]),
    ],
    'bridge': [
        ('0.10-0.50', [('K', 'x.. ... ... ..'), ('S', '... ... ... x.'), ('R', 'x.x x.x x.x x.')]),
        ('0.30-0.70', [('K', 'x.. ... x.. ..'), ('S', '... x.. ... x.'), ('H', 'xxx xxx xxx xx')]),
        ('0.50-0.90', [('K', 'x.. ..x ..x ..'), ('S', '... x.. ... x.'), ('R', 'xxx xxx xxx xx')]),
    ],
})
ROCK += blocks('classic', '13/8', {
    'verse': [
        ('0.20-0.60', [('K', 'x.. ... x.. .. ..'), ('S', '... x.. ... x. x.'), ('H', 'x.x x.x x.x x. x.')]),
        ('0.40-0.80', [('K', 'x.. ..x ..x .. ..'), ('S', '... x.. ... x. x.'), ('H', 'xxx xxx xxx xx xx')]),
        ('0.60-1.00', [('K', 'x.. ..x ..x .. .x'), ('S', '... x.. x.. x. x.'), ('R', 'xxx xxx xxx xx xx'),
                       ('C', 'X.. ... ... .. ..')]),
    ],
    'chorus': [
        ('0.40-0.80', [('K', 'x.. ..x ..x .. ..'), ('S', '... x.. x.. x. x.'), ('R', 'xxx xxx xxx xx xx'),
                       ('C', 'X.. ... ... .. ..')]),
        ('0.60-1.00', [('K', 'x.x ..x .xx .. .x'), ('S', '... x.. x.. x. x.'), ('R', 'xxx xxx xxx xx xx'),
                       ('C', 'X.. ... ... .. ..')]),
        ('0.75-1.00', [('K', 'xxx ..x .xx .. .x'), ('S', '... x.. x.. x. x.'), ('R', 'xxx xxx xxx xx xx'),
                       ('C', 'X.. ... ... .. ..')]),
    ],
    'bridge': [
        ('0.10-0.50', [('K', 'x.. ... ... .. ..'), ('S', '... ... ... x. ..'), ('R', 'x.x x.x x.x x. x.')]),
        ('0.30-0.70', [('K', 'x.. ... x.. .. ..'), ('S', '... x.. ... x. x.'), ('H', 'xxx xxx xxx xx xx')]),
        ('0.50-0.90', [('K', 'x.. ..x ..x .. ..'), ('S', '... x.. ... x. x.'), ('R', 'xxx xxx xxx xx xx')]),
    ],
})

# --------------------------------------------------------------------- jazz
# Jazz counts in triplets: 3 steps per quarter. Ride "ding, ding-a, ding-a".
JAZZ = []
JAZZ += blocks('swing', '3/4', {
    'verse': [
        ('0.20-0.60', [('R', 'x.. x.x x.x'), ('HP', '... x.. x..'), ('K', 'x.. ... ...'), ('S', '... ... ..x')]),
        ('0.40-0.80', [('R', 'x.. x.x x.x'), ('HP', '... x.. x..'), ('K', 'x.. ... x..'), ('S', '... ..x ...')]),
        ('0.60-1.00', [('R', 'x.. x.x x.x'), ('HP', '... x.. x..'), ('K', 'x.. ... ..x'), ('S', '... ..x .x.')]),
    ],
    'chorus': [
        ('0.40-0.80', [('R', 'x.. x.x x.x'), ('HP', '... x.. x..'), ('K', 'x.. ... ...'), ('S', '... ..x x..')]),
        ('0.60-1.00', [('R', 'x.. x.x x.x'), ('HP', '... x.. x..'), ('K', 'x.. ..x ...'), ('S', '... ... x.x')]),
    ],
})
JAZZ += blocks('swing', '5/4', {
    'verse': [
        ('0.20-0.60', [('R', 'x.. x.x x.x x.. x.x'), ('HP', '... x.. ... x.. ...'),
                       ('K', 'x.. ... ... ... ...'), ('SS', '... ... ... x.. ...')]),
        ('0.40-0.80', [('R', 'x.. x.x x.x x.. x.x'), ('HP', '... x.. ... x.. ...'),
                       ('K', 'x.. ... ..x ... ...'), ('S', '... ... ... ..x ...')]),
        ('0.60-1.00', [('R', 'x.. x.x x.x x.. x.x'), ('HP', '... x.. ... x.. ...'),
                       ('K', 'x.. ... ... ..x ...'), ('S', '... ..x ... ... .x.')]),
    ],
    'chorus': [
        ('0.40-0.80', [('R', 'x.. x.x x.x x.. x.x'), ('HP', '... x.. ... x.. ...'),
                       ('K', 'x.. ... ..x ... ...'), ('SS', '... ... x.. ... x..')]),
    ],
})
JAZZ += blocks('swing', '7/8', {
    'verse': [
        ('0.20-0.70', [('R', 'xx xx xxx'), ('HP', '.x .. .x.'), ('K', 'x. .. ...'), ('S', '.. .x ..x')]),
        ('0.40-0.90', [('R', 'xx xx xxx'), ('HP', '.x .. .x.'), ('K', 'x. .. ..x'), ('S', '.. .x ...')]),
    ],
})

# --------------------------------------------------------------------- funk
FUNK = []
FUNK += blocks('classic', '7/8', {
    'verse': [
        ('0.20-0.60', [('K', 'x.x .. .x'), ('S', '... x. x.'), ('H', 'xxx xx xx')]),
        ('0.40-0.80', [('K', 'x.x .. .x'), ('S', '... x. x.'), ('H', 'xxx xx xx'), ('S@0.7', '.g. .g ..')]),
        ('0.60-1.00', [('K', 'x. .x ..x'), ('S', '.. x. x..'), ('H', 'xx xx xxx'), ('S@0.6', '.g .. .g.')]),
    ],
})
FUNK += blocks('classic', '5/4', {
    'verse': [
        ('0.20-0.60', [('K', 'x. .. .x .. x.'), ('S', '.. .. .. x. ..'), ('H', 'x. x. x. x. x.')]),
        ('0.40-0.80', [('K', 'x. .x .. .x x.'), ('S', '.. .. .. x. ..'), ('H', 'xx xx xx xx xx'),
                       ('S@0.6', '.. g. .g .. .g')]),
        ('0.60-1.00', [('K', 'x. .. .x .. .x'), ('S', '.. .. x. .. x.'), ('H', 'xx xx xx xx xx'),
                       ('S@0.6', '.g .. .. g. ..')]),
    ],
})
FUNK += blocks('classic', '3/4', {
    'verse': [
        ('0.20-0.60', [('K', 'x. .. .x'), ('S', '.. x. ..'), ('H', 'xx xx xx')]),
        ('0.40-0.80', [('K', 'x. .x .x'), ('S', '.. x. x.'), ('H', 'xx xx xx'), ('S@0.6', '.g .. g.')]),
        ('0.60-1.00', [('K', 'xx .x .x'), ('S', '.. x. x.'), ('H', 'xx xx xx'), ('S@0.6', '.g .g g.')]),
    ],
})

# -------------------------------------------------------------------- metal
# Kick under the snare is the sound of metal, so it is allowed here.
METAL = []
METAL += blocks('heavy', '7/8', {
    'verse': [
        ('0.20-0.60', [('K', 'x.x .x .x'), ('S', '... x. x.'), ('H', 'x.x x. x.'), ('C', 'X.. .. ..')]),
        ('0.40-0.80', [('K', 'x.x xx xx'), ('S', '... x. x.'), ('H', 'x.x x. x.'), ('C', 'X.. .. ..')]),
    ],
    'chorus': [
        ('0.40-1.00', [('K', 'xxx xx xx'), ('S', '... x. x.'), ('R', 'xxx xx xx'), ('C', 'X.. .. ..')]),
    ],
})
METAL += blocks('heavy', '5/4', {
    'verse': [
        ('0.20-0.80', [('K', 'x. .x x. x. ..'), ('S', '.. .. .. x. ..'), ('H', 'x. x. x. x. x.'),
                       ('C', 'X. .. .. .. ..')]),
    ],
})
METAL += blocks('doom', '3/4', {
    'verse': [
        ('0.10-0.60', [('K', 'x. .. ..'), ('S', '.. .. x.'), ('R', 'x. x. x.'), ('C@0.5', 'X. .. ..')]),
    ],
})

# --------------------------------------------------------------- electronic
ELECTRONIC = []
ELECTRONIC += blocks('house', '7/8', {
    'verse': [
        ('0.20-0.80', [('K', 'x.. .x .x'), ('S', '... x. x.'), ('H', 'xxx xx xx')]),
    ],
})
ELECTRONIC += blocks('techno', '5/4', {
    'verse': [
        ('0.20-0.80', [('K', 'x. x. x. x. x.'), ('RS', '.. .. .. x. ..'), ('H', '.x .x .x .x .x')]),
    ],
})

FILES = {'rock': ROCK, 'jazz': JAZZ, 'funk': FUNK, 'metal': METAL, 'electronic': ELECTRONIC}


def main():
    for genre, blks in FILES.items():
        path = os.path.join(GROOVES, genre + '.tab')
        text = open(path, encoding='utf-8-sig').read().replace('\r\n', '\n')
        if MARK in text:
            text = text[:text.index(MARK)].rstrip('\n') + '\n'
        text += '\n' + MARK + '\n'
        text += '# The step counts divide the bar: 7/8 takes 7, 14, 21 ... steps; spaces are only for reading.\n'
        text += '# Jazz /4 meters count triplets (3 steps per quarter), the others eighths.\n\n'
        text += '\n'.join(blks)
        with open(path, 'w', encoding='utf-8', newline='\r\n') as f:
            f.write(text)
        print('%s.tab: %d meter grooves' % (genre, len(blks)))


if __name__ == '__main__':
    main()
