UNIT test_unit;
INTERFACE
uses SysUtils,Classes,Math;
const PI_APPROX=3.14159;MAX_SIZE=256;
type
TColor=(clRed,clGreen,clBlue);
TPoint=RECORD X:Integer;Y:Integer; END;
TMyClass=CLASS
PRIVATE
FX:Integer;FY:Integer;
PUBLIC
CONSTRUCTOR Create(CONST AX,AY:Integer);
DESTRUCTOR Destroy();OVERRIDE;
FUNCTION Distance(CONST AOther:TPoint):Double;
PROPERTY X:Integer READ FX WRITE FX;
PROPERTY Y:Integer READ FY WRITE FY;
END;
IMPLEMENTATION
uses StrUtils;
CONSTRUCTOR TMyClass.Create(CONST AX,AY:Integer);
BEGIN
FX:=AX;FY:=AY;
END;
DESTRUCTOR TMyClass.Destroy();
BEGIN
INHERITED Destroy();
END;
FUNCTION TMyClass.Distance(CONST AOther:TPoint):Double;
VAR LDX,LDY:Double;
BEGIN
LDX:=FX-AOther.X;LDY:=FY-AOther.Y;
Result:=Sqrt(LDX*LDX+LDY*LDY);
END;
INITIALIZATION
Writeln('TestUnit initialized');
FINALIZATION
Writeln('TestUnit finalized');
END.
