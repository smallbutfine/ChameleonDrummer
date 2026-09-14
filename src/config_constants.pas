unit config_constants;

{$mode objfpc}{$H+}

interface

// VELOCITY constants
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

// TIMING constants (fractions of a beat)
const
  BEAT_QUARTER    = 1.0;
  BEAT_EIGHTH     = 0.5;
  BEAT_SIXTEENTH  = 0.25;
  BEAT_THIRTYSECOND = 0.125;

// DEFAULT BPM by genre/style
const
  DEFAULT_ROCK_TEMPO      = 110;
  DEFAULT_METAL_TEMPO     = 155;
  DEFAULT_JAZZ_TEMPO      = 120;
  DEFAULT_FUNK_TEMPO      = 100;

// HUMANIZATION defaults
const
  DEFAULT_COMPLEXITY           = 0.5;
  DEFAULT_HUMANIZATION         = 0.3;
  DEFAULT_VARIATION_FREQ       = 0.2;
  DEFAULT_FILL_FREQUENCY       = 0.15;

implementation

end.
