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
  System.IOUtils,
  Metamorf.Utils,
  Metamorf.Common,
  Metamorf.Engine;

type
  { TMorCLI }
  TMorCLI = class
  private
    FEngine:          TMorEngine;
    FLangFile:        string;
    FSourceFile:      string;
    FOutputPath:      string;
    FAutoRun:         Boolean;
    FDebug:           Boolean;
    FBakeFile:        string;
    FBakeProduct:     string;
    FBakeCompany:     string;
    FBakeCopyright:   string;
    FBakeDescription: string;
    FBakeVersion:     string;
    FBakeIcon:        string;
    FBakeURL:         string;
    FBakedMode:       Boolean;
    procedure ShowBanner();
    procedure ShowHelp();
    procedure ShowErrors();
    procedure SetupCallbacks();
    function  ParseArgs(): Boolean;
    procedure RunCompile();
    procedure RunDebug();
    procedure RunBake();
  public
    constructor Create();
    destructor Destroy(); override;
    procedure Execute();
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  Metamorf.AST,
  Metamorf.Build,
  Metamorf.Debug.REPL;

{ TMorCLI }

constructor TMorCLI.Create();
begin
  inherited Create();
  FEngine          := TMorEngine.Create();
  FLangFile        := '';
  FSourceFile      := '';
  FOutputPath      := 'output';
  FAutoRun         := False;
  FDebug           := False;
  FBakeFile        := '';
  FBakeProduct     := '';
  FBakeCompany     := '';
  FBakeCopyright   := '';
  FBakeDescription := '';
  FBakeVersion     := '1.0.0';
  FBakeIcon        := '';
  FBakeURL         := '';
  FBakedMode       := False;
end;

destructor TMorCLI.Destroy();
begin
  FreeAndNil(FEngine);
  inherited Destroy();
end;

procedure TMorCLI.ShowBanner();
var
  LVersion: TVersionInfo;
begin
  if FBakedMode then
  begin
    // Baked mode: read all branding from self's VERSIONINFO
    if TUtils.GetVersionInfo(LVersion, '') then
    begin
      TUtils.PrintLn(COLOR_WHITE + COLOR_BOLD +
        LVersion.ProductName + ' v' + LVersion.VersionString);
      TUtils.PrintLn(COLOR_WHITE + LVersion.Copyright);
      if LVersion.URL <> '' then
        TUtils.PrintLn(COLOR_YELLOW + LVersion.URL);
    end;
  end
  else
  begin
    // Normal mode: hardcoded branding, version from Metamorf.dll
    if TUtils.GetVersionInfo(LVersion, 'Metamorf.dll') then
      TUtils.PrintLn(COLOR_WHITE + COLOR_BOLD +
        'Metamorf™ Compiler v' + LVersion.VersionString)
    else
      TUtils.PrintLn(COLOR_WHITE + COLOR_BOLD +
        'Metamorf™ Compiler v0.0.0');
    TUtils.PrintLn(COLOR_WHITE +
      'Copyright © 2025-present tinyBigGAMES™ LLC, All Rights Reserved.');
    TUtils.PrintLn(COLOR_YELLOW + 'https://metamorf.dev');
  end;
  TUtils.PrintLn('');
end;

procedure TMorCLI.ShowHelp();
var
  LExeName: string;
begin
  LExeName := TPath.GetFileNameWithoutExtension(ParamStr(0));

  if FBakedMode then
  begin
    // Baked mode: stripped CLI surface
    TUtils.PrintLn(COLOR_WHITE +
      'Syntax: ' + LExeName + ' -s <file> [options]');
    TUtils.PrintLn('');
    TUtils.PrintLn(COLOR_BOLD + 'USAGE:');
    TUtils.PrintLn('  ' + LExeName + ' ' + COLOR_CYAN +
      '-s <file>' + COLOR_RESET + ' [OPTIONS]');
    TUtils.PrintLn('');
    TUtils.PrintLn(COLOR_BOLD + 'REQUIRED:');
    TUtils.PrintLn('  ' + COLOR_CYAN + '-s, --source  <file>' + COLOR_RESET +
      '   Source file to compile');
    TUtils.PrintLn('');
    TUtils.PrintLn(COLOR_BOLD + 'OPTIONS:');
    TUtils.PrintLn('  ' + COLOR_CYAN + '-o, --output  <path>' + COLOR_RESET +
      '   Output path (default: output)');
    TUtils.PrintLn('  ' + COLOR_CYAN + '-r, --autorun       ' + COLOR_RESET +
      '   Build and run the compiled binary');
    TUtils.PrintLn('  ' + COLOR_CYAN + '-d, --debug         ' + COLOR_RESET +
      '   Build and debug the compiled binary');
    TUtils.PrintLn('  ' + COLOR_CYAN + '-h, --help          ' + COLOR_RESET +
      '   Display this help message');
    TUtils.PrintLn('');
    TUtils.PrintLn(COLOR_BOLD + 'EXAMPLES:');
    TUtils.PrintLn('  ' + COLOR_CYAN +
      LExeName + ' -s hello.src');
    TUtils.PrintLn('  ' + COLOR_CYAN +
      LExeName + ' -s hello.src -o build');
    TUtils.PrintLn('  ' + COLOR_CYAN +
      LExeName + ' -s hello.src -r');
    TUtils.PrintLn('');
  end
  else
  begin
    // Normal mode: full CLI surface
    TUtils.PrintLn(COLOR_WHITE +
      'Syntax: Mor [options] -l <file> -s <file> [options]');
    TUtils.PrintLn('');
    TUtils.PrintLn(COLOR_BOLD + 'USAGE:');
    TUtils.PrintLn('  Mor ' + COLOR_CYAN +
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
    TUtils.PrintLn('  ' + COLOR_CYAN + '-d, --debug         ' + COLOR_RESET +
      '   Build and debug the compiled binary');
    TUtils.PrintLn('  ' + COLOR_CYAN + '-h, --help          ' + COLOR_RESET +
      '   Display this help message');
    TUtils.PrintLn('');
    TUtils.PrintLn(COLOR_BOLD + 'BAKE:');
    TUtils.PrintLn('  ' + COLOR_CYAN + '--bake <file.mor>' + COLOR_RESET +
      '       Bake a standalone compiler from a .mor definition');
    TUtils.PrintLn('  ' + COLOR_CYAN + '-o <output.exe>   ' + COLOR_RESET +
      '       Output path (required with --bake)');
    TUtils.PrintLn('  ' + COLOR_CYAN + '--product <name>  ' + COLOR_RESET +
      '       Product name for VERSIONINFO');
    TUtils.PrintLn('  ' + COLOR_CYAN + '--company <name>  ' + COLOR_RESET +
      '       Company name for VERSIONINFO');
    TUtils.PrintLn('  ' + COLOR_CYAN + '--copyright <text>' + COLOR_RESET +
      '       Copyright string for VERSIONINFO');
    TUtils.PrintLn('  ' + COLOR_CYAN + '--description <text>' + COLOR_RESET +
      '     File description for VERSIONINFO');
    TUtils.PrintLn('  ' + COLOR_CYAN + '--version <M.N.P> ' + COLOR_RESET +
      '       Version for VERSIONINFO (default: 1.0.0)');
    TUtils.PrintLn('  ' + COLOR_CYAN + '--icon <file.ico> ' + COLOR_RESET +
      '       Custom icon for baked exe');
    TUtils.PrintLn('  ' + COLOR_CYAN + '--url <url>       ' + COLOR_RESET +
      '       URL for banner display');
    TUtils.PrintLn('');
    TUtils.PrintLn(COLOR_BOLD + 'EXAMPLES:');
    TUtils.PrintLn('  ' + COLOR_CYAN +
      'Mor -l mylang.mor -s hello.src');
    TUtils.PrintLn('  ' + COLOR_CYAN +
      'Mor -l mylang.mor -s hello.src -o build');
    TUtils.PrintLn('  ' + COLOR_CYAN +
      'Mor -l mylang.mor -s hello.src -r');
    TUtils.PrintLn('  ' + COLOR_CYAN +
      'Mor --bake mylang.mor -o mylang.exe --product "MyLang"');
    TUtils.PrintLn('');
  end;
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

  FEngine.SetOutputCallback(
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
    else if FBakedMode and ((LFlag = '-l') or (LFlag = '--lang') or
      (LFlag = '--bake') or (LFlag = '--company') or
      (LFlag = '--product') or (LFlag = '--description') or
      (LFlag = '--copyright') or (LFlag = '--version') or
      (LFlag = '--icon') or (LFlag = '--url')) then
    begin
      TUtils.PrintLn(COLOR_RED + 'Error: ' + LFlag +
        ' is not available in this compiler');
      TUtils.PrintLn('');
      ExitCode := 2;
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
      FLangFile := TPath.ChangeExtension(ParamStr(LI).Trim(), MOR_LANG_EXT);
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
    else if (LFlag = '-d') or (LFlag = '--debug') then
    begin
      FDebug := True;
    end
    else if (LFlag = '--bake') then
    begin
      Inc(LI);
      if LI > ParamCount() then
      begin
        TUtils.PrintLn(COLOR_RED + 'Error: --bake requires a .mor file argument');
        TUtils.PrintLn('');
        ExitCode := 2;
        Result := False;
        Exit;
      end;
      FBakeFile := TPath.ChangeExtension(ParamStr(LI).Trim(), MOR_LANG_EXT);
    end
    else if (LFlag = '--company') then
    begin
      Inc(LI);
      if LI > ParamCount() then
      begin
        TUtils.PrintLn(COLOR_RED + 'Error: --company requires an argument');
        TUtils.PrintLn('');
        ExitCode := 2;
        Result := False;
        Exit;
      end;
      FBakeCompany := ParamStr(LI).Trim();
    end
    else if (LFlag = '--product') then
    begin
      Inc(LI);
      if LI > ParamCount() then
      begin
        TUtils.PrintLn(COLOR_RED + 'Error: --product requires an argument');
        TUtils.PrintLn('');
        ExitCode := 2;
        Result := False;
        Exit;
      end;
      FBakeProduct := ParamStr(LI).Trim();
    end
    else if (LFlag = '--description') then
    begin
      Inc(LI);
      if LI > ParamCount() then
      begin
        TUtils.PrintLn(COLOR_RED + 'Error: --description requires an argument');
        TUtils.PrintLn('');
        ExitCode := 2;
        Result := False;
        Exit;
      end;
      FBakeDescription := ParamStr(LI).Trim();
    end
    else if (LFlag = '--copyright') then
    begin
      Inc(LI);
      if LI > ParamCount() then
      begin
        TUtils.PrintLn(COLOR_RED + 'Error: --copyright requires an argument');
        TUtils.PrintLn('');
        ExitCode := 2;
        Result := False;
        Exit;
      end;
      FBakeCopyright := ParamStr(LI).Trim();
    end
    else if (LFlag = '--version') then
    begin
      Inc(LI);
      if LI > ParamCount() then
      begin
        TUtils.PrintLn(COLOR_RED + 'Error: --version requires an argument');
        TUtils.PrintLn('');
        ExitCode := 2;
        Result := False;
        Exit;
      end;
      FBakeVersion := ParamStr(LI).Trim();
    end
    else if (LFlag = '--icon') then
    begin
      Inc(LI);
      if LI > ParamCount() then
      begin
        TUtils.PrintLn(COLOR_RED + 'Error: --icon requires a file argument');
        TUtils.PrintLn('');
        ExitCode := 2;
        Result := False;
        Exit;
      end;
      FBakeIcon := ParamStr(LI).Trim();
    end
    else if (LFlag = '--url') then
    begin
      Inc(LI);
      if LI > ParamCount() then
      begin
        TUtils.PrintLn(COLOR_RED + 'Error: --url requires an argument');
        TUtils.PrintLn('');
        ExitCode := 2;
        Result := False;
        Exit;
      end;
      FBakeURL := ParamStr(LI).Trim();
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

  // Validate arguments based on mode
  if FBakedMode then
  begin
    // Baked mode: only -s is required
    if FSourceFile = '' then
    begin
      TUtils.PrintLn(COLOR_RED +
        'Error: Source file is required (-s <file>)');
      TUtils.PrintLn('');
      ExitCode := 2;
      Result := False;
      Exit;
    end;

    if FAutoRun and FDebug then
    begin
      TUtils.PrintLn(COLOR_RED +
        'Error: -r and -d cannot be used together');
      TUtils.PrintLn('');
      ExitCode := 2;
      Result := False;
      Exit;
    end;
  end
  else if FBakeFile <> '' then
  begin
    // Bake mode validation
    if FAutoRun or FDebug then
    begin
      TUtils.PrintLn(COLOR_RED +
        'Error: -r and -d cannot be used with --bake');
      TUtils.PrintLn('');
      ExitCode := 2;
      Result := False;
      Exit;
    end;

    if FOutputPath = 'output' then
    begin
      TUtils.PrintLn(COLOR_RED +
        'Error: -o <path> is required with --bake');
      TUtils.PrintLn('');
      ExitCode := 2;
      Result := False;
      Exit;
    end;
  end
  else
  begin
    // Normal mode validation
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

    if FAutoRun and FDebug then
    begin
      TUtils.PrintLn(COLOR_RED +
        'Error: -r and -d cannot be used together');
      TUtils.PrintLn('');
      ExitCode := 2;
      Result := False;
      Exit;
    end;
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

procedure TMorCLI.RunDebug();
var
  LExePath: string;
  LREPL: TMetamorfDebugREPL;
begin
  // Debug requires Win64 target
  if FEngine.GetTarget() <> tpWin64 then
  begin
    TUtils.PrintLn(COLOR_RED +
      'Error: Debugging is only supported for Win64 targets');
    ExitCode := 1;
    Exit;
  end;

  // Build exe path
  LExePath := TPath.Combine(FOutputPath,
    TPath.Combine('zig-out',
      TPath.Combine('bin',
        FEngine.GetProjectName() + '.exe')));

  if not FileExists(LExePath) then
  begin
    TUtils.PrintLn(COLOR_RED + 'Executable not found: ' + LExePath);
    ExitCode := 1;
    Exit;
  end;

  LREPL := TMetamorfDebugREPL.Create();
  try
    LREPL.Run(LExePath);
  finally
    LREPL.Free();
  end;
end;

procedure TMorCLI.RunBake();
var
  LASTStream: TMemoryStream;
  LOutputExe: string;
  LSourceExe: string;
  LVersionParts: TArray<string>;
  LMajor: Word;
  LMinor: Word;
  LPatch: Word;
  LProductName: string;
  LDescription: string;
  LFilename: string;
begin
  SetupCallbacks();

  // Phase 1: Setup the .mor language (lex, parse, setup, resolve imports)
  if not FEngine.SetupLanguage(FBakeFile) then
  begin
    ShowErrors();
    TUtils.PrintLn(COLOR_RED + 'Bake failed: language setup error.');
    ExitCode := 1;
    Exit;
  end;

  // Phase 2: Serialize the master AST
  LASTStream := TMemoryStream.Create();
  try
    TASTNode.SaveASTToStream(FEngine.GetMorMasterRoot(), LASTStream);

    // Phase 3: Copy mor.exe to output path
    LSourceExe := ParamStr(0);
    LOutputExe := FOutputPath;

    // Ensure output has .exe extension
    if not LOutputExe.EndsWith('.exe', True) then
      LOutputExe := LOutputExe + '.exe';

    // Ensure output directory exists
    TUtils.CreateDirInPath(LOutputExe);

    TFile.Copy(LSourceExe, LOutputExe, True);

    // Phase 4: Apply resources in correct order (matching TBuild.ApplyPostBuildResources)

    // 4a. Manifest
    if TUtils.ResourceExist('EXE_MANIFEST') then
      TUtils.AddResManifestFromResource('EXE_MANIFEST', LOutputExe);

    // 4b. Icon (if provided and file exists)
    if (FBakeIcon <> '') and TFile.Exists(FBakeIcon) then
      TUtils.UpdateIconResource(LOutputExe, FBakeIcon);

    // 4c. Version info
    LVersionParts := FBakeVersion.Split(['.']);
    LMajor := 1;
    LMinor := 0;
    LPatch := 0;
    if Length(LVersionParts) >= 1 then
      LMajor := StrToIntDef(LVersionParts[0], 1);
    if Length(LVersionParts) >= 2 then
      LMinor := StrToIntDef(LVersionParts[1], 0);
    if Length(LVersionParts) >= 3 then
      LPatch := StrToIntDef(LVersionParts[2], 0);

    LProductName := FBakeProduct;
    if LProductName = '' then
      LProductName := TPath.GetFileNameWithoutExtension(LOutputExe);

    LDescription := FBakeDescription;
    if LDescription = '' then
      LDescription := LProductName;

    LFilename := TPath.GetFileName(LOutputExe);

    TUtils.UpdateVersionInfoResource(LOutputExe,
      LMajor, LMinor, LPatch,
      LProductName, LDescription, LFilename,
      FBakeCompany, FBakeCopyright, FBakeURL);

    // 4d. AST payload
    TUtils.UpdateRCDataResource(LOutputExe, MOR_BAKED_AST_RES, LASTStream);

    TUtils.PrintLn(COLOR_GREEN + 'Bake OK: ' + COLOR_WHITE +
      TUtils.DisplayPath(LOutputExe));
  finally
    LASTStream.Free();
  end;
end;

procedure TMorCLI.Execute();
begin
  // Detect baked mode before anything else
  FBakedMode := TUtils.ResourceExist(MOR_BAKED_AST_RES);

  ShowBanner();

  if not ParseArgs() then
    Exit;

  try
    if FBakeFile <> '' then
    begin
      RunBake();
    end
    else if FBakedMode then
    begin
      SetupCallbacks();
      FEngine.CompileBaked(FSourceFile, FOutputPath, FAutoRun);
      ShowErrors();

      if FEngine.GetErrors().HasErrors() then
      begin
        TUtils.PrintLn(COLOR_RED + 'Build failed.');
        ExitCode := 1;
      end
      else
      begin
        TUtils.PrintLn(COLOR_GREEN + 'Build OK');

        // Launch debug REPL if -d flag and build succeeded
        if FDebug then
          RunDebug();
      end;
    end
    else
    begin
      RunCompile();

      // Launch debug REPL if -d flag and build succeeded
      if FDebug and (not FEngine.GetErrors().HasErrors()) then
        RunDebug();
    end;
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
