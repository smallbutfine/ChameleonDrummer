unit ConfigConstants;

{$mode objfpc}{$H+}

interface

// ============================================================================
// VELOCITY â€” All drum velocity constants (no magic numbers)
// ============================================================================
type
  TVelocity = record class
  const
    // Kick velocities
    KICK_LIGHT      = 95;
    KICK_NORMAL     = 100;
    KICK_HEAVY      = 120;
    KICK_ACCENT     = 127;

    // Snare velocities
    SNARE_GHOST     = 40;
    SNARE_LIGHT     = 72;
    SNARE_NORMAL    = 85;
    SNARE_HEAVY     = 115;
    SNARE_RIMSHOT   = 118;
    SNARE_ACCENT    = 127;

    // Hi-hat velocities
    HIHAT_LIGHT     = 60;
    HIHAT_NORMAL    = 80;
    HIHAT_ACCENT    = 100;
    HIHAT_OPEN      = 100;
    HIHAT_PEDAL     = 70;

    // Ride velocities
    RIDE_LIGHT      = 70;
    RIDE_NORMAL     = 90;
    RIDE_ACCENT     = 105;

    // Crash velocities
    CRASH_LIGHT     = 100;
    CRASH_NORMAL    = 110;
    CRASH_ACCENT    = 120;
    CRASH_HEAVY     = 127;

    // Tom velocities
    TOM_NORMAL      = 100;
    TOM_HEAVY       = 115;
  end;

// ============================================================================
// TIMING â€” Beat position and duration constants
// ============================================================================
type
  TTiming = record class
  const
    // Note durations
    WHOLE           = 4.0;
    HALF            = 2.0;
    QUARTER         = 1.0;
    EIGHTH          = 0.5;
    SIXTEENTH       = 0.25;
    THIRTY_SECOND   = 0.125;

    // Triplet values
    EIGHTH_TRIPLET  = 0.3333;
    SIXTEENTH_TRIPLET = 0.1667;

    // Beat positions
    BEAT_0          = 0.0;
    BEAT_1          = 1.0;
    BEAT_2          = 2.0;
    BEAT_3          = 3.0;

    // Micro-timing (in beats)
    MICRO_EARLY     = -0.015;
    MICRO_LATE      = 0.015;
  end;

// ============================================================================
// DEFAULTS â€” Default parameters for generation
// ============================================================================
type
  TDefaults = record class
  const
    // Default tempo per genre
    TEMPO_METAL     = 155;
    TEMPO_ROCK      = 110;
    TEMPO_JAZZ      = 120;
    TEMPO_FUNK      = 100;
    TEMPO_ELECTRONIC = 128;

    // Default complexity ranges per genre
    COMPLEXITY_METAL_LOW      = 0.3;
    COMPLEXITY_METAL_HIGH     = 0.9;
    COMPLEXITY_ROCK_LOW       = 0.2;
    COMPLEXITY_ROCK_HIGH      = 0.8;
    COMPLEXITY_JAZZ_LOW       = 0.4;
    COMPLEXITY_JAZZ_HIGH      = 0.9;
    COMPLEXITY_FUNK_LOW       = 0.3;
    COMPLEXITY_FUNK_HIGH      = 0.8;

    // Default humanization
    HUMANIZATION_DEFAULT  = 0.3;
    HUMANIZATION_LIGHT    = 0.15;
    HUMANIZATION_HEAVY    = 0.45;

    // Song structure defaults
    DEFAULT_BARS_PER_SECTION = 8;
    MIN_BARS                   = 4;
    MAX_BARS                   = 64;

    // Pattern defaults
    PATTERN_BARS_DEFAULT      = 2;
    PATTERN_VARIATIONS_MIN    = 4;
    PATTERN_VARIATIONS_MAX    = 16;

    // MIDI export defaults
    MIDI_RESOLUTION          = 480;     // ticks per quarter note
    MIDI_FORMAT              = 0;       // Format 0 (single track)
    CHANNEL_DRUM             = 10;      // MIDI channel 10 (drums)
  end;

// ============================================================================
// GENRE_DEFAULT_BPM â€” Genre-specific default tempos from published tempo data
// ============================================================================
type
  TGenreBPM = record class
  const
    // Metal styles with realistic default tempos
    METAL_HEAVY        = 130;
    METAL_DEATH        = 220;
    METAL_POWER        = 160;
    METAL_PROGRESSIVE  = 140;
    METALTHRASH        = 180;
    METAL_DOOM         = 75;
    METAL_BREAKDOWN    = 90;

    // Rock styles
    ROCK_CLASSIC       = 110;
    ROCK_BLUES         = 95;
    ROCK_ALTERNATIVE   = 120;
    ROCK_PROGRESSIVE   = 130;
    ROCK_PUNK          = 180;
    ROCK_HARD          = 115;
    ROCK_POP           = 120;

    // Jazz styles
    JAZZ_SWING         = 140;
    JAZZ_BEBOP         = 200;
    JAZZ_FUSION        = 160;
    JAZZ_LATIN         = 130;
    JAZZ_BALLAD        = 70;
    JAZZ_HARD_BOP      = 180;
    JAZZ_CONTEMPORARY  = 120;

    // Funk styles
    FUNK_CLASSIC       = 105;
    FUNK_PFUNK         = 110;
    FUNK_SHUFFLE       = 90;
    FUNK_NEW_ORLEANS   = 100;
    FUNK_FUSION        = 120;
    FUNK_MINIMAL       = 95;
    FUNK_HEAVY         = 100;

    // Electronic styles
    ELECTRONIC_HOUSE       = 128;
    ELECTRONIC_TECHNO      = 135;
    ELECTRONIC_DRUM_AND_BASS = 174;
    ELECTRONIC_DUBSTEP     = 140;
  end;

// ============================================================================
// GENRE_ARCHETYPES â€” Default song structures per genre (sections with bar counts)
// ============================================================================
type
  TSectionDef = record
    Name: String;
    Bars: Integer;
  end;

type
  TGenreArchetype = record class
  const
    // Metal structure
    METAL_SECTIONS_COUNT = 8;
    METAL_SECTIONS: array[0..7] of TSectionDef = (
      (Name: 'intro';     Bars: 8),
      (Name: 'verse';     Bars: 8),
      (Name: 'chorus';    Bars: 8),
      (Name: 'verse';     Bars: 8),
      (Name: 'breakdown'; Bars: 8),
      (Name: 'chorus';    Bars: 8),
      (Name: 'bridge';    Bars: 4),
      (Name: 'solo';      Bars: 8)
    );

    // Rock structure
    ROCK_SECTIONS_COUNT = 8;
    ROCK_SECTIONS: array[0..7] of TSectionDef = (
      (Name: 'intro';   Bars: 4),
      (Name: 'verse';   Bars: 8),
      (Name: 'chorus';  Bars: 8),
      (Name: 'verse';   Bars: 8),
      (Name: 'chorus';  Bars: 8),
      (Name: 'bridge';  Bars: 4),
      (Name: 'solo';    Bars: 8),
      (Name: 'outro';   Bars: 4)
    );

    // Jazz structure
    JAZZ_SECTIONS_COUNT = 6;
    JAZZ_SECTIONS: array[0..5] of TSectionDef = (
      (Name: 'intro';    Bars: 8),
      (Name: 'verse';    Bars: 16),
      (Name: 'chorus';   Bars: 16),
      (Name: 'bridge';   Bars: 8),
      (Name: 'chorus';   Bars: 16),
      (Name: 'outro';    Bars: 8)
    );

    // Funk structure
    FUNK_SECTIONS_COUNT = 7;
    FUNK_SECTIONS: array[0..6] of TSectionDef = (
      (Name: 'intro';     Bars: 4),
      (Name: 'verse';     Bars: 8),
      (Name: 'chorus';    Bars: 8),
      (Name: 'verse';     Bars: 8),
      (Name: 'breakdown'; Bars: 8),
      (Name: 'bridge';    Bars: 4),
      (Name: 'outro';     Bars: 8)
    );

    // Electronic structure
    ELECTRONIC_SECTIONS_COUNT = 6;
    ELECTRONIC_SECTIONS: array[0..5] of TSectionDef = (
      (Name: 'intro';     Bars: 8),
      (Name: 'verse';     Bars: 16),
      (Name: 'chorus';    Bars: 16),
      (Name: 'breakdown'; Bars: 8),
      (Name: 'chorus';    Bars: 16),
      (Name: 'outro';     Bars: 8)
    );
  end;

// ============================================================================
// DRUMMER_FILLS â€” Default fill counts per drummer
// ============================================================================
type
  TDrummerFillCount = record class
  const
    BONHAM      = 8;
    PORCARO     = 8;
    WECKL       = 8;
    CHAMBERS    = 8;
    ROEDER      = 8;
    DEE         = 8;
    HOGLAN      = 8;
    PEART       = 6;
    RICH        = 8;
    CAREY       = 8;
    COPELAND    = 8;
    SMITH       = 8;
    HAAKE       = 8;
    HALPERN     = 8;
    MOON        = 6;
    WATTS       = 7;
  end;

// ============================================================================
// GROVE_RESTRAINTS â€” Genre-specific rhythmic constraints
// ============================================================================
type
  TGrooveRestraints = record class
  const
    // Metal: double bass density range
    METAL_MIN_DOUBLE_BASS   = 0.4;
    METAL_MAX_DOUBLE_BASS   = 0.9;

    // Rock: cymbal emphasis
    ROCK_CYMBAL_WEIGHT      = 0.6;

    // Jazz: ride pattern preference
    JAZZ_RIDE_PREFERENCE    = 0.8;

    // Funk: ghost note density
    FUNK_GHOST_DENSITY      = 0.4;

    // Electronic: kick drum prominence
    ELECTRONIC_KICK_WEIGHT  = 0.7;
  end;

// ============================================================================
// TIME_SIGNATURE_DEFAULTS â€” Default time signatures per genre
// ============================================================================
type
  TTimeSigDefaults = record class
  const
    METAL_DEFAULT_NUM   = 4;
    METAL_DEFAULT_DENOM = 4;

    ROCK_DEFAULT_NUM    = 4;
    ROCK_DEFAULT_DENOM  = 4;

    JAZZ_DEFAULT_NUM    = 4;
    JAZZ_DEFAULT_DENOM  = 4;

    FUNK_DEFAULT_NUM    = 4;
    FUNK_DEFAULT_DENOM  = 4;

    ELECTRONIC_DEFAULT_NUM   = 4;
    ELECTRONIC_DEFAULT_DENOM = 4;
  end;

end.
