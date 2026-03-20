program test_program;

uses
  SysUtils,
  Classes;

const
  MAX_ITEMS = 10;

var
  GCounter: Integer;
  GName: string;

procedure PrintHeader(const ATitle: string);
begin
  Writeln('=== ', ATitle, ' ===');
end;

function SumArray(const AArr: array of Integer; const ALen: Integer): Integer;
var
  LI: Integer;
begin
  Result := 0;
  for LI := 0 to ALen - 1 do
    Result := Result + AArr[LI];
end;

begin
  GCounter := 0;
  GName := 'TestProgram';
  PrintHeader(GName);
  while GCounter < MAX_ITEMS do
  begin
    Writeln('Item: ', GCounter);
    INC(GCounter);
  end;
  Writeln('Done. Sum 1..5 = ', SumArray([1, 2, 3, 4, 5], 5));
end.
