unit Declarations;

{$mode objfpc}{$H+}

{ Shared type aliases for FPC 3.2 — define all generic types here
  so every unit gets identical CRC hashes. }

interface

uses Generics.Collections, pattern, song;

type
  TIntensityProfile = specialize TDictionary<string, Double>;
  TPatternList = specialize TList<Pattern.TPattern>;
  TFillList = specialize TList<Song.TFill>;
  TStringDict = specialize TDictionary<string, string>;
  TIntList = specialize TList<Integer>;

implementation

end.
