#!/usr/bin/env python3
"""Download a MIDI file and convert it to ChameleonDrummer .tab format.

Usage:
    python tools/download_and_convert.py <midi_url_or_path> <output.tab> [--fill] [--name NAME] [--energy 0.5] [--style STYLE] [--kind KIND] [--intensity 0.2-0.6] [--meter 4/4] [--resolution 16]

If the first argument is a URL (http/https), it is downloaded first.
Otherwise it is treated as a local file path.

Output is written CRLF to match the repo convention.
"""
import os
import sys
import urllib.request

# Import the converter from the same directory
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from midi_to_tab import main as midi_main


def download(url, dest):
    """Download url to dest, returning dest path."""
    print('Downloading %s -> %s' % (url, dest))
    urllib.request.urlretrieve(url, dest)
    print('Download complete.')
    return dest


def main():
    args = sys.argv[1:]
    if not args or args[0] in ('-h', '--help', '-?'):
        print(__doc__)
        sys.exit(0)

    src = args[0]
    rest = args[1:]

    # If it's a URL, download to a temp file first
    if src.startswith('http://') or src.startswith('https://'):
        tmp = os.path.join(os.getcwd(), '_downloaded.mid')
        try:
            src = download(src, tmp)
        except Exception as e:
            print('Error downloading %s: %s' % (src, e))
            sys.exit(1)

    # Rebuild argv for midi_to_tab.main: [input, output, ...flags]
    new_argv = [src] + rest
    sys.argv = ['midi_to_tab.py'] + new_argv
    midi_main()


if __name__ == '__main__':
    main()
