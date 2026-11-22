"""Create a macOS .app zip with correct Unix permission bits.

Windows/NTFS has no executable bit, so a naive zip (Compress-Archive, bsdtar)
ships the binaries as 0644 and they will not run after extraction on macOS.
This walks the bundle and writes the archive with explicit modes:
  Contents/MacOS/* and Contents/Resources/tools/*  -> 0755
  everything else                                  -> 0644

Usage: python tools/zip_app.py <bundle.app> <out.zip>
"""

import os
import sys
import zipfile


def is_executable(arc_path: str) -> bool:
    p = arc_path.replace("\\", "/")
    return ("/Contents/MacOS/" in p) or ("/Contents/Resources/tools/" in p)


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__.strip())
        return 2
    src, out = sys.argv[1], sys.argv[2]
    if not os.path.isdir(src):
        print(f"error: not a directory: {src}")
        return 1

    # Archive paths must be relative to the bundle's PARENT directory, so that
    # extracting produces "MyApp.app/..." and not "Deploy/MyApp.app/...".
    src = os.path.abspath(src)
    base = os.path.dirname(src)

    # Deterministic order so repeated builds produce comparable archives.
    entries = []
    for root, dirs, files in os.walk(src):
        dirs.sort()
        for name in sorted(files):
            entries.append(os.path.join(root, name))

    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for full in entries:
            arc = os.path.relpath(full, base).replace("\\", "/")
            info = zipfile.ZipInfo(arc)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = 3  # 3 = Unix, so the mode is honoured
            mode = 0o755 if is_executable(arc) else 0o644
            info.external_attr = mode << 16
            with open(full, "rb") as fh:
                z.writestr(info, fh.read())

    print(f"  OK: {out} ({len(entries)} files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())