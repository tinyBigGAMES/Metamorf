// hello_debug.pas — Debug test: two breakpoints (one in function, one in main)

@optimize debug
@subsystem console
program hello_debug;

var
  LValue: integer;

function ComputeAnswer(): integer;
var
  LResult: integer;
begin
  LResult := 40;
  @breakpoint
  LResult := LResult + 2;
  Result := LResult;
end;

begin
  writeln("Debug test starting...");
  @breakpoint
  LValue := ComputeAnswer();
  writeln("The answer is: {}", LValue);
  writeln("Debug test complete.");
end.
