# ChameleonDrummer GUI

A Lazarus/LCL front end for the Engine V2 generator. It links the engine
units in `../src` directly, so it produces exactly what the command line
tool produces - it does not shell out to `ChameleonDrummer.exe`.

## Building

Either open the project in the Lazarus IDE:

```
lazarus gui\chameleondrummer_gui.lpi
```

or build it from the command line:

```
gui\build_gui.bat
```

which is a thin wrapper around:

```
lazbuild --build-all --build-mode=Default gui\chameleondrummer_gui.lpi
```

The executable is written to the **project root** (`..\chameleondrummer_gui.exe`),
next to `ChameleonDrummer.exe`. That is deliberate: the engine loads
`mappings\template.json`, the four keymaps and `Assets\GMD\gmd_patterns.json`
relative to the executable, so the GUI has to sit in the same directory as the
command line tool.

## What it does

| Control | Meaning |
|---|---|
| Genre / Style | the genre and its style; the style list follows the genre |
| Drummer | one of the 16 registered drummer personalities |
| Keymap | `gm`, `ad2`, `ezd3` or `xg` |
| Tempo | BPM; `0` uses the style's own default |
| Complexity | 0..1 - the density control (16th-note timekeeping, ghost notes, blast beats) |
| Humanization | 0..1 - how much timing and velocity drift the drummer adds |
| Export | MIDI only, MIDI + REAPER project, or MIDI + REAPER project + Ardour session |
| File | the base name; `<name>.mid`, `<name>.rpp` and `<name>.ardour\` are written next to it |

The log panel shows what was written, and the Ardour export reports the
session directory it created.

## Notes

- The Ardour export needs Ardour 8 or 9 on the machine, because it drives
  Ardour's own `ardour9-lua` to build the session. If it is missing, the
  export says so instead of failing silently.
- The interface is the LCL, so the project is platform independent; only
  the "open output folder" button is Windows specific.
