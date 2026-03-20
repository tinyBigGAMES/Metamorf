{===============================================================================
  DelphiFmt Test File — Deliberately Unformatted
  This file is intentionally malformatted to exercise every formatter rule.
  After formatting, inspect output visually. Format again to verify idempotency.
===============================================================================}
UNIT test_unit_complex;
{$IFDEF WIN64}
{$I DelphiFmt.Defines.inc}
   {$ENDIF}
INTERFACE
uses  Windows,SysUtils,
  Classes,      IOUtils,Generics.Collections,
    Math,AnsiStrings;
const MAX_ITEMS=100;MIN_VALUE   =   0;   MAX_VALUE=9999;
  VERSION_STR  =   'PasFmt v1.0';

TYPE
  TDirection=(dirNorth,dirSouth,dirEast,   dirWest);
  TStatusFlag=(sfNone,sfActive,     sfPending,sfDone);
  TStatusSet=SET OF TStatusFlag;

  TSimpleRecord=RECORD
  ID:Integer;
    Name:STRING;
      Value:Double;
  Flags:TStatusSet;
  END;

  IMyInterface=INTERFACE
  PROCEDURE DoSomething();
    FUNCTION  GetValue():Integer;
  PROCEDURE SetValue(CONST AValue:Integer);
  END;

  TBaseClass=CLASS
  PRIVATE
  FID:Integer;
    FName:STRING;
  FValue:Double;
  PROTECTED
  PROCEDURE InternalUpdate();VIRTUAL;
  FUNCTION  GetID():Integer;
    FUNCTION GetName():STRING;
  PUBLIC
  CONSTRUCTOR Create(CONST AID:Integer;CONST AName:STRING);VIRTUAL;
  DESTRUCTOR Destroy();OVERRIDE;
  PROCEDURE Update(CONST AValue:Double);
    FUNCTION  IsValid():BOOLEAN;
  PROPERTY ID:Integer READ FID;
  PROPERTY Name:STRING READ FName;
  PUBLISHED
  PROPERTY Value:Double READ FValue WRITE FValue;
  END;

  TChildClass=CLASS(TBaseClass)
  PRIVATE
  FExtra:STRING;
    FCount:Integer;
  FItems:TList<STRING>;
  PUBLIC
  CONSTRUCTOR Create(CONST AID:Integer;CONST AName:STRING);OVERRIDE;
  DESTRUCTOR Destroy();OVERRIDE;
  PROCEDURE AddItem(CONST AItem:STRING);
    PROCEDURE RemoveItem(CONST AIndex:Integer);
  FUNCTION  ItemCount():Integer;
  FUNCTION  GetItem(CONST AIndex:Integer):STRING;
  END;

IMPLEMENTATION
{$REGION 'TBaseClass'}
CONSTRUCTOR TBaseClass.Create(CONST AID:Integer;CONST AName:STRING);
BEGIN FID:=AID;FName:=AName;FValue:=0.0; END;

DESTRUCTOR TBaseClass.Destroy();
BEGIN
inherited Destroy();
END;

PROCEDURE TBaseClass.InternalUpdate();
BEGIN
// nothing in base
END;

FUNCTION TBaseClass.GetID():Integer;
BEGIN Result:=FID; END;

FUNCTION TBaseClass.GetName():STRING;
BEGIN
  Result:=FName;
END;

PROCEDURE TBaseClass.Update(CONST AValue:Double);
VAR LDelta:Double;LValid:BOOLEAN;
BEGIN
LDelta:=AValue-FValue;
LValid:=IsValid();
IF LValid THEN BEGIN FValue:=AValue;InternalUpdate(); END
ELSE BEGIN
RAISE Exception.Create('Update failed: value out of range'); END;
IF LDelta>0 THEN
Writeln('Value increased by ',LDelta:8:2)
ELSE IF LDelta<0 THEN
Writeln('Value decreased by ',Abs(LDelta):8:2)
ELSE
Writeln('No change');
END;

FUNCTION TBaseClass.IsValid():BOOLEAN;
BEGIN
Result:=(FID>0)AND(FName<>'')AND(FValue>=MIN_VALUE)AND(FValue<=MAX_VALUE);
END;
{$ENDREGION}


{$REGION 'TChildClass'}
CONSTRUCTOR TChildClass.Create(CONST AID:Integer;CONST AName:STRING);
BEGIN
INHERITED Create(AID,AName);
FExtra:='';FCount:=0;
FItems:=TList<STRING>.Create();
END;

DESTRUCTOR TChildClass.Destroy();
BEGIN
IF Assigned(FItems) THEN BEGIN FItems.Free();FItems:=NIL; END;
INHERITED Destroy();
END;

PROCEDURE TChildClass.AddItem(CONST AItem:STRING);
VAR LIdx:Integer;LExists:BOOLEAN;LS:STRING;
BEGIN
LExists:=FALSE;
FOR LIdx:=0 TO FItems.Count-1 DO BEGIN
LS:=FItems[LIdx];
IF LS=AItem THEN BEGIN LExists:=TRUE;BREAK; END;
END;
IF NOT LExists THEN BEGIN
FItems.Add(AItem);
INC(FCount);
END;
END;

PROCEDURE TChildClass.RemoveItem(CONST AIndex:Integer);
BEGIN
IF(AIndex>=0)AND(AIndex<FItems.Count) THEN BEGIN
FItems.Delete(AIndex);
DEC(FCount);
END;
END;

FUNCTION TChildClass.ItemCount():Integer;
BEGIN
Result:=FCount;
END;

FUNCTION TChildClass.GetItem(CONST AIndex:Integer):STRING;
BEGIN
IF(AIndex>=0)AND(AIndex<FItems.Count) THEN
Result:=FItems[AIndex]
ELSE
Result:='';
END;
{$ENDREGION}


PROCEDURE StandaloneProc(CONST AList:TList<STRING>;CONST AMax:Integer);
VAR LI:Integer;LItem:STRING;LCount:Integer;LSB:TStringBuilder;
BEGIN
LCount:=0;LSB:=TStringBuilder.Create();
TRY
FOR LI:=0 TO AList.Count-1 DO BEGIN
LItem:=AList[LI];
IF Length(LItem)>0 THEN BEGIN
LSB.Append(LItem);
INC(LCount);
IF LCount>=AMax THEN BREAK;
END;
END;
Writeln(LSB.ToString());
FINALLY
LSB.Free();
END;
END;

FUNCTION ComplexFunction(CONST AInput:STRING;CONST AFlags:TStatusSet;CONST ADir:TDirection):STRING;
VAR LResult:STRING;LParts:TArray<STRING>;LI:Integer;LVal:Integer;
BEGIN
LResult:='';
CASE ADir OF
dirNorth:BEGIN LResult:='N:'+AInput; END;
dirSouth:BEGIN LResult:='S:'+AInput; END;
dirEast:BEGIN
LParts:=AInput.Split([',']);
FOR LI:=0 TO High(LParts) DO BEGIN
IF LI>0 THEN LResult:=LResult+',';
LResult:=LResult+LParts[LI].Trim();
END;
END;
dirWest:BEGIN
LResult:=AInput.ToUpper();
END;
ELSE BEGIN LResult:=AInput; END;
END;
IF sfActive IN AFlags THEN LResult:='[A]'+LResult;
IF sfPending IN AFlags THEN LResult:='[P]'+LResult;
TRY
LVal:=StrToInt(LResult);
IF LVal<0 THEN LResult:=IntToStr(Abs(LVal));
EXCEPT
ON E:EConvertError DO BEGIN
{handle silently} LResult:=StringReplace(LResult,' ','_',[rfReplaceAll]);
END;
ON E:Exception DO BEGIN
RAISE;
END;
END;
Result:=LResult;
END;

PROCEDURE DemoWithLabels();
VAR LI:Integer;LDone:BOOLEAN;
BEGIN
LI:=0;LDone:=FALSE;
{$IFDEF DEBUG}
Writeln('DemoWithLabels starting');
{$ENDIF}
MainLoop:
WHILE NOT LDone DO BEGIN
IF LI>MAX_ITEMS THEN BEGIN
LDone:=TRUE;
GOTO Cleanup;
END;
INC(LI);
END;
Cleanup:
Writeln('Done after ',LI,' iterations');
END;

PROCEDURE DemoTypes();
TYPE
  TLocalEnum=(leA,leB,leC);
  TLocalRecord=RECORD
  X:Integer;Y:Integer;
  END;
VAR LEnum:TLocalEnum;LRec:TLocalRecord;
BEGIN
LEnum:=leA;LRec.X:=1;LRec.Y:=2;
CASE LEnum OF
leA:Writeln('A');
leB:Writeln('B');
leC:Writeln('C');
END;
WITH LRec DO BEGIN
Writeln(X,' ',Y);
END;
END;

INITIALIZATION
Writeln('PasFmtTest unit initialized');
FINALIZATION
Writeln('PasFmtTest unit finalized');
END.
