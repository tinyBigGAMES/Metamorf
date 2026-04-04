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

// Report an error with position info extracted from an AST node's token.
procedure ReportNodeError(
  const AErrors: TErrors;
  const ANode: TASTNode;
  const ACode: string;
  const AFmt: string;
  const AArgs: array of const
);

implementation

procedure ReportNodeError(
  const AErrors: TErrors;
  const ANode: TASTNode;
  const ACode: string;
  const AFmt: string;
  const AArgs: array of const
);
var
  LToken: TToken;
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

end.
