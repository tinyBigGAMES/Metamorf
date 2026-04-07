{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Build;

{$I Metamorf.Defines.inc}

interface

uses
  WinAPI.Windows,
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  System.Generics.Collections,
  Metamorf.Utils,
  Metamorf.Config,
  Metamorf.Resources;

const
  ERR_ZIGBUILD_NO_OUTPUT_PATH   = 'Z001';
  ERR_ZIGBUILD_NO_SOURCES       = 'Z002';
  ERR_ZIGBUILD_SAVE_FAILED      = 'Z003';
  ERR_ZIGBUILD_ZIG_NOT_FOUND    = 'Z004';
  ERR_ZIGBUILD_BUILD_FAILED     = 'Z005';
  WRN_ZIGBUILD_CANNOT_RUN_CROSS = 'Z006';

type

  { TMorBuildMode }
  TMorBuildMode = (
    bmExe,
    bmLib,
    bmDll
  );

  { TMorOptimizeLevel }
  TMorOptimizeLevel = (
    olDebug,
    olReleaseSafe,
    olReleaseFast,
    olReleaseSmall
  );

  { TMorTargetPlatform }
  TMorTargetPlatform = (
    tpWin64,
    tpLinux64
  );

  { TMorSubsystemType }
  TMorSubsystemType = (
    stConsole,
    stGUI
  );

  { TMorBreakpointEntry }
  TMorBreakpointEntry = record
    FileName: string;
    LineNumber: Integer;
  end;


  { TMorBuild }
  TMorBuild = class(TMorErrorsObject)
  private
    FOutputPath: string;
    FProjectName: string;
    FBuildMode: TMorBuildMode;
    FOptimizeLevel: TMorOptimizeLevel;
    FTarget: TMorTargetPlatform;
    FSubsystem: TMorSubsystemType;
    FSourceFiles: TStringList;
    FIncludePaths: TStringList;
    FLibraryPaths: TStringList;
    FLinkLibraries: TStringList;
    FDefines: TStringList;
    FUndefines: TStringList;
    FCopyDLLs: TStringList;
    //FErrors: TErrors;
    FOutput: TMorCallback<TMorCaptureConsoleCallback>;
    FLastExitCode: DWORD;
    FRawOutput: Boolean;

    // Toolchain path
    FToolchainPath: string;
    FBuildConfig: TMorConfig;
    FBuildConfigPath: string;

    // Version info / post-build resources
    FAddVersionInfo: Boolean;
    FVIMajor: Word;
    FVIMinor: Word;
    FVIPatch: Word;
    FVIProductName: string;
    FVIDescription: string;
    FVIFilename: string;
    FVICompanyName: string;
    FVICopyright: string;
    FExeIcon: string;

    // Breakpoints
    FBreakpoints: TList<TMorBreakpointEntry>;

    function GenerateBuildZig(): string;
    function BuildFlagsString(): string;
    function GetZigTargetString(): string;
    function GetZigOptimizeString(): string;
    function GetTargetDisplayName(): string;
    function GetOptimizeLevelDisplayName(): string;
    function GetSubsystemDisplayName(): string;
    procedure HandleOutputLine(const ALine: string; const AUserData: Pointer);
    function FindDefineIndex(const ADefineName: string): Integer;
    procedure ParseFlagsLine(const ALine: string);
    function FilterOutputBuffer(const ABuffer: string): string;
    procedure ApplyPostBuildResources(const AExePath: string);

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Configuration
    procedure SetOutputPath(const APath: string);
    procedure SetProjectName(const AProjectName: string);
    procedure SetBuildMode(const ABuildMode: TMorBuildMode);
    procedure SetOptimizeLevel(const AOptimizeLevel: TMorOptimizeLevel);
    procedure SetTarget(const ATarget: TMorTargetPlatform);
    procedure SetSubsystem(const ASubsystem: TMorSubsystemType);
    procedure SetOutputCallback(const ACallback: TMorCaptureConsoleCallback; const AUserData: Pointer = nil);
    procedure SetRawOutput(const AValue: Boolean);

    // Source files
    procedure AddSourceFile(const ASourceFile: string);
    procedure RemoveSourceFile(const ASourceFile: string);
    procedure ClearSourceFiles();

    // Include paths
    procedure AddIncludePath(const APath: string);
    procedure RemoveIncludePath(const APath: string);
    procedure ClearIncludePaths();

    // Library paths
    procedure AddLibraryPath(const APath: string);
    procedure RemoveLibraryPath(const APath: string);
    procedure ClearLibraryPaths();


    // Link libraries
    procedure AddLinkLibrary(const ALibrary: string);
    procedure RemoveLinkLibrary(const ALibrary: string);
    procedure ClearLinkLibraries();

    // Defines (-DNAME or -DNAME=VALUE)
    procedure SetDefine(const ADefineName: string); overload;
    procedure SetDefine(const ADefineName, AValue: string); overload;
    procedure RemoveDefine(const ADefineName: string);
    procedure ClearDefines();
    function HasDefine(const ADefineName: string): Boolean;
    function GetDefines(): TStringList;

    // Undefines (-UNAME)
    procedure UnsetDefine(const ADefineName: string);
    procedure RemoveUndefine(const ADefineName: string);
    procedure ClearUndefines();
    function HasUndefine(const ADefineName: string): Boolean;
    function GetUndefines(): TStringList;

    // Copy DLLs (copied to exe output directory after build)
    procedure AddCopyDLL(const ADLLPath: string);
    procedure RemoveCopyDLL(const ADLLPath: string);
    procedure ClearCopyDLLs();

    // Clear all
    procedure Clear();

    // Actions
    function LoadBuildFile(const AFilename: string): Boolean;
    function SaveBuildFile(): Boolean;
    function Process(const AAutoRun: Boolean = True): Boolean;
    function Run(): Boolean;
    function ClearCache(): Boolean;
    function ClearOutput(): Boolean;

    // Getters
    function GetLastExitCode(): DWORD;
    function GetOutputPath(): string;
    function GetProjectName(): string;
    function GetBuildMode(): TMorBuildMode;
    function GetOptimizeLevel(): TMorOptimizeLevel;
    function GetTarget(): TMorTargetPlatform;
    function GetSubsystem(): TMorSubsystemType;
    function GetSourceFileCount(): Integer;
    function GetSourceFile(const AIndex: Integer): string;

    // Platform extension helpers
    function GetExeExtension(): string;
    function GetDllExtension(): string;
    function GetLibExtension(): string;
    function GetOutputFilename(): string;

    // Version info / post-build resources
    procedure SetAddVersionInfo(const AValue: Boolean);
    function GetAddVersionInfo(): Boolean;
    procedure SetVIMajor(const AValue: Word);
    function GetVIMajor(): Word;
    procedure SetVIMinor(const AValue: Word);
    function GetVIMinor(): Word;
    procedure SetVIPatch(const AValue: Word);
    function GetVIPatch(): Word;
    procedure SetVIProductName(const AValue: string);
    function GetVIProductName(): string;
    procedure SetVIDescription(const AValue: string);
    function GetVIDescription(): string;
    procedure SetVIFilename(const AValue: string);
    function GetVIFilename(): string;
    procedure SetVICompanyName(const AValue: string);
    function GetVICompanyName(): string;
    procedure SetVICopyright(const AValue: string);
    function GetVICopyright(): string;
    procedure SetExeIcon(const AValue: string);
    function GetExeIcon(): string;

    // Breakpoints
    procedure AddBreakpoint(const AFileName: string; const ALineNumber: Integer);
    procedure ClearBreakpoints();
    function GetBreakpoints(): TArray<TMorBreakpointEntry>;
    procedure WriteBreakpointsFile(const AExePath: string);

    // Toolchain paths
    procedure SetToolchainPath(const APath: string);
    function GetToolchainPath(): string;
    function GetZigPath(const AFilename: string = ''): string;
    function GetRuntimePath(const AFilename: string = ''): string;
    function GetLibsPath(const AFilename: string = ''): string;
    function GetAssetsPath(const AFilename: string = ''): string;
  end;

implementation

uses
  Metamorf.Common;

{ TMorBuild }

constructor TMorBuild.Create();
begin
  inherited;

  FOutputPath := '';
  FProjectName := 'output';
  FBuildMode := bmExe;
  FOptimizeLevel := olDebug;
  FTarget := tpWin64;
  FSubsystem := stConsole;
  FSourceFiles := TStringList.Create();
  FIncludePaths := TStringList.Create();
  FLibraryPaths := TStringList.Create();
  FLinkLibraries := TStringList.Create();
  FDefines := TStringList.Create();
  FUndefines := TStringList.Create();
  FCopyDLLs := TStringList.Create();
  FLastExitCode := 0;
  FRawOutput := False;

  // Version info defaults
  FAddVersionInfo := False;
  FVIMajor := 0;
  FVIMinor := 0;
  FVIPatch := 0;
  FVIProductName := '';
  FVIDescription := '';
  FVIFilename := '';
  FVICompanyName := '';
  FVICopyright := '';
  FExeIcon := '';

  // Breakpoints
  FBreakpoints := TList<TMorBreakpointEntry>.Create();

  // Toolchain config
  FBuildConfig := TMorConfig.Create();
  FBuildConfigPath := TPath.Combine(
    TPath.GetDirectoryName(ParamStr(0)),
    'build.toml'
  );
  FToolchainPath := '';
  if TFile.Exists(FBuildConfigPath) then
  begin
    FBuildConfig.LoadFromFile(FBuildConfigPath);
    FToolchainPath := FBuildConfig.GetString('build.toolchain_path', '');
  end;

  // Resolve toolchain path: empty means default "toolchain" in exe dir
  // Non-empty means parent folder; "toolchain" is always appended
  if FToolchainPath = '' then
    FToolchainPath := TPath.Combine(
      TPath.GetDirectoryName(ParamStr(0)),
      'toolchain'
    )
  else
  begin
    if not TPath.IsPathRooted(FToolchainPath) then
      FToolchainPath := TPath.Combine(
        TPath.GetDirectoryName(ParamStr(0)),
        FToolchainPath
      );
    FToolchainPath := TPath.Combine(FToolchainPath, 'toolchain');
  end;
end;

destructor TMorBuild.Destroy();
begin
  // Save toolchain config
  FBuildConfig.SetString('build.toolchain_path',
    FBuildConfig.GetString('build.toolchain_path', ''));
  FBuildConfig.SaveToFile(FBuildConfigPath);
  FreeAndNil(FBuildConfig);

  FreeAndNil(FBreakpoints);
  FreeAndNil(FUndefines);
  FreeAndNil(FCopyDLLs);
  FreeAndNil(FDefines);
  FreeAndNil(FLinkLibraries);
  FreeAndNil(FLibraryPaths);
  FreeAndNil(FIncludePaths);
  FreeAndNil(FSourceFiles);

  inherited;
end;

procedure TMorBuild.SetOutputPath(const APath: string);
begin
  FOutputPath := APath;
end;

procedure TMorBuild.SetProjectName(const AProjectName: string);
begin
  FProjectName := AProjectName;
end;

procedure TMorBuild.SetBuildMode(const ABuildMode: TMorBuildMode);
begin
  FBuildMode := ABuildMode;
end;

procedure TMorBuild.SetOptimizeLevel(const AOptimizeLevel: TMorOptimizeLevel);
begin
  FOptimizeLevel := AOptimizeLevel;
end;

procedure TMorBuild.SetTarget(const ATarget: TMorTargetPlatform);
begin
  FTarget := ATarget;

  // Clear all platform-specific defines
  RemoveDefine('PARSE');
  RemoveDefine('CPUX64');
  RemoveDefine('CPUARM64');
  RemoveDefine('ARM64');
  RemoveDefine('WIN64');
  RemoveDefine('MSWINDOWS');
  RemoveDefine('WINDOWS');
  RemoveDefine('LINUX');
  RemoveDefine('MACOS');
  RemoveDefine('DARWIN');
  RemoveDefine('POSIX');
  RemoveDefine('UNIX');
  RemoveDefine('TARGET_WIN64');
  RemoveDefine('TARGET_LINUX64');
  RemoveDefine('TARGET_MACOS64');
  RemoveDefine('TARGET_WINARM64');
  RemoveDefine('TARGET_LINUXARM64');

  // Always set PARSE define
  SetDefine('PARSE', '1');

  // Set platform-specific defines
  case ATarget of
    tpWin64:
      begin
        SetDefine('TARGET_WIN64', '1');
        SetDefine('CPUX64', '1');
        SetDefine('WIN64', '1');
        SetDefine('MSWINDOWS', '1');
        SetDefine('WINDOWS', '1');
      end;
    tpLinux64:
      begin
        SetDefine('TARGET_LINUX64', '1');
        SetDefine('CPUX64', '1');
        SetDefine('LINUX', '1');
        SetDefine('POSIX', '1');
        SetDefine('UNIX', '1');
      end;
  end;
end;

procedure TMorBuild.SetSubsystem(const ASubsystem: TMorSubsystemType);
begin
  FSubsystem := ASubsystem;
end;

function TMorBuild.GetSubsystem(): TMorSubsystemType;
begin
  Result := FSubsystem;
end;

procedure TMorBuild.SetOutputCallback(const ACallback: TMorCaptureConsoleCallback; const AUserData: Pointer);
begin
  FOutput.Callback := ACallback;
  FOutput.UserData := AUserData;
end;

procedure TMorBuild.SetRawOutput(const AValue: Boolean);
begin
  FRawOutput := AValue;
end;

// Source files

procedure TMorBuild.AddSourceFile(const ASourceFile: string);
begin
  if (ASourceFile <> '') and (FSourceFiles.IndexOf(ASourceFile) < 0) then
    FSourceFiles.Add(ASourceFile);
end;

procedure TMorBuild.RemoveSourceFile(const ASourceFile: string);
var
  LIndex: Integer;
begin
  LIndex := FSourceFiles.IndexOf(ASourceFile);
  if LIndex >= 0 then
    FSourceFiles.Delete(LIndex);
end;

procedure TMorBuild.ClearSourceFiles();
begin
  FSourceFiles.Clear();
end;

// Include paths

procedure TMorBuild.AddIncludePath(const APath: string);
begin
  if (APath <> '') and (FIncludePaths.IndexOf(APath) < 0) then
    FIncludePaths.Add(APath);
end;

procedure TMorBuild.RemoveIncludePath(const APath: string);
var
  LIndex: Integer;
begin
  LIndex := FIncludePaths.IndexOf(APath);
  if LIndex >= 0 then
    FIncludePaths.Delete(LIndex);
end;

procedure TMorBuild.ClearIncludePaths();
begin
  FIncludePaths.Clear();
end;

// Library paths

procedure TMorBuild.AddLibraryPath(const APath: string);
begin
  if (APath <> '') and (FLibraryPaths.IndexOf(APath) < 0) then
    FLibraryPaths.Add(APath);
end;

procedure TMorBuild.RemoveLibraryPath(const APath: string);
var
  LIndex: Integer;
begin
  LIndex := FLibraryPaths.IndexOf(APath);
  if LIndex >= 0 then
    FLibraryPaths.Delete(LIndex);
end;

procedure TMorBuild.ClearLibraryPaths();
begin
  FLibraryPaths.Clear();
end;


// Link libraries

procedure TMorBuild.AddLinkLibrary(const ALibrary: string);
begin
  if (ALibrary <> '') and (FLinkLibraries.IndexOf(ALibrary) < 0) then
    FLinkLibraries.Add(ALibrary);
end;

procedure TMorBuild.RemoveLinkLibrary(const ALibrary: string);
var
  LIndex: Integer;
begin
  LIndex := FLinkLibraries.IndexOf(ALibrary);
  if LIndex >= 0 then
    FLinkLibraries.Delete(LIndex);
end;

procedure TMorBuild.ClearLinkLibraries();
begin
  FLinkLibraries.Clear();
end;

// Defines

function TMorBuild.FindDefineIndex(const ADefineName: string): Integer;
var
  LI: Integer;
  LEntry: string;
  LEqualPos: Integer;
  LName: string;
begin
  Result := -1;
  for LI := 0 to FDefines.Count - 1 do
  begin
    LEntry := FDefines[LI];
    LEqualPos := Pos('=', LEntry);
    if LEqualPos > 0 then
      LName := Copy(LEntry, 1, LEqualPos - 1)
    else
      LName := LEntry;

    if SameText(LName, ADefineName) then
    begin
      Result := LI;
      Exit;
    end;
  end;
end;

procedure TMorBuild.SetDefine(const ADefineName: string);
var
  LIndex: Integer;
begin
  if ADefineName = '' then
    Exit;

  // Check if already defined, update if so
  LIndex := FindDefineIndex(ADefineName);
  if LIndex >= 0 then
    FDefines[LIndex] := ADefineName
  else
    FDefines.Add(ADefineName);
end;

procedure TMorBuild.SetDefine(const ADefineName, AValue: string);
var
  LIndex: Integer;
  LEntry: string;
begin
  if ADefineName = '' then
    Exit;

  LEntry := ADefineName + '=' + AValue;

  // Check if already defined, update if so
  LIndex := FindDefineIndex(ADefineName);
  if LIndex >= 0 then
    FDefines[LIndex] := LEntry
  else
    FDefines.Add(LEntry);
end;

procedure TMorBuild.RemoveDefine(const ADefineName: string);
var
  LIndex: Integer;
begin
  LIndex := FindDefineIndex(ADefineName);
  if LIndex >= 0 then
    FDefines.Delete(LIndex);
end;

procedure TMorBuild.ClearDefines();
begin
  FDefines.Clear();
end;

function TMorBuild.HasDefine(const ADefineName: string): Boolean;
begin
  Result := FindDefineIndex(ADefineName) >= 0;
end;

function TMorBuild.GetDefines(): TStringList;
begin
  Result := FDefines;
end;

// Undefines

procedure TMorBuild.UnsetDefine(const ADefineName: string);
begin
  if ADefineName = '' then
    Exit;

  if FUndefines.IndexOf(ADefineName) < 0 then
    FUndefines.Add(ADefineName);
end;

procedure TMorBuild.RemoveUndefine(const ADefineName: string);
var
  LIndex: Integer;
begin
  LIndex := FUndefines.IndexOf(ADefineName);
  if LIndex >= 0 then
    FUndefines.Delete(LIndex);
end;

procedure TMorBuild.ClearUndefines();
begin
  FUndefines.Clear();
end;

function TMorBuild.HasUndefine(const ADefineName: string): Boolean;
begin
  Result := FUndefines.IndexOf(ADefineName) >= 0;
end;

function TMorBuild.GetUndefines(): TStringList;
begin
  Result := FUndefines;
end;

// Copy DLLs

procedure TMorBuild.AddCopyDLL(const ADLLPath: string);
begin
  if FCopyDLLs.IndexOf(ADLLPath) < 0 then
    FCopyDLLs.Add(ADLLPath);
end;

procedure TMorBuild.RemoveCopyDLL(const ADLLPath: string);
var
  LIndex: Integer;
begin
  LIndex := FCopyDLLs.IndexOf(ADLLPath);
  if LIndex >= 0 then
    FCopyDLLs.Delete(LIndex);
end;

procedure TMorBuild.ClearCopyDLLs();
begin
  FCopyDLLs.Clear();
end;

// Clear all

procedure TMorBuild.Clear();
begin
  ClearSourceFiles();
  ClearIncludePaths();
  ClearLibraryPaths();
  ClearLinkLibraries();
  ClearDefines();
  ClearUndefines();
  ClearCopyDLLs();
  ClearBreakpoints();
  FProjectName := 'parse_output';
  FBuildMode := bmExe;
  FOptimizeLevel := olDebug;
  FTarget := tpWin64;
  FSubsystem := stConsole;
  FLastExitCode := 0;

  // Reset version info
  FAddVersionInfo := False;
  FVIMajor := 0;
  FVIMinor := 0;
  FVIPatch := 0;
  FVIProductName := '';
  FVIDescription := '';
  FVIFilename := '';
  FVICompanyName := '';
  FVICopyright := '';
  FExeIcon := '';
end;

function TMorBuild.GetLastExitCode(): DWORD;
begin
  Result := FLastExitCode;
end;

function TMorBuild.GetOutputPath(): string;
begin
  Result := FOutputPath;
end;

function TMorBuild.GetProjectName(): string;
begin
  Result := FProjectName;
end;

function TMorBuild.GetBuildMode(): TMorBuildMode;
begin
  Result := FBuildMode;
end;

function TMorBuild.GetOptimizeLevel(): TMorOptimizeLevel;
begin
  Result := FOptimizeLevel;
end;

function TMorBuild.GetTarget(): TMorTargetPlatform;
begin
  Result := FTarget;
end;

function TMorBuild.GetSourceFileCount(): Integer;
begin
  Result := FSourceFiles.Count;
end;

function TMorBuild.GetSourceFile(const AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex < FSourceFiles.Count) then
    Result := FSourceFiles[AIndex]
  else
    Result := '';
end;

// Platform extension helpers

function TMorBuild.GetExeExtension(): string;
begin
  case FTarget of
    tpWin64:
      Result := '.exe';
    tpLinux64:
      Result := '';
  else
    Result := '.exe';
  end;
end;

function TMorBuild.GetDllExtension(): string;
begin
  case FTarget of
    tpWin64:
      Result := '.dll';
    tpLinux64:
      Result := '.so';
  else
    Result := '.dll';
  end;
end;

function TMorBuild.GetLibExtension(): string;
begin
  case FTarget of
    tpWin64:
      Result := '.lib';
    tpLinux64:
      Result := '.a';
  else
    Result := '.lib';
  end;
end;

function TMorBuild.GetOutputFilename(): string;
var
  LExtension: string;
begin
  case FBuildMode of
    bmExe:
      LExtension := GetExeExtension();
    bmLib:
      LExtension := GetLibExtension();
    bmDll:
      LExtension := GetDllExtension();
  else
    LExtension := GetExeExtension();
  end;

  Result := FProjectName + LExtension;
end;

function TMorBuild.GetZigTargetString(): string;
begin
  case FTarget of
    tpWin64:
      Result := '.{ .cpu_arch = .x86_64, .os_tag = .windows }';
    tpLinux64:
      Result := '.{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu }';
  else
    Result := '.{ .cpu_arch = .x86_64, .os_tag = .windows }';
  end;
end;

function TMorBuild.GetZigOptimizeString(): string;
begin
  case FOptimizeLevel of
    olDebug:
      Result := '.Debug';
    olReleaseSafe:
      Result := '.ReleaseSafe';
    olReleaseFast:
      Result := '.ReleaseFast';
    olReleaseSmall:
      Result := '.ReleaseSmall';
  else
    Result := '.Debug';
  end;
end;

function TMorBuild.GetTargetDisplayName(): string;
begin
  case FTarget of
    tpWin64:
      Result := 'Win64';
    tpLinux64:
      Result := 'Linux64';
  else
    Result := 'Unknown';
  end;
end;

function TMorBuild.GetOptimizeLevelDisplayName(): string;
begin
  case FOptimizeLevel of
    olDebug:
      Result := 'Debug';
    olReleaseSafe:
      Result := 'ReleaseSafe';
    olReleaseFast:
      Result := 'ReleaseFast';
    olReleaseSmall:
      Result := 'ReleaseSmall';
  else
    Result := 'Unknown';
  end;
end;

function TMorBuild.GetSubsystemDisplayName(): string;
begin
  if FSubsystem = stGUI then
    Result := 'GUI'
  else
    Result := 'Console';
end;

function TMorBuild.BuildFlagsString(): string;
var
  LFlags: TStringList;
  LI: Integer;
  LEntry: string;
  LMaxErrors: Integer;
begin
  LFlags := TStringList.Create();
  try
    // Base C++ flags
    LFlags.Add('"-std=c++23"');
    LFlags.Add('"-fexceptions"');
    LFlags.Add('"-frtti"');
    LFlags.Add('"-fexperimental-library"');
    LFlags.Add('"-fno-sanitize=undefined"');  // Required for hardware exception handling
    LFlags.Add('"-Wno-parentheses-equality"');  // Suppress warning about ((a == b)) in if statements
    LFlags.Add('"-Wno-unused-command-line-argument"');  // Suppress Zig-injected flags like -fno-rtlib-defaultlib
    LFlags.Add('"-fdeclspec"');
    LFlags.Add('"-fms-extensions"');
    LFlags.Add('"-fno-omit-frame-pointer"');  // Required for debugger stack unwinding via [RBP+8]

    // Hide symbols by default in DLLs to prevent runtime symbol conflicts
    if FBuildMode = bmDll then
      LFlags.Add('"-fvisibility=hidden"');

    // Add defines
    for LI := 0 to FDefines.Count - 1 do
    begin
      LEntry := FDefines[LI];
      LFlags.Add('"-D' + LEntry + '"');
    end;

    // Add undefines
    for LI := 0 to FUndefines.Count - 1 do
    begin
      LEntry := FUndefines[LI];
      LFlags.Add('"-U' + LEntry + '"');
    end;

    // Error limit (default to 1)
    LMaxErrors := 1;
    if (FErrors <> nil) and (FErrors.GetMaxErrors() > 0) then
      LMaxErrors := FErrors.GetMaxErrors();
    LFlags.Add(Format('"-ferror-limit=%d"', [LMaxErrors]));

    // Build the result string
    Result := '';
    for LI := 0 to LFlags.Count - 1 do
    begin
      if LI > 0 then
        Result := Result + ', ';
      Result := Result + LFlags[LI];
    end;
  finally
    LFlags.Free();
  end;
end;

procedure TMorBuild.ParseFlagsLine(const ALine: string);
var
  LStart: Integer;
  LEnd: Integer;
  LFlag: string;
  LDefineName: string;
  LEqualPos: Integer;
begin
  // Parse flags from line like: .flags = &.{ "-std=c++23", "-DFOO", "-DBAR=1", "-UBAZ" },
  LStart := 1;
  while LStart <= Length(ALine) do
  begin
    // Find start of quoted flag
    LStart := Pos('"-', ALine, LStart);
    if LStart = 0 then
      Break;

    // Find end quote
    LEnd := Pos('"', ALine, LStart + 1);
    if LEnd = 0 then
      Break;

    // Extract flag without quotes
    LFlag := Copy(ALine, LStart + 1, LEnd - LStart - 1);

    // Check if it's a define (-D) or undefine (-U)
    if LFlag.StartsWith('-D') then
    begin
      LDefineName := Copy(LFlag, 3, Length(LFlag) - 2);
      // Skip standard flags
      if not LDefineName.StartsWith('std=') then
      begin
        // Check if it has a value
        LEqualPos := Pos('=', LDefineName);
        if LEqualPos > 0 then
          SetDefine(Copy(LDefineName, 1, LEqualPos - 1), Copy(LDefineName, LEqualPos + 1, Length(LDefineName)))
        else
          SetDefine(LDefineName);
      end;
    end
    else if LFlag.StartsWith('-U') then
    begin
      LDefineName := Copy(LFlag, 3, Length(LFlag) - 2);
      UnsetDefine(LDefineName);
    end;

    LStart := LEnd + 1;
  end;
end;

function TMorBuild.GenerateBuildZig(): string;
var
  LBuilder: TStringBuilder;
  LI: Integer;
  LLinkage: string;
  LSourcePath: string;
  LFlagsStr: string;

  function MakeRelativePath(const ABasePath, ATargetPath: string): string;
  var
    LBase: string;
    LTarget: string;
    LBaseParts: TArray<string>;
    LTargetParts: TArray<string>;
    LCommonCount: Integer;
    LIdx: Integer;
    LRelativeParts: TList<string>;
  begin
    LBase := TPath.GetFullPath(ABasePath).Replace('\', '/');
    LTarget := TPath.GetFullPath(ATargetPath).Replace('\', '/');

    if SameText(LBase, LTarget) then
      Exit('.');

    LBaseParts := LBase.Split(['/']);
    LTargetParts := LTarget.Split(['/']);

    LCommonCount := 0;
    while (LCommonCount < Length(LBaseParts)) and
          (LCommonCount < Length(LTargetParts)) and
          SameText(LBaseParts[LCommonCount], LTargetParts[LCommonCount]) do
      Inc(LCommonCount);

    LRelativeParts := TList<string>.Create();
    try
      for LIdx := LCommonCount to High(LBaseParts) do
        LRelativeParts.Add('..');

      for LIdx := LCommonCount to High(LTargetParts) do
        LRelativeParts.Add(LTargetParts[LIdx]);

      Result := string.Join('/', LRelativeParts.ToArray());
    finally
      LRelativeParts.Free();
    end;
  end;

begin
  LBuilder := TStringBuilder.Create();
  try
    // Build flags string once
    LFlagsStr := BuildFlagsString();

    // Header
    LBuilder.AppendLine('const std = @import("std");');
    LBuilder.AppendLine();
    LBuilder.AppendLine('pub fn build(b: *std.Build) void {');

    // Explicit target based on platform setting
    LBuilder.AppendLine('    const target = b.resolveTargetQuery(' + GetZigTargetString() + ');');
    LBuilder.AppendLine('    const optimize: std.builtin.OptimizeMode = ' + GetZigOptimizeString() + ';');
    LBuilder.AppendLine();

    // Determine linkage for library builds
    if FBuildMode = bmExe then
      LBuilder.AppendLine('    const exe = b.addExecutable(.{')
    else
    begin
      LBuilder.AppendLine('    const lib = b.addLibrary(.{');
      if FBuildMode = bmLib then
        LLinkage := '.static'
      else
        LLinkage := '.dynamic';
      LBuilder.AppendLine('        .linkage = ' + LLinkage + ',');
    end;

    // Name and root module
    LBuilder.AppendLine('        .name = "' + FProjectName + '",');
    LBuilder.AppendLine('        .root_module = b.createModule(.{');
    LBuilder.AppendLine('            .target = target,');
    LBuilder.AppendLine('            .optimize = optimize,');
    LBuilder.AppendLine('            .link_libc = true,');
    LBuilder.AppendLine('            .link_libcpp = true,');
    LBuilder.AppendLine('        }),');
    LBuilder.AppendLine('    });');

    // GUI subsystem — suppress console window on Windows
    if (FBuildMode = bmExe) and (FSubsystem = stGUI) then
    begin
      LBuilder.AppendLine();
      LBuilder.AppendLine('    // GUI subsystem: no console window');
      LBuilder.AppendLine('    if (target.result.os.tag == .windows) {');
      LBuilder.AppendLine('        exe.subsystem = .windows;');
      LBuilder.AppendLine('    }');
    end;

    LBuilder.AppendLine();

    // Artifact variable name
    if FBuildMode = bmExe then
    begin
      // Include paths
      for LI := 0 to FIncludePaths.Count - 1 do
        LBuilder.AppendLine('    exe.root_module.addIncludePath(b.path("' +
          MakeRelativePath(FOutputPath, FIncludePaths[LI]) + '"));');

      // Library paths
      for LI := 0 to FLibraryPaths.Count - 1 do
        LBuilder.AppendLine('    exe.root_module.addLibraryPath(b.path("' +
          MakeRelativePath(FOutputPath, FLibraryPaths[LI]) + '"));');

      // On Linux, add rpath $ORIGIN so the binary finds .so files in its own directory
      if FTarget in [tpLinux64] then
        LBuilder.AppendLine('    exe.root_module.addRPathSpecial("$ORIGIN");');

      // Link libraries
      for LI := 0 to FLinkLibraries.Count - 1 do
        LBuilder.AppendLine('    exe.root_module.linkSystemLibrary("' + FLinkLibraries[LI] + '", .{});');

      // Source files
      if FSourceFiles.Count > 0 then
      begin
        LBuilder.AppendLine('    exe.root_module.addCSourceFiles(.{');
        LBuilder.AppendLine('        .files = &.{');
        for LI := 0 to FSourceFiles.Count - 1 do
        begin
          LSourcePath := MakeRelativePath(FOutputPath, FSourceFiles[LI]);
          LBuilder.Append('            "' + LSourcePath + '"');
          if LI < FSourceFiles.Count - 1 then
            LBuilder.AppendLine(',')
          else
            LBuilder.AppendLine();
        end;
        LBuilder.AppendLine('        },');
        LBuilder.AppendLine('        .flags = &.{ ' + LFlagsStr + ' },');
        LBuilder.AppendLine('    });');
      end;

      LBuilder.AppendLine();
      LBuilder.AppendLine('    b.installArtifact(exe);');
    end
    else
    begin
      // Include paths
      for LI := 0 to FIncludePaths.Count - 1 do
        LBuilder.AppendLine('    lib.root_module.addIncludePath(b.path("' +
          MakeRelativePath(FOutputPath, FIncludePaths[LI]) + '"));');

      // Library paths
      for LI := 0 to FLibraryPaths.Count - 1 do
        LBuilder.AppendLine('    lib.root_module.addLibraryPath(b.path("' +
          MakeRelativePath(FOutputPath, FLibraryPaths[LI]) + '"));');

      // Link libraries
      for LI := 0 to FLinkLibraries.Count - 1 do
        LBuilder.AppendLine('    lib.root_module.linkSystemLibrary("' + FLinkLibraries[LI] + '", .{});');

      // Source files
      if FSourceFiles.Count > 0 then
      begin
        LBuilder.AppendLine('    lib.root_module.addCSourceFiles(.{');
        LBuilder.AppendLine('        .files = &.{');
        for LI := 0 to FSourceFiles.Count - 1 do
        begin
          LSourcePath := MakeRelativePath(FOutputPath, FSourceFiles[LI]);
          LBuilder.Append('            "' + LSourcePath + '"');
          if LI < FSourceFiles.Count - 1 then
            LBuilder.AppendLine(',')
          else
            LBuilder.AppendLine();
        end;
        LBuilder.AppendLine('        },');
        LBuilder.AppendLine('        .flags = &.{ ' + LFlagsStr + ' },');
        LBuilder.AppendLine('    });');
      end;

      LBuilder.AppendLine();
      LBuilder.AppendLine('    b.installArtifact(lib);');
    end;

    LBuilder.AppendLine('}');

    Result := LBuilder.ToString();
  finally
    LBuilder.Free();
  end;
end;

function TMorBuild.FilterOutputBuffer(const ABuffer: string): string;
var
  LCleanLine: string;
  LFilePath: string;
  LLineNum: Integer;
  LColNum: Integer;
  LSeverity: string;
  LMessage: string;
  LErrorSeverity: TMorErrorSeverity;

  function StripAnsiCodes(const AText: string): string;
  var
    LI: Integer;
    LInEscape: Boolean;
    LC: Char;
  begin
    Result := '';
    LInEscape := False;
    LI := 0;
    while LI < AText.Length do
    begin
      LC := AText.Chars[LI];

      if LC = #27 then
      begin
        LInEscape := True;
        Inc(LI);
        Continue;
      end;

      if LInEscape then
      begin
        if LC = '[' then
        begin
          Inc(LI);
          while (LI < AText.Length) and not CharInSet(AText.Chars[LI], ['A'..'Z', 'a'..'z']) do
            Inc(LI);
          if LI < AText.Length then
            Inc(LI);
          LInEscape := False;
          Continue;
        end
        else if LC = ']' then
        begin
          Inc(LI);
          while LI < AText.Length do
          begin
            if AText.Chars[LI] = #7 then
            begin
              Inc(LI);
              Break;
            end;
            if (AText.Chars[LI] = #27) and (LI + 1 < AText.Length) and (AText.Chars[LI + 1] = '\') then
            begin
              Inc(LI, 2);
              Break;
            end;
            Inc(LI);
          end;
          LInEscape := False;
          Continue;
        end
        else
        begin
          LInEscape := False;
          Inc(LI);
          Continue;
        end;
      end;

      Result := Result + LC;
      Inc(LI);
    end;
  end;

  function TryParseCompilerMessage(const ALine: string; out AFilePath: string;
    out ALineNum, AColNum: Integer; out ASeverity, AMessage: string): Boolean;
  var
    LPos1, LPos2, LPos3: Integer;
    LLineStr, LColStr, LSevStr: string;
  begin
    Result := False;

    // Look for pattern: filepath:line:col: severity: message
    // Skip the drive letter colon on Windows paths (e.g. C:\...)
    if (Length(ALine) > 2) and (ALine[2] = ':') then
      LPos1 := ALine.IndexOf(':', 2)
    else
      LPos1 := ALine.IndexOf(':');

    if LPos1 < 1 then
      Exit;

    LPos2 := ALine.IndexOf(':', LPos1 + 1);
    if LPos2 < 0 then
      Exit;

    LPos3 := ALine.IndexOf(':', LPos2 + 1);
    if LPos3 < 0 then
      Exit;

    LLineStr := ALine.Substring(LPos1 + 1, LPos2 - LPos1 - 1).Trim();
    if not TryStrToInt(LLineStr, ALineNum) then
      Exit;

    LColStr := ALine.Substring(LPos2 + 1, LPos3 - LPos2 - 1).Trim();
    if not TryStrToInt(LColStr, AColNum) then
      Exit;

    AFilePath := ALine.Substring(0, LPos1);

    LSevStr := ALine.Substring(LPos3 + 1).TrimLeft();

    if LSevStr.StartsWith('error:') then
    begin
      ASeverity := 'error';
      AMessage := LSevStr.Substring(6).Trim();
      Result := True;
    end
    else if LSevStr.StartsWith('warning:') then
    begin
      ASeverity := 'warning';
      AMessage := LSevStr.Substring(8).Trim();
      Result := True;
    end
    else if LSevStr.StartsWith('note:') then
    begin
      ASeverity := 'note';
      AMessage := LSevStr.Substring(5).Trim();
      Result := True;
    end;
  end;

begin
  // Strip ANSI codes for parsing only — original line always passes through
  LCleanLine := StripAnsiCodes(ABuffer);

  // If this line is a clang error/warning/note, capture it in FErrors
  if Assigned(FErrors) and TryParseCompilerMessage(LCleanLine, LFilePath, LLineNum, LColNum, LSeverity, LMessage) then
  begin
    if LSeverity = 'error' then
      LErrorSeverity := esError
    else if LSeverity = 'warning' then
      LErrorSeverity := esWarning
    else
      LErrorSeverity := esHint;

    FErrors.Add(LFilePath, LLineNum, LColNum, LErrorSeverity, ERR_ZIGBUILD_BUILD_FAILED, LMessage.Trim());
  end;

  // Always return the original line unchanged
  Result := ABuffer;
end;

procedure TMorBuild.HandleOutputLine(const ALine: string; const AUserData: Pointer);
var
  LFiltered: string;
begin
  if not FOutput.IsAssigned() then
    Exit;

  if FRawOutput then
  begin
    FOutput.Callback(ALine, FOutput.UserData);
    Exit;
  end;

  LFiltered := FilterOutputBuffer(ALine);
  if LFiltered.Length > 0 then
    FOutput.Callback(LFiltered, FOutput.UserData);
end;

function TMorBuild.LoadBuildFile(const AFilename: string): Boolean;
var
  LLines: TStringList;
  LLine: string;
  LI: Integer;
  LIdx: Integer;
  LValue: string;
begin
  Result := False;

  if not TFile.Exists(AFilename) then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_ZIGBUILD_SAVE_FAILED, Format(RSZigBuildFileNotFound, [AFilename]));
    Exit;
  end;

  // Clear existing data and set output path from filename
  Clear();
  FOutputPath := TPath.GetDirectoryName(AFilename);

  LLines := TStringList.Create();
  try
    LLines.Text := TFile.ReadAllText(AFilename);

    for LI := 0 to LLines.Count - 1 do
    begin
      LLine := LLines[LI].Trim();

      // Parse .name = "<projectname>"
      LIdx := LLine.IndexOf('.name = "');
      if LIdx >= 0 then
      begin
        LValue := LLine.Substring(LIdx + 9);
        LIdx := LValue.IndexOf('"');
        if LIdx >= 0 then
          FProjectName := LValue.Substring(0, LIdx);
        Continue;
      end;

      // Parse addExecutable -> bmExe
      if LLine.Contains('addExecutable') then
      begin
        FBuildMode := bmExe;
        Continue;
      end;

      // Parse addLibrary with .static -> bmLib
      if LLine.Contains('addLibrary') then
      begin
        FBuildMode := bmLib;
        Continue;
      end;

      // Parse .linkage = .dynamic -> bmDll
      if LLine.Contains('.linkage = .dynamic') then
      begin
        FBuildMode := bmDll;
        Continue;
      end;

      // Parse GUI subsystem
      if LLine.Contains('exe.subsystem = .windows') then
      begin
        FSubsystem := stGUI;
        Continue;
      end;

      // Parse target platform (need to check both cpu_arch and os_tag)
      if LLine.Contains('.cpu_arch = .x86_64') and LLine.Contains('.os_tag = .windows') then
      begin
        FTarget := tpWin64;
        Continue;
      end;

      if LLine.Contains('.cpu_arch = .x86_64') and LLine.Contains('.os_tag = .linux') then
      begin
        FTarget := tpLinux64;
        Continue;
      end;

      // Parse addIncludePath
      LIdx := LLine.IndexOf('root_module.addIncludePath(b.path("');
      if LIdx >= 0 then
      begin
        LValue := LLine.Substring(LIdx + 35);
        LIdx := LValue.IndexOf('"');
        if LIdx >= 0 then
          FIncludePaths.Add(TPath.Combine(FOutputPath, LValue.Substring(0, LIdx)));
        Continue;
      end;

      // Parse addLibraryPath
      LIdx := LLine.IndexOf('root_module.addLibraryPath(b.path("');
      if LIdx >= 0 then
      begin
        LValue := LLine.Substring(LIdx + 35);
        LIdx := LValue.IndexOf('"');
        if LIdx >= 0 then
          FLibraryPaths.Add(TPath.Combine(FOutputPath, LValue.Substring(0, LIdx)));
        Continue;
      end;

      // Parse linkSystemLibrary
      LIdx := LLine.IndexOf('root_module.linkSystemLibrary("');
      if LIdx >= 0 then
      begin
        LValue := LLine.Substring(LIdx + 32);
        LIdx := LValue.IndexOf('"');
        if LIdx >= 0 then
          FLinkLibraries.Add(LValue.Substring(0, LIdx));
        Continue;
      end;

      // Parse flags for defines and undefines
      if LLine.Contains('.flags = &.{') then
      begin
        ParseFlagsLine(LLine);
        Continue;
      end;

      // Parse source files from .files = &.{
      LIdx := LLine.IndexOf('"');
      if LIdx >= 0 then
      begin
        LValue := LLine.Substring(LIdx + 1);
        LIdx := LValue.IndexOf('"');
        if (LIdx >= 0) and LValue.Contains('.cpp') then
          FSourceFiles.Add(TPath.Combine(FOutputPath, LValue.Substring(0, LIdx)));
      end;
    end;

    Result := not FProjectName.IsEmpty;
  finally
    LLines.Free();
  end;
end;

function TMorBuild.SaveBuildFile(): Boolean;
var
  LBuildZigPath: string;
  LContent: string;
  LUTF8NoBOM: TEncoding;
begin
  Result := False;

  // Validate output path
  if FOutputPath = '' then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_ZIGBUILD_NO_OUTPUT_PATH, RSZigBuildNoOutputPath);
    Exit;
  end;

  // Validate source files
  if FSourceFiles.Count = 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_ZIGBUILD_NO_SOURCES, RSZigBuildNoSources);
    Exit;
  end;

  // Generate build.zig path and ensure directory exists
  LBuildZigPath := TPath.Combine(FOutputPath, 'build.zig');
  TMorUtils.CreateDirInPath(LBuildZigPath);
  LContent := GenerateBuildZig();

  // Write without BOM - Zig doesn't accept BOM in source files
  LUTF8NoBOM := TUTF8Encoding.Create(False);
  try
    try
      TFile.WriteAllText(LBuildZigPath, LContent, LUTF8NoBOM);
      Result := True;
    except
      on E: Exception do
      begin
        if Assigned(FErrors) then
          FErrors.Add(esError, ERR_ZIGBUILD_SAVE_FAILED, Format(RSZigBuildSaveFailed, [E.Message]));
      end;
    end;
  finally
    LUTF8NoBOM.Free();
  end;
end;

function TMorBuild.Process(const AAutoRun: Boolean): Boolean;
var
  LZigExe: string;
  LI: Integer;
  LSrcPath: string;
  LDestPath: string;
  LDestDir: string;
  LOutputFile: string;
begin
  Result := False;

  // Show target platform status
  Status(RSZigBuildTargetPlatform, [GetTargetDisplayName()]);
  Status(RSZigBuildOptimizeLevel, [GetOptimizeLevelDisplayName()]);
  if FTarget = tpWin64 then
    Status(RSZigBuildSubsystem, [GetSubsystemDisplayName()]);

  // Always save build file first
  Status(RSZigBuildSaving);
  if not SaveBuildFile() then
    Exit;

  // Find zig executable
  LZigExe := GetZigPath('zig.exe');
  if (LZigExe = '') or (not TFile.Exists(LZigExe)) then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_ZIGBUILD_ZIG_NOT_FOUND,
        RSZigBuildZigNotFound, [LZigExe]);
    Exit;
  end;

  // Set environment variables for color output
  TMorUtils.SetEnv('YES_COLOR', '1');
  TMorUtils.SetEnv('CLICOLOR_FORCE', '1');
  TMorUtils.SetEnv('TERM', 'xterm-256color');

  // Run zig build
  Status(RSZigBuildBuilding, [FProjectName]);
  TMorUtils.CaptureZigConsolePTY(
    PChar(LZigExe),
    'build --color auto --summary none --multiline-errors newline --error-style minimal',
    FOutputPath,
    FLastExitCode,
    nil,
    HandleOutputLine
  );

  if FLastExitCode <> 0 then
  begin
    Status(RSZigBuildFailedWithCode, [FLastExitCode]);
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_ZIGBUILD_BUILD_FAILED,
        RSZigBuildFailed, [FLastExitCode]);
    Exit;
  end;

  Status(RSZigBuildSucceeded);

  // Report full path of the built artifact
  if FBuildMode = bmLib then
    LOutputFile := TPath.Combine(FOutputPath, TPath.Combine('zig-out', TPath.Combine('lib', GetOutputFilename())))
  else
    LOutputFile := TPath.Combine(FOutputPath, TPath.Combine('zig-out', TPath.Combine('bin', GetOutputFilename())));
  Status(RSZigBuildOutput, [TMorUtils.NormalizePath(TPath.GetFullPath(LOutputFile))]);

  // Copy DLLs to output directory
  if FCopyDLLs.Count > 0 then
  begin
    LDestDir := TPath.Combine(FOutputPath, TPath.Combine('zig-out', 'bin'));
    for LI := 0 to FCopyDLLs.Count - 1 do
    begin
      LSrcPath := FCopyDLLs[LI];
      if not TPath.IsPathRooted(LSrcPath) then
        LSrcPath := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), LSrcPath);

      // Skip copy if src is already in dest dir
      if SameText(TPath.GetFullPath(TPath.GetDirectoryName(LSrcPath)), TPath.GetFullPath(LDestDir)) then
        Continue;

      if TFile.Exists(LSrcPath) then
      begin
        LDestPath := TPath.Combine(LDestDir, TPath.GetFileName(LSrcPath));
        Status(RSZigBuildCopying, [TPath.GetFileName(LSrcPath)]);
        TFile.Copy(LSrcPath, LDestPath, True);
      end
      else if Assigned(FErrors) then
        FErrors.Add(esWarning, WRN_ZIGBUILD_CANNOT_RUN_CROSS, Format(RSZigBuildDllNotFound, [LSrcPath]));
    end;
  end;

  // Apply post-build resources (manifest, icon, version info)
  ApplyPostBuildResources(LOutputFile);

  // Write breakpoints file if any were collected
  WriteBreakpointsFile(LOutputFile);

  if AAutoRun then
    Result := Run()
  else
    Result := True;
end;

function TMorBuild.Run(): Boolean;
var
  LExePath: string;
  LWslPath: string;
begin
  Result := False;

  // Can only run executables
  if FBuildMode <> bmExe then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_ZIGBUILD_BUILD_FAILED, RSZigBuildCannotRunLib);
    Exit;
  end;

  // Can only run Win64 and Linux64 targets
  if not (FTarget in [tpWin64, tpLinux64]) then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esWarning, WRN_ZIGBUILD_CANNOT_RUN_CROSS, Format(RSZigBuildCannotRunCross, [GetTargetDisplayName()]));
    Result := True;
    Exit;
  end;

  // Validate project name
  if FProjectName = '' then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_ZIGBUILD_NO_OUTPUT_PATH, RSZigBuildNoProjectName);
    Exit;
  end;

  // Build exe path
  LExePath := TPath.Combine(FOutputPath, TPath.Combine('zig-out', TPath.Combine('bin', GetOutputFilename())));

  if not TFile.Exists(LExePath) then
  begin
    FLastExitCode := 2;
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_ZIGBUILD_BUILD_FAILED, Format(RSZigBuildExeNotFound, [LExePath]));
    Exit;
  end;

  // Run the exe and capture output
  Status(RSZigBuildRunning, [GetOutputFilename()]);

  if FTarget = tpLinux64 then
  begin
    // Convert to WSL path and chmod +x before running
    LWslPath := TMorUtils.WindowsPathToWSL(LExePath);
    TMorUtils.CaptureZigConsolePTY('wsl.exe', PChar('chmod +x "' + LWslPath + '"'), TPath.GetDirectoryName(LExePath), FLastExitCode, nil, nil);
    TMorUtils.CaptureZigConsolePTY(
      'wsl.exe',
      PChar('"' + LWslPath + '"'),
      TPath.GetDirectoryName(LExePath),
      FLastExitCode,
      nil,
      HandleOutputLine
    );
  end
  else
  begin
    TMorUtils.CaptureZigConsolePTY(
      PChar(LExePath),
      '',
      TPath.GetDirectoryName(LExePath),
      FLastExitCode,
      nil,
      HandleOutputLine
    );
  end;

  if FLastExitCode <> 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_ZIGBUILD_BUILD_FAILED, Format(RSZigBuildRunFailed, [FLastExitCode]));
    Exit;
  end;

  Result := True;
end;

function TMorBuild.ClearCache(): Boolean;
var
  LCachePath: string;
begin
  Result := True;
  LCachePath := TPath.Combine(FOutputPath, '.zig-cache');
  if TDirectory.Exists(LCachePath) then
    TDirectory.Delete(LCachePath, True);
end;

function TMorBuild.ClearOutput(): Boolean;
var
  LOutputDir: string;
begin
  Result := True;
  LOutputDir := TPath.Combine(FOutputPath, 'zig-out');
  if TDirectory.Exists(LOutputDir) then
    TDirectory.Delete(LOutputDir, True);
end;

// Version info / post-build resources

procedure TMorBuild.ApplyPostBuildResources(const AExePath: string);
var
  LIsExe: Boolean;
  LIsDll: Boolean;
begin
  LIsExe := AExePath.EndsWith('.exe', True);
  LIsDll := AExePath.EndsWith('.dll', True);
  if not LIsExe and not LIsDll then
    Exit;

  // Add manifest to executable
  if LIsExe then
  begin
    if TMorUtils.ResourceExist('EXE_MANIFEST') then
      if not TMorUtils.AddResManifestFromResource('EXE_MANIFEST', AExePath) then
        if Assigned(FErrors) then
          FErrors.Add(esWarning, 'W980',
            'Failed to add manifest to executable', []);
  end;

  // Embed icon
  if LIsExe and (FExeIcon <> '') then
  begin
    if TFile.Exists(FExeIcon) then
      TMorUtils.UpdateIconResource(AExePath, FExeIcon)
    else if Assigned(FErrors) then
      FErrors.Add(esWarning, 'W982',
        'Icon file not found: %s', [FExeIcon]);
  end;

  // Stamp version info
  if FAddVersionInfo then
    TMorUtils.UpdateVersionInfoResource(AExePath,
      FVIMajor, FVIMinor, FVIPatch, FVIProductName,
      FVIDescription, FVIFilename, FVICompanyName, FVICopyright);
end;

procedure TMorBuild.SetAddVersionInfo(const AValue: Boolean);
begin
  FAddVersionInfo := AValue;
end;

function TMorBuild.GetAddVersionInfo(): Boolean;
begin
  Result := FAddVersionInfo;
end;

procedure TMorBuild.SetVIMajor(const AValue: Word);
begin
  FVIMajor := AValue;
end;

function TMorBuild.GetVIMajor(): Word;
begin
  Result := FVIMajor;
end;

procedure TMorBuild.SetVIMinor(const AValue: Word);
begin
  FVIMinor := AValue;
end;

function TMorBuild.GetVIMinor(): Word;
begin
  Result := FVIMinor;
end;

procedure TMorBuild.SetVIPatch(const AValue: Word);
begin
  FVIPatch := AValue;
end;

function TMorBuild.GetVIPatch(): Word;
begin
  Result := FVIPatch;
end;

procedure TMorBuild.SetVIProductName(const AValue: string);
begin
  FVIProductName := AValue;
end;

function TMorBuild.GetVIProductName(): string;
begin
  Result := FVIProductName;
end;

procedure TMorBuild.SetVIDescription(const AValue: string);
begin
  FVIDescription := AValue;
end;

function TMorBuild.GetVIDescription(): string;
begin
  Result := FVIDescription;
end;

procedure TMorBuild.SetVIFilename(const AValue: string);
begin
  FVIFilename := AValue;
end;

function TMorBuild.GetVIFilename(): string;
begin
  Result := FVIFilename;
end;

procedure TMorBuild.SetVICompanyName(const AValue: string);
begin
  FVICompanyName := AValue;
end;

function TMorBuild.GetVICompanyName(): string;
begin
  Result := FVICompanyName;
end;

procedure TMorBuild.SetVICopyright(const AValue: string);
begin
  FVICopyright := AValue;
end;

function TMorBuild.GetVICopyright(): string;
begin
  Result := FVICopyright;
end;

procedure TMorBuild.SetExeIcon(const AValue: string);
begin
  FExeIcon := AValue;
end;

function TMorBuild.GetExeIcon(): string;
begin
  Result := FExeIcon;
end;

// Breakpoints

procedure TMorBuild.AddBreakpoint(const AFileName: string; const ALineNumber: Integer);
var
  LEntry: TMorBreakpointEntry;
begin
  LEntry.FileName := AFileName;
  LEntry.LineNumber := ALineNumber;
  FBreakpoints.Add(LEntry);
end;

procedure TMorBuild.ClearBreakpoints();
begin
  FBreakpoints.Clear();
end;

function TMorBuild.GetBreakpoints(): TArray<TMorBreakpointEntry>;
begin
  Result := FBreakpoints.ToArray();
end;

procedure TMorBuild.WriteBreakpointsFile(const AExePath: string);
var
  LBreakpointFile: string;
  LConfig: TMorConfig;
  LExeDir: string;
  LRelativePath: string;
  LI: Integer;
  LIndex: Integer;
begin
  if FBreakpoints.Count = 0 then
    Exit;

  LBreakpointFile := TPath.ChangeExtension(AExePath, MOR_BREAKPOINT_EXT);
  LExeDir := TPath.GetDirectoryName(AExePath);

  LConfig := TMorConfig.Create();
  try
    for LI := 0 to FBreakpoints.Count - 1 do
    begin
      LIndex := LConfig.AddTableEntry('breakpoints');
      LRelativePath := ExtractRelativePath(LExeDir + PathDelim, FBreakpoints[LI].FileName);
      LRelativePath := LRelativePath.Replace('\', '/');
      LConfig.SetTableString('breakpoints', LIndex, 'file', LRelativePath);
      LConfig.SetTableInteger('breakpoints', LIndex, 'line', FBreakpoints[LI].LineNumber);
    end;
    LConfig.SaveToFile(LBreakpointFile);
  finally
    LConfig.Free();
  end;
end;

// -- Toolchain paths ----------------------------------------------------------

procedure TMorBuild.SetToolchainPath(const APath: string);
begin
  if APath = '' then
    FToolchainPath := TPath.Combine(
      TPath.GetDirectoryName(ParamStr(0)),
      'toolchain'
    )
  else
  begin
    if not TPath.IsPathRooted(APath) then
      FToolchainPath := TPath.Combine(
        TPath.GetDirectoryName(ParamStr(0)),
        APath
      )
    else
      FToolchainPath := APath;
    FToolchainPath := TPath.Combine(FToolchainPath, 'toolchain');
  end;

  // Persist the raw value (empty or user-provided)
  FBuildConfig.SetString('build.toolchain_path', APath);
end;

function TMorBuild.GetToolchainPath(): string;
begin
  Result := FToolchainPath;
end;

function TMorBuild.GetZigPath(const AFilename: string): string;
begin
  Result := TPath.Combine(FToolchainPath, 'zig');
  if AFilename <> '' then
    Result := TPath.Combine(Result, AFilename);
end;

function TMorBuild.GetRuntimePath(const AFilename: string): string;
begin
  Result := TPath.Combine(FToolchainPath, 'runtime');
  if AFilename <> '' then
    Result := TPath.Combine(Result, AFilename);
end;

function TMorBuild.GetLibsPath(const AFilename: string): string;
begin
  Result := TPath.Combine(FToolchainPath, 'libs');
  if AFilename <> '' then
    Result := TPath.Combine(Result, AFilename);
end;

function TMorBuild.GetAssetsPath(const AFilename: string): string;
begin
  Result := TPath.Combine(FToolchainPath, 'assets');
  if AFilename <> '' then
    Result := TPath.Combine(Result, AFilename);
end;

end.
