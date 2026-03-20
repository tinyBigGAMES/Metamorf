PROGRAM test_program;
uses SysUtils,Classes;
const MAX_ITEMS=10;
var GCounter:Integer;GName:STRING;
procedure PrintHeader(CONST ATitle:STRING);
BEGIN
Writeln('=== ',ATitle,' ===');
END;
function SumArray(CONST AArr:ARRAY OF Integer;CONST ALen:Integer):Integer;
VAR LI:Integer;
BEGIN
Result:=0;
FOR LI:=0 TO ALen-1 DO
Result:=Result+AArr[LI];
END;
BEGIN
GCounter:=0;GName:='TestProgram';
PrintHeader(GName);
WHILE GCounter<MAX_ITEMS DO BEGIN
Writeln('Item: ',GCounter);
INC(GCounter);
END;
Writeln('Done. Sum 1..5 = ',SumArray([1,2,3,4,5],5));
END.
