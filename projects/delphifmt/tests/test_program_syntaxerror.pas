program test_program_syntaxerror;

// This file contains intentional Delphi syntax errors.
// The formatter must detect these via the parser error list and refuse
// to format, returning the error location and description in ErrorMsg.

uses
  System.SysUtils

var
  LValue: Integer;

begin
  LValue := 42
  Writeln('Value = ', LValue;
  // missing closing parenthesis above, missing semicolon after 42
  ReadLn
end.
