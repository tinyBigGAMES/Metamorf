{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Lang;

{$I Metamorf.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Metamorf.API,
  Metamorf.Lang.Common,
  Metamorf.Lang.Interp;

type

  { TMetamorfLang }
  TMetamorfLang = class(TOutputObject)
  private
    FBootstrapMetamorf: TMetamorf;
    FCustomMetamorf:  TMetamorf;
    FInterp:       TMetamorfLangInterpreter;

    FLangFile:   string;
    FSourceFile: string;
    FOutputPath: string;

    FLineDirectives:         Boolean;
    FLastErrorsFromBootstrap: Boolean;

    // Temp TMetamorf instances from import — keep alive for AST lifetime
    FImportedInstances: TObjectList<TMetamorf>;

    procedure FreeInstances();
    procedure ForwardSettingsToCustom();
    function  BuildPipelineCallbacks(): TMetamorfLangPipelineCallbacks;

  public
    constructor Create(); override;
    destructor  Destroy(); override;

    // ---- Language definition ----
    procedure SetLangFile(const AFilename: string);
    function  GetLangFile(): string;

    // ---- Source and output ----
    procedure SetSourceFile(const AFilename: string);
    function  GetSourceFile(): string;
    procedure SetOutputPath(const APath: string);
    function  GetOutputPath(): string;

    // ---- Callbacks ----
    procedure SetStatusCallback(const ACallback: TStatusCallback;
      const AUserData: Pointer = nil); override;
    procedure SetOutputCallback(const ACallback: TCaptureConsoleCallback;
      const AUserData: Pointer = nil); override;

    // ---- Code generation options ----
    procedure SetLineDirectives(const AEnabled: Boolean);
    function  GetLineDirectives(): Boolean;

    // ---- Error access ----
    function HasErrors(): Boolean;
    function GetErrors(): TErrors;

    // ---- Pipeline ----
    function Compile(const ABuild: Boolean = True;
      const AAutoRun: Boolean = False): Boolean;
    function Run(): Cardinal;
    function GetLastExitCode(): Cardinal;
    function GetVersionStr(): string;
  end;

implementation

uses
  System.IOUtils,
  Metamorf.Common,
  Metamorf.Cpp,
  Metamorf.Lang.Lexer,
  Metamorf.Lang.Grammar,
  Metamorf.Lang.Semantics;

{ TMetamorfLang }

constructor TMetamorfLang.Create();
begin
  inherited Create();
  FBootstrapMetamorf          := nil;
  FCustomMetamorf             := nil;
  FInterp                := nil;
  FLangFile                := '';
  FSourceFile              := '';
  FOutputPath              := '';
  FLineDirectives          := False;
  FLastErrorsFromBootstrap := False;
  FImportedInstances             := TObjectList<TMetamorf>.Create(True);
end;

destructor TMetamorfLang.Destroy();
begin
  FreeInstances();
  FreeAndNil(FImportedInstances);
  inherited Destroy();
end;

procedure TMetamorfLang.FreeInstances();
begin
  // FCustomMetamorf must be freed before FInterp/FBootstrapMetamorf because its
  // closures hold references to the interpreter and AST nodes.
  FreeAndNil(FCustomMetamorf);
  FreeAndNil(FInterp);
  // Imported TMetamorf instances own AST nodes referenced by closures —
  // free after FCustomMetamorf (closures) and FInterp (FImportedASTs list)
  FImportedInstances.Clear();
  FreeAndNil(FBootstrapMetamorf);
end;

procedure TMetamorfLang.ForwardSettingsToCustom();
begin
  if FCustomMetamorf = nil then
    Exit;

  FCustomMetamorf.SetSourceFile(FSourceFile);
  if FOutputPath <> '' then
    FCustomMetamorf.SetOutputPath(FOutputPath);

  FCustomMetamorf.SetStatusCallback(
    FStatusCallback.Callback, FStatusCallback.UserData);
  FCustomMetamorf.SetOutputCallback(
    FOutput.Callback, FOutput.UserData);
  FCustomMetamorf.SetLineDirectives(FLineDirectives);
end;

function TMetamorfLang.BuildPipelineCallbacks(): TMetamorfLangPipelineCallbacks;
begin
  // Each callback delegates directly into FCustomMetamorf. TMetamorf owns all
  // build config, version info, and post-build resources internally.

  Result.OnSetPlatform :=
    procedure(AValue: string)
    begin
      if AValue = 'win64'        then FCustomMetamorf.SetTargetPlatform(tpWin64)
      else if AValue = 'linux64' then FCustomMetamorf.SetTargetPlatform(tpLinux64);
    end;

  Result.OnSetBuildMode :=
    procedure(AValue: string)
    begin
      if AValue = 'exe'      then FCustomMetamorf.SetBuildMode(bmExe)
      else if AValue = 'lib' then FCustomMetamorf.SetBuildMode(bmLib)
      else if AValue = 'dll' then FCustomMetamorf.SetBuildMode(bmDll);
    end;

  Result.OnSetOptimize :=
    procedure(AValue: string)
    begin
      if AValue = 'debug'             then FCustomMetamorf.SetOptimizeLevel(olDebug)
      else if AValue = 'releasesafe'  then FCustomMetamorf.SetOptimizeLevel(olReleaseSafe)
      else if AValue = 'releasefast'  then FCustomMetamorf.SetOptimizeLevel(olReleaseFast)
      else if AValue = 'releasesmall' then FCustomMetamorf.SetOptimizeLevel(olReleaseSmall);
    end;

  Result.OnSetSubsystem :=
    procedure(AValue: string)
    begin
      if AValue = 'console'  then FCustomMetamorf.SetSubsystem(stConsole)
      else if AValue = 'gui' then FCustomMetamorf.SetSubsystem(stGui);
    end;

  Result.OnSetOutputPath :=
    procedure(AValue: string)
    begin
      FCustomMetamorf.SetOutputPath(AValue);
    end;

  Result.OnSetVIEnabled :=
    procedure(AValue: string)
    begin
      FCustomMetamorf.SetAddVersionInfo(
        SameText(AValue, 'true') or SameText(AValue, 'on'));
    end;

  Result.OnSetVIExeIcon :=
    procedure(AValue: string)
    begin
      FCustomMetamorf.SetExeIcon(AValue);
    end;

  Result.OnSetVIMajor :=
    procedure(AValue: string)
    begin
      FCustomMetamorf.SetVIMajor(Word(StrToIntDef(AValue, 0)));
    end;

  Result.OnSetVIMinor :=
    procedure(AValue: string)
    begin
      FCustomMetamorf.SetVIMinor(Word(StrToIntDef(AValue, 0)));
    end;

  Result.OnSetVIPatch :=
    procedure(AValue: string)
    begin
      FCustomMetamorf.SetVIPatch(Word(StrToIntDef(AValue, 0)));
    end;

  Result.OnSetVIProductName :=
    procedure(AValue: string)
    begin
      FCustomMetamorf.SetVIProductName(AValue);
    end;

  Result.OnSetVIDescription :=
    procedure(AValue: string)
    begin
      FCustomMetamorf.SetVIDescription(AValue);
    end;

  Result.OnSetVIFilename :=
    procedure(AValue: string)
    begin
      FCustomMetamorf.SetVIFilename(AValue);
    end;

  Result.OnSetVICompanyName :=
    procedure(AValue: string)
    begin
      FCustomMetamorf.SetVICompanyName(AValue);
    end;

  Result.OnSetVICopyright :=
    procedure(AValue: string)
    begin
      FCustomMetamorf.SetVICopyright(AValue);
    end;

  Result.OnAddSourceFile :=
    procedure(AValue: string)
    begin
      FCustomMetamorf.AddSourceFile(AValue);
    end;

  Result.OnAddIncludePath :=
    procedure(AValue: string)
    begin
      FCustomMetamorf.AddIncludePath(AValue);
    end;

  Result.OnAddLibraryPath :=
    procedure(AValue: string)
    begin
      FCustomMetamorf.AddLibraryPath(AValue);
    end;

  Result.OnAddLinkLibrary :=
    procedure(AValue: string)
    begin
      FCustomMetamorf.AddLinkLibrary(AValue);
    end;

  Result.OnSetDefine :=
    procedure(AName: string; AValue: string)
    begin
      if AValue = '' then
        FCustomMetamorf.SetDefine(AName)
      else
        FCustomMetamorf.SetDefine(AName, AValue);
    end;

  Result.OnHasDefine :=
    function(AName: string): Boolean
    begin
      Result := FCustomMetamorf.HasDefine(AName);
    end;

  Result.OnUnsetDefine :=
    procedure(AValue: string)
    begin
      FCustomMetamorf.UnsetDefine(AValue);
    end;

  Result.OnHasUndefine :=
    function(AName: string): Boolean
    begin
      Result := FCustomMetamorf.HasUndefine(AName);
    end;

  Result.OnAddCopyDLL :=
    procedure(AValue: string)
    begin
      FCustomMetamorf.AddCopyDLL(AValue);
    end;

  Result.OnSetModuleExtension :=
    procedure(AValue: string)
    begin
      FCustomMetamorf.Config().SetModuleExtension(AValue);
    end;
end;

// =========================================================================
// Public Setters
// =========================================================================

procedure TMetamorfLang.SetLangFile(const AFilename: string);
begin
  FLangFile := AFilename;
end;

function TMetamorfLang.GetLangFile(): string;
begin
  Result := FLangFile;
end;

procedure TMetamorfLang.SetSourceFile(const AFilename: string);
begin
  FSourceFile := AFilename;
end;

function TMetamorfLang.GetSourceFile(): string;
begin
  Result := FSourceFile;
end;

procedure TMetamorfLang.SetOutputPath(const APath: string);
begin
  FOutputPath := APath;
end;

function TMetamorfLang.GetOutputPath(): string;
begin
  Result := FOutputPath;
end;

procedure TMetamorfLang.SetLineDirectives(const AEnabled: Boolean);
begin
  FLineDirectives := AEnabled;
end;

function TMetamorfLang.GetLineDirectives(): Boolean;
begin
  Result := FLineDirectives;
end;

procedure TMetamorfLang.SetStatusCallback(
  const ACallback: TStatusCallback; const AUserData: Pointer);
begin
  inherited SetStatusCallback(ACallback, AUserData);
  if FBootstrapMetamorf <> nil then
    FBootstrapMetamorf.SetStatusCallback(ACallback, AUserData);
  if FCustomMetamorf <> nil then
    FCustomMetamorf.SetStatusCallback(ACallback, AUserData);
end;

procedure TMetamorfLang.SetOutputCallback(
  const ACallback: TCaptureConsoleCallback; const AUserData: Pointer);
begin
  inherited SetOutputCallback(ACallback, AUserData);
  if FBootstrapMetamorf <> nil then
    FBootstrapMetamorf.SetOutputCallback(ACallback, AUserData);
  if FCustomMetamorf <> nil then
    FCustomMetamorf.SetOutputCallback(ACallback, AUserData);
end;

// =========================================================================
// Error Access
// =========================================================================

function TMetamorfLang.HasErrors(): Boolean;
begin
  if FLastErrorsFromBootstrap then
  begin
    if FBootstrapMetamorf <> nil then
      Result := FBootstrapMetamorf.HasErrors()
    else
      Result := False;
  end
  else
  begin
    if FCustomMetamorf <> nil then
      Result := FCustomMetamorf.HasErrors()
    else
      Result := False;
  end;
end;

function TMetamorfLang.GetErrors(): TErrors;
begin
  if FLastErrorsFromBootstrap then
  begin
    if FBootstrapMetamorf <> nil then
      Result := FBootstrapMetamorf.GetErrors()
    else
      Result := nil;
  end
  else
  begin
    if FCustomMetamorf <> nil then
      Result := FCustomMetamorf.GetErrors()
    else
      Result := nil;
  end;
end;

// =========================================================================
// Compile
// =========================================================================

function TMetamorfLang.Compile(const ABuild: Boolean;
  const AAutoRun: Boolean): Boolean;
begin
  Result := False;

  if FLangFile = '' then
    raise Exception.Create('TMetamorfLang.Compile: LangFile not set');
  if not TFile.Exists(FLangFile) then
    raise Exception.CreateFmt(
      'TMetamorfLang.Compile: LangFile not found: %s', [FLangFile]);
  if FSourceFile = '' then
    raise Exception.Create('TMetamorfLang.Compile: SourceFile not set');

  FreeInstances();

  // =======================================================================
  // PHASE 1 — Parse the .pax language definition file
  // =======================================================================

  FBootstrapMetamorf := TMetamorf.Create();
  FCustomMetamorf    := TMetamorf.Create();

  FBootstrapMetamorf.SetStatusCallback(
    FStatusCallback.Callback, FStatusCallback.UserData);
  FBootstrapMetamorf.SetOutputCallback(
    FOutput.Callback, FOutput.UserData);

  ConfigLexer(FBootstrapMetamorf);
  ConfigGrammar(FBootstrapMetamorf);
  ConfigSemantics(FBootstrapMetamorf);

  ForwardSettingsToCustom();

  // Phase 1: parse + semantics only — no codegen emitters registered
  FBootstrapMetamorf.SetSourceFile(FLangFile);
  FBootstrapMetamorf.SetOutputPath(FOutputPath);
  FBootstrapMetamorf.Compile(False, False);

  FLastErrorsFromBootstrap := True;
  if FBootstrapMetamorf.HasErrors() then
    Exit;

  // Walk the Phase 1 AST with the new interpreter to configure FCustomMetamorf
  FInterp := TMetamorfLangInterpreter.Create();
  FInterp.SetErrors(FBootstrapMetamorf.GetErrors());
  FInterp.SetPipeline(BuildPipelineCallbacks());

  // Wire import callback — resolves .pax imports relative to main lang file
  FInterp.SetOnLoadDefinition(
    function(APath: string): TASTNode
    var
      LResolved: string;
      LImportMor: TMetamorf;
    begin
      Result := nil;
      LResolved := TPath.Combine(
        TPath.GetDirectoryName(FLangFile), APath);
      if not TFile.Exists(LResolved) then
        Exit;
      LImportMor := TMetamorf.Create();
      try
        ConfigLexer(LImportMor);
        ConfigGrammar(LImportMor);
        ConfigSemantics(LImportMor);
        LImportMor.SetSourceFile(LResolved);
        LImportMor.SetOutputPath(FOutputPath);
        LImportMor.Compile(False, False);
        if LImportMor.HasErrors() then
        begin
          LImportMor.Free();
          Exit;
        end;
        Result := LImportMor.GetProject() as TASTNode;
        FImportedInstances.Add(LImportMor);
      except
        LImportMor.Free();
        raise;
      end;
    end);

  if not FInterp.Execute(
    FBootstrapMetamorf.GetProject(), FCustomMetamorf) then
    Exit;

  // Register C++ passthrough emitters on the custom language
  ConfigCpp(FCustomMetamorf);

  // =======================================================================
  // PHASE 2 — Compile the user source file with the configured language
  // =======================================================================

  FLastErrorsFromBootstrap := False;

  // TMetamorf.Compile handles everything internally: codegen, Zig build,
  // ApplyPostBuildResources (icon, version info, manifest), and auto-run.
  Result := FCustomMetamorf.Compile(ABuild, AAutoRun);
end;

function TMetamorfLang.Run(): Cardinal;
begin
  if FCustomMetamorf <> nil then
    Result := FCustomMetamorf.Run()
  else
    Result := High(Cardinal);
end;

function TMetamorfLang.GetLastExitCode(): Cardinal;
begin
  if FCustomMetamorf <> nil then
    Result := FCustomMetamorf.GetLastExitCode()
  else
    Result := High(Cardinal);
end;

function TMetamorfLang.GetVersionStr(): string;
begin
  Result := METAMORF_VERSION_STR;
end;

end.
