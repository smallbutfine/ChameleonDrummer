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
- **Grid:** a bar has 4, 8, 12, 16, 24 or 32 steps (16 = sixteenths, 12 = triplet eighths).
  Spaces inside a bar are ignored, so group the steps by beat. Bars are separated by `|`.
  A line with fewer bars than the longest line repeats its bars.
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
(run from the project root). That overwrites your edits to the files in `config\`;
keep your own copies in the user folder.
