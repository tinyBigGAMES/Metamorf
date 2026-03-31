@optimize debug

@subsystem console

program Hello2;

@platform win64

uses mathlib;

var
  x: integer;
  msg: string;

procedure Greet(name: string);
begin
  WriteLn("Hello, {}!", name);
end;

procedure Greet(name: string, times: integer);
var
  i: integer;
begin
  for i := 1 to times do
    WriteLn("Hello, {}!", name);
  end
end;

begin
  x := 42;
  msg := "World";
  Greet(msg);
  Greet(msg, 3);
  WriteLn("x = {}", x);
  WriteLn("doubleVal(21) = {}", doubleVal(21));
  WriteLn("triple(7) = {}", triple(7));
  WriteLn("add(10, 32) = {}", add(10, 32));
end.
