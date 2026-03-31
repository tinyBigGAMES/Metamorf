@optimize debug

@subsystem console

@optimize releasesmall

@exeicon "res\assets\icons\metamorf.ico"
@vermajor 2
@verminor 0
@verpatch 0
@product "Hello2"
@description "Pascal2 test program compiled by Metamorf"
@filename "hello2.exe"
@company "tinyBigGAMES LLC"
@copyright "Copyright (c) 2025 tinyBigGAMES LLC"

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
