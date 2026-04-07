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

  { TMorScope }
  TMorScope = TDictionary<string, TValue>;

  { TEnvironment }
  TMorEnvironment = class(TMorBaseObject)
  private
    FScopeStack: TObjectList<TMorScope>;

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

{ TMorEnvironment }

constructor TMorEnvironment.Create();
begin
  inherited;
  FScopeStack := TObjectList<TMorScope>.Create(True);

  // Push the global scope
  Push();
end;

destructor TMorEnvironment.Destroy();
begin
  FreeAndNil(FScopeStack);
  inherited;
end;

procedure TMorEnvironment.Push();
var
  LScope: TMorScope;
begin
  LScope := TMorScope.Create();
  FScopeStack.Add(LScope);
end;

procedure TMorEnvironment.Pop();
begin
  if FScopeStack.Count <= 1 then
    raise Exception.Create('Cannot pop the global scope');

  FScopeStack.Delete(FScopeStack.Count - 1);
end;

procedure TMorEnvironment.SetVar(const AName: string; const AValue: TValue);
var
  LScope: TMorScope;
begin
  LScope := FScopeStack[FScopeStack.Count - 1];
  LScope.AddOrSetValue(AName, AValue);
end;

procedure TMorEnvironment.UpdateVar(const AName: string; const AValue: TValue);
var
  LI: Integer;
  LScope: TMorScope;
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

function TMorEnvironment.GetVar(const AName: string): TValue;
var
  LI: Integer;
  LScope: TMorScope;
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

function TMorEnvironment.HasVar(const AName: string): Boolean;
var
  LI: Integer;
  LScope: TMorScope;
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

function TMorEnvironment.Depth(): Integer;
begin
  Result := FScopeStack.Count;
end;

end.
