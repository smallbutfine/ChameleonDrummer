#!/usr/bin/env python3
"""Convert licensed Groove MIDI Dataset performances to bar-bounded JSON phrases."""

import argparse
import csv
import json
import math
import os
import struct
import sys


GMD_SOURCE_URL = "https://magenta.tensorflow.org/datasets/groove"
GMD_LICENSE_URL = "https://creativecommons.org/licenses/by/4.0/"
GMD_ARCHIVE_SHA256 = "651cbc524ffb891be1a3e46d89dc82a1cecb09a57c748c7b45b844c4841dcc1e"
OUTPUT_PPQ = 960
BEAT_PHRASE_BARS = 4


def read_vlq(data, offset):
    value = 0
    for _ in range(4):
        if offset >= len(data):
            raise ValueError("truncated MIDI variable-length quantity")
        byte = data[offset]
        offset += 1
        value = (value << 7) | (byte & 0x7F)
        if byte < 0x80:
            return value, offset
    raise ValueError("MIDI variable-length quantity exceeds four bytes")


def parse_midi(path):
    with open(path, "rb") as midi_file:
        data = midi_file.read()

    if data[:4] != b"MThd" or len(data) < 14:
        raise ValueError("invalid Standard MIDI File header: " + path)
    header_length = struct.unpack_from(">I", data, 4)[0]
    if header_length < 6 or 8 + header_length > len(data):
        raise ValueError("invalid Standard MIDI File header length: " + path)
    _, track_count, division = struct.unpack_from(">HHH", data, 8)
    if division == 0 or division & 0x8000:
        raise ValueError("unsupported MIDI time division: " + path)

    offset = 8 + header_length
    notes = []
    for _ in range(track_count):
        if data[offset : offset + 4] != b"MTrk" or offset + 8 > len(data):
            raise ValueError("invalid MIDI track header: " + path)
        track_length = struct.unpack_from(">I", data, offset + 4)[0]
        offset += 8
        track_end = offset + track_length
        if track_end > len(data):
            raise ValueError("truncated MIDI track: " + path)

        tick = 0
        running_status = 0
        while offset < track_end:
            delta, offset = read_vlq(data, offset)
            tick += delta
            status = data[offset]
            offset += 1
            if status < 0x80:
                if not running_status:
                    raise ValueError("MIDI running status without prior status: " + path)
                offset -= 1
                status = running_status
            elif status < 0xF0:
                running_status = status

            if status == 0xFF:
                if offset >= track_end:
                    raise ValueError("truncated MIDI meta event: " + path)
                offset += 1
                length, offset = read_vlq(data, offset)
                offset += length
            elif status in (0xF0, 0xF7):
                length, offset = read_vlq(data, offset)
                offset += length
            else:
                command = status & 0xF0
                channel = status & 0x0F
                if command in (0x80, 0x90, 0xA0, 0xB0, 0xE0):
                    if offset + 2 > track_end:
                        raise ValueError("truncated MIDI channel event: " + path)
                    data1, data2 = data[offset], data[offset + 1]
                    offset += 2
                    if command == 0x90 and channel == 9 and data2 > 0:
                        notes.append((tick, data1, data2))
                elif command in (0xC0, 0xD0):
                    offset += 1
                else:
                    raise ValueError("unsupported MIDI event status: " + hex(status))

            if offset > track_end:
                raise ValueError("MIDI event extends past its track: " + path)
        offset = track_end

    return division, notes


def build_phrases(gmd_root):
    info_path = os.path.join(gmd_root, "info.csv")
    license_path = os.path.join(gmd_root, "LICENSE")
    with open(license_path, "r", encoding="utf-8") as license_file:
        license_text = license_file.read()
    if "creativecommons.org/licenses/by/4.0" not in license_text.lower():
        raise ValueError("input dataset does not declare CC BY 4.0")

    phrases = []
    with open(info_path, newline="", encoding="utf-8") as info_file:
        rows = csv.DictReader(info_file)
        required_columns = {
            "drummer", "session", "id", "style", "bpm", "beat_type",
            "time_signature", "midi_filename", "duration", "split",
        }
        if not required_columns.issubset(set(rows.fieldnames or [])):
            raise ValueError("GMD info.csv is missing required metadata columns")

        for row in rows:
            midi_path = os.path.join(gmd_root, row["midi_filename"])
            division, notes = parse_midi(midi_path)
            if not notes:
                continue

            numerator_text, denominator_text = row["time_signature"].split("-", 1)
            numerator = int(numerator_text)
            denominator = int(denominator_text)
            bpm = int(row["bpm"])
            bar_quarters = numerator * 4.0 / denominator
            duration_bars = (
                float(row["duration"]) * bpm / 60.0 / bar_quarters
            )
            note_end_bars = max(note[0] for note in notes) / division / bar_quarters
            total_bars = max(duration_bars, note_end_bars)

            if row["beat_type"] == "fill":
                phrase_bars = max(1, min(2, int(math.ceil(total_bars))))
                starts = [0]
            else:
                phrase_bars = max(1, min(BEAT_PHRASE_BARS, int(math.floor(total_bars))))
                last_start = max(0, int(math.floor(total_bars - phrase_bars)))
                center_start = (last_start // phrase_bars) * phrase_bars
                starts = [center_start]

            for start_bar in starts:
                actual_bars = min(phrase_bars, int(math.ceil(total_bars - start_bar)))
                if actual_bars <= 0:
                    continue
                start_tick = start_bar * bar_quarters * division
                end_tick = (start_bar + actual_bars) * bar_quarters * division
                phrase_notes = [
                    [
                        round((tick - start_tick) * OUTPUT_PPQ / division),
                        pitch,
                        velocity,
                    ]
                    for tick, pitch, velocity in notes
                    if start_tick <= tick < end_tick
                ]
                if not phrase_notes:
                    continue

                phrases.append(
                    {
                        "id": row["id"] + "/bar-" + str(start_bar),
                        "source_id": row["id"],
                        "source_midi": row["midi_filename"],
                        "source_drummer": row["drummer"],
                        "source_split": row["split"],
                        "style": row["style"],
                        "type": row["beat_type"],
                        "bpm": bpm,
                        "time_signature": [numerator, denominator],
                        "bars": actual_bars,
                        "ppq": OUTPUT_PPQ,
                        "notes": phrase_notes,
                    }
                )

    return {
        "source": "Groove MIDI Dataset (GMD) v1.0.0",
        "source_url": GMD_SOURCE_URL,
        "source_archive_sha256": GMD_ARCHIVE_SHA256,
        "license": "CC BY 4.0",
        "license_url": GMD_LICENSE_URL,
        "transformation": (
            "Extracted bar-bounded performance phrases; converted event positions "
            "to 960 ticks per quarter note; retained source pitch and velocity."
        ),
        "ppq": OUTPUT_PPQ,
        "patterns": phrases,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--gmd-root", required=True, help="Extracted GMD directory containing info.csv and LICENSE")
    parser.add_argument("--output", required=True, help="Output JSON path")
    args = parser.parse_args()

    corpus = build_phrases(args.gmd_root)
    output_dir = os.path.dirname(os.path.abspath(args.output))
    os.makedirs(output_dir, exist_ok=True)
    with open(args.output, "w", encoding="utf-8", newline="\n") as output_file:
        json.dump(corpus, output_file, separators=(",", ":"), ensure_ascii=True)
        output_file.write("\n")
    print("Wrote {} GMD phrases to {}".format(len(corpus["patterns"]), args.output))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, csv.Error) as error:
        print("GMD import failed: {}".format(error), file=sys.stderr)
        sys.exit(1)
