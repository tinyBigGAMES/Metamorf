{===============================================================================
  DelphiFmt Test File — Deliberately Unformatted
  This file is intentionally malformatted to exercise every formatter rule.
  After formatting, inspect output visually. Format again to verify idempotency.
===============================================================================}
unit test_unit_complex;
{$IFDEF WIN64}
{$I DELPHIFMT.DEFINES.INC}
{$ENDIF}

interface

uses
  Windows,
  SysUtils,
  Classes,
  IOUtils,
  Generics.Collections,
  Math,
  AnsiStrings;

const
  MAX_ITEMS = 100;
  MIN_VALUE = 0;
  MAX_VALUE = 9999;
  VERSION_STR = 'PasFmt v1.0';

type
  TDirection = (dirNorth, dirSouth, dirEast, dirWest);
  TStatusFlag = (sfNone, sfActive, sfPending, sfDone);
  TStatusSet = set of TStatusFlag;

  TSimpleRecord = record
    ID: Integer;
    Name: string;
    Value: Double;
    Flags: TStatusSet;
  end;

  IMyInterface = interface
    procedure DoSomething();
    function GetValue(): Integer;
    procedure SetValue(const AValue: Integer);
  end;

  TBaseClass = class
  private
    FID: Integer;
    FName: string;
    FValue: Double;
  protected
    procedure InternalUpdate(); virtual;
    function GetID(): Integer;
    function GetName(): string;
  public
    constructor Create(const AID: Integer; const AName: string); virtual;
    destructor Destroy(); override;
    procedure Update(const AValue: Double);
    function IsValid(): BOOLEAN;
    property ID: Integer read FID;
    property Name: string read FName;
  published
    property Value: Double read FValue write FValue;
  end;

  TChildClass = class(TBaseClass)
  private
    FExtra: string;
    FCount: Integer;
    FItems: TList<string>;
  public
    constructor Create(const AID: Integer; const AName: string); override;
    destructor Destroy(); override;
    procedure AddItem(const AItem: string);
    procedure RemoveItem(const AIndex: Integer);
    function ItemCount(): Integer;
    function GetItem(const AIndex: Integer): string;
  end;

implementation

{$REGION 'TBASECLASS'}

constructor TBaseClass.Create(const AID: Integer; const AName: string);
begin
  FID := AID;
  FName := AName;
  FValue := 0.0;
end;

destructor TBaseClass.Destroy();
begin
  inherited Destroy();
end;

procedure TBaseClass.InternalUpdate();
begin
end;

// nothing in base
function TBaseClass.GetID(): Integer;
begin
  Result := FID;
end;

function TBaseClass.GetName(): string;
begin
  Result := FName;
end;

procedure TBaseClass.Update(const AValue: Double);
var
  LDelta: Double;
  LValid: BOOLEAN;
begin
  LDelta := AValue - FValue;
  LValid := IsValid();
  if LValid then
  begin
    FValue := AValue;
    InternalUpdate();
  end
  else
  begin
    raise Exception.Create('Update failed: value out of range');
  end;
  if LDelta > 0 then
    Writeln('Value increased by ', LDelta:8:2);
  else if LDelta < 0 then
    Writeln('Value decreased by ', Abs(LDelta):8:2);
  else
    Writeln('No change');
end;

function TBaseClass.IsValid(): BOOLEAN;
begin
  Result := (FID > 0) and (FName <> '') and (FValue >= MIN_VALUE) and (FValue <= MAX_VALUE);
end;
{$ENDREGION}
{$REGION 'TCHILDCLASS'}

constructor TChildClass.Create(const AID: Integer; const AName: string);
begin
  inherited Create(AID, AName);
  FExtra := '';
  FCount := 0;
  FItems := TList<STRING>.Create();
end;

destructor TChildClass.Destroy();
begin
  if Assigned(FItems) then
  begin
    FItems.Free();
    FItems := nil;
  end;
  inherited Destroy();
end;

procedure TChildClass.AddItem(const AItem: string);
var
  LIdx: Integer;
  LExists: BOOLEAN;
  LS: string;
begin
  LExists := false;
  for LIdx := 0 to FItems.Count - 1 do
  begin
    LS := FItems[LIdx];
    if LS = AItem then
    begin
      LExists := true;
      break;
    end;
  end;
  if not LExists then
  begin
    FItems.Add(AItem);
    INC(FCount);
  end;
end;

procedure TChildClass.RemoveItem(const AIndex: Integer);
begin
  if (AIndex >= 0) and (AIndex < FItems.Count) then
  begin
    FItems.Delete(AIndex);
    DEC(FCount);
  end;
end;

function TChildClass.ItemCount(): Integer;
begin
  Result := FCount;
end;

function TChildClass.GetItem(const AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex < FItems.Count) then
    Result := FItems[AIndex];
  else
    Result := '';
end;
{$ENDREGION}

procedure StandaloneProc(const AList: TList<string>; const AMax: Integer);
var
  LI: Integer;
  LItem: string;
  LCount: Integer;
  LSB: TStringBuilder;
begin
  LCount := 0;
  LSB := TStringBuilder.Create();
  try
    for LI := 0 to AList.Count - 1 do
    begin
      LItem := AList[LI];
      if Length(LItem) > 0 then
      begin
        LSB.Append(LItem);
        INC(LCount);
        if LCount >= AMax then
          break;
      end;
    end;
    Writeln(LSB.ToString());
  finally
    LSB.Free();
  end;
end;

function ComplexFunction(const AInput: string; const AFlags: TStatusSet; const ADir: TDirection): string;
var
  LResult: string;
  LParts: TArray<string>;
  LI: Integer;
  LVal: Integer;
begin
  LResult := '';
  case ADir of
    dirNorth:
      begin
        LResult := 'N:' + AInput;
      end;
    dirSouth:
      begin
        LResult := 'S:' + AInput;
      end;
    dirEast:
      begin
        LParts := AInput.Split([',']);
        for LI := 0 to High(LParts) do
        begin
          if LI > 0 then
            LResult := LResult + ',';
          LResult := LResult + LParts[LI].Trim();
        end;
      end;
    dirWest:
      begin
        LResult := AInput.ToUpper();
      end;
  else
    begin
      LResult := AInput;
    end;
  end;
  if sfActive in AFlags then
    LResult := '[A]' + LResult;
  if sfPending in AFlags then
    LResult := '[P]' + LResult;
  try
    LVal := StrToInt(LResult);
    if LVal < 0 then
      LResult := IntToStr(Abs(LVal));
  except
    on E: EConvertError do
    begin
      {handle silently}
      LResult := StringReplace(LResult, ' ', '_', [rfReplaceAll]);
    end;
    on E: Exception do
    begin
      raise;
    end;
  end;
  Result := LResult;
end;

procedure DemoWithLabels();
var
  LI: Integer;
  LDone: BOOLEAN;
begin
  LI := 0;
  LDone := false;
{$IFDEF DEBUG}
  Writeln('DemoWithLabels starting');
{$ENDIF}
MainLoop:
  while not LDone do
  begin
    if LI > MAX_ITEMS then
    begin
      LDone := true;
      goto Cleanup;
    end;
    INC(LI);
  end;
Cleanup:
  Writeln('Done after ', LI, ' iterations');
end;

procedure DemoTypes();
type
  TLocalEnum = (leA, leB, leC);

  TLocalRecord = record
    X: Integer;
    Y: Integer;
  end;
var
  LEnum: TLocalEnum;
  LRec: TLocalRecord;
begin
  LEnum := leA;
  LRec.X := 1;
  LRec.Y := 2;
  case LEnum of
    leA:
        Writeln('A');
    leB:
        Writeln('B');
    leC:
        Writeln('C');
  end;
  with LRec do
  begin
    Writeln(X, ' ', Y);
  end;
end;

initialization
  Writeln('PasFmtTest unit initialized');

finalization
  Writeln('PasFmtTest unit finalized');

end.
