unit Declarations;

{$mode objfpc}{$H+}

{ Shared type aliases for FPC 3.2 — define all generic types here
  so every unit gets identical CRC hashes. }

interface

uses
  Generics.Collections, Pattern, Song, ComposerTypes;

type
  TIntensityProfile = specialize TDictionary<string, Double>;
  TPatternList = specialize TList<Pattern.TPattern>;
  TFillList = specialize TList<Song.TFill>;
  TStringDict = specialize TDictionary<string, string>;
  TIntList = specialize TList<Integer>;

  { Thread-safe context for generation pipeline }
  TThreadContext = record
    Random: TThreadedRandom;
  end;

implementation

end.
