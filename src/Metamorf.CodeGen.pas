{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.CodeGen;

{$I Metamorf.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  Metamorf.Utils,
  Metamorf.Resources,
  Metamorf.Common,
  Metamorf.LangConfig,
  Metamorf.IR;

type

  { TCodeGen }
  TCodeGen = class(TCodeGenBase)
  private
    // Keyed by unit name — each entry is an owned TIR with its own
    // header + source buffers. Single-unit mode uses the key 'default'.
    FUnits:     TObjectDictionary<string, TIR>;

    // Preserves the order in which units were emitted. SaveAllFiles()
    // writes them in this order so dependencies appear before dependents.
    FUnitOrder: TStringList;

    // Points to whichever TIR is currently being written to.
    // Set by GenerateUnit() before walking the AST. Not owned separately.
    FCurrentIR: TIR;

    // Language config — not owned. Passed through to each TIR.
    FConfig:    TLangConfig;

    // Mirrors the line directive setting — applied to each TIR in AcquireIR().
    FLineDirectives: Boolean;

    // Creates a new TIR for AUnitName, wires errors + config,
    // registers it in FUnits + FUnitOrder, and sets FCurrentIR.
    // Returns the new IR instance.
    function AcquireIR(const AUnitName: string): TIR;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Configuration — must be set before Generate() / GenerateUnit()
    procedure SetConfig(const AConfig: TLangConfig);

    // Enable or disable #line directive emission. Applied to each TIR
    // instance created by AcquireIR().
    procedure SetLineDirectives(const AEnabled: Boolean);

    // ---- Single-unit path ----

    // TCodeGenBase override. Creates IR under 'default', walks tree.
    // Equivalent to GenerateUnit('default', ARoot).
    function Generate(const ARoot: TASTNodeBase): Boolean; override;

    // Single-unit output convenience — reads the 'default' IR
    procedure SaveToFiles(const AHeaderPath, ASourcePath: string);
    function GetHeaderContent(): string;
    function GetSourceContent(): string;

    // ---- Multi-unit path ----

    // Process one unit's AST. Call once per unit in dependency order.
    // If AUnitName was already emitted, the call is silently skipped
    // (returns True). Returns False on error.
    function GenerateUnit(const AUnitName: string;
      const ARoot: TASTNodeBase): Boolean;

    // Write every unit's .h + .cpp pair into AOutputDir.
    // Files are named AUnitName.h and AUnitName.cpp.
    // Written in dependency order (the order GenerateUnit was called).
    procedure SaveAllFiles(const AOutputDir: string);

    // ---- Access ----

    // Returns the IR for a given unit name, or nil if not found
    function GetIR(const AUnitName: string): TIR;

    // Returns the IR currently being written to (set by GenerateUnit)
    function GetCurrentIR(): TIR;

    // Number of units emitted so far
    function GetUnitCount(): Integer;

    // Unit name by emission order index (0-based)
    function GetUnitNameByIndex(const AIndex: Integer): string;

    // True if a unit with this name has already been emitted
    function HasUnit(const AUnitName: string): Boolean;

    // Debug
    function Dump(const AId: Integer = 0): string; override;
  end;

implementation

const
  // Default unit name for the single-unit Generate() path
  DEFAULT_UNIT_NAME = 'default';

{ TCodeGen }

constructor TCodeGen.Create();
begin
  inherited;
  FUnits     := TObjectDictionary<string, TIR>.Create([doOwnsValues]);
  FUnitOrder := TStringList.Create();
  FCurrentIR      := nil;
  FConfig         := nil;
  FLineDirectives := False;
end;

destructor TCodeGen.Destroy();
begin
  FCurrentIR := nil;
  FConfig    := nil;
  FreeAndNil(FUnitOrder);
  FreeAndNil(FUnits);
  inherited;
end;

procedure TCodeGen.SetConfig(const AConfig: TLangConfig);
begin
  FConfig := AConfig;
end;

procedure TCodeGen.SetLineDirectives(const AEnabled: Boolean);
begin
  FLineDirectives := AEnabled;
end;

function TCodeGen.AcquireIR(const AUnitName: string): TIR;
var
  LIR:     TIR;
  LErrors: TErrors;
begin
  LIR := TIR.Create();

  // Wire shared errors so IR validation failures surface to the caller
  LErrors := GetErrors();
  if LErrors <> nil then
    LIR.SetErrors(LErrors);

  // Wire language config so IR can dispatch emit handlers
  if FConfig <> nil then
    LIR.SetConfig(FConfig);

  // Wire line directive setting
  LIR.SetLineDirectives(FLineDirectives);

  // Register and track
  FUnits.Add(AUnitName, LIR);
  FUnitOrder.Add(AUnitName);

  // Set as current
  FCurrentIR := LIR;

  Result := LIR;
end;

// ---- Single-unit path ----

function TCodeGen.Generate(
  const ARoot: TASTNodeBase): Boolean;
begin
  // Report the filename so the user can see what is being compiled to C++23
  if ARoot <> nil then
    Status('Generating code for %s...', [ARoot.GetToken().Filename])
  else
    Status('Generating code...');
  Result := GenerateUnit(DEFAULT_UNIT_NAME, ARoot);
end;

procedure TCodeGen.SaveToFiles(const AHeaderPath,
  ASourcePath: string);
var
  LIR: TIR;
begin
  LIR := GetIR(DEFAULT_UNIT_NAME);
  if LIR <> nil then
    LIR.SaveToFiles(AHeaderPath, ASourcePath);
end;

function TCodeGen.GetHeaderContent(): string;
var
  LIR: TIR;
begin
  LIR := GetIR(DEFAULT_UNIT_NAME);
  if LIR <> nil then
    Result := LIR.GetHeaderContent()
  else
    Result := '';
end;

function TCodeGen.GetSourceContent(): string;
var
  LIR: TIR;
begin
  LIR := GetIR(DEFAULT_UNIT_NAME);
  if LIR <> nil then
    Result := LIR.GetSourceContent()
  else
    Result := '';
end;

// ---- Multi-unit path ----

function TCodeGen.GenerateUnit(const AUnitName: string;
  const ARoot: TASTNodeBase): Boolean;
var
  LErrors: TErrors;
  LIR:     TIR;
begin
  Result := False;
  LErrors := GetErrors();

  // Validate unit name
  if AUnitName = '' then
  begin
    if LErrors <> nil then
      LErrors.Add(esError, ERR_CODEGEN_EMPTY_UNIT, RSCodeGenEmptyUnit);
    Exit;
  end;

  // Deduplicate — if this unit was already emitted, skip silently
  if FUnits.ContainsKey(AUnitName) then
  begin
    Result := True;
    Exit;
  end;

  // Validate AST root
  if ARoot = nil then
  begin
    if LErrors <> nil then
      LErrors.Add(esError, ERR_CODEGEN_NIL_ROOT, RSCodeGenNilRoot);
    Exit;
  end;

  // Validate config
  if FConfig = nil then
  begin
    if LErrors <> nil then
      LErrors.Add(esError, ERR_CODEGEN_NO_CONFIG, RSCodeGenNoConfig);
    Exit;
  end;

  // Create the IR for this unit and walk the AST
  LIR := AcquireIR(AUnitName);
  Result := LIR.Generate(ARoot);
end;

procedure TCodeGen.SaveAllFiles(const AOutputDir: string);
var
  LI:         Integer;
  LUnitName:  string;
  LIR:        TIR;
  LHeaderPath: string;
  LSourcePath: string;
begin
  // Ensure output directory exists (creates full chain)
  if AOutputDir <> '' then
    TUtils.CreateDirInPath(AOutputDir);

  // Write each unit in dependency order
  for LI := 0 to FUnitOrder.Count - 1 do
  begin
    LUnitName := FUnitOrder[LI];
    if FUnits.TryGetValue(LUnitName, LIR) then
    begin
      LHeaderPath := TPath.Combine(AOutputDir, LUnitName + '.h');
      LSourcePath := TPath.Combine(AOutputDir, LUnitName + '.cpp');
      LIR.SaveToFiles(LHeaderPath, LSourcePath);
    end;
  end;
end;

// ---- Access ----

function TCodeGen.GetIR(const AUnitName: string): TIR;
begin
  if not FUnits.TryGetValue(AUnitName, Result) then
    Result := nil;
end;

function TCodeGen.GetCurrentIR(): TIR;
begin
  Result := FCurrentIR;
end;

function TCodeGen.GetUnitCount(): Integer;
begin
  Result := FUnitOrder.Count;
end;

function TCodeGen.GetUnitNameByIndex(
  const AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex < FUnitOrder.Count) then
    Result := FUnitOrder[AIndex]
  else
    Result := '';
end;

function TCodeGen.HasUnit(const AUnitName: string): Boolean;
begin
  Result := FUnits.ContainsKey(AUnitName);
end;

// ---- Debug ----

function TCodeGen.Dump(const AId: Integer): string;
var
  LI:        Integer;
  LUnitName: string;
  LIR:       TIR;
begin
  Result := '';
  for LI := 0 to FUnitOrder.Count - 1 do
  begin
    LUnitName := FUnitOrder[LI];
    if FUnits.TryGetValue(LUnitName, LIR) then
    begin
      Result := Result +
        '=== UNIT: ' + LUnitName + ' ===' + sLineBreak +
        LIR.Dump(AId) + sLineBreak;
    end;
  end;
end;

end.
