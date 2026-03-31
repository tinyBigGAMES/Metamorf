{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Scopes;

{$I Metamorf.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Metamorf.Utils,
  Metamorf.Resources;

const
  // User Semantic Error Codes (US001-US099)
  ERR_SCOPES_UNDECLARED   = 'US001';
  ERR_SCOPES_DUPLICATE    = 'US002';
  ERR_SCOPES_MODULE_NOT_FOUND = 'US003';
  ERR_SCOPES_NOT_EXPORTED     = 'US004';

type

  { TSymbol }
  TSymbol = class
  private
    FSymName: string;
    FSymKind: string;
    FTypeName: string;
    FAttrs: TDictionary<string, string>;
    FDeclNode: TObject;
  public
    constructor Create(const AName: string; const ASymKind: string);
    destructor Destroy(); override;
    function GetSymName(): string;
    function GetSymKind(): string;
    function GetTypeName(): string;
    procedure SetTypeName(const ATypeName: string);
    function GetSymAttr(const AKey: string): string;
    procedure SetSymAttr(const AKey: string; const AValue: string);
    function HasSymAttr(const AKey: string): Boolean;
    function GetDeclNode(): TObject;
    procedure SetDeclNode(const ANode: TObject);
  end;

  { TScope }
  TScope = class
  private
    FScopeName: string;
    FSymbols: TObjectDictionary<string, TSymbol>;
    FParent: TScope;
  public
    constructor Create(const AName: string; const AParent: TScope);
    destructor Destroy(); override;
    function GetScopeName(): string;
    function GetParent(): TScope;
    procedure DeclareSymbol(const AName: string; const ASymKind: string; const ADeclNode: TObject = nil);
    function LookupLocal(const AName: string): TSymbol;
  end;

  { TScopeManager }
  TScopeManager = class(TErrorsObject)
  private
    FRoot: TScope;
    FCurrent: TScope;
  public
    constructor Create(); override;
    destructor Destroy(); override;

    procedure Push(const AName: string);
    procedure Pop();
    procedure Reset();
    procedure Declare(const AName: string; const ASymKind: string; const ADeclNode: TObject = nil);
    function Lookup(const AName: string): TSymbol;
    function SymbolExistsWithPrefix(const APrefix: string): Boolean;
    function DemoteCLinkageForPrefix(const APrefix: string): Integer;
    function GetCurrent(): TScope;
  end;

implementation

uses
  Metamorf.AST;

{ TSymbol }

constructor TSymbol.Create(const AName: string; const ASymKind: string);
begin
  inherited Create();
  FSymName := AName;
  FSymKind := ASymKind;
  FTypeName := '';
  FAttrs := TDictionary<string, string>.Create();
  FDeclNode := nil;
end;

destructor TSymbol.Destroy();
begin
  FreeAndNil(FAttrs);
  inherited;
end;

function TSymbol.GetSymName(): string;
begin
  Result := FSymName;
end;

function TSymbol.GetSymKind(): string;
begin
  Result := FSymKind;
end;

function TSymbol.GetTypeName(): string;
begin
  Result := FTypeName;
end;

procedure TSymbol.SetTypeName(const ATypeName: string);
begin
  FTypeName := ATypeName;
end;

function TSymbol.GetSymAttr(const AKey: string): string;
begin
  if not FAttrs.TryGetValue(AKey, Result) then
    Result := '';
end;

procedure TSymbol.SetSymAttr(const AKey: string; const AValue: string);
begin
  FAttrs.AddOrSetValue(AKey, AValue);
end;

function TSymbol.HasSymAttr(const AKey: string): Boolean;
begin
  Result := FAttrs.ContainsKey(AKey);
end;

function TSymbol.GetDeclNode(): TObject;
begin
  Result := FDeclNode;
end;

procedure TSymbol.SetDeclNode(const ANode: TObject);
begin
  FDeclNode := ANode;
end;

{ TScope }

constructor TScope.Create(const AName: string; const AParent: TScope);
begin
  inherited Create();
  FScopeName := AName;
  FParent := AParent;
  FSymbols := TObjectDictionary<string, TSymbol>.Create([doOwnsValues]);
end;

destructor TScope.Destroy();
begin
  FreeAndNil(FSymbols);
  inherited;
end;

function TScope.GetScopeName(): string;
begin
  Result := FScopeName;
end;

function TScope.GetParent(): TScope;
begin
  Result := FParent;
end;


procedure TScope.DeclareSymbol(const AName: string; const ASymKind: string; const ADeclNode: TObject);
var
  LSym: TSymbol;
begin
  LSym := TSymbol.Create(AName, ASymKind);
  LSym.SetDeclNode(ADeclNode);
  FSymbols.AddOrSetValue(AName, LSym);
end;

function TScope.LookupLocal(const AName: string): TSymbol;
begin
  if not FSymbols.TryGetValue(AName, Result) then
    Result := nil;
end;

{ TScopeManager }

constructor TScopeManager.Create();
begin
  inherited;
  FRoot := TScope.Create('global', nil);
  FCurrent := FRoot;
end;

destructor TScopeManager.Destroy();
var
  LScope: TScope;
begin
  // Walk up from current to root, freeing non-root scopes
  while FCurrent <> FRoot do
  begin
    LScope := FCurrent;
    FCurrent := FCurrent.GetParent();
    LScope.Free();
  end;
  FreeAndNil(FRoot);
  FCurrent := nil;
  inherited;
end;

procedure TScopeManager.Push(const AName: string);
var
  LNewScope: TScope;
begin
  LNewScope := TScope.Create(AName, FCurrent);
  FCurrent := LNewScope;
end;

procedure TScopeManager.Pop();
var
  LOld: TScope;
begin
  if FCurrent = FRoot then
    Exit;
  LOld := FCurrent;
  FCurrent := FCurrent.GetParent();
  LOld.Free();
end;

procedure TScopeManager.Reset();
var
  LScope: TScope;
begin
  // Pop all scopes back to root (for multi-pass)
  while FCurrent <> FRoot do
  begin
    LScope := FCurrent;
    FCurrent := FCurrent.GetParent();
    LScope.Free();
  end;
end;

procedure TScopeManager.Declare(const AName: string; const ASymKind: string; const ADeclNode: TObject);
begin
  if FCurrent <> nil then
    FCurrent.DeclareSymbol(AName, ASymKind, ADeclNode);
end;

function TScopeManager.Lookup(const AName: string): TSymbol;
var
  LScope: TScope;
begin
  LScope := FCurrent;
  while LScope <> nil do
  begin
    Result := LScope.LookupLocal(AName);
    if Result <> nil then
      Exit;
    LScope := LScope.GetParent();
  end;
  Result := nil;
end;

function TScopeManager.SymbolExistsWithPrefix(const APrefix: string): Boolean;
var
  LScope: TScope;
  LKey: string;
begin
  LScope := FCurrent;
  while LScope <> nil do
  begin
    for LKey in LScope.FSymbols.Keys do
    begin
      if LKey.StartsWith(APrefix) then
        Exit(True);
    end;
    LScope := LScope.GetParent();
  end;
  Result := False;
end;

function TScopeManager.DemoteCLinkageForPrefix(const APrefix: string): Integer;
var
  LScope: TScope;
  LPair: TPair<string, TSymbol>;
  LNode: TASTNode;
begin
  Result := 0;
  LScope := FCurrent;
  while LScope <> nil do
  begin
    for LPair in LScope.FSymbols do
    begin
      if LPair.Key.StartsWith(APrefix) and
         (LPair.Value.GetDeclNode() <> nil) then
      begin
        LNode := TASTNode(LPair.Value.GetDeclNode());
        if LNode.HasAttr('decl.linkage') and
           (LNode.GetAttr('decl.linkage') = '"C"') then
        begin
          LNode.SetAttr('decl.linkage', '');
          Inc(Result);
        end;
      end;
    end;
    LScope := LScope.GetParent();
  end;
end;

function TScopeManager.GetCurrent(): TScope;
begin
  Result := FCurrent;
end;

end.
