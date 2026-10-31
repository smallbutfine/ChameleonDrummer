# config - what you can change without recompiling

Every file is named after what it describes, so it is easy to find, copy and
extend. The engine reads these files when it starts; a mistake in one file
prints a `[Warning]` with the file and line, that file is ignored, and the
built-in version plays instead.

| Folder / file | Describes | Example |
|---|---|---|
| `grooves/<genre>.tab` | the grooves of a genre, every style, verse / chorus / bridge | `grooves/metal.tab` |
| `fills/<drummer>.tab` | the fills of one drummer | `fills/weckl.tab` |
| `defaults/<genre>.ini` | tempo per style, drummers that suit the genre | `defaults/jazz.ini` |
| `sections/<genre>.json` | the default song structure of a genre | `sections/rock.json` |
| `drummer_profiles.ini` | timing feel of each drummer | |
| `example_structure.json` | an example for `--structure` | |

Where the files are looked up, first hit wins, so your own copy never touches
the installed one:

1. the folder in the environment variable `CHAMELEON_CONFIG`, if set
2. `%APPDATA%\ChameleonDrummer\config` (Linux: `~/.config/ChameleonDrummer/config`)
3. `config` next to the program
4. `..\config` (development builds)

To change a groove: copy `config\grooves\metal.tab` to
`%APPDATA%\ChameleonDrummer\config\grooves\metal.tab` and edit that copy. A
file replaces the grooves of the styles it contains; styles it does not
mention keep the built-in grooves.

## Grooves and fills: the tab format

    # a comment
    [heavy verse intensity=0.4-0.8]       a groove: style, kind, bar intensities it suits
    K  x... ..x. x... ..x. | x... ....    one line per instrument, one block of steps per bar
    S  .... x... .... x... | .... x...
    C@0.6  X... .... .... ....            @0.6: only when the song complexity is at least 0.6

    [weckl_fill_short energy=0.3]         a fill: a name, the bar energy it suits
    S .... .... .... x.x.
    K .... .... .... .x.x

- **Instruments:** `K` kick, `S` snare, `RS` rimshot, `SS` side stick, `H` closed hi-hat,
  `HO` open hi-hat, `HP` hi-hat pedal, `R` ride, `RB` ride bell, `C` crash, `C2` second crash,
  `CH` china, `SP` splash, `T1`..`T4` toms. Which MIDI note each one plays is decided by
  your keymap (`--mapping`), not here.
- **Steps:** `.` rest, `x` hit, `X` accent, `o` soft, `g` ghost note.
- **Grid:** in 4/4 a bar has 4, 8, 12, 16, 24 or 32 steps (16 = sixteenths, 12 = triplet
  eighths). Spaces inside a bar are ignored, so group the steps by beat. Bars are separated
  by `|`. A line with fewer bars than the longest line repeats its bars.
- **Other meters:** put the meter in the header, `[classic verse 7/8 intensity=0.2-0.7]`
  (a fill: `[weckl_fill energy=0.5 7/8]`). The steps then divide that bar: a bar of N/D has
  N units (1/D notes), and 1, 2, 3, 4, 6 or 8 steps per unit. 7/8 takes 7, 14, 21, 28, 42 or
  56 steps; 3/4 takes 3, 6, 9, 12, 18 or 24; 5/4 takes 5, 10, 15, 20, 30 or 40. A wrong count
  is reported with the counts that work. Count a 7/8 bar in its groups to write it:
  `K x.. x. x.` is 3+2+2, spaces are only for reading.
- **Grooves:** kinds are `verse`, `chorus`, `bridge`. The blocks of one style and kind are
  its variants, lightest first; the composer picks one whose `intensity=` band fits the
  bar. Give your own grooves an `intensity=` (the first three variants of a style have
  standard bands without it). A new style name makes a new style of that genre; it shows
  up in `list styles` and the GUI.
- **Fills:** `energy=` is the bar intensity (0-1) the fill suits: about 0.3 for a short
  one, 0.9 for a big one. Add blocks to give a drummer more fills.
- Playable by one drummer: snare, crash and toms 1 and 3 with the right hand; hi-hat,
  ride and tom 2 with the left; kick and hi-hat pedal with the feet; at most 3 hits on one
  step. Anything else is thinned out by the playability fixer.

## Odd meters (2/4, 3/4, 5/4, 7/8, 9/8, 11/8, 13/8 ...)

`--time-sig 7/8` sets the meter of the whole song, `--segment bridge:4:96:7/8` gives one section
its own tempo and meter (`-` instead of the tempo keeps the song's). A numerator from 2 to 32
over 2, 4, 8 or 16 is accepted. In a `--structure` file: `"time_signature": [7, 8]` at the top or
in a section.

You do not need a groove or fill for every meter. The engine looks for one in this order and says
what it did:

1. a groove with that meter for the style (`[classic verse 7/8]` in `grooves/rock.tab`)
2. a groove with that meter for another style of the genre
3. a plain groove it builds itself (kick on the downbeat, snare where each beat group starts,
   hi-hat on every unit) and a `[Warning]` that names the block to add and the file it goes in

Fills work the same way: only fills with the song's meter are used (the built-in fills are 4/4),
and without any the engine plays a short tom run and prints the warning with the file to add to.
So a song in any meter always plays, and it gets better as you add grooves and fills to the files.

The beat groups the engine counts are 3+2+2 for 7/8, 3+3+3 for 9/8, 3+3+3+2 for 11/8,
3+3+3+2+2 for 13/8 and 3+2 for 5/4; 2/4, 3/4 and 4/4 count every quarter.

## defaults/<genre>.ini

    [bpm]
    default=140          a style that is not listed (e.g. one you added)
    heavy=140
    doom=70

    [drummers]
    preferred=bonham, roeder, dee      picked at random when --drummer is not given

## sections/<genre>.json

The same format as `--structure` (`name` and `bars` per section, optionally `tempo` and
`complexity`). It is the default structure when neither `--section` nor `--structure` is
given, and its total length is fitted to a radio-length song. For a song of an exact
length use `--structure`.

## Regenerating the shipped files

They were written from the built-in content and can be rewritten with
`tools/export_grooves.pas`, `tools/export_fills.py` and `tools/export_defaults.pas`
(run from the project root; the grooves with a meter in their header are kept).
`python tools/meter_audit.py` lays out every odd-meter groove per beat group and flags likely mistakes
(a snare on the one, kick and snare on one step, a wrong step count) - run it after editing them. That overwrites your edits to the files in `config\`;
keep your own copies in the user folder.
