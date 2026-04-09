{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.Common;

{$I Metamorf.Defines.inc}

interface

uses
  System.SysUtils,
  Metamorf.Utils,
  Metamorf.AST;

const
  // File extension for breakpoint sidecar files (e.g. hello_debug.mbp)
  MOR_BREAKPOINT_EXT = '.mbp';
  MOR_LANG_EXT = '.mor';

  // Baked compiler resource name and AST stream format identifiers
  MOR_BAKED_AST_RES = 'MOR_BAKED_AST';
  MOR_AST_MAGIC     = $314D4F52; // 'MOR1' as DWORD (little-endian: R, O, M, 1)
  MOR_AST_VERSION   = 1;

  // ResolvePath behavior when no explicit base path is provided
  // 0 = raw passthrough (no resolution)
  // 1 = resolve relative to exe directory (ParamStr(0))
  // 2 = resolve relative to source file directory (FSourceDir)
  MOR_RESOLVEPATH_BEHAVIOR = 1;

type
  { TMorRunMode }
  TMorRunMode = (
    rmNone,
    rmExecute,
    rmDebug
  );

  { TMorBuildObject }
  TMorBuildObject = class(TMorErrorsObject)
  protected
    FBuild: TObject;
  public
    procedure SetBuild(const ABuild: TObject); virtual;
    function GetBuild(): TObject;
  end;

// Report an error with position info extracted from an AST node's token.
procedure MorReportNodeError(
  const AErrors: TMorErrors;
  const ANode: TMorASTNode;
  const ACode: string;
  const AFmt: string;
  const AArgs: array of const
);

implementation

procedure MorReportNodeError(
  const AErrors: TMorErrors;
  const ANode: TMorASTNode;
  const ACode: string;
  const AFmt: string;
  const AArgs: array of const
);
var
  LToken: TMorToken;
begin
  if not Assigned(AErrors) then
    Exit;
  LToken.Filename := '';
  LToken.Line := 0;
  LToken.Col := 0;
  if Assigned(ANode) then
    LToken := ANode.GetToken();
  AErrors.Add(LToken.Filename, LToken.Line, LToken.Col, esError, ACode,
    AFmt, AArgs);
end;

{ TMorBuildObject }

procedure TMorBuildObject.SetBuild(const ABuild: TObject);
begin
  FBuild := ABuild;
end;

function TMorBuildObject.GetBuild(): TObject;
begin
  Result := FBuild;
end;

end.
