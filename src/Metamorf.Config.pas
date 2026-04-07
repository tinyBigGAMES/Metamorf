{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Config;

{$I Metamorf.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.DateUtils,
  System.Generics.Collections,
  Metamorf.Utils,
  Metamorf.TOML;

type
  { TMorConfig }
  TMorConfig = class(TMorBaseObject)
  private
    FToml:      TToml;
    FLastError: string;
    FFilename:  string;

    function  NavigateToTable(const AKeyPath: string;
      const ACreateMissing: Boolean; out ATable: TToml;
      out AFinalKey: string): Boolean;
    function  GetValueAtPath(const AKeyPath: string;
      out AValue: TTomlValue): Boolean;
    procedure SerializeToml(const AToml: TToml;
      const ABuilder: TStringBuilder; const AIndent: Integer;
      const ATablePath: string);
    procedure SerializeValue(const AValue: TTomlValue;
      const ABuilder: TStringBuilder);
    function  EscapeString(const AValue: string): string;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // File operations
    function LoadFromFile(const AFilename: string): Boolean;
    function LoadFromString(const ASource: string): Boolean;
    function SaveToFile(const AFilename: string): Boolean;
    function GetLastError(): string;
    procedure Clear();

    // Key existence
    function HasKey(const AKeyPath: string): Boolean;

    // String
    function GetString(const AKeyPath: string;
      const ADefault: string = ''): string;
    procedure SetString(const AKeyPath: string; const AValue: string);

    // Integer
    function GetInteger(const AKeyPath: string;
      const ADefault: Int64 = 0): Int64;
    procedure SetInteger(const AKeyPath: string; const AValue: Int64);

    // Float
    function GetFloat(const AKeyPath: string;
      const ADefault: Double = 0.0): Double;
    procedure SetFloat(const AKeyPath: string; const AValue: Double);

    // Boolean
    function GetBoolean(const AKeyPath: string;
      const ADefault: Boolean = False): Boolean;
    procedure SetBoolean(const AKeyPath: string; const AValue: Boolean);

    // DateTime
    function GetDateTime(const AKeyPath: string;
      const ADefault: TDateTime = 0): TDateTime;
    procedure SetDateTime(const AKeyPath: string; const AValue: TDateTime);

    // String Array
    function GetStringArray(const AKeyPath: string): TArray<string>;
    procedure SetStringArray(const AKeyPath: string;
      const AValues: TArray<string>);

    // Integer Array
    function GetIntegerArray(const AKeyPath: string): TArray<Int64>;
    procedure SetIntegerArray(const AKeyPath: string;
      const AValues: TArray<Int64>);

    // Float Array
    function GetFloatArray(const AKeyPath: string): TArray<Double>;
    procedure SetFloatArray(const AKeyPath: string;
      const AValues: TArray<Double>);

    // Array of Tables access (for [[section]] syntax)
    function GetTableCount(const AKeyPath: string): Integer;
    function GetTableString(const AKeyPath: string; const AIndex: Integer;
      const AField: string; const ADefault: string = ''): string;
    function GetTableInteger(const AKeyPath: string; const AIndex: Integer;
      const AField: string; const ADefault: Int64 = 0): Int64;
    function GetTableFloat(const AKeyPath: string; const AIndex: Integer;
      const AField: string; const ADefault: Double = 0.0): Double;
    function GetTableBoolean(const AKeyPath: string; const AIndex: Integer;
      const AField: string; const ADefault: Boolean = False): Boolean;

    // Array of Tables write (for [[section]] syntax)
    function  AddTableEntry(const AKeyPath: string): Integer;
    procedure SetTableString(const AKeyPath: string; const AIndex: Integer;
      const AField: string; const AValue: string);
    procedure SetTableInteger(const AKeyPath: string; const AIndex: Integer;
      const AField: string; const AValue: Int64);
    procedure SetTableFloat(const AKeyPath: string; const AIndex: Integer;
      const AField: string; const AValue: Double);
    procedure SetTableBoolean(const AKeyPath: string; const AIndex: Integer;
      const AField: string; const AValue: Boolean);

    // Array of Tables — string array field access
    function GetTableStringArray(const AKeyPath: string;
      const AIndex: Integer; const AField: string): TArray<string>;
    procedure SetTableStringArray(const AKeyPath: string;
      const AIndex: Integer; const AField: string;
      const AValues: TArray<string>);
  end;

implementation

{ TMorConfig }

constructor TMorConfig.Create();
begin
  inherited;
  FToml      := nil;
  FLastError := '';
  FFilename  := '';
end;

destructor TMorConfig.Destroy();
begin
  Clear();
  inherited;
end;

procedure TMorConfig.Clear();
begin
  if Assigned(FToml) then
  begin
    FToml.Free();
    FToml := nil;
  end;
  FLastError := '';
  FFilename  := '';
end;

function TMorConfig.GetLastError(): string;
begin
  Result := FLastError;
end;

function TMorConfig.NavigateToTable(const AKeyPath: string;
  const ACreateMissing: Boolean; out ATable: TToml;
  out AFinalKey: string): Boolean;
var
  LParts: TArray<string>;
  LI:     Integer;
  LValue: TTomlValue;
begin
  Result    := False;
  ATable    := nil;
  AFinalKey := '';

  if not Assigned(FToml) then
    Exit;

  LParts := AKeyPath.Split(['.']);
  if Length(LParts) = 0 then
    Exit;

  AFinalKey := LParts[High(LParts)];
  ATable    := FToml;

  // Navigate through all parts except the last one
  for LI := 0 to High(LParts) - 1 do
  begin
    if ATable.TryGetValue(LParts[LI], LValue) then
    begin
      if LValue.Kind = tvkTable then
        ATable := LValue.AsTable()
      else
        Exit; // Path element is not a table
    end
    else if ACreateMissing then
      ATable := ATable.GetOrCreateTable(LParts[LI])
    else
      Exit; // Path not found
  end;

  Result := True;
end;

function TMorConfig.GetValueAtPath(const AKeyPath: string;
  out AValue: TTomlValue): Boolean;
var
  LTable:    TToml;
  LFinalKey: string;
begin
  Result := False;

  if not NavigateToTable(AKeyPath, False, LTable, LFinalKey) then
    Exit;

  Result := LTable.TryGetValue(LFinalKey, AValue);
end;

function TMorConfig.LoadFromFile(const AFilename: string): Boolean;
begin
  Result := False;
  Clear();

  if not TFile.Exists(AFilename) then
  begin
    FLastError := 'File not found: ' + AFilename;
    Exit;
  end;

  try
    FToml     := TToml.FromFile(AFilename);
    FFilename := AFilename;
    Result    := True;
  except
    on E: Exception do
    begin
      FLastError := 'Failed to parse TOML: ' + E.Message;
      FToml      := nil;
    end;
  end;
end;

function TMorConfig.LoadFromString(const ASource: string): Boolean;
begin
  Result := False;
  Clear();

  try
    FToml  := TToml.FromString(ASource);
    Result := True;
  except
    on E: Exception do
    begin
      FLastError := 'Failed to parse TOML: ' + E.Message;
      FToml      := nil;
    end;
  end;
end;

function TMorConfig.EscapeString(const AValue: string): string;
begin
  Result := AValue;
  Result := Result.Replace('\', '\\');
  Result := Result.Replace('"', '\"');
  Result := Result.Replace(#9,  '\t');
  Result := Result.Replace(#10, '\n');
  Result := Result.Replace(#13, '\r');
end;

procedure TMorConfig.SerializeValue(const AValue: TTomlValue;
  const ABuilder: TStringBuilder);
var
  LArray: TTomlArray;
  LI:     Integer;
begin
  if AValue.Kind = tvkString then
  begin
    if (Pos(#10, AValue.AsString()) > 0) or
       (Pos(#13, AValue.AsString()) > 0) then
      ABuilder.Append('"""' + #10 + AValue.AsString() + '"""')
    else
      ABuilder.Append('"' + EscapeString(AValue.AsString()) + '"');
  end
  else if AValue.Kind = tvkInteger then
    ABuilder.Append(IntToStr(AValue.AsInteger()))
  else if AValue.Kind = tvkFloat then
    ABuilder.Append(FloatToStr(AValue.AsFloat()))
  else if AValue.Kind = tvkBoolean then
  begin
    if AValue.AsBoolean() then
      ABuilder.Append('true')
    else
      ABuilder.Append('false');
  end
  else if AValue.Kind = tvkDateTime then
    ABuilder.Append(DateToISO8601(AValue.AsDateTime()))
  else if AValue.Kind = tvkArray then
  begin
    LArray := AValue.AsArray();
    if LArray.Count = 0 then
      ABuilder.Append('[]')
    else
    begin
      ABuilder.Append('[');
      for LI := 0 to LArray.Count - 1 do
      begin
        ABuilder.AppendLine();
        ABuilder.Append('  ');
        SerializeValue(LArray[LI], ABuilder);
        if LI < LArray.Count - 1 then
          ABuilder.Append(',');
      end;
      ABuilder.AppendLine();
      ABuilder.Append(']');
    end;
  end;
end;

procedure TMorConfig.SerializeToml(const AToml: TToml;
  const ABuilder: TStringBuilder; const AIndent: Integer;
  const ATablePath: string);
var
  LKeys:     TArray<string>;
  LKey:      string;
  LValue:    TTomlValue;
  LSubTable: TToml;
  LNewPath:  string;
  LArray:    TTomlArray;
  LI:        Integer;
  LItem:     TTomlValue;
begin
  LKeys := AToml.Keys;

  // First pass: simple scalar values
  for LKey in LKeys do
  begin
    if AToml.TryGetValue(LKey, LValue) then
    begin
      if (LValue.Kind <> tvkTable) and
         not ((LValue.Kind = tvkArray) and (LValue.AsArray().Count > 0) and
              (LValue.AsArray()[0].Kind = tvkTable)) then
      begin
        ABuilder.Append(LKey + ' = ');
        SerializeValue(LValue, ABuilder);
        ABuilder.AppendLine();
      end;
    end;
  end;

  // Second pass: nested tables
  for LKey in LKeys do
  begin
    if AToml.TryGetValue(LKey, LValue) then
    begin
      if LValue.Kind = tvkTable then
      begin
        if ATablePath = '' then
          LNewPath := LKey
        else
          LNewPath := ATablePath + '.' + LKey;

        ABuilder.AppendLine();
        ABuilder.AppendLine('[' + LNewPath + ']');

        LSubTable := LValue.AsTable();
        SerializeToml(LSubTable, ABuilder, AIndent, LNewPath);
      end;
    end;
  end;

  // Third pass: arrays of tables
  for LKey in LKeys do
  begin
    if AToml.TryGetValue(LKey, LValue) then
    begin
      if (LValue.Kind = tvkArray) and (LValue.AsArray().Count > 0) and
         (LValue.AsArray()[0].Kind = tvkTable) then
      begin
        if ATablePath = '' then
          LNewPath := LKey
        else
          LNewPath := ATablePath + '.' + LKey;

        LArray := LValue.AsArray();
        for LI := 0 to LArray.Count - 1 do
        begin
          LItem := LArray[LI];
          if LItem.Kind = tvkTable then
          begin
            ABuilder.AppendLine();
            ABuilder.AppendLine('[[' + LNewPath + ']]');
            SerializeToml(LItem.AsTable(), ABuilder, AIndent, '');
          end;
        end;
      end;
    end;
  end;
end;

function TMorConfig.SaveToFile(const AFilename: string): Boolean;
var
  LBuilder: TStringBuilder;
begin
  Result := False;

  if not Assigned(FToml) then
  begin
    FLastError := 'No configuration loaded';
    Exit;
  end;

  LBuilder := TStringBuilder.Create();
  try
    SerializeToml(FToml, LBuilder, 0, '');

    try
      TMorUtils.CreateDirInPath(AFilename);
      TFile.WriteAllText(AFilename,
        LBuilder.ToString().Trim() + #10, TEncoding.UTF8);
      FFilename := AFilename;
      Result    := True;
    except
      on E: Exception do
        FLastError := 'Failed to write file: ' + E.Message;
    end;
  finally
    LBuilder.Free();
  end;
end;

function TMorConfig.HasKey(const AKeyPath: string): Boolean;
var
  LValue: TTomlValue;
begin
  Result := GetValueAtPath(AKeyPath, LValue);
end;

// -- String -------------------------------------------------------------------

function TMorConfig.GetString(const AKeyPath: string;
  const ADefault: string): string;
var
  LValue: TTomlValue;
begin
  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkString) then
    Result := LValue.AsString()
  else
    Result := ADefault;
end;

procedure TMorConfig.SetString(const AKeyPath: string;
  const AValue: string);
var
  LTable:    TToml;
  LFinalKey: string;
begin
  if not Assigned(FToml) then
    FToml := TToml.Create();

  if NavigateToTable(AKeyPath, True, LTable, LFinalKey) then
    LTable.SetString(LFinalKey, AValue);
end;

// -- Integer ------------------------------------------------------------------

function TMorConfig.GetInteger(const AKeyPath: string;
  const ADefault: Int64): Int64;
var
  LValue: TTomlValue;
begin
  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkInteger) then
    Result := LValue.AsInteger()
  else
    Result := ADefault;
end;

procedure TMorConfig.SetInteger(const AKeyPath: string;
  const AValue: Int64);
var
  LTable:    TToml;
  LFinalKey: string;
begin
  if not Assigned(FToml) then
    FToml := TToml.Create();

  if NavigateToTable(AKeyPath, True, LTable, LFinalKey) then
    LTable.SetInteger(LFinalKey, AValue);
end;

// -- Float --------------------------------------------------------------------

function TMorConfig.GetFloat(const AKeyPath: string;
  const ADefault: Double): Double;
var
  LValue: TTomlValue;
begin
  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkFloat) then
    Result := LValue.AsFloat()
  else
    Result := ADefault;
end;

procedure TMorConfig.SetFloat(const AKeyPath: string;
  const AValue: Double);
var
  LTable:    TToml;
  LFinalKey: string;
begin
  if not Assigned(FToml) then
    FToml := TToml.Create();

  if NavigateToTable(AKeyPath, True, LTable, LFinalKey) then
    LTable.SetFloat(LFinalKey, AValue);
end;

// -- Boolean ------------------------------------------------------------------

function TMorConfig.GetBoolean(const AKeyPath: string;
  const ADefault: Boolean): Boolean;
var
  LValue: TTomlValue;
begin
  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkBoolean) then
    Result := LValue.AsBoolean()
  else
    Result := ADefault;
end;

procedure TMorConfig.SetBoolean(const AKeyPath: string;
  const AValue: Boolean);
var
  LTable:    TToml;
  LFinalKey: string;
begin
  if not Assigned(FToml) then
    FToml := TToml.Create();

  if NavigateToTable(AKeyPath, True, LTable, LFinalKey) then
    LTable.SetBoolean(LFinalKey, AValue);
end;

// -- DateTime -----------------------------------------------------------------

function TMorConfig.GetDateTime(const AKeyPath: string;
  const ADefault: TDateTime): TDateTime;
var
  LValue: TTomlValue;
begin
  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkDateTime) then
    Result := LValue.AsDateTime()
  else
    Result := ADefault;
end;

procedure TMorConfig.SetDateTime(const AKeyPath: string;
  const AValue: TDateTime);
var
  LTable:    TToml;
  LFinalKey: string;
begin
  if not Assigned(FToml) then
    FToml := TToml.Create();

  if NavigateToTable(AKeyPath, True, LTable, LFinalKey) then
    LTable.SetValue(LFinalKey, TTomlValue.CreateDateTime(AValue));
end;

// -- String Array -------------------------------------------------------------

function TMorConfig.GetStringArray(const AKeyPath: string): TArray<string>;
var
  LValue: TTomlValue;
  LArray: TTomlArray;
  LI:     Integer;
begin
  SetLength(Result, 0);

  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    SetLength(Result, LArray.Count);
    for LI := 0 to LArray.Count - 1 do
    begin
      if LArray[LI].Kind = tvkString then
        Result[LI] := LArray[LI].AsString()
      else
        Result[LI] := '';
    end;
  end;
end;

procedure TMorConfig.SetStringArray(const AKeyPath: string;
  const AValues: TArray<string>);
var
  LTable:    TToml;
  LFinalKey: string;
  LArray:    TTomlArray;
  LValue:    string;
begin
  if not Assigned(FToml) then
    FToml := TToml.Create();

  if NavigateToTable(AKeyPath, True, LTable, LFinalKey) then
  begin
    // Remove existing key to clear old array
    LTable.RemoveKey(LFinalKey);
    // Create new array and populate
    LArray := LTable.GetOrCreateArray(LFinalKey);
    for LValue in AValues do
      LArray.AddString(LValue);
  end;
end;

// -- Integer Array ------------------------------------------------------------

function TMorConfig.GetIntegerArray(const AKeyPath: string): TArray<Int64>;
var
  LValue: TTomlValue;
  LArray: TTomlArray;
  LI:     Integer;
begin
  SetLength(Result, 0);

  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    SetLength(Result, LArray.Count);
    for LI := 0 to LArray.Count - 1 do
    begin
      if LArray[LI].Kind = tvkInteger then
        Result[LI] := LArray[LI].AsInteger()
      else
        Result[LI] := 0;
    end;
  end;
end;

procedure TMorConfig.SetIntegerArray(const AKeyPath: string;
  const AValues: TArray<Int64>);
var
  LTable:    TToml;
  LFinalKey: string;
  LArray:    TTomlArray;
  LValue:    Int64;
begin
  if not Assigned(FToml) then
    FToml := TToml.Create();

  if NavigateToTable(AKeyPath, True, LTable, LFinalKey) then
  begin
    LTable.RemoveKey(LFinalKey);
    LArray := LTable.GetOrCreateArray(LFinalKey);
    for LValue in AValues do
      LArray.AddInteger(LValue);
  end;
end;

// -- Float Array --------------------------------------------------------------

function TMorConfig.GetFloatArray(const AKeyPath: string): TArray<Double>;
var
  LValue: TTomlValue;
  LArray: TTomlArray;
  LI:     Integer;
begin
  SetLength(Result, 0);

  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    SetLength(Result, LArray.Count);
    for LI := 0 to LArray.Count - 1 do
    begin
      if LArray[LI].Kind = tvkFloat then
        Result[LI] := LArray[LI].AsFloat()
      else
        Result[LI] := 0.0;
    end;
  end;
end;

procedure TMorConfig.SetFloatArray(const AKeyPath: string;
  const AValues: TArray<Double>);
var
  LTable:    TToml;
  LFinalKey: string;
  LArray:    TTomlArray;
  LValue:    Double;
begin
  if not Assigned(FToml) then
    FToml := TToml.Create();

  if NavigateToTable(AKeyPath, True, LTable, LFinalKey) then
  begin
    LTable.RemoveKey(LFinalKey);
    LArray := LTable.GetOrCreateArray(LFinalKey);
    for LValue in AValues do
      LArray.AddFloat(LValue);
  end;
end;

// -- Array of Tables (read) ---------------------------------------------------

function TMorConfig.GetTableCount(const AKeyPath: string): Integer;
var
  LValue: TTomlValue;
begin
  Result := 0;

  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
    Result := LValue.AsArray().Count;
end;

function TMorConfig.GetTableString(const AKeyPath: string;
  const AIndex: Integer; const AField: string;
  const ADefault: string): string;
var
  LValue:      TTomlValue;
  LArray:      TTomlArray;
  LTable:      TToml;
  LFieldValue: TTomlValue;
begin
  Result := ADefault;

  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    if (AIndex >= 0) and (AIndex < LArray.Count) and
       (LArray[AIndex].Kind = tvkTable) then
    begin
      LTable := LArray[AIndex].AsTable();
      if LTable.TryGetValue(AField, LFieldValue) and
         (LFieldValue.Kind = tvkString) then
        Result := LFieldValue.AsString();
    end;
  end;
end;

function TMorConfig.GetTableInteger(const AKeyPath: string;
  const AIndex: Integer; const AField: string;
  const ADefault: Int64): Int64;
var
  LValue:      TTomlValue;
  LArray:      TTomlArray;
  LTable:      TToml;
  LFieldValue: TTomlValue;
begin
  Result := ADefault;

  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    if (AIndex >= 0) and (AIndex < LArray.Count) and
       (LArray[AIndex].Kind = tvkTable) then
    begin
      LTable := LArray[AIndex].AsTable();
      if LTable.TryGetValue(AField, LFieldValue) and
         (LFieldValue.Kind = tvkInteger) then
        Result := LFieldValue.AsInteger();
    end;
  end;
end;

function TMorConfig.GetTableFloat(const AKeyPath: string;
  const AIndex: Integer; const AField: string;
  const ADefault: Double): Double;
var
  LValue:      TTomlValue;
  LArray:      TTomlArray;
  LTable:      TToml;
  LFieldValue: TTomlValue;
begin
  Result := ADefault;

  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    if (AIndex >= 0) and (AIndex < LArray.Count) and
       (LArray[AIndex].Kind = tvkTable) then
    begin
      LTable := LArray[AIndex].AsTable();
      if LTable.TryGetValue(AField, LFieldValue) and
         (LFieldValue.Kind = tvkFloat) then
        Result := LFieldValue.AsFloat();
    end;
  end;
end;

function TMorConfig.GetTableBoolean(const AKeyPath: string;
  const AIndex: Integer; const AField: string;
  const ADefault: Boolean): Boolean;
var
  LValue:      TTomlValue;
  LArray:      TTomlArray;
  LTable:      TToml;
  LFieldValue: TTomlValue;
begin
  Result := ADefault;

  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    if (AIndex >= 0) and (AIndex < LArray.Count) and
       (LArray[AIndex].Kind = tvkTable) then
    begin
      LTable := LArray[AIndex].AsTable();
      if LTable.TryGetValue(AField, LFieldValue) and
         (LFieldValue.Kind = tvkBoolean) then
        Result := LFieldValue.AsBoolean();
    end;
  end;
end;

// -- Array of Tables (write) --------------------------------------------------

function TMorConfig.AddTableEntry(const AKeyPath: string): Integer;
var
  LTable:    TToml;
  LFinalKey: string;
  LArray:    TTomlArray;
  LNewTable: TToml;
begin
  Result := -1;

  if not Assigned(FToml) then
    FToml := TToml.Create();

  if NavigateToTable(AKeyPath, True, LTable, LFinalKey) then
  begin
    LArray    := LTable.GetOrCreateArray(LFinalKey);
    LNewTable := LTable.CreateOwnedTable();
    LArray.Add(TTomlValue.CreateTable(LNewTable));
    Result := LArray.Count - 1;
  end;
end;

procedure TMorConfig.SetTableString(const AKeyPath: string;
  const AIndex: Integer; const AField: string; const AValue: string);
var
  LValue: TTomlValue;
  LArray: TTomlArray;
  LTable: TToml;
begin
  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    if (AIndex >= 0) and (AIndex < LArray.Count) and
       (LArray[AIndex].Kind = tvkTable) then
    begin
      LTable := LArray[AIndex].AsTable();
      LTable.SetString(AField, AValue);
    end;
  end;
end;

procedure TMorConfig.SetTableInteger(const AKeyPath: string;
  const AIndex: Integer; const AField: string; const AValue: Int64);
var
  LValue: TTomlValue;
  LArray: TTomlArray;
  LTable: TToml;
begin
  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    if (AIndex >= 0) and (AIndex < LArray.Count) and
       (LArray[AIndex].Kind = tvkTable) then
    begin
      LTable := LArray[AIndex].AsTable();
      LTable.SetInteger(AField, AValue);
    end;
  end;
end;

procedure TMorConfig.SetTableFloat(const AKeyPath: string;
  const AIndex: Integer; const AField: string; const AValue: Double);
var
  LValue: TTomlValue;
  LArray: TTomlArray;
  LTable: TToml;
begin
  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    if (AIndex >= 0) and (AIndex < LArray.Count) and
       (LArray[AIndex].Kind = tvkTable) then
    begin
      LTable := LArray[AIndex].AsTable();
      LTable.SetFloat(AField, AValue);
    end;
  end;
end;

procedure TMorConfig.SetTableBoolean(const AKeyPath: string;
  const AIndex: Integer; const AField: string; const AValue: Boolean);
var
  LValue: TTomlValue;
  LArray: TTomlArray;
  LTable: TToml;
begin
  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    if (AIndex >= 0) and (AIndex < LArray.Count) and
       (LArray[AIndex].Kind = tvkTable) then
    begin
      LTable := LArray[AIndex].AsTable();
      LTable.SetBoolean(AField, AValue);
    end;
  end;
end;

// -- Array of Tables — string array field ------------------------------------

function TMorConfig.GetTableStringArray(const AKeyPath: string;
  const AIndex: Integer; const AField: string): TArray<string>;
var
  LValue:      TTomlValue;
  LArray:      TTomlArray;
  LTable:      TToml;
  LFieldValue: TTomlValue;
  LFieldArray: TTomlArray;
  LI:          Integer;
begin
  SetLength(Result, 0);

  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    if (AIndex >= 0) and (AIndex < LArray.Count) and
       (LArray[AIndex].Kind = tvkTable) then
    begin
      LTable := LArray[AIndex].AsTable();
      if LTable.TryGetValue(AField, LFieldValue) and
         (LFieldValue.Kind = tvkArray) then
      begin
        LFieldArray := LFieldValue.AsArray();
        SetLength(Result, LFieldArray.Count);
        for LI := 0 to LFieldArray.Count - 1 do
        begin
          if LFieldArray[LI].Kind = tvkString then
            Result[LI] := LFieldArray[LI].AsString()
          else
            Result[LI] := '';
        end;
      end;
    end;
  end;
end;

procedure TMorConfig.SetTableStringArray(const AKeyPath: string;
  const AIndex: Integer; const AField: string;
  const AValues: TArray<string>);
var
  LValue:      TTomlValue;
  LArray:      TTomlArray;
  LTable:      TToml;
  LFieldArray: TTomlArray;
  LItem:       string;
begin
  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    if (AIndex >= 0) and (AIndex < LArray.Count) and
       (LArray[AIndex].Kind = tvkTable) then
    begin
      LTable := LArray[AIndex].AsTable();
      LTable.RemoveKey(AField);
      LFieldArray := LTable.GetOrCreateArray(AField);
      for LItem in AValues do
        LFieldArray.AddString(LItem);
    end;
  end;
end;

end.
