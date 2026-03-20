unit test_unit;

interface

uses
  SysUtils,
  Classes,
  Math;

const
  PI_APPROX = 3.14159;
  MAX_SIZE = 256;

type
  TColor = (clRed, clGreen, clBlue);

  TPoint = record
    X: Integer;
    Y: Integer;
  end;

  TMyClass = class
  private
    FX: Integer;
    FY: Integer;
  public
    constructor Create(const AX, AY: Integer);
    destructor Destroy(); override;
    function Distance(const AOther: TPoint): Double;
    property X: Integer read FX write FX;
    property Y: Integer read FY write FY;
  end;

implementation

uses
  StrUtils;

constructor TMyClass.Create(const AX, AY: Integer);
begin
  FX := AX;
  FY := AY;
end;

destructor TMyClass.Destroy();
begin
  inherited Destroy();
end;

function TMyClass.Distance(const AOther: TPoint): Double;
var
  LDX, LDY: Double;
begin
  LDX := FX - AOther.X;
  LDY := FY - AOther.Y;
  Result := Sqrt(LDX * LDX + LDY * LDY);
end;

initialization
  Writeln('TestUnit initialized');

finalization
  Writeln('TestUnit finalized');

end.
