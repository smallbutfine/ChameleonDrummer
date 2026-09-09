unit AIBackends;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, JSON, Generics.Collections;

// ============================================================================
// TAIBackend — Base class for AI generation backends
// ============================================================================
type
  TAIBackend = class
  private
    FAPIKey: String;
    FEndpoint: String;
    FModel: String;
  public
    constructor Create; virtual;
    destructor Destroy; override;

    function Prompt(const APrompt: String): String; virtual; abstract;
    function Available: Boolean; virtual;

    property APIKey: String read FAPIKey write FAPIKey;
    property Endpoint: String read FEndpoint write FEndpoint;
    property Model: String read FModel write FModel;
  end;

// ============================================================================
// TOpenAIBackend — OpenAI-compatible backend (ChatGPT, GPT-4)
// ============================================================================
type
  TOpenAIBackend = class(TAIBackend)
  public
    function Prompt(const APrompt: String): String; override;
    function Available: Boolean; override;
  end;

// ============================================================================
// TLangchainBackend — LangChain agent backend
// ============================================================================
type
  TLagChainBackend = class(TAIBackend)
  public
    function Prompt(const APrompt: String): String; override;
    function Available: Boolean; override;
  end;

// ============================================================================
// TAIBackendManager — Manages multiple AI backends
// ============================================================================
type
  TAIBackendManager = class
  private
    FBackends: TList<TAIBackend>;
    FDefaultBackend: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    function AddBackend(ABackend: TAIBackend): Integer;
    function GetBackend(Index: Integer): TAIBackend;
    function GetDefaultBackend: TAIBackend;
    function Prompt(const APrompt: String): String;
  end;

implementation

{ TAIBackend }
constructor TAIBackend.Create;
begin
  FAPIKey := '';
  FEndpoint := '';
  FModel := '';
end;

destructor TAIBackend.Destroy;
begin
  inherited Destroy;
end;

function TAIBackend.Available: Boolean;
begin
  Result := FAPIKey <> '';
end;

{ TOpenAIBackend }
function TOpenAIBackend.Prompt(const APrompt: String): String;
begin
  // Placeholder for actual HTTP call to OpenAI API
  // Would use TIdHTTP or similar to POST to endpoint
  Result := '';
end;

function TOpenAIBackend.Available: Boolean;
begin
  Result := inherited Available and (FModel <> '');
end;

{ TLagChainBackend }
function TLagChainBackend.Prompt(const APrompt: String): String;
begin
  // Placeholder for LangChain agent invocation
  Result := '';
end;

function TLagChainBackend.Available: Boolean;
begin
  Result := inherited Available;
end;

{ TAIBackendManager }
constructor TAIBackendManager.Create;
begin
  FBackends := TList<TAIBackend>.Create;
  FDefaultBackend := -1;
end;

destructor TAIBackendManager.Destroy;
var
  I: Integer;
begin
  for I := 0 to FBackends.Count - 1 do
    FBackends[I].Free;
  FBackends.Free;
  inherited Destroy;
end;

function TAIBackendManager.AddBackend(ABackend: TAIBackend): Integer;
begin
  Result := FBackends.Add(ABackend);
  if (FDefaultBackend = -1) then
    FDefaultBackend := Result;
end;

function TAIBackendManager.GetBackend(Index: Integer): TAIBackend;
begin
  if (Index >= 0) and (Index < FBackends.Count) then
    Result := FBackends[Index]
  else
    Result := nil;
end;

function TAIBackendManager.GetDefaultBackend: TAIBackend;
begin
  if (FDefaultBackend >= 0) then
    Result := FBackends[FDefaultBackend]
  else
    Result := nil;
end;

function TAIBackendManager.Prompt(const APrompt: String): String;
var
  DefaultBackend: TAIBackend;
begin
  DefaultBackend := GetDefaultBackend;
  if (Assigned(DefaultBackend)) then
    Result := DefaultBackend.Prompt(APrompt)
  else
    Result := '';
end;

end.
