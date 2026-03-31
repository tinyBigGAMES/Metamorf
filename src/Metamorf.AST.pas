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
  System.Rtti,
  System.TypInfo,
  System.Generics.Collections,
  Metamorf.Utils;

type

  { TToken }
  TToken = record
    Kind: string;
    Text: string;
    Filename: string;
    Line: Integer;
    Col: Integer;
  end;

  { TASTNode }
  TASTNode = class(TBaseObject)
  private
    FKind: string;
    FToken: TToken;
    FAttrs: TDictionary<string, string>;
    FChildren: TObjectList<TASTNode>;
    FNamedChildren: TDictionary<string, TASTNode>;

  public
    constructor Create(); override;
    destructor Destroy(); override;
    function Dump(const AId: Integer = 0): string; override;

    // Kind
    function GetKind(): string;
    procedure SetKind(const AKind: string);

    // Token
    function GetToken(): TToken;
    procedure SetToken(const AToken: TToken);

    // Attribute access
    function GetAttr(const AKey: string): string;
    procedure SetAttr(const AKey: string; const AValue: string);
    function HasAttr(const AKey: string): Boolean;

    // Child management
    function ChildCount(): Integer;
    function GetChild(const AIndex: Integer): TASTNode;
    procedure AddChild(const AChild: TASTNode);

    // Named child access
    function GetNamedChild(const AName: string): TASTNode;
    procedure SetNamedChild(const AName: string; const AChild: TASTNode);
    function HasNamedChild(const AName: string): Boolean;
  end;

// Helper functions for TValue operations
function MorIsTrue(const AValue: TValue): Boolean;
function MorToString(const AValue: TValue): string;

// Factory helper
function MakeToken(const AKind: string; const AText: string;
  const ALine: Integer; const ACol: Integer): TToken;

implementation

{ TToken factory }

function MakeToken(const AKind: string; const AText: string;
  const ALine: Integer; const ACol: Integer): TToken;
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
    if AValue.AsObject() is TASTNode then
      Exit('<node:' + TASTNode(AValue.AsObject()).GetKind() + '>');
    Exit('<object>');
  end;

  Result := '<unknown>';
end;

{ TASTNode }

constructor TASTNode.Create();
begin
  inherited;
  FKind := '';
  FToken.Kind := '';
  FToken.Text := '';
  FToken.Filename := '';
  FToken.Line := 0;
  FToken.Col := 0;
  FAttrs := TDictionary<string, string>.Create();
  FChildren := TObjectList<TASTNode>.Create(True);
  FNamedChildren := TDictionary<string, TASTNode>.Create();
end;

destructor TASTNode.Destroy();
begin
  FreeAndNil(FNamedChildren);
  FreeAndNil(FChildren);
  FreeAndNil(FAttrs);
  inherited;
end;

function TASTNode.Dump(const AId: Integer): string;
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

function TASTNode.GetKind(): string;
begin
  Result := FKind;
end;

procedure TASTNode.SetKind(const AKind: string);
begin
  FKind := AKind;
end;

function TASTNode.GetToken(): TToken;
begin
  Result := FToken;
end;

procedure TASTNode.SetToken(const AToken: TToken);
begin
  FToken := AToken;
end;

function TASTNode.GetAttr(const AKey: string): string;
begin
  if not FAttrs.TryGetValue(AKey, Result) then
    Result := '';
end;

procedure TASTNode.SetAttr(const AKey: string; const AValue: string);
begin
  FAttrs.AddOrSetValue(AKey, AValue);
end;

function TASTNode.HasAttr(const AKey: string): Boolean;
begin
  Result := FAttrs.ContainsKey(AKey);
end;

function TASTNode.ChildCount(): Integer;
begin
  Result := FChildren.Count;
end;

function TASTNode.GetChild(const AIndex: Integer): TASTNode;
begin
  Result := FChildren[AIndex];
end;

procedure TASTNode.AddChild(const AChild: TASTNode);
begin
  FChildren.Add(AChild);
end;

function TASTNode.GetNamedChild(const AName: string): TASTNode;
begin
  if not FNamedChildren.TryGetValue(AName, Result) then
    Result := nil;
end;

procedure TASTNode.SetNamedChild(const AName: string; const AChild: TASTNode);
begin
  FNamedChildren.AddOrSetValue(AName, AChild);
end;

function TASTNode.HasNamedChild(const AName: string): Boolean;
begin
  Result := FNamedChildren.ContainsKey(AName);
end;

end.
