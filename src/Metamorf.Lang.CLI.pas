{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Lang.CLI;

{$I Metamorf.Defines.inc}

interface

uses
  Metamorf.API,
  Metamorf.Lang;

type
  { TMetamorfLangCLI }
  TMetamorfLangCLI = class
  private
    FCompiler:   TMetamorfLang;
    FLangFile:   string;
    FSourceFile: string;
    FOutputPath: string;
    FBuild:      Boolean;
    FAutoRun:    Boolean;
    procedure Print(const AText: string);
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

{ TMetamorfLangCLI }

constructor TMetamorfLangCLI.Create();
begin
  inherited Create();
  FCompiler   := TMetamorfLang.Create();
  FLangFile   := '';
  FSourceFile := '';
  FOutputPath := 'output';
  FBuild      := True;
  FAutoRun    := False;
end;

destructor TMetamorfLangCLI.Destroy();
begin
  FreeAndNil(FCompiler);
  inherited Destroy();
end;

procedure TMetamorfLangCLI.Print(const AText: string);
begin
  TUtils.PrintLn(AText);
end;

procedure TMetamorfLangCLI.ShowBanner();
begin
  Print(COLOR_WHITE + COLOR_BOLD + 'Metamorf™ Compiler for Win64 v' + FCompiler.GetVersionStr());
  Print(COLOR_WHITE + 'Copyright © 2025-present tinyBigGAMES™ LLC, All Rights Reserved.');
  Print(COLOR_YELLOW + 'https://metamorf.dev');
  Print('');
end;

procedure TMetamorfLangCLI.ShowHelp();
begin
  Print(COLOR_WHITE + 'Syntax: Metamorf [options] -l <file> -s <file> [options]');
  Print('');
  Print(COLOR_BOLD + 'USAGE:');
  Print('  Metamorf ' + COLOR_CYAN + '-l <file> -s <file>' + COLOR_RESET + ' [OPTIONS]');
  Print('');
  Print(COLOR_BOLD + 'REQUIRED:');
  Print('  ' + COLOR_CYAN + '-l, --lang    <file>' + COLOR_RESET +
    '   Language definition file (.pax)');
  Print('  ' + COLOR_CYAN + '-s, --source  <file>' + COLOR_RESET +
    '   Source file to compile');
  Print('');
  Print(COLOR_BOLD + 'OPTIONS:');
  Print('  ' + COLOR_CYAN + '-o, --output  <path>' + COLOR_RESET +
    '   Output path (default: output)');
  Print('  ' + COLOR_CYAN + '-nb, --no-build     ' + COLOR_RESET +
    '   Generate sources only, skip binary build');
  Print('  ' + COLOR_CYAN + '-r, --autorun       ' + COLOR_RESET +
    '   Build and run the compiled binary');
  Print('  ' + COLOR_CYAN + '-h, --help          ' + COLOR_RESET +
    '   Display this help message');
  Print('');
  Print(COLOR_BOLD + 'EXAMPLES:');
  Print('  ' + COLOR_CYAN + 'Metamorf -l mylang.mor -s hello.src');
  Print('  ' + COLOR_CYAN + 'Metamorf -l mylang.mor -s hello.src -o build');
  Print('  ' + COLOR_CYAN + 'Metamorf -l mylang.mor -s hello.src -r');
  Print('');
end;

procedure TMetamorfLangCLI.ShowErrors();
var
  LErrors: TErrors;
  LError:  TError;
  LColor:  string;
  LI:      Integer;
begin
  if not FCompiler.HasErrors() then
    Exit;

  LErrors := FCompiler.GetErrors();

  Print('');
  Print(COLOR_WHITE + Format('Errors (%d):', [LErrors.Count()]));

  for LI := 0 to LErrors.GetItems().Count - 1 do
  begin
    LError := LErrors.GetItems()[LI];

    case LError.Severity of
      esHint:    LColor := COLOR_CYAN;
      esWarning: LColor := COLOR_YELLOW;
      esError:   LColor := COLOR_RED;
      esFatal:   LColor := COLOR_BOLD + COLOR_RED;
    else
      LColor := COLOR_WHITE;
    end;

    Print(LColor + '  ' + LError.ToFullString());
  end;
end;

procedure TMetamorfLangCLI.SetupCallbacks();
begin
  FCompiler.SetStatusCallback(
    procedure(const AText: string; const AUserData: Pointer)
    begin
      TUtils.PrintLn(AText);
    end);

  FCompiler.SetOutputCallback(
    procedure(const ALine: string; const AUserData: Pointer)
    begin
      TUtils.Print(ALine);
    end);
end;

function TMetamorfLangCLI.ParseArgs(): Boolean;
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
        Print(COLOR_RED + 'Error: ' + LFlag + ' requires a file argument');
        Print('');
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
        Print(COLOR_RED + 'Error: ' + LFlag + ' requires a file argument');
        Print('');
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
        Print(COLOR_RED + 'Error: ' + LFlag + ' requires a path argument');
        Print('');
        ExitCode := 2;
        Result := False;
        Exit;
      end;
      FOutputPath := ParamStr(LI).Trim();
    end
    else if (LFlag = '-nb') or (LFlag = '--no-build') then
    begin
      FBuild := False;
    end
    else if (LFlag = '-r') or (LFlag = '--autorun') then
    begin
      FAutoRun := True;
    end
    else
    begin
      Print(COLOR_RED + 'Error: Unknown flag: ' + COLOR_YELLOW + LFlag);
      Print('');
      Print('Run ' + COLOR_CYAN + 'Metamorf -h' +
        COLOR_RESET + ' to see available options');
      Print('');
      ExitCode := 2;
      Result := False;
      Exit;
    end;

    Inc(LI);
  end;

  // Validate required arguments
  if FLangFile = '' then
  begin
    Print(COLOR_RED + 'Error: Language file is required (-l <file>)');
    Print('');
    Print('Run ' + COLOR_CYAN + 'Metamorf -h' +
      COLOR_RESET + ' to see available options');
    Print('');
    ExitCode := 2;
    Result := False;
    Exit;
  end;

  if FSourceFile = '' then
  begin
    Print(COLOR_RED + 'Error: Source file is required (-s <file>)');
    Print('');
    Print('Run ' + COLOR_CYAN + 'Metamorf -h' +
      COLOR_RESET + ' to see available options');
    Print('');
    ExitCode := 2;
    Result := False;
    Exit;
  end;
end;

procedure TMetamorfLangCLI.RunCompile();
var
  LSuccess: Boolean;
begin
  FCompiler.SetLangFile(TPath.GetFullPath(FLangFile));
  FCompiler.SetSourceFile(TPath.GetFullPath(FSourceFile));
  FCompiler.SetOutputPath(TPath.GetFullPath(FOutputPath));
  FCompiler.SetLineDirectives(True);

  SetupCallbacks();

  Print('');

  LSuccess := FCompiler.Compile(FBuild, False);

  // Always display all errors/warnings/hints regardless of outcome
  ShowErrors();

  if LSuccess then
  begin
    if FBuild then
      Print(COLOR_GREEN + 'Build OK')
    else
      Print(COLOR_GREEN + 'Compile OK');
  end
  else
  begin
    Print(COLOR_RED + 'Build failed.');
    ExitCode := 1;
  end;

  if FAutoRun then
  begin
    ExitCode := FCompiler.Run();
  end;
end;

procedure TMetamorfLangCLI.Execute();
begin
  ShowBanner();

  if not ParseArgs() then
    Exit;

  RunCompile();
end;

end.
