{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit DelphiCImp.Common;

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  Metamorf.Utils,
  Metamorf.Build;


type
  { TCTokenKind }
  TCTokenKind = (
    ctkEOF,
    ctkError,
    ctkIdentifier,
    ctkIntLiteral,
    ctkFloatLiteral,
    ctkStringLiteral,
    ctkTypedef,
    ctkStruct,
    ctkUnion,
    ctkEnum,
    ctkConst,
    ctkVoid,
    ctkChar,
    ctkShort,
    ctkInt,
    ctkLong,
    ctkFloat,
    ctkDouble,
    ctkSigned,
    ctkUnsigned,
    ctkBool,
    ctkExtern,
    ctkStatic,
    ctkInline,
    ctkRestrict,
    ctkVolatile,
    ctkAtomic,
    ctkBuiltin,
    ctkLBrace,
    ctkRBrace,
    ctkLParen,
    ctkRParen,
    ctkLBracket,
    ctkRBracket,
    ctkSemicolon,
    ctkComma,
    ctkStar,
    ctkEquals,
    ctkColon,
    ctkEllipsis,
    ctkDot,
    ctkHash,
    ctkLineMarker
  );

  { TCToken }
  TCToken = record
    Kind: TCTokenKind;
    Lexeme: string;
    IntValue: Int64;
    FloatValue: Double;
    Line: Integer;
    Column: Integer;
  end;

  { TCLexer }
  TCLexer = class(TBaseObject)
  private
    FSource: string;
    FPos: Integer;
    FLine: Integer;
    FColumn: Integer;
    FTokens: TList<TCToken>;
    FCurrentChar: Char;

    procedure Advance();
    {$HINTS OFF}
    function Peek(): Char;
    {$HINTS ON}
    function PeekNext(): Char;
    procedure SkipWhitespace();
    procedure SkipLineComment();
    procedure SkipBlockComment();
    function ScanLineMarker(): TCToken;
    function IsAlpha(const AChar: Char): Boolean;
    function IsDigit(const AChar: Char): Boolean;
    function IsAlphaNumeric(const AChar: Char): Boolean;
    function IsHexDigit(const AChar: Char): Boolean;
    function ScanIdentifier(): TCToken;
    function ScanNumber(): TCToken;
    function ScanString(): TCToken;
    function MakeToken(const AKind: TCTokenKind): TCToken;
    function GetKeywordKind(const AIdent: string): TCTokenKind;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    procedure Tokenize(const ASource: string);
    function GetTokenCount(): Integer;
    function GetToken(const AIndex: Integer): TCToken;
    procedure Clear();
  end;

  { TCFieldInfo }
  TCFieldInfo = record
    FieldName: string;
    TypeName: string;
    IsPointer: Boolean;
    PointerDepth: Integer;
    ArraySize: Integer;
    BitWidth: Integer;
  end;

  { TCStructInfo }
  TCStructInfo = record
    StructName: string;
    IsUnion: Boolean;
    Fields: TArray<TCFieldInfo>;
  end;

  { TCEnumValue }
  TCEnumValue = record
    ValueName: string;
    Value: Int64;
    HasExplicitValue: Boolean;
  end;

  { TCEnumInfo }
  TCEnumInfo = record
    EnumName: string;
    Values: TArray<TCEnumValue>;
  end;

  { TCDefineInfo }
  TCDefineInfo = record
    DefineName: string;
    DefineValue: string;
    IsInteger: Boolean;
    IntValue: Int64;
    IsFloat: Boolean;
    FloatValue: Double;
    IsString: Boolean;
    StringValue: string;
    IsTypedConstant: Boolean;
    TypedConstType: string;
    TypedConstValues: string;
  end;

  { TCParamInfo }
  TCParamInfo = record
    ParamName: string;
    TypeName: string;
    IsPointer: Boolean;
    PointerDepth: Integer;
    IsConst: Boolean;
    IsConstTarget: Boolean;
  end;

  { TCFunctionInfo }
  TCFunctionInfo = record
    FuncName: string;
    ReturnType: string;
    ReturnIsPointer: Boolean;
    ReturnPointerDepth: Integer;
    Params: TArray<TCParamInfo>;
    IsVariadic: Boolean;
  end;

  { TCTypedefInfo }
  TCTypedefInfo = record
    AliasName: string;
    TargetType: string;
    IsPointer: Boolean;
    PointerDepth: Integer;
    IsFunctionPointer: Boolean;
    FuncInfo: TCFunctionInfo;
  end;

  { TInsertionInfo }
  TInsertionInfo = record
    TargetLine: string;
    Content: string;
    InsertBefore: Boolean;
    Occurrence: Integer;
  end;

  { TReplacementInfo }
  TReplacementInfo = record
    OldText: string;
    NewText: string;
    Occurrence: Integer;
  end;

  { TPostCopyInfo }
  TPostCopyInfo = record
    Platform: TTargetPlatform;
    SourceFile: string;
    DestDir: string;
  end;

implementation

{ TCLexer }

constructor TCLexer.Create();
begin
  inherited;
  FTokens := TList<TCToken>.Create();
  Clear();
end;

destructor TCLexer.Destroy();
begin
  FTokens.Free();
  inherited;
end;

procedure TCLexer.Advance();
begin
  if FPos <= Length(FSource) then
  begin
    if FCurrentChar = #10 then
    begin
      Inc(FLine);
      FColumn := 1;
    end
    else
      Inc(FColumn);
    Inc(FPos);
  end;

  if FPos <= Length(FSource) then
    FCurrentChar := FSource[FPos]
  else
    FCurrentChar := #0;
end;

function TCLexer.Peek(): Char;
begin
  Result := FCurrentChar;
end;

function TCLexer.PeekNext(): Char;
begin
  if FPos + 1 <= Length(FSource) then
    Result := FSource[FPos + 1]
  else
    Result := #0;
end;

procedure TCLexer.SkipWhitespace();
begin
  while (FCurrentChar <> #0) and (FCurrentChar <= ' ') do
    Advance();
end;

procedure TCLexer.SkipLineComment();
begin
  while (FCurrentChar <> #0) and (FCurrentChar <> #10) do
    Advance();
end;

procedure TCLexer.SkipBlockComment();
begin
  Advance();
  while FCurrentChar <> #0 do
  begin
    if (FCurrentChar = '*') and (PeekNext() = '/') then
    begin
      Advance();
      Advance();
      Exit;
    end;
    Advance();
  end;
end;

function TCLexer.ScanLineMarker(): TCToken;
var
  LFilename: string;
  LKeyword: string;
begin
  Result.Kind := ctkLineMarker;
  Result.Lexeme := '';
  Result.IntValue := 0;
  Result.FloatValue := 0;
  Result.Line := FLine;
  Result.Column := FColumn;

  // Skip the '#'
  Advance();
  SkipWhitespace();

  // Check if this is a #define directive (skip it, parsed separately)
  if IsAlpha(FCurrentChar) then
  begin
    LKeyword := '';
    while IsAlphaNumeric(FCurrentChar) do
    begin
      LKeyword := LKeyword + FCurrentChar;
      Advance();
    end;
    // Skip rest of line for #define, #undef, etc.
    while (FCurrentChar <> #0) and (FCurrentChar <> #10) do
      Advance();
    // Return empty line marker (will be ignored)
    Result.Lexeme := '';
    Exit;
  end;

  // Skip line number
  while IsDigit(FCurrentChar) do
    Advance();
  SkipWhitespace();

  // Parse filename in quotes
  if FCurrentChar = '"' then
  begin
    Advance(); // skip opening quote
    LFilename := '';
    while (FCurrentChar <> #0) and (FCurrentChar <> '"') and (FCurrentChar <> #10) do
    begin
      LFilename := LFilename + FCurrentChar;
      Advance();
    end;
    if FCurrentChar = '"' then
      Advance(); // skip closing quote
    Result.Lexeme := LFilename;
  end;

  // Skip rest of line (flags)
  while (FCurrentChar <> #0) and (FCurrentChar <> #10) do
    Advance();
end;

function TCLexer.IsAlpha(const AChar: Char): Boolean;
begin
  Result := ((AChar >= 'a') and (AChar <= 'z')) or
            ((AChar >= 'A') and (AChar <= 'Z')) or
            (AChar = '_');
end;

function TCLexer.IsDigit(const AChar: Char): Boolean;
begin
  Result := (AChar >= '0') and (AChar <= '9');
end;

function TCLexer.IsAlphaNumeric(const AChar: Char): Boolean;
begin
  Result := IsAlpha(AChar) or IsDigit(AChar);
end;

function TCLexer.IsHexDigit(const AChar: Char): Boolean;
begin
  Result := IsDigit(AChar) or
            ((AChar >= 'a') and (AChar <= 'f')) or
            ((AChar >= 'A') and (AChar <= 'F'));
end;

function TCLexer.GetKeywordKind(const AIdent: string): TCTokenKind;
begin
  if AIdent = 'typedef' then Result := ctkTypedef
  else if AIdent = 'struct' then Result := ctkStruct
  else if AIdent = 'union' then Result := ctkUnion
  else if AIdent = 'enum' then Result := ctkEnum
  else if AIdent = 'const' then Result := ctkConst
  else if AIdent = 'void' then Result := ctkVoid
  else if AIdent = 'char' then Result := ctkChar
  else if AIdent = 'short' then Result := ctkShort
  else if AIdent = 'int' then Result := ctkInt
  else if AIdent = 'long' then Result := ctkLong
  else if AIdent = 'float' then Result := ctkFloat
  else if AIdent = 'double' then Result := ctkDouble
  else if AIdent = 'signed' then Result := ctkSigned
  else if AIdent = 'unsigned' then Result := ctkUnsigned
  else if AIdent = '_Bool' then Result := ctkBool
  else if AIdent = 'extern' then Result := ctkExtern
  else if AIdent = 'static' then Result := ctkStatic
  else if AIdent = 'inline' then Result := ctkInline
  else if AIdent = '__inline' then Result := ctkInline
  else if AIdent = '__inline__' then Result := ctkInline
  else if AIdent = 'restrict' then Result := ctkRestrict
  else if AIdent = '__restrict' then Result := ctkRestrict
  else if AIdent = '__restrict__' then Result := ctkRestrict
  else if AIdent = 'volatile' then Result := ctkVolatile
  else if AIdent = '_Atomic' then Result := ctkAtomic
  else if AIdent.StartsWith('__builtin') then Result := ctkBuiltin
  else if AIdent.StartsWith('__attribute') then Result := ctkBuiltin
  else if AIdent.StartsWith('__declspec') then Result := ctkBuiltin
  else Result := ctkIdentifier;
end;

function TCLexer.ScanIdentifier(): TCToken;
var
  LStart: Integer;
  LIdent: string;
begin
  LStart := FPos;
  while IsAlphaNumeric(FCurrentChar) do
    Advance();
  LIdent := Copy(FSource, LStart, FPos - LStart);
  Result.Kind := GetKeywordKind(LIdent);
  Result.Lexeme := LIdent;
  Result.IntValue := 0;
  Result.FloatValue := 0;
  Result.Line := FLine;
  Result.Column := FColumn - Length(LIdent);
end;

function TCLexer.ScanNumber(): TCToken;
var
  LStart: Integer;
  LNumStr: string;
  LIsHex: Boolean;
  LIsFloat: Boolean;
begin
  LStart := FPos;
  LIsHex := False;
  LIsFloat := False;

  if (FCurrentChar = '0') and ((PeekNext() = 'x') or (PeekNext() = 'X')) then
  begin
    LIsHex := True;
    Advance();
    Advance();
    while IsHexDigit(FCurrentChar) do
      Advance();
  end
  else
  begin
    while IsDigit(FCurrentChar) do
      Advance();
    if (FCurrentChar = '.') and IsDigit(PeekNext()) then
    begin
      LIsFloat := True;
      Advance();
      while IsDigit(FCurrentChar) do
        Advance();
    end;
    if (FCurrentChar = 'e') or (FCurrentChar = 'E') then
    begin
      LIsFloat := True;
      Advance();
      if (FCurrentChar = '+') or (FCurrentChar = '-') then
        Advance();
      while IsDigit(FCurrentChar) do
        Advance();
    end;
  end;

  while CharInSet(FCurrentChar, ['u', 'U', 'l', 'L', 'f', 'F']) do
    Advance();

  LNumStr := Copy(FSource, LStart, FPos - LStart);

  if LIsFloat then
  begin
    Result.Kind := ctkFloatLiteral;
    Result.FloatValue := StrToFloatDef(LNumStr, 0);
    Result.IntValue := 0;
  end
  else
  begin
    Result.Kind := ctkIntLiteral;
    // Strip suffixes (U, L, LL, ULL, etc.) before parsing
    while (Length(LNumStr) > 0) and CharInSet(LNumStr[Length(LNumStr)], ['u', 'U', 'l', 'L']) do
      LNumStr := Copy(LNumStr, 1, Length(LNumStr) - 1);
    if LIsHex then
      Result.IntValue := StrToInt64Def('$' + Copy(LNumStr, 3, Length(LNumStr)), 0)
    else
      Result.IntValue := StrToInt64Def(LNumStr, 0);
    Result.FloatValue := 0;
  end;
  Result.Lexeme := LNumStr;
  Result.Line := FLine;
  Result.Column := FColumn - Length(LNumStr);
end;

function TCLexer.ScanString(): TCToken;
var
  LStart: Integer;
  LQuote: Char;
begin
  LQuote := FCurrentChar;
  LStart := FPos;
  Advance();
  while (FCurrentChar <> #0) and (FCurrentChar <> LQuote) do
  begin
    if FCurrentChar = '\' then
      Advance();
    Advance();
  end;
  if FCurrentChar = LQuote then
    Advance();
  Result.Kind := ctkStringLiteral;
  Result.Lexeme := Copy(FSource, LStart, FPos - LStart);
  Result.IntValue := 0;
  Result.FloatValue := 0;
  Result.Line := FLine;
  Result.Column := FColumn - Length(Result.Lexeme);
end;

function TCLexer.MakeToken(const AKind: TCTokenKind): TCToken;
begin
  Result.Kind := AKind;
  Result.Lexeme := FCurrentChar;
  Result.IntValue := 0;
  Result.FloatValue := 0;
  Result.Line := FLine;
  Result.Column := FColumn;
  Advance();
end;

procedure TCLexer.Tokenize(const ASource: string);
var
  LToken: TCToken;
begin
  Clear();
  FSource := ASource;
  FPos := 1;
  FLine := 1;
  FColumn := 1;
  if Length(FSource) > 0 then
    FCurrentChar := FSource[1]
  else
    FCurrentChar := #0;

  while FCurrentChar <> #0 do
  begin
    SkipWhitespace();
    if FCurrentChar = #0 then
      Break;

    if (FCurrentChar = '#') and (FColumn = 1) then
    begin
      LToken := ScanLineMarker();
      FTokens.Add(LToken);
      Continue;
    end;

    if (FCurrentChar = '/') and (PeekNext() = '/') then
    begin
      SkipLineComment();
      Continue;
    end;

    if (FCurrentChar = '/') and (PeekNext() = '*') then
    begin
      Advance();
      SkipBlockComment();
      Continue;
    end;

    if IsAlpha(FCurrentChar) then
    begin
      LToken := ScanIdentifier();
      FTokens.Add(LToken);
      Continue;
    end;

    if IsDigit(FCurrentChar) then
    begin
      LToken := ScanNumber();
      FTokens.Add(LToken);
      Continue;
    end;

    if (FCurrentChar = '"') or (FCurrentChar = '''') then
    begin
      LToken := ScanString();
      FTokens.Add(LToken);
      Continue;
    end;

    case FCurrentChar of
      '{': FTokens.Add(MakeToken(ctkLBrace));
      '}': FTokens.Add(MakeToken(ctkRBrace));
      '(': FTokens.Add(MakeToken(ctkLParen));
      ')': FTokens.Add(MakeToken(ctkRParen));
      '[': FTokens.Add(MakeToken(ctkLBracket));
      ']': FTokens.Add(MakeToken(ctkRBracket));
      ';': FTokens.Add(MakeToken(ctkSemicolon));
      ',': FTokens.Add(MakeToken(ctkComma));
      '*': FTokens.Add(MakeToken(ctkStar));
      '=': FTokens.Add(MakeToken(ctkEquals));
      ':': FTokens.Add(MakeToken(ctkColon));
      '#': FTokens.Add(MakeToken(ctkHash));
      '.':
        begin
          if PeekNext() = '.' then
          begin
            Advance();
            Advance();
            if FCurrentChar = '.' then
            begin
              LToken.Kind := ctkEllipsis;
              LToken.Lexeme := '...';
              LToken.Line := FLine;
              LToken.Column := FColumn - 2;
              Advance();
              FTokens.Add(LToken);
            end;
          end
          else
            FTokens.Add(MakeToken(ctkDot));
        end;
    else
      Advance();
    end;
  end;

  LToken.Kind := ctkEOF;
  LToken.Lexeme := '';
  LToken.IntValue := 0;
  LToken.FloatValue := 0;
  LToken.Line := FLine;
  LToken.Column := FColumn;
  FTokens.Add(LToken);
end;

function TCLexer.GetTokenCount(): Integer;
begin
  Result := FTokens.Count;
end;

function TCLexer.GetToken(const AIndex: Integer): TCToken;
begin
  if (AIndex >= 0) and (AIndex < FTokens.Count) then
    Result := FTokens[AIndex]
  else
  begin
    Result.Kind := ctkEOF;
    Result.Lexeme := '';
  end;
end;

procedure TCLexer.Clear();
begin
  FTokens.Clear();
  FSource := '';
  FPos := 1;
  FLine := 1;
  FColumn := 1;
  FCurrentChar := #0;
end;

end.
