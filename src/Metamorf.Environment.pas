{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Environment;

{$I Metamorf.Defines.inc}

interface

uses
  System.SysUtils,
  System.Rtti,
  System.Generics.Collections,
  Metamorf.Utils;

type

  { TScope }
  TScope = TDictionary<string, TValue>;

  { TEnvironment }
  TEnvironment = class(TBaseObject)
  private
    FScopeStack: TObjectList<TScope>;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    procedure Push();
    procedure Pop();

    procedure SetVar(const AName: string; const AValue: TValue);
    procedure UpdateVar(const AName: string; const AValue: TValue);
    function GetVar(const AName: string): TValue;
    function HasVar(const AName: string): Boolean;

    function Depth(): Integer;
  end;

implementation

{ TEnvironment }

constructor TEnvironment.Create();
begin
  inherited;
  FScopeStack := TObjectList<TScope>.Create(True);

  // Push the global scope
  Push();
end;

destructor TEnvironment.Destroy();
begin
  FreeAndNil(FScopeStack);
  inherited;
end;

procedure TEnvironment.Push();
var
  LScope: TScope;
begin
  LScope := TScope.Create();
  FScopeStack.Add(LScope);
end;

procedure TEnvironment.Pop();
begin
  if FScopeStack.Count <= 1 then
    raise Exception.Create('Cannot pop the global scope');

  FScopeStack.Delete(FScopeStack.Count - 1);
end;

procedure TEnvironment.SetVar(const AName: string; const AValue: TValue);
var
  LScope: TScope;
begin
  LScope := FScopeStack[FScopeStack.Count - 1];
  LScope.AddOrSetValue(AName, AValue);
end;

procedure TEnvironment.UpdateVar(const AName: string; const AValue: TValue);
var
  LI: Integer;
  LScope: TScope;
begin
  // Search from top of stack downward for the nearest frame that has this var
  for LI := FScopeStack.Count - 1 downto 0 do
  begin
    LScope := FScopeStack[LI];
    if LScope.ContainsKey(AName) then
    begin
      LScope.AddOrSetValue(AName, AValue);
      Exit;
    end;
  end;

  // If not found in any scope, set in current (top) scope
  FScopeStack[FScopeStack.Count - 1].AddOrSetValue(AName, AValue);
end;

function TEnvironment.GetVar(const AName: string): TValue;
var
  LI: Integer;
  LScope: TScope;
  LValue: TValue;
begin
  // Search from top of stack downward
  for LI := FScopeStack.Count - 1 downto 0 do
  begin
    LScope := FScopeStack[LI];
    if LScope.TryGetValue(AName, LValue) then
      Exit(LValue);
  end;

  Result := TValue.Empty;
end;

function TEnvironment.HasVar(const AName: string): Boolean;
var
  LI: Integer;
  LScope: TScope;
begin
  // Search from top of stack downward
  for LI := FScopeStack.Count - 1 downto 0 do
  begin
    LScope := FScopeStack[LI];
    if LScope.ContainsKey(AName) then
      Exit(True);
  end;

  Result := False;
end;

function TEnvironment.Depth(): Integer;
begin
  Result := FScopeStack.Count;
end;

end.
