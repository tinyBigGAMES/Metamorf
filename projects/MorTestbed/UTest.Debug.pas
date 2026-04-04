unit UTest.Debug;

{$I Metamorf.Defines.inc}

interface

procedure Test01();

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Metamorf.Utils,
  Metamorf.Debug.REPL;

procedure Test01();
var
  LBasePath: string;
  LExePath: string;
  LREPL: TMetamorfDebugREPL;
begin
  TUtils.PrintLn('========================================');
  TUtils.PrintLn('Test01: PDB DAP Debugger (REPL)');
  TUtils.PrintLn('========================================');
  TUtils.PrintLn('');

  LBasePath := ExtractFilePath(ParamStr(0));
  LExePath := TPath.Combine(LBasePath,
    'output\zig-out\bin\hello_debug.exe');

  if not TFile.Exists(LExePath) then
  begin
    TUtils.PrintLn(COLOR_RED +
      'ERROR: Executable not found: ' + LExePath);
    TUtils.PrintLn(COLOR_YELLOW +
      'Compile hello_debug.pas first.');
    Exit;
  end;

  LREPL := TMetamorfDebugREPL.Create();
  try
    LREPL.Run(LExePath);
  finally
    LREPL.Free();
  end;
end;

end.
