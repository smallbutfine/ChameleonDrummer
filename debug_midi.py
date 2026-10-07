#!/usr/bin/env python3
"""Parse MIDI file showing EVERY event with proper delta parsing."""
import struct, sys

def parse_midi(path):
    with open(path, 'rb') as f:
        data = f.read()
    
    print(f"File size: {len(data)} bytes")
    mthd_len = struct.unpack('>I', data[4:8])[0]
    fmt = struct.unpack('>H', data[8:10])[0]
    ntracks = struct.unpack('>H', data[10:12])[0]
    tpq = struct.unpack('>H', data[12:14])[0]
    print(f"MThd: len={mthd_len} fmt={fmt} tracks={ntracks} tpq={tpq}")
    
    mtrk_off = 14
    mtrk_len_file = struct.unpack('>I', data[18:22])[0]
    mtrk_actual = len(data) - mtrk_off - 8
    print(f"MTrk declared: {mtrk_len_file} actual_remaining: {mtrk_actual}")
    
    track = data[mtrk_off+8 : mtrk_off+8 + min(mtrk_len_file, mtrk_actual)]
    print(f"Track length used: {len(track)} bytes\n")
    
    pos = 0
    abs_tick = 0
    note_on_count = 0
    note_off_count = 0
    tick_values = []
    
    while pos < len(track):
        # Read VLQ delta time
        delta = 0
        for _ in range(4):
            b = track[pos]
            pos += 1
            if b & 0x80 == 0:
                break
            delta = (delta << 7) | (b & 0x7F)
        
        abs_tick += delta
        
        status = track[pos]; pos += 1
        
        if status == 0xFF:  # Meta event
            mt = track[pos]; pos += 1
            ml = 0
            for _ in range(4):
                b = track[pos]; pos += 1; ml = (ml << 7) | (b & 0x7F)
                if b & 0x80 == 0: break
            
            if mt == 0x2F:
                print(f"  [{abs_tick}] END_TRACK")
                print(f"\nTotal events parsed: {note_on_count + note_off_count}")
                print(f"Note-on count: {note_on_count}")
                print(f"Note-off count: {note_off_count}")
                print(f"Abs tick range: {min(tick_values) if tick_values else 0} - {max(tick_values)}")
                print(f"Durations (tick differences between note-ons): {[(tick_values[i+1]-tick_values[i]) for i in range(min(10, len(tick_values)-1))]}")
                break
            elif mt == 0x51:
                us = int.from_bytes(track[pos-3:pos], 'big')
                bpm = 60000000 / us
                print(f"  [{abs_tick}] Tempo {bpm:.0f} BPM")
            else:
                print(f"  [{abs_tick}] Meta #{mt} len={ml}")
        
        elif status == 0x99:  # Note on ch 10
            note = track[pos]; vel = track[pos+1]; pos += 2
            note_on_count += 1
            tick_values.append(abs_tick)
            if note_on_count <= 5:
                print(f"  [{abs_tick}] NOTE-ON ch10 note={note} vel={vel}")
        
        elif status == 0x89:  # Note off ch 10
            note = track[pos]; vel = track[pos+1]; pos += 2
            note_off_count += 1
        
        elif status in (0xB0, 0xE0):
            ml = 0
            for _ in range(4):
                b = track[pos]; pos += 1; ml = (ml << 7) | (b & 0x7F)
                if b & 0x80 == 0: break
            pos += ml
        
        else:
            high = status >> 4
            if high in (0x8, 0x9, 0xB):
                pos += 2
            elif high in (0xC, 0xD):
                pos += 1
            # Running status for note-on/off with different velocity: skip extra byte
        
        if abs_tick > 0 and len(tick_values) == 0:
            print(f"  [{abs_tick}] status={status:02X}")

if __name__ == '__main__':
    path = sys.argv[1] if len(sys.argv) > 1 else 'C:/temp/test2.mid'
    parse_midi(path)
