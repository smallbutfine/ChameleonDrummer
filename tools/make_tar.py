"""Create a Linux .tar.gz with correct Unix permission bits.

Windows/NTFS has no executable bit, so a plain tar (bsdtar, or GNU tar without
--mode) stores every binary as 0644 and the programs will not run after
extraction on Linux. This walks the staged directory and writes the archive with
explicit modes:
  the four executables (ChameleonDrummer, chameleondrummer_gui,
  tools/midi_to_tab, tools/step_editor) -> 0755
  everything else                         -> 0644

Pure Python (tarfile) so it works the same from cmd.exe or Git Bash, with no
external tar/gzip/cp/rm and no /tmp or C:/ path quirks.

Usage: python tools/make_tar.py <staged_dir> <out.tar.gz>
"""

import os
import sys
import tarfile

EXEC_NAMES = {"ChameleonDrummer", "chameleondrummer_gui", "midi_to_tab", "step_editor"}


def is_executable(arc_path: str) -> bool:
    name = arc_path.replace("\\", "/").rsplit("/", 1)[-1]
    return name in EXEC_NAMES


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__.strip())
        return 2
    src, out = sys.argv[1], sys.argv[2]
    if not os.path.isdir(src):
        print(f"error: not a directory: {src}")
        return 1

    # Archive paths are relative to the staged dir's PARENT, so extracting
    # produces "<staged>/..." (matching the previous tar behaviour).
    src = os.path.abspath(src)
    base = os.path.dirname(src)

    # Create the output directory (Deploy/) if it does not exist yet.
    out = os.path.abspath(out)
    os.makedirs(os.path.dirname(out), exist_ok=True)

    entries = []
    for root, dirs, files in os.walk(src):
        dirs.sort()
        for name in sorted(files):
            entries.append(os.path.join(root, name))

    with tarfile.open(out, "w:gz") as t:
        for full in entries:
            arc = os.path.relpath(full, base).replace("\\", "/")
            info = tarfile.TarInfo(arc)
            info.size = os.path.getsize(full)
            info.mode = 0o755 if is_executable(arc) else 0o644
            info.uid = info.gid = 0
            info.uname = info.gname = ""
            with open(full, "rb") as fh:
                t.addfile(info, fh)

    print(f"  OK: {out} ({len(entries)} files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())