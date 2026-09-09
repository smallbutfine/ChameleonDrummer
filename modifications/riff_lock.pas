unit RiffLock;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections, Math,
  core_models_pattern;

// ============================================================================
// TRiffAccentTracker — tracks and locks kick accents to snare patterns
// ============================================================================
type
  TRiffAccentTracker = class
  private
    FLastKickTime: Double;
    FLastSnareTime: Double;
    FAccentsPerBar: Integer;
  public
    constructor Create;
    function GetAccentPattern(BeatIndex: Integer): Boolean;
    procedure Reset;
  end;

implementation

constructor TRiffAccentTracker.Create;
begin
  FLastKickTime := -1.0;
  FLastSnareTime := -1.0;
  FAccentsPerBar := 2;
end;

function TRiffAccentTracker.GetAccentPattern(BeatIndex: Integer): Boolean;
begin
  // Determine if this beat should have a kick accent based on snare position
  Result := (BeatIndex mod (8 div FAccentsPerBar)) = 0;
end;

procedure TRiffAccentTracker.Reset;
begin
  FLastKickTime := -1.0;
  FLastSnareTime := -1.0;
end;

end.
