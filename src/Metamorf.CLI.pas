{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.CLI;

{$I Metamorf.Defines.inc}

interface

uses
  Metamorf.Utils,
  Metamorf.Engine;

type
  { TMorCLI }
  TMorCLI = class
  private
    FEngine:     TMorEngine;
    FLangFile:   string;
    FSourceFile: string;
    FOutputPath: string;
    FAutoRun:    Boolean;
    procedure ShowBanner();
    procedure ShowHelp();
    procedure ShowErrors();
    procedure SetupCallbacks();
    function  ParseArgs(): Boolean;
    procedure RunCompile();
  public
    constructor Create();
    destructor Destroy(); override;
    procedure Execute();
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils;

{ TMorCLI }

constructor TMorCLI.Create();
begin
  inherited Create();
  FEngine     := TMorEngine.Create();
  FLangFile   := '';
  FSourceFile := '';
  FOutputPath := 'output';
  FAutoRun    := False;
end;

destructor TMorCLI.Destroy();
begin
  FreeAndNil(FEngine);
  inherited Destroy();
end;

procedure TMorCLI.ShowBanner();
var
  LVersion: TVersionInfo;
  LVersionStr: string;
begin
  if TUtils.GetVersionInfo(LVersion) then
    LVersionStr := LVersion.VersionString
  else
    LVersionStr := '0.0.0';

  TUtils.PrintLn(COLOR_WHITE + COLOR_BOLD +
    'Metamorf™ Compiler v' + LVersionStr);
  TUtils.PrintLn(COLOR_WHITE +
    'Copyright © 2025-present tinyBigGAMES™ LLC, All Rights Reserved.');
  TUtils.PrintLn(COLOR_YELLOW + 'https://metamorf.dev');
  TUtils.PrintLn('');
end;

procedure TMorCLI.ShowHelp();
begin
  TUtils.PrintLn(COLOR_WHITE +
    'Syntax: Metamorf [options] -l <file> -s <file> [options]');
  TUtils.PrintLn('');
  TUtils.PrintLn(COLOR_BOLD + 'USAGE:');
  TUtils.PrintLn('  Metamorf ' + COLOR_CYAN +
    '-l <file> -s <file>' + COLOR_RESET + ' [OPTIONS]');
  TUtils.PrintLn('');
  TUtils.PrintLn(COLOR_BOLD + 'REQUIRED:');
  TUtils.PrintLn('  ' + COLOR_CYAN + '-l, --lang    <file>' + COLOR_RESET +
    '   Language definition file (.mor)');
  TUtils.PrintLn('  ' + COLOR_CYAN + '-s, --source  <file>' + COLOR_RESET +
    '   Source file to compile');
  TUtils.PrintLn('');
  TUtils.PrintLn(COLOR_BOLD + 'OPTIONS:');
  TUtils.PrintLn('  ' + COLOR_CYAN + '-o, --output  <path>' + COLOR_RESET +
    '   Output path (default: output)');
  TUtils.PrintLn('  ' + COLOR_CYAN + '-r, --autorun       ' + COLOR_RESET +
    '   Build and run the compiled binary');
  TUtils.PrintLn('  ' + COLOR_CYAN + '-h, --help          ' + COLOR_RESET +
    '   Display this help message');
  TUtils.PrintLn('');
  TUtils.PrintLn(COLOR_BOLD + 'EXAMPLES:');
  TUtils.PrintLn('  ' + COLOR_CYAN +
    'Metamorf -l mylang.mor -s hello.src');
  TUtils.PrintLn('  ' + COLOR_CYAN +
    'Metamorf -l mylang.mor -s hello.src -o build');
  TUtils.PrintLn('  ' + COLOR_CYAN +
    'Metamorf -l mylang.mor -s hello.src -r');
  TUtils.PrintLn('');
end;

procedure TMorCLI.ShowErrors();
var
  LErrors: TErrors;
  LError:  TError;
  LColor:  string;
  LI:      Integer;
begin
  LErrors := FEngine.GetErrors();
  if not LErrors.HasErrors() then
    Exit;

  TUtils.PrintLn('');
  TUtils.PrintLn(COLOR_WHITE +
    Format('Errors (%d):', [LErrors.Count()]));

  for LI := 0 to LErrors.GetItems().Count - 1 do
  begin
    LError := LErrors.GetItems()[LI];

    if LError.Severity = esHint then
      LColor := COLOR_CYAN
    else if LError.Severity = esWarning then
      LColor := COLOR_YELLOW
    else if LError.Severity = esError then
      LColor := COLOR_RED
    else if LError.Severity = esFatal then
      LColor := COLOR_BOLD + COLOR_RED
    else
      LColor := COLOR_WHITE;

    TUtils.PrintLn(LColor + '  ' + LError.ToFullString());
  end;
end;

procedure TMorCLI.SetupCallbacks();
begin
  FEngine.SetStatusCallback(
    procedure(const AText: string; const AUserData: Pointer)
    begin
      TUtils.PrintLn(AText);
    end);

  FEngine.GetBuild().SetOutputCallback(
    procedure(const ALine: string; const AUserData: Pointer)
    begin
      TUtils.Print(ALine);
    end);
end;

function TMorCLI.ParseArgs(): Boolean;
var
  LI:    Integer;
  LFlag: string;
begin
  Result := True;

  if ParamCount() = 0 then
  begin
    ShowHelp();
    Result := False;
    Exit;
  end;

  LI := 1;
  while LI <= ParamCount() do
  begin
    LFlag := ParamStr(LI).Trim();

    if (LFlag = '-h') or (LFlag = '--help') then
    begin
      ShowHelp();
      Result := False;
      Exit;
    end
    else if (LFlag = '-l') or (LFlag = '--lang') then
    begin
      Inc(LI);
      if LI > ParamCount() then
      begin
        TUtils.PrintLn(COLOR_RED + 'Error: ' + LFlag +
          ' requires a file argument');
        TUtils.PrintLn('');
        ExitCode := 2;
        Result := False;
        Exit;
      end;
      FLangFile := ParamStr(LI).Trim();
    end
    else if (LFlag = '-s') or (LFlag = '--source') then
    begin
      Inc(LI);
      if LI > ParamCount() then
      begin
        TUtils.PrintLn(COLOR_RED + 'Error: ' + LFlag +
          ' requires a file argument');
        TUtils.PrintLn('');
        ExitCode := 2;
        Result := False;
        Exit;
      end;
      FSourceFile := ParamStr(LI).Trim();
    end
    else if (LFlag = '-o') or (LFlag = '--output') then
    begin
      Inc(LI);
      if LI > ParamCount() then
      begin
        TUtils.PrintLn(COLOR_RED + 'Error: ' + LFlag +
          ' requires a path argument');
        TUtils.PrintLn('');
        ExitCode := 2;
        Result := False;
        Exit;
      end;
      FOutputPath := ParamStr(LI).Trim();
    end
    else if (LFlag = '-r') or (LFlag = '--autorun') then
    begin
      FAutoRun := True;
    end
    else
    begin
      TUtils.PrintLn(COLOR_RED + 'Error: Unknown flag: ' +
        COLOR_YELLOW + LFlag);
      TUtils.PrintLn('');
      TUtils.PrintLn('Run ' + COLOR_CYAN + 'Metamorf -h' +
        COLOR_RESET + ' to see available options');
      TUtils.PrintLn('');
      ExitCode := 2;
      Result := False;
      Exit;
    end;

    Inc(LI);
  end;

  // Validate required arguments
  if FLangFile = '' then
  begin
    TUtils.PrintLn(COLOR_RED +
      'Error: Language file is required (-l <file>)');
    TUtils.PrintLn('');
    TUtils.PrintLn('Run ' + COLOR_CYAN + 'Metamorf -h' +
      COLOR_RESET + ' to see available options');
    TUtils.PrintLn('');
    ExitCode := 2;
    Result := False;
    Exit;
  end;

  if FSourceFile = '' then
  begin
    TUtils.PrintLn(COLOR_RED +
      'Error: Source file is required (-s <file>)');
    TUtils.PrintLn('');
    TUtils.PrintLn('Run ' + COLOR_CYAN + 'Metamorf -h' +
      COLOR_RESET + ' to see available options');
    TUtils.PrintLn('');
    ExitCode := 2;
    Result := False;
    Exit;
  end;
end;

procedure TMorCLI.RunCompile();
begin
  SetupCallbacks();

  FEngine.Compile(FLangFile, FSourceFile, FOutputPath, FAutoRun);

  // Display all errors/warnings/hints
  ShowErrors();

  if FEngine.GetErrors().HasErrors() then
  begin
    TUtils.PrintLn(COLOR_RED + 'Build failed.');
    ExitCode := 1;
  end
  else
  begin
    TUtils.PrintLn(COLOR_GREEN + 'Build OK');
  end;
end;

procedure TMorCLI.Execute();
begin
  ShowBanner();

  if not ParseArgs() then
    Exit;

  try
    RunCompile();
  except
    on E: Exception do
    begin
      TUtils.PrintLn('');
      TUtils.PrintLn(COLOR_RED + COLOR_BOLD + 'Fatal Error: ' +
        E.Message + COLOR_RESET);
      TUtils.PrintLn('');
      ExitCode := 1;
    end;
  end;
end;

end.
