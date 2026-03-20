LIBRARY test_library;
uses SysUtils,Classes;
const LIB_VERSION=1;LIB_NAME='TestLibrary';
type
TCallback=PROCEDURE(CONST AMsg:STRING); STDCALL;
THandle=TYPE Integer;
function GetVersion():Integer; STDCALL;
BEGIN
Result:=LIB_VERSION;
END;
function GetName():PCHAR; STDCALL;
BEGIN
Result:=LIB_NAME;
END;
procedure DoCallback(CONST ACallback:TCallback;CONST AMsg:STRING); STDCALL;
BEGIN
IF Assigned(ACallback) THEN
ACallback(AMsg);
END;
exports
GetVersion,
GetName,
DoCallback;
BEGIN
Writeln('TestLibrary loaded');
END.
