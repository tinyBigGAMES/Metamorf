library test_library;

uses
  SysUtils,
  Classes;

const
  LIB_VERSION = 1;
  LIB_NAME = 'TestLibrary';

type
  TCallback = procedure(const AMsg: string); stdcall;
  THandle = type Integer;

function GetVersion(): Integer; stdcall;
begin
  Result := LIB_VERSION;
end;

function GetName(): PCHAR; stdcall;
begin
  Result := LIB_NAME;
end;

procedure DoCallback(const ACallback: TCallback; const AMsg: string); stdcall;
begin
  if Assigned(ACallback) then
    ACallback(AMsg);
end;

exports
  GetVersion,
  GetName,
  DoCallback;

begin
  Writeln('TestLibrary loaded');
end.
