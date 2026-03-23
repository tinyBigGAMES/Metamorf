program DCITestbed;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  UDCITestbed in 'UDCITestbed.pas',
  raylib in '..\..\bin\res\libs\raylib\imports\raylib.pas',
  DelphiCImp in 'DelphiCImp.pas',
  DelphiCImp.Common in 'DelphiCImp.Common.pas';

begin
  RunDCITestbed();
end.
