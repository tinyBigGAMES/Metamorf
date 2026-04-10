{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.AST;

{$I Metamorf.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.TypInfo,
  System.Generics.Collections,
  Metamorf.Utils;

type

  { TMorToken }
  TMorToken = record
    Kind: string;
    Text: string;
    Filename: string;
    Line: Integer;
    Col: Integer;
  end;

  { TMorASTNode }
  TMorASTNode = class(TMorBaseObject)
  private
    FKind: string;
    FToken: TMorToken;
    FAttrs: TDictionary<string, string>;
    FChildren: TObjectList<TMorASTNode>;
    FNamedChildren: TDictionary<string, TMorASTNode>;
    FRange: TMorSourceRange;

  public
    constructor Create(); override;
    destructor Destroy(); override;
    function Dump(const AId: Integer = 0): string; override;

    // Kind
    function GetKind(): string;
    procedure SetKind(const AKind: string);

    // Token
    function GetToken(): TMorToken;
    procedure SetToken(const AToken: TMorToken);

    // Attribute access
    function GetAttr(const AKey: string): string;
    procedure SetAttr(const AKey: string; const AValue: string);
    function HasAttr(const AKey: string): Boolean;

    // Child management
    function ChildCount(): Integer;
    function GetChild(const AIndex: Integer): TMorASTNode;
    procedure AddChild(const AChild: TMorASTNode);

    // Named child access
    function GetNamedChild(const AName: string): TMorASTNode;
    procedure SetNamedChild(const AName: string; const AChild: TMorASTNode);
    function HasNamedChild(const AName: string): Boolean;

    // Source range
    function GetRange(): TMorSourceRange;
    procedure SetRange(const ARange: TMorSourceRange);

    // AST serialization
    procedure SaveToStream(const AStream: TStream);
    class function LoadFromStream(const AStream: TStream): TMorASTNode; static;
    class procedure SaveASTToStream(const ARoot: TMorASTNode; const AStream: TStream); static;
    class function LoadASTFromStream(const AStream: TStream): TMorASTNode; static;
  end;

// Helper functions for TValue operations
function MorIsTrue(const AValue: TValue): Boolean;
function MorToString(const AValue: TValue): string;

// Factory helper
function MorMakeToken(const AKind: string; const AText: string;
  const ALine: Integer; const ACol: Integer): TMorToken;

implementation

uses
  Metamorf.Common;

{ TMorToken }

function MorMakeToken(const AKind: string; const AText: string;
  const ALine: Integer; const ACol: Integer): TMorToken;
begin
  Result.Kind := AKind;
  Result.Text := AText;
  Result.Filename := '';
  Result.Line := ALine;
  Result.Col := ACol;
end;

{ TValue helpers }

function MorIsTrue(const AValue: TValue): Boolean;
begin
  if AValue.IsEmpty then
    Exit(False);

  if AValue.IsType<Boolean>() then
    Exit(AValue.AsBoolean());

  if (AValue.Kind = tkInt64) then
    Exit(AValue.AsInt64() <> 0);

  if (AValue.Kind = tkInteger) then
    Exit(AValue.AsInteger() <> 0);

  if (AValue.Kind = tkFloat) then
    Exit(AValue.AsExtended() <> 0.0);

  if AValue.IsType<string>() then
    Exit(AValue.AsString() <> '');

  if AValue.IsObject() then
    Exit(AValue.AsObject() <> nil);

  Result := False;
end;

function MorToString(const AValue: TValue): string;
begin
  if AValue.IsEmpty then
    Exit('nil');

  if AValue.IsType<string>() then
    Exit(AValue.AsString());

  if (AValue.Kind = tkInt64) then
    Exit(IntToStr(AValue.AsInt64()));

  if (AValue.Kind = tkInteger) then
    Exit(IntToStr(AValue.AsInteger()));

  if (AValue.Kind = tkFloat) then
    Exit(FloatToStr(AValue.AsExtended()));

  if AValue.IsType<Boolean>() then
  begin
    if AValue.AsBoolean() then
      Exit('true')
    else
      Exit('false');
  end;

  if AValue.IsObject() then
  begin
    if AValue.AsObject() = nil then
      Exit('nil');
    if AValue.AsObject() is TMorASTNode then
      Exit('<node:' + TMorASTNode(AValue.AsObject()).GetKind() + '>');
    Exit('<object>');
  end;

  Result := '<unknown>';
end;

{ TMorASTNode }

constructor TMorASTNode.Create();
begin
  inherited;
  FKind := '';
  FToken.Kind := '';
  FToken.Text := '';
  FToken.Filename := '';
  FToken.Line := 0;
  FToken.Col := 0;
  FAttrs := TDictionary<string, string>.Create();
  FChildren := TObjectList<TMorASTNode>.Create(True);
  FNamedChildren := TDictionary<string, TMorASTNode>.Create();
  FRange.Clear();
end;

destructor TMorASTNode.Destroy();
begin
  FreeAndNil(FNamedChildren);
  FreeAndNil(FChildren);
  FreeAndNil(FAttrs);
  inherited;
end;

function TMorASTNode.Dump(const AId: Integer): string;
var
  LIndent: string;
  LPair: TPair<string, string>;
  LI: Integer;
begin
  LIndent := StringOfChar(' ', AId * 2);
  Result := LIndent + FKind;

  // Append attributes inline
  for LPair in FAttrs do
    Result := Result + ' ' + LPair.Key + '="' + LPair.Value + '"';

  Result := Result + sLineBreak;

  // Dump children recursively
  for LI := 0 to FChildren.Count - 1 do
    Result := Result + FChildren[LI].Dump(AId + 1);
end;

function TMorASTNode.GetKind(): string;
begin
  Result := FKind;
end;

procedure TMorASTNode.SetKind(const AKind: string);
begin
  FKind := AKind;
  {$IFDEF MOR_LEAK_TRACK}
  LeakTrackUpdateLabel('kind=' + AKind);
  {$ENDIF}
end;

function TMorASTNode.GetToken(): TMorToken;
begin
  Result := FToken;
end;

procedure TMorASTNode.SetToken(const AToken: TMorToken);
begin
  FToken := AToken;
  {$IFDEF MOR_LEAK_TRACK}
  LeakTrackUpdateLabel('token=' + AToken.Text + ' @' +
    AToken.Filename + ':' + AToken.Line.ToString());
  {$ENDIF}
end;

function TMorASTNode.GetAttr(const AKey: string): string;
begin
  if not FAttrs.TryGetValue(AKey, Result) then
    Result := '';
end;

procedure TMorASTNode.SetAttr(const AKey: string; const AValue: string);
begin
  FAttrs.AddOrSetValue(AKey, AValue);
end;

function TMorASTNode.HasAttr(const AKey: string): Boolean;
begin
  Result := FAttrs.ContainsKey(AKey);
end;

function TMorASTNode.ChildCount(): Integer;
begin
  Result := FChildren.Count;
end;

function TMorASTNode.GetChild(const AIndex: Integer): TMorASTNode;
begin
  Result := FChildren[AIndex];
end;

procedure TMorASTNode.AddChild(const AChild: TMorASTNode);
begin
  FChildren.Add(AChild);
  {$IFDEF MOR_LEAK_TRACK}
  if Assigned(AChild) then
    AChild.LeakTrackUpdateLabel('parented');
  {$ENDIF}
end;

function TMorASTNode.GetNamedChild(const AName: string): TMorASTNode;
begin
  if not FNamedChildren.TryGetValue(AName, Result) then
    Result := nil;
end;

procedure TMorASTNode.SetNamedChild(const AName: string; const AChild: TMorASTNode);
begin
  FNamedChildren.AddOrSetValue(AName, AChild);
end;

function TMorASTNode.HasNamedChild(const AName: string): Boolean;
begin
  Result := FNamedChildren.ContainsKey(AName);
end;

function TMorASTNode.GetRange(): TMorSourceRange;
begin
  Result := FRange;
end;

procedure TMorASTNode.SetRange(const ARange: TMorSourceRange);
begin
  FRange := ARange;
end;

{ AST Serialization Helpers }

procedure WriteString(const AStream: TStream; const AValue: string);
var
  LBytes: TBytes;
  LLen: Integer;
begin
  LBytes := TEncoding.UTF8.GetBytes(AValue);
  LLen := Length(LBytes);
  AStream.WriteData<Integer>(LLen);
  if LLen > 0 then
    AStream.WriteBuffer(LBytes[0], LLen);
end;

function ReadString(const AStream: TStream): string;
var
  LBytes: TBytes;
  LLen: Integer;
begin
  AStream.ReadData<Integer>(LLen);
  if LLen > 0 then
  begin
    SetLength(LBytes, LLen);
    AStream.ReadBuffer(LBytes[0], LLen);
    Result := TEncoding.UTF8.GetString(LBytes);
  end
  else
    Result := '';
end;

{ AST Serialization Methods }

procedure TMorASTNode.SaveToStream(const AStream: TStream);
var
  LI: Integer;
  LCount: Integer;
  LPair: TPair<string, string>;
begin
  // 1. FKind
  WriteString(AStream, FKind);

  // 2-4. FToken fields
  WriteString(AStream, FToken.Kind);
  WriteString(AStream, FToken.Text);
  WriteString(AStream, FToken.Filename);

  // 5-6. FToken integer fields
  AStream.WriteData<Integer>(FToken.Line);
  AStream.WriteData<Integer>(FToken.Col);

  // 7. FAttrs: count then key+value pairs
  LCount := FAttrs.Count;
  AStream.WriteData<Integer>(LCount);
  for LPair in FAttrs do
  begin
    WriteString(AStream, LPair.Key);
    WriteString(AStream, LPair.Value);
  end;

  // 8. FRange.Filename
  WriteString(AStream, FRange.Filename);

  // 9. FRange integer fields (6x)
  AStream.WriteData<Integer>(FRange.StartLine);
  AStream.WriteData<Integer>(FRange.StartColumn);
  AStream.WriteData<Integer>(FRange.EndLine);
  AStream.WriteData<Integer>(FRange.EndColumn);
  AStream.WriteData<Integer>(FRange.StartByteOffset);
  AStream.WriteData<Integer>(FRange.EndByteOffset);

  // 10. FChildren: count then recurse
  LCount := FChildren.Count;
  AStream.WriteData<Integer>(LCount);
  for LI := 0 to LCount - 1 do
    FChildren[LI].SaveToStream(AStream);
end;

class function TMorASTNode.LoadFromStream(const AStream: TStream): TMorASTNode;
var
  LI: Integer;
  LCount: Integer;
  LKey: string;
  LValue: string;
  LChild: TMorASTNode;
begin
  Result := TMorASTNode.Create();
  try
    // 1. FKind
    Result.FKind := ReadString(AStream);

    // 2-4. FToken fields
    Result.FToken.Kind := ReadString(AStream);
    Result.FToken.Text := ReadString(AStream);
    Result.FToken.Filename := ReadString(AStream);

    // 5-6. FToken integer fields
    AStream.ReadData<Integer>(Result.FToken.Line);
    AStream.ReadData<Integer>(Result.FToken.Col);

    // 7. FAttrs
    AStream.ReadData<Integer>(LCount);
    for LI := 0 to LCount - 1 do
    begin
      LKey := ReadString(AStream);
      LValue := ReadString(AStream);
      Result.FAttrs.AddOrSetValue(LKey, LValue);
    end;

    // 8. FRange.Filename
    Result.FRange.Filename := ReadString(AStream);

    // 9. FRange integer fields (6x)
    AStream.ReadData<Integer>(Result.FRange.StartLine);
    AStream.ReadData<Integer>(Result.FRange.StartColumn);
    AStream.ReadData<Integer>(Result.FRange.EndLine);
    AStream.ReadData<Integer>(Result.FRange.EndColumn);
    AStream.ReadData<Integer>(Result.FRange.StartByteOffset);
    AStream.ReadData<Integer>(Result.FRange.EndByteOffset);

    // 10. FChildren
    AStream.ReadData<Integer>(LCount);
    for LI := 0 to LCount - 1 do
    begin
      LChild := TMorASTNode.LoadFromStream(AStream);
      Result.FChildren.Add(LChild);
    end;
  except
    Result.Free();
    raise;
  end;
end;

class procedure TMorASTNode.SaveASTToStream(const ARoot: TMorASTNode; const AStream: TStream);
var
  LReserved: Integer;
begin
  // Write header: magic + format version + reserved
  AStream.WriteData<Cardinal>(MOR_AST_MAGIC);
  AStream.WriteData<Integer>(MOR_AST_VERSION);
  LReserved := 0;
  AStream.WriteData<Integer>(LReserved);

  // Write the AST tree
  ARoot.SaveToStream(AStream);
end;

class function TMorASTNode.LoadASTFromStream(const AStream: TStream): TMorASTNode;
var
  LMagic: Cardinal;
  LVersion: Integer;
  LReserved: Integer;
begin
  // Read and validate header
  AStream.ReadData<Cardinal>(LMagic);
  if LMagic <> MOR_AST_MAGIC then
    raise Exception.Create('Invalid AST stream: bad magic number');

  AStream.ReadData<Integer>(LVersion);
  if LVersion > MOR_AST_VERSION then
    raise Exception.CreateFmt('Unsupported AST format version %d (max supported: %d)',
      [LVersion, MOR_AST_VERSION]);

  AStream.ReadData<Integer>(LReserved);

  // Load the AST tree
  Result := TMorASTNode.LoadFromStream(AStream);
end;

end.
