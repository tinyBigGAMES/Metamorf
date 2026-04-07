{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit Metamorf.LSP;

{$I Metamorf.Defines.inc}

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  System.IOUtils,
  System.Math,
  System.StrUtils,
  Metamorf.Utils,
  Metamorf.Common,
  Metamorf.AST,
  Metamorf.Interpreter,
  Metamorf.Scopes,
  Metamorf.EngineAPI;

type

  { Forward declarations }
  TMorLSPDocument = class;
  TMorLSPService  = class;

  { TMorLSPPosition }
  TMorLSPPosition = record
    Line: Integer;
    Character: Integer;

    procedure Clear();
    function ToJSON(): TJSONObject;
    class function FromJSON(const AObj: TJSONObject): TMorLSPPosition; static;
  end;

  { TMorLSPRange }
  TMorLSPRange = record
    StartPos: TMorLSPPosition;
    EndPos: TMorLSPPosition;

    procedure Clear();
    function ToJSON(): TJSONObject;
    class function FromJSON(const AObj: TJSONObject): TMorLSPRange; static;
    class function FromSourceRange(
      const ARange: TMorSourceRange): TMorLSPRange; static;
  end;

  { TMorLSPLocation }
  TMorLSPLocation = record
    Uri: string;
    Range: TMorLSPRange;

    function IsEmpty(): Boolean;
    function ToJSON(): TJSONObject;
  end;

  { TMorLSPDiagnosticRelated }
  TMorLSPDiagnosticRelated = record
    Location: TMorLSPLocation;
    Message: string;

    function ToJSON(): TJSONObject;
  end;

  { TMorLSPDiagnostic }
  TMorLSPDiagnostic = record
    Range: TMorLSPRange;
    Severity: Integer;       // 1=Error, 2=Warning, 3=Info, 4=Hint
    Code: string;
    Source: string;
    Message: string;
    Related: TArray<TMorLSPDiagnosticRelated>;

    function ToJSON(): TJSONObject;
  end;

  { TMorLSPCompletionItem }
  TMorLSPCompletionItem = record
    LabelText: string;
    Kind: Integer;
    Detail: string;
    Documentation: string;
    InsertText: string;
    InsertTextFormat: Integer;  // 1=PlainText, 2=Snippet
    SortText: string;

    function ToJSON(): TJSONObject;
  end;

  { TMorLSPParameterInfo }
  TMorLSPParameterInfo = record
    LabelText: string;
    Documentation: string;

    function ToJSON(): TJSONObject;
  end;

  { TMorLSPSignatureInfo }
  TMorLSPSignatureInfo = record
    LabelText: string;
    Documentation: string;
    Parameters: TArray<TMorLSPParameterInfo>;

    function ToJSON(): TJSONObject;
  end;

  { TMorLSPSignatureHelp }
  TMorLSPSignatureHelp = record
    Signatures: TArray<TMorLSPSignatureInfo>;
    ActiveSignature: Integer;
    ActiveParameter: Integer;

    function ToJSON(): TJSONObject;
  end;

  { TMorLSPHover }
  TMorLSPHover = record
    Contents: string;
    Range: TMorLSPRange;
    HasRange: Boolean;

    function IsEmpty(): Boolean;
    function ToJSON(): TJSONObject;
  end;

  { TMorLSPDocumentSymbol - recursive }
  TMorLSPDocumentSymbol = record
    SymbolName: string;
    Detail: string;
    Kind: Integer;
    Range: TMorLSPRange;
    SelectionRange: TMorLSPRange;
    Children: TArray<TMorLSPDocumentSymbol>;

    function ToJSON(): TJSONObject;
  end;

  { TMorLSPFoldingRange }
  TMorLSPFoldingRange = record
    StartLine: Integer;
    EndLine: Integer;
    Kind: string;

    function ToJSON(): TJSONObject;
  end;

  { TMorLSPInlayHint }
  TMorLSPInlayHint = record
    Position: TMorLSPPosition;
    LabelText: string;
    Kind: Integer;   // 1=Type, 2=Parameter

    function ToJSON(): TJSONObject;
  end;

  { TMorLSPTextEdit }
  TMorLSPTextEdit = record
    Range: TMorLSPRange;
    NewText: string;

    function ToJSON(): TJSONObject;
  end;

  { TMorLSPWorkspaceEdit }
  TMorLSPWorkspaceEdit = record
    Uri: string;
    Edits: TArray<TMorLSPTextEdit>;

    function ToJSON(): TJSONObject;
  end;

  { TMorLSPSymbolInformation - flat symbol for workspace/symbol }
  TMorLSPSymbolInformation = record
    SymbolName: string;
    Kind: Integer;
    Uri: string;
    Range: TMorLSPRange;

    function ToJSON(): TJSONObject;
  end;

  { TMorLSPCallHierarchyItem }
  TMorLSPCallHierarchyItem = record
    ItemName: string;
    Kind: Integer;
    Uri: string;
    Range: TMorLSPRange;
    SelectionRange: TMorLSPRange;

    function ToJSON(): TJSONObject;
  end;

  { TMorLSPCallHierarchyCall }
  TMorLSPCallHierarchyCall = record
    Item: TMorLSPCallHierarchyItem;
    FromRanges: TArray<TMorLSPRange>;

    function ToJSON(const ADirection: string): TJSONObject;
  end;

  { TMorLSPDocument }
  TMorLSPDocument = class(TMorBaseObject)
  private
    FUri: string;
    FContent: string;
    FVersion: Integer;
    FLines: TStringList;
    FAST: TMorASTNode;
    FErrors: TMorErrors;
    FTokens: TList<TMorToken>;
    FScopes: TScopeManager;
    FInterp: TMorInterpreter;  // shared, NOT owned

    procedure UpdateLines();

  public
    constructor Create(); override;
    destructor Destroy(); override;

    function GetUri(): string;
    procedure SetUri(const AValue: string);
    function GetContent(): string;
    procedure SetContent(const AValue: string);
    function GetVersion(): Integer;
    procedure SetVersion(const AValue: Integer);

    procedure SetInterpreter(const AInterp: TMorInterpreter);
    procedure Parse();

    function GetAST(): TMorASTNode;
    function GetErrors(): TMorErrors;
    function GetTokens(): TList<TMorToken>;
    function GetScopes(): TScopeManager;

    function OffsetToPosition(const AOffset: Integer): TMorLSPPosition;
    function PositionToOffset(const APosition: TMorLSPPosition): Integer;
    function GetLineCount(): Integer;
    function GetLine(const AIndex: Integer): string;

    function FindNodeAtPosition(
      const APosition: TMorLSPPosition): TMorASTNode;
    function FindTokenAtPosition(
      const APosition: TMorLSPPosition): TMorToken;
  end;

  { TMorLSPService }
  TMorLSPService = class(TMorBaseObject)
  private
    FDocuments: TObjectDictionary<string, TMorLSPDocument>;
    FInterp: TMorInterpreter;  // shared, NOT owned

    function GetDocument(const AUri: string): TMorLSPDocument;

    // Internal helpers
    function GetIdentifierFromNode(const ANode: TMorASTNode): string;
    function ResolveIdentifierAtPosition(
      const ADoc: TMorLSPDocument;
      const APosition: TMorLSPPosition;
      out ANode: TMorASTNode): string;
    function LookupSymbolByName(const ADoc: TMorLSPDocument;
      const AName: string): TSymbol;
    procedure CollectFoldingRangesFromNode(const ANode: TMorASTNode;
      var ARanges: TArray<TMorLSPFoldingRange>);
    procedure CollectReferencesInNode(const ANode: TMorASTNode;
      const ATargetName: string; const AUri: string;
      var ALocations: TArray<TMorLSPLocation>);
    procedure CollectReferencesFromTokens(
      const ADoc: TMorLSPDocument;
      const ATargetName: string; const AUri: string;
      var ALocations: TArray<TMorLSPLocation>);
    procedure CollectDocSymbolsFromScope(const AScope: TScope;
      var ASymbols: TArray<TMorLSPDocumentSymbol>);
    procedure CollectCompletionsFromScope(const AScope: TScope;
      var AItems: TArray<TMorLSPCompletionItem>);
    procedure CollectWorkspaceSymbolsFromScope(const AScope: TScope;
      const AQuery: string; const AUri: string;
      var ASymbols: TArray<TMorLSPSymbolInformation>);

    // Kind mapping
    function NodeKindToSymbolKind(const AKind: string): Integer;
    function SymKindToCompletionKind(const ASymKind: string): Integer;
    function TokenKindToSemanticType(const AKind: string): Integer;
    function ErrorSeverityToLSPSeverity(
      const ASeverity: TMorErrorSeverity): Integer;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    procedure SetInterpreter(const AInterp: TMorInterpreter);

    // Document management
    procedure OpenDocument(const AUri: string; const AContent: string);
    procedure UpdateDocument(const AUri: string; const AContent: string;
      const AVersion: Integer);
    procedure CloseDocument(const AUri: string);
    function HasDocument(const AUri: string): Boolean;

    // LSP features
    function GetDiagnostics(const AUri: string): TArray<TMorLSPDiagnostic>;
    function GetCompletions(const AUri: string; const ALine: Integer;
      const ACharacter: Integer): TArray<TMorLSPCompletionItem>;
    function GetHover(const AUri: string; const ALine: Integer;
      const ACharacter: Integer): TMorLSPHover;
    function GetDefinition(const AUri: string; const ALine: Integer;
      const ACharacter: Integer): TMorLSPLocation;
    function GetReferences(const AUri: string; const ALine: Integer;
      const ACharacter: Integer;
      const AIncludeDeclaration: Boolean): TArray<TMorLSPLocation>;
    function GetDocumentSymbols(
      const AUri: string): TArray<TMorLSPDocumentSymbol>;
    function GetFoldingRanges(
      const AUri: string): TArray<TMorLSPFoldingRange>;
    function GetSemanticTokens(const AUri: string): TArray<Integer>;
    function GetRenameEdits(const AUri: string; const ALine: Integer;
      const ACharacter: Integer;
      const ANewName: string): TMorLSPWorkspaceEdit;
    function GetWorkspaceSymbols(const AQuery: string;
      const AUri: string): TArray<TMorLSPSymbolInformation>;
    function GetSignatureHelp(const AUri: string; const ALine: Integer;
      const ACharacter: Integer): TMorLSPSignatureHelp;
    function GetInlayHints(const AUri: string; const AStartLine: Integer;
      const AStartChar: Integer; const AEndLine: Integer;
      const AEndChar: Integer): TArray<TMorLSPInlayHint>;
    function GetDocumentFormatting(const AUri: string;
      const ATabSize: Integer;
      const AInsertSpaces: Boolean): TArray<TMorLSPTextEdit>;
    function GetCodeActions(const AUri: string;
      const AStartLine: Integer; const AStartChar: Integer;
      const AEndLine: Integer;
      const AEndChar: Integer): TArray<TJSONObject>;

    // Utility
    class function FilePathToUri(const APath: string): string; static;
    class function UriToFilePath(const AUri: string): string; static;
  end;

  { TMorLSPServer }
  TMorLSPServer = class(TMorBaseObject)
  private
    FService: TMorLSPService;
    FEngineAPI: TMorEngineAPI;
    FMorFile: string;
    FInitialized: Boolean;
    FShutdownRequested: Boolean;
    FInputStream: TStream;
    FOutputStream: TStream;
    FOwnsStreams: Boolean;

    function ReadMessage(): TJSONObject;
    procedure WriteMessage(const AMessage: TJSONObject);
    procedure SendResponse(const AId: TJSONValue;
      const AResult: TJSONValue);
    procedure SendError(const AId: TJSONValue; const ACode: Integer;
      const AMessage: string);
    procedure SendNotification(const AMethod: string;
      const AParams: TJSONValue);
    procedure DispatchMessage(const AMessage: TJSONObject);
    procedure PublishDiagnostics(const AUri: string);

    // LSP method handlers
    procedure HandleInitialize(const AId: TJSONValue;
      const AParams: TJSONObject);
    procedure HandleShutdown(const AId: TJSONValue);
    procedure HandleInitialized(const AParams: TJSONObject);
    procedure HandleExit();
    procedure HandleTextDocumentDidOpen(const AParams: TJSONObject);
    procedure HandleTextDocumentDidChange(const AParams: TJSONObject);
    procedure HandleTextDocumentDidClose(const AParams: TJSONObject);
    procedure HandleTextDocumentCompletion(const AId: TJSONValue;
      const AParams: TJSONObject);
    procedure HandleTextDocumentHover(const AId: TJSONValue;
      const AParams: TJSONObject);
    procedure HandleTextDocumentDefinition(const AId: TJSONValue;
      const AParams: TJSONObject);
    procedure HandleTextDocumentReferences(const AId: TJSONValue;
      const AParams: TJSONObject);
    procedure HandleTextDocumentDocumentSymbol(const AId: TJSONValue;
      const AParams: TJSONObject);
    procedure HandleTextDocumentSignatureHelp(const AId: TJSONValue;
      const AParams: TJSONObject);
    procedure HandleTextDocumentFoldingRange(const AId: TJSONValue;
      const AParams: TJSONObject);
    procedure HandleTextDocumentSemanticTokensFull(const AId: TJSONValue;
      const AParams: TJSONObject);
    procedure HandleTextDocumentInlayHint(const AId: TJSONValue;
      const AParams: TJSONObject);
    procedure HandleTextDocumentRename(const AId: TJSONValue;
      const AParams: TJSONObject);
    procedure HandleWorkspaceSymbol(const AId: TJSONValue;
      const AParams: TJSONObject);
    procedure HandleTextDocumentCodeAction(const AId: TJSONValue;
      const AParams: TJSONObject);
    procedure HandleTextDocumentFormatting(const AId: TJSONValue;
      const AParams: TJSONObject);

  public
    constructor Create(); override;
    destructor Destroy(); override;

    procedure SetMorFile(const AMorFile: string);
    procedure SetStreams(const AInput: TStream; const AOutput: TStream);
    function GetService(): TMorLSPService;
    procedure Run();
  end;

implementation

uses
  Metamorf.Resources,
  Metamorf.GenericLexer,
  Metamorf.GenericParser,
  Metamorf.CodeGen;

{ TMorLSPPosition }

procedure TMorLSPPosition.Clear();
begin
  Line := 0;
  Character := 0;
end;

function TMorLSPPosition.ToJSON(): TJSONObject;
begin
  Result := TJSONObject.Create();
  Result.AddPair('line', TJSONNumber.Create(Line));
  Result.AddPair('character', TJSONNumber.Create(Character));
end;

class function TMorLSPPosition.FromJSON(
  const AObj: TJSONObject): TMorLSPPosition;
begin
  Result.Line := AObj.GetValue<Integer>('line', 0);
  Result.Character := AObj.GetValue<Integer>('character', 0);
end;

procedure TMorLSPRange.Clear();
begin
  StartPos.Clear();
  EndPos.Clear();
end;

function TMorLSPRange.ToJSON(): TJSONObject;
begin
  Result := TJSONObject.Create();
  Result.AddPair('start', StartPos.ToJSON());
  Result.AddPair('end', EndPos.ToJSON());
end;

class function TMorLSPRange.FromJSON(
  const AObj: TJSONObject): TMorLSPRange;
var
  LStart: TJSONObject;
  LEnd: TJSONObject;
begin
  Result.Clear();
  LStart := AObj.GetValue<TJSONObject>('start', nil);
  if LStart <> nil then
    Result.StartPos := TMorLSPPosition.FromJSON(LStart);
  LEnd := AObj.GetValue<TJSONObject>('end', nil);
  if LEnd <> nil then
    Result.EndPos := TMorLSPPosition.FromJSON(LEnd);
end;

class function TMorLSPRange.FromSourceRange(
  const ARange: TMorSourceRange): TMorLSPRange;
begin
  // LSP is 0-based; Metamorf source ranges are 1-based
  Result.StartPos.Line := Max(0, ARange.StartLine - 1);
  Result.StartPos.Character := Max(0, ARange.StartColumn - 1);
  Result.EndPos.Line := Max(0, ARange.EndLine - 1);
  Result.EndPos.Character := Max(0, ARange.EndColumn - 1);
end;

function TMorLSPLocation.IsEmpty(): Boolean;
begin
  Result := Uri = '';
end;

function TMorLSPLocation.ToJSON(): TJSONObject;
begin
  Result := TJSONObject.Create();
  Result.AddPair('uri', Uri);
  Result.AddPair('range', Range.ToJSON());
end;

function TMorLSPDiagnosticRelated.ToJSON(): TJSONObject;
begin
  Result := TJSONObject.Create();
  Result.AddPair('location', Location.ToJSON());
  Result.AddPair('message', Message);
end;

function TMorLSPDiagnostic.ToJSON(): TJSONObject;
var
  LRelatedArray: TJSONArray;
  LI: Integer;
begin
  Result := TJSONObject.Create();
  Result.AddPair('range', Range.ToJSON());
  Result.AddPair('severity', TJSONNumber.Create(Severity));
  if Code <> '' then
    Result.AddPair('code', Code);
  if Source <> '' then
    Result.AddPair('source', Source);
  Result.AddPair('message', Message);
  if Length(Related) > 0 then
  begin
    LRelatedArray := TJSONArray.Create();
    for LI := 0 to High(Related) do
      LRelatedArray.AddElement(Related[LI].ToJSON());
    Result.AddPair('relatedInformation', LRelatedArray);
  end;
end;

function TMorLSPCompletionItem.ToJSON(): TJSONObject;
begin
  Result := TJSONObject.Create();
  Result.AddPair('label', LabelText);
  Result.AddPair('kind', TJSONNumber.Create(Kind));
  if Detail <> '' then
    Result.AddPair('detail', Detail);
  if Documentation <> '' then
    Result.AddPair('documentation', Documentation);
  if InsertText <> '' then
    Result.AddPair('insertText', InsertText);
  if InsertTextFormat <> 0 then
    Result.AddPair('insertTextFormat',
      TJSONNumber.Create(InsertTextFormat));
  if SortText <> '' then
    Result.AddPair('sortText', SortText);
end;

function TMorLSPParameterInfo.ToJSON(): TJSONObject;
begin
  Result := TJSONObject.Create();
  Result.AddPair('label', LabelText);
  if Documentation <> '' then
    Result.AddPair('documentation', Documentation);
end;

function TMorLSPSignatureInfo.ToJSON(): TJSONObject;
var
  LParamsArray: TJSONArray;
  LI: Integer;
begin
  Result := TJSONObject.Create();
  Result.AddPair('label', LabelText);
  if Documentation <> '' then
    Result.AddPair('documentation', Documentation);
  if Length(Parameters) > 0 then
  begin
    LParamsArray := TJSONArray.Create();
    for LI := 0 to High(Parameters) do
      LParamsArray.AddElement(Parameters[LI].ToJSON());
    Result.AddPair('parameters', LParamsArray);
  end;
end;

function TMorLSPSignatureHelp.ToJSON(): TJSONObject;
var
  LSigsArray: TJSONArray;
  LI: Integer;
begin
  Result := TJSONObject.Create();
  LSigsArray := TJSONArray.Create();
  for LI := 0 to High(Signatures) do
    LSigsArray.AddElement(Signatures[LI].ToJSON());
  Result.AddPair('signatures', LSigsArray);
  Result.AddPair('activeSignature',
    TJSONNumber.Create(ActiveSignature));
  Result.AddPair('activeParameter',
    TJSONNumber.Create(ActiveParameter));
end;

function TMorLSPHover.IsEmpty(): Boolean;
begin
  Result := Contents = '';
end;

function TMorLSPHover.ToJSON(): TJSONObject;
var
  LContents: TJSONObject;
begin
  Result := TJSONObject.Create();
  LContents := TJSONObject.Create();
  LContents.AddPair('kind', 'markdown');
  LContents.AddPair('value', Contents);
  Result.AddPair('contents', LContents);
  if HasRange then
    Result.AddPair('range', Range.ToJSON());
end;

function TMorLSPDocumentSymbol.ToJSON(): TJSONObject;
var
  LChildArray: TJSONArray;
  LI: Integer;
begin
  Result := TJSONObject.Create();
  Result.AddPair('name', SymbolName);
  if Detail <> '' then
    Result.AddPair('detail', Detail);
  Result.AddPair('kind', TJSONNumber.Create(Kind));
  Result.AddPair('range', Range.ToJSON());
  Result.AddPair('selectionRange', SelectionRange.ToJSON());
  if Length(Children) > 0 then
  begin
    LChildArray := TJSONArray.Create();
    for LI := 0 to High(Children) do
      LChildArray.AddElement(Children[LI].ToJSON());
    Result.AddPair('children', LChildArray);
  end;
end;

function TMorLSPFoldingRange.ToJSON(): TJSONObject;
begin
  Result := TJSONObject.Create();
  Result.AddPair('startLine', TJSONNumber.Create(StartLine));
  Result.AddPair('endLine', TJSONNumber.Create(EndLine));
  if Kind <> '' then
    Result.AddPair('kind', Kind);
end;

function TMorLSPInlayHint.ToJSON(): TJSONObject;
begin
  Result := TJSONObject.Create();
  Result.AddPair('position', Position.ToJSON());
  Result.AddPair('label', LabelText);
  Result.AddPair('kind', TJSONNumber.Create(Kind));
end;

function TMorLSPTextEdit.ToJSON(): TJSONObject;
begin
  Result := TJSONObject.Create();
  Result.AddPair('range', Range.ToJSON());
  Result.AddPair('newText', NewText);
end;

function TMorLSPWorkspaceEdit.ToJSON(): TJSONObject;
var
  LEditsArray: TJSONArray;
  LI: Integer;
begin
  Result := TJSONObject.Create();
  Result.AddPair('uri', Uri);
  LEditsArray := TJSONArray.Create();
  for LI := 0 to High(Edits) do
    LEditsArray.AddElement(Edits[LI].ToJSON());
  Result.AddPair('edits', LEditsArray);
end;

function TMorLSPSymbolInformation.ToJSON(): TJSONObject;
var
  LLocation: TJSONObject;
begin
  Result := TJSONObject.Create();
  Result.AddPair('name', SymbolName);
  Result.AddPair('kind', TJSONNumber.Create(Kind));
  LLocation := TJSONObject.Create();
  LLocation.AddPair('uri', Uri);
  LLocation.AddPair('range', Range.ToJSON());
  Result.AddPair('location', LLocation);
end;

function TMorLSPCallHierarchyItem.ToJSON(): TJSONObject;
begin
  Result := TJSONObject.Create();
  Result.AddPair('name', ItemName);
  Result.AddPair('kind', TJSONNumber.Create(Kind));
  Result.AddPair('uri', Uri);
  Result.AddPair('range', Range.ToJSON());
  Result.AddPair('selectionRange', SelectionRange.ToJSON());
end;

function TMorLSPCallHierarchyCall.ToJSON(
  const ADirection: string): TJSONObject;
var
  LRangesArray: TJSONArray;
  LI: Integer;
begin
  Result := TJSONObject.Create();
  Result.AddPair(ADirection, Item.ToJSON());
  LRangesArray := TJSONArray.Create();
  for LI := 0 to High(FromRanges) do
    LRangesArray.AddElement(FromRanges[LI].ToJSON());
  Result.AddPair('fromRanges', LRangesArray);
end;

constructor TMorLSPDocument.Create();
begin
  inherited Create();
  FUri := '';
  FContent := '';
  FVersion := 0;
  FLines := TStringList.Create();
  FAST := nil;
  FErrors := nil;
  FTokens := nil;
  FScopes := nil;
  FInterp := nil;
end;

destructor TMorLSPDocument.Destroy();
begin
  FreeAndNil(FScopes);
  FreeAndNil(FAST);
  FreeAndNil(FTokens);
  FreeAndNil(FErrors);
  FreeAndNil(FLines);
  inherited Destroy();
end;

procedure TMorLSPDocument.UpdateLines();
begin
  FLines.Clear();
  FLines.Text := FContent;
end;

function TMorLSPDocument.GetUri(): string;
begin
  Result := FUri;
end;

procedure TMorLSPDocument.SetUri(const AValue: string);
begin
  FUri := AValue;
end;

function TMorLSPDocument.GetContent(): string;
begin
  Result := FContent;
end;

procedure TMorLSPDocument.SetContent(const AValue: string);
begin
  FContent := AValue;
end;

function TMorLSPDocument.GetVersion(): Integer;
begin
  Result := FVersion;
end;

procedure TMorLSPDocument.SetVersion(const AValue: Integer);
begin
  FVersion := AValue;
end;

procedure TMorLSPDocument.SetInterpreter(
  const AInterp: TMorInterpreter);
begin
  FInterp := AInterp;
end;

procedure TMorLSPDocument.Parse();
var
  LGenLexer: TMorGenericLexer;
  LGenParser: TMorGenericParser;
  LOutput: TMorCodeOutput;
  LMasterRoot: TMorASTNode;
  LBranch: TMorASTNode;
begin
  // Free previous results
  FreeAndNil(FScopes);
  FreeAndNil(FAST);
  FreeAndNil(FTokens);
  FreeAndNil(FErrors);

  FErrors := TMorErrors.Create();
  FErrors.SetMaxErrors(100);

  // Lex user source via table-driven lexer
  LGenLexer := TMorGenericLexer.Create();
  try
    LGenLexer.SetErrors(FErrors);
    LGenLexer.Configure(FInterp);
    FTokens := LGenLexer.Tokenize(FContent, FUri);
  finally
    LGenLexer.Free();
  end;

  if FErrors.HasErrors() then
  begin
    UpdateLines();
    Exit;
  end;

  // Parse user source into a branch
  LGenParser := TMorGenericParser.Create();
  try
    LGenParser.SetErrors(FErrors);
    LGenParser.Configure(FInterp);
    LBranch := LGenParser.ParseProgram(FTokens, FUri);
  finally
    LGenParser.Free();
  end;

  if LBranch = nil then
  begin
    UpdateLines();
    Exit;
  end;

  // Assemble master AST (single branch for this document)
  LMasterRoot := TMorASTNode.Create();
  LMasterRoot.SetKind('master.root');
  LMasterRoot.AddChild(LBranch);
  FAST := LMasterRoot;

  // Run semantic analysis with per-document scopes
  FScopes := TScopeManager.Create();
  FScopes.SetErrors(FErrors);
  LOutput := TMorCodeOutput.Create();
  try
    FInterp.SetScopes(FScopes);
    FInterp.SetOutput(LOutput);
    FInterp.RunSemantics(FAST);
  finally
    FInterp.SetScopes(nil);
    FInterp.SetOutput(nil);
    LOutput.Free();
  end;

  UpdateLines();
end;

function TMorLSPDocument.GetAST(): TMorASTNode;
begin
  Result := FAST;
end;

function TMorLSPDocument.GetErrors(): TMorErrors;
begin
  Result := FErrors;
end;

function TMorLSPDocument.GetTokens(): TList<TMorToken>;
begin
  Result := FTokens;
end;

function TMorLSPDocument.GetScopes(): TScopeManager;
begin
  Result := FScopes;
end;

function TMorLSPDocument.OffsetToPosition(
  const AOffset: Integer): TMorLSPPosition;
var
  LLine: Integer;
  LPos: Integer;
  LLineLen: Integer;
begin
  Result.Clear();
  LPos := 0;
  LLine := 0;

  while LLine < FLines.Count do
  begin
    LLineLen := Length(FLines[LLine]) + 1;
    if LPos + LLineLen > AOffset then
    begin
      Result.Line := LLine;
      Result.Character := AOffset - LPos;
      Exit;
    end;
    LPos := LPos + LLineLen;
    Inc(LLine);
  end;

  if FLines.Count > 0 then
  begin
    Result.Line := FLines.Count - 1;
    Result.Character := Length(FLines[FLines.Count - 1]);
  end;
end;

function TMorLSPDocument.PositionToOffset(
  const APosition: TMorLSPPosition): Integer;
var
  LLine: Integer;
  LI: Integer;
begin
  LLine := 0;
  LI := 1;

  while LI <= Length(FContent) do
  begin
    if LLine = APosition.Line then
    begin
      Result := LI - 1 + APosition.Character;
      Exit;
    end;
    if FContent[LI] = #13 then
    begin
      Inc(LLine);
      Inc(LI);
      if (LI <= Length(FContent)) and (FContent[LI] = #10) then
        Inc(LI);
    end
    else if FContent[LI] = #10 then
    begin
      Inc(LLine);
      Inc(LI);
    end
    else
      Inc(LI);
  end;

  if LLine = APosition.Line then
    Result := Length(FContent) + APosition.Character
  else
    Result := Length(FContent);
end;

function TMorLSPDocument.GetLineCount(): Integer;
begin
  Result := FLines.Count;
end;

function TMorLSPDocument.GetLine(const AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex < FLines.Count) then
    Result := FLines[AIndex]
  else
    Result := '';
end;

function TMorLSPDocument.FindNodeAtPosition(
  const APosition: TMorLSPPosition): TMorASTNode;

  function ContainsPosition(const ARange: TMorSourceRange): Boolean;
  var
    LLine: Integer;
    LChar: Integer;
  begin
    LLine := APosition.Line + 1;
    LChar := APosition.Character + 1;

    if ARange.IsEmpty() then
      Exit(False);

    if (LLine < ARange.StartLine) or (LLine > ARange.EndLine) then
      Exit(False);
    if ARange.StartLine = ARange.EndLine then
    begin
      Result := (LChar >= ARange.StartColumn) and
        (LChar <= ARange.EndColumn);
      Exit;
    end;
    if LLine = ARange.StartLine then
      Result := LChar >= ARange.StartColumn
    else if LLine = ARange.EndLine then
      Result := LChar <= ARange.EndColumn
    else
      Result := True;
  end;

  function SearchNode(const ANode: TMorASTNode): TMorASTNode;
  var
    LI: Integer;
    LChild: TMorASTNode;
    LFound: TMorASTNode;
    LContains: Boolean;
  begin
    Result := nil;
    if ANode = nil then Exit;

    LContains := ContainsPosition(ANode.GetRange());

    // Skip if node has a range that doesn't contain the position.
    // Nodes with empty ranges (e.g. master.root) always recurse.
    if (not ANode.GetRange().IsEmpty()) and (not LContains) then Exit;

    for LI := 0 to ANode.ChildCount() - 1 do
    begin
      LChild := ANode.GetChild(LI);
      LFound := SearchNode(LChild);
      if LFound <> nil then
        Exit(LFound);
    end;

    // Only return this node if its range actually contains the position
    if LContains then
      Result := ANode;
  end;

begin
  Result := SearchNode(FAST);
end;

function TMorLSPDocument.FindTokenAtPosition(
  const APosition: TMorLSPPosition): TMorToken;
var
  LLine: Integer;
  LCol: Integer;
  LLow: Integer;
  LHigh: Integer;
  LMid: Integer;
  LToken: TMorToken;
  LTokenEnd: Integer;
begin
  Result.Kind := '';
  Result.Text := '';
  Result.Filename := '';
  Result.Line := 0;
  Result.Col := 0;

  if (FTokens = nil) or (FTokens.Count = 0) then Exit;

  // Convert LSP 0-indexed position to 1-indexed token coordinates
  LLine := APosition.Line + 1;
  LCol := APosition.Character + 1;

  // Binary search: tokens are sorted by (Line, Col) in source order
  LLow := 0;
  LHigh := FTokens.Count - 1;
  while LLow <= LHigh do
  begin
    LMid := (LLow + LHigh) div 2;
    LToken := FTokens[LMid];

    if LToken.Line < LLine then
      LLow := LMid + 1
    else if LToken.Line > LLine then
      LHigh := LMid - 1
    else
    begin
      // Same line: check column range
      LTokenEnd := LToken.Col + Length(LToken.Text) - 1;
      if LCol < LToken.Col then
        LHigh := LMid - 1
      else if LCol > LTokenEnd then
        LLow := LMid + 1
      else
      begin
        // Position is within this token
        Result := LToken;
        Exit;
      end;
    end;
  end;
end;

constructor TMorLSPService.Create();
begin
  inherited Create();
  FDocuments := TObjectDictionary<string, TMorLSPDocument>.Create(
    [doOwnsValues]);
  FInterp := nil;
end;

destructor TMorLSPService.Destroy();
begin
  FreeAndNil(FDocuments);
  inherited Destroy();
end;

procedure TMorLSPService.SetInterpreter(
  const AInterp: TMorInterpreter);
begin
  FInterp := AInterp;
end;

function TMorLSPService.GetDocument(
  const AUri: string): TMorLSPDocument;
begin
  if not FDocuments.TryGetValue(AUri, Result) then
    Result := nil;
end;

procedure TMorLSPService.OpenDocument(const AUri: string;
  const AContent: string);
var
  LDoc: TMorLSPDocument;
begin
  LDoc := TMorLSPDocument.Create();
  LDoc.SetUri(AUri);
  LDoc.SetContent(AContent);
  LDoc.SetVersion(1);
  LDoc.SetInterpreter(FInterp);
  LDoc.Parse();
  FDocuments.AddOrSetValue(AUri, LDoc);
end;

procedure TMorLSPService.UpdateDocument(const AUri: string;
  const AContent: string; const AVersion: Integer);
var
  LDoc: TMorLSPDocument;
begin
  LDoc := GetDocument(AUri);
  if LDoc = nil then
  begin
    OpenDocument(AUri, AContent);
    Exit;
  end;
  LDoc.SetContent(AContent);
  LDoc.SetVersion(AVersion);
  LDoc.Parse();
end;

procedure TMorLSPService.CloseDocument(const AUri: string);
begin
  FDocuments.Remove(AUri);
end;

function TMorLSPService.HasDocument(const AUri: string): Boolean;
begin
  Result := FDocuments.ContainsKey(AUri);
end;

function TMorLSPService.GetIdentifierFromNode(
  const ANode: TMorASTNode): string;
begin
  Result := '';
  if ANode = nil then Exit;

  // Language-agnostic: if the node's token is an identifier, use its text.
  // This works because FindNodeAtPosition returns the deepest node,
  // so identifier tokens resolve directly without attribute guessing.
  if ANode.GetToken().Kind = 'identifier' then
    Result := ANode.GetToken().Text;
end;

function TMorLSPService.ResolveIdentifierAtPosition(
  const ADoc: TMorLSPDocument;
  const APosition: TMorLSPPosition;
  out ANode: TMorASTNode): string;
var
  LToken: TMorToken;
begin
  Result := '';
  ANode := nil;
  if ADoc = nil then Exit;

  // First pass: AST-based lookup (deepest node at position)
  ANode := ADoc.FindNodeAtPosition(APosition);
  if ANode <> nil then
  begin
    Result := GetIdentifierFromNode(ANode);
    if Result <> '' then Exit;
  end;

  // Second pass: token-based lookup via binary search on the token list.
  // This handles identifiers consumed as attributes on parent nodes
  // (e.g. function names, variable names in declarations) which have
  // no dedicated AST node of their own.
  LToken := ADoc.FindTokenAtPosition(APosition);
  if LToken.Kind = 'identifier' then
    Result := LToken.Text;
end;

function TMorLSPService.LookupSymbolByName(
  const ADoc: TMorLSPDocument;
  const AName: string): TSymbol;
var
  LScopes: TScopeManager;
begin
  Result := nil;
  if (ADoc = nil) or (AName = '') then Exit;
  LScopes := ADoc.GetScopes();
  if LScopes = nil then Exit;
  Result := LScopes.LookupGlobal(AName);
end;

function TMorLSPService.NodeKindToSymbolKind(
  const AKind: string): Integer;
begin
  // Language-agnostic: maps TSymbol.GetSymKind() strings
  // (set by .mor `declare @name as kind` statements) to LSP SymbolKind
  if (AKind = 'routine') or (AKind = 'function') or
     (AKind = 'procedure') or (AKind = 'method') then
    Result := 12   // Function
  else if (AKind = 'variable') or (AKind = 'parameter') then
    Result := 13   // Variable
  else if (AKind = 'type') or (AKind = 'class') or
          (AKind = 'record') or (AKind = 'struct') then
    Result := 5    // Class
  else if AKind = 'constant' then
    Result := 14   // Constant
  else if (AKind = 'module') or (AKind = 'unit') or
          (AKind = 'program') or (AKind = 'package') then
    Result := 2    // Module
  else if AKind = 'field' then
    Result := 8    // Field
  else if (AKind = 'enum') or (AKind = 'enum_value') then
    Result := 10   // Enum
  else
    Result := 13;  // Variable (fallback)
end;

function TMorLSPService.SymKindToCompletionKind(
  const ASymKind: string): Integer;
begin
  if ASymKind = 'variable' then
    Result := 6
  else if ASymKind = 'routine' then
    Result := 3
  else if ASymKind = 'type' then
    Result := 7
  else if ASymKind = 'parameter' then
    Result := 6
  else if ASymKind = 'field' then
    Result := 5
  else if ASymKind = 'constant' then
    Result := 21
  else
    Result := 1;
end;

function TMorLSPService.TokenKindToSemanticType(
  const AKind: string): Integer;
begin
  if AKind.StartsWith('kw.') then
    Result := 10   // keyword
  else if AKind.StartsWith('op.') then
    Result := 11   // operator
  else if AKind.StartsWith('num.') then
    Result := 12   // number
  else if AKind.StartsWith('str.') then
    Result := 13   // string
  else if AKind.StartsWith('comment.') then
    Result := 14   // comment
  else if AKind = 'identifier' then
    Result := 7    // variable
  else
    Result := -1;  // skip
end;

function TMorLSPService.ErrorSeverityToLSPSeverity(
  const ASeverity: TMorErrorSeverity): Integer;
begin
  if ASeverity = esHint then
    Result := 4
  else if ASeverity = esWarning then
    Result := 2
  else
    Result := 1;
end;

class function TMorLSPService.FilePathToUri(const APath: string): string;
var
  LNormalized: string;
begin
  LNormalized := StringReplace(APath, '\', '/', [rfReplaceAll]);
  Result := 'file:///' + LNormalized;
end;

class function TMorLSPService.UriToFilePath(const AUri: string): string;
begin
  Result := AUri;
  if Result.StartsWith('file:///') then
    Result := Copy(Result, 9, MaxInt);
  Result := StringReplace(Result, '/', PathDelim, [rfReplaceAll]);
end;

function TMorLSPService.GetDiagnostics(
  const AUri: string): TArray<TMorLSPDiagnostic>;
var
  LDoc: TMorLSPDocument;
  LErrors: TMorErrors;
  LItems: TList<TMorError>;
  LI: Integer;
  LJ: Integer;
  LError: TMorError;
  LDiag: TMorLSPDiagnostic;
  LRelated: TMorLSPDiagnosticRelated;
begin
  SetLength(Result, 0);
  LDoc := GetDocument(AUri);
  if LDoc = nil then Exit;
  LErrors := LDoc.GetErrors();
  if LErrors = nil then Exit;

  LItems := LErrors.GetItems();
  SetLength(Result, LItems.Count);
  for LI := 0 to LItems.Count - 1 do
  begin
    LError := LItems[LI];
    LDiag.Range := TMorLSPRange.FromSourceRange(LError.Range);
    LDiag.Severity := ErrorSeverityToLSPSeverity(LError.Severity);
    LDiag.Code := LError.Code;
    LDiag.Source := 'metamorf';
    LDiag.Message := LError.Message;
    SetLength(LDiag.Related, Length(LError.Related));
    for LJ := 0 to High(LError.Related) do
    begin
      LRelated.Location.Uri := AUri;
      LRelated.Location.Range := TMorLSPRange.FromSourceRange(
        LError.Related[LJ].Range);
      LRelated.Message := LError.Related[LJ].Message;
      LDiag.Related[LJ] := LRelated;
    end;
    Result[LI] := LDiag;
  end;
end;

function TMorLSPService.GetCompletions(const AUri: string;
  const ALine: Integer;
  const ACharacter: Integer): TArray<TMorLSPCompletionItem>;
var
  LDoc: TMorLSPDocument;
  LScopes: TScopeManager;
  LScope: TScope;
  LItem: TMorLSPCompletionItem;
  LKwPair: TPair<string, string>;
begin
  SetLength(Result, 0);
  LDoc := GetDocument(AUri);

  // Add scope symbols from entire scope tree
  if LDoc <> nil then
  begin
    LScopes := LDoc.GetScopes();
    if LScopes <> nil then
    begin
      LScope := LScopes.GetCurrent();
      CollectCompletionsFromScope(LScope, Result);
    end;
  end;

  // Add keyword completions from interpreter
  if FInterp <> nil then
  begin
    for LKwPair in FInterp.GetKeywords() do
    begin
      LItem.LabelText := LKwPair.Key;
      LItem.Kind := 14;  // Keyword
      LItem.Detail := 'keyword';
      LItem.Documentation := '';
      LItem.InsertText := LKwPair.Key;
      LItem.InsertTextFormat := 1;
      LItem.SortText := '9' + LKwPair.Key;
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := LItem;
    end;
  end;
end;

function TMorLSPService.GetHover(const AUri: string;
  const ALine: Integer;
  const ACharacter: Integer): TMorLSPHover;
var
  LDoc: TMorLSPDocument;
  LPosition: TMorLSPPosition;
  LNode: TMorASTNode;
  LName: string;
  LSym: TSymbol;
  LContent: string;
begin
  Result.Contents := '';
  Result.HasRange := False;

  LDoc := GetDocument(AUri);
  if LDoc = nil then Exit;

  LPosition.Line := ALine;
  LPosition.Character := ACharacter;
  LName := ResolveIdentifierAtPosition(LDoc, LPosition, LNode);
  if LName = '' then Exit;

  LSym := LookupSymbolByName(LDoc, LName);
  if LSym <> nil then
  begin
    LContent := '**' + LSym.GetSymKind() + '** `' + LSym.GetSymName() + '`';
    if LSym.GetTypeName() <> '' then
      LContent := LContent + ': `' + LSym.GetTypeName() + '`';
    Result.Contents := LContent;
    if (LNode <> nil) and (not LNode.GetRange().IsEmpty()) then
    begin
      Result.Range := TMorLSPRange.FromSourceRange(LNode.GetRange());
      Result.HasRange := True;
    end;
    Exit;
  end;

  // Fallback: show resolved identifier name
  Result.Contents := '`' + LName + '`';
end;

function TMorLSPService.GetDefinition(const AUri: string;
  const ALine: Integer;
  const ACharacter: Integer): TMorLSPLocation;
var
  LDoc: TMorLSPDocument;
  LPosition: TMorLSPPosition;
  LNode: TMorASTNode;
  LName: string;
  LSym: TSymbol;
  LDeclNode: TMorASTNode;
  LDeclRange: TMorSourceRange;
begin
  Result.Uri := '';
  Result.Range.Clear();

  LDoc := GetDocument(AUri);
  if LDoc = nil then Exit;

  LPosition.Line := ALine;
  LPosition.Character := ACharacter;
  LName := ResolveIdentifierAtPosition(LDoc, LPosition, LNode);
  if LName = '' then Exit;

  LSym := LookupSymbolByName(LDoc, LName);
  if (LSym <> nil) and (LSym.GetDeclNode() <> nil) then
  begin
    LDeclNode := TMorASTNode(LSym.GetDeclNode());
    LDeclRange := LDeclNode.GetRange();
    if not LDeclRange.IsEmpty() then
    begin
      Result.Uri := AUri;
      Result.Range := TMorLSPRange.FromSourceRange(LDeclRange);
    end
    else
    begin
      // Fall back to token position
      Result.Uri := AUri;
      Result.Range.StartPos.Line := Max(0, LDeclNode.GetToken().Line - 1);
      Result.Range.StartPos.Character := Max(0, LDeclNode.GetToken().Col - 1);
      Result.Range.EndPos := Result.Range.StartPos;
    end;
  end;
end;

procedure TMorLSPService.CollectReferencesInNode(
  const ANode: TMorASTNode;
  const ATargetName: string; const AUri: string;
  var ALocations: TArray<TMorLSPLocation>);
var
  LI: Integer;
  LName: string;
  LLocation: TMorLSPLocation;
begin
  if ANode = nil then Exit;

  LName := GetIdentifierFromNode(ANode);
  if SameText(LName, ATargetName) then
  begin
    LLocation.Uri := AUri;
    LLocation.Range := TMorLSPRange.FromSourceRange(ANode.GetRange());
    SetLength(ALocations, Length(ALocations) + 1);
    ALocations[High(ALocations)] := LLocation;
  end;

  for LI := 0 to ANode.ChildCount() - 1 do
    CollectReferencesInNode(ANode.GetChild(LI), ATargetName, AUri,
      ALocations);
end;

procedure TMorLSPService.CollectReferencesFromTokens(
  const ADoc: TMorLSPDocument;
  const ATargetName: string; const AUri: string;
  var ALocations: TArray<TMorLSPLocation>);
var
  LTokens: TList<TMorToken>;
  LI: Integer;
  LJ: Integer;
  LToken: TMorToken;
  LLocation: TMorLSPLocation;
  LAlreadyFound: Boolean;
  LLine: Integer;
  LCol: Integer;
begin
  if ADoc = nil then Exit;
  LTokens := ADoc.GetTokens();
  if LTokens = nil then Exit;

  for LI := 0 to LTokens.Count - 1 do
  begin
    LToken := LTokens[LI];
    if LToken.Kind <> 'identifier' then Continue;
    if not SameText(LToken.Text, ATargetName) then Continue;

    // Convert from 1-based token position to 0-based LSP position
    LLine := LToken.Line - 1;
    LCol := LToken.Col - 1;

    // Deduplicate: skip if already found at this position by AST walk
    LAlreadyFound := False;
    for LJ := 0 to High(ALocations) do
    begin
      if (ALocations[LJ].Range.StartPos.Line = LLine) and
         (ALocations[LJ].Range.StartPos.Character = LCol) then
      begin
        LAlreadyFound := True;
        Break;
      end;
    end;

    if not LAlreadyFound then
    begin
      LLocation.Uri := AUri;
      LLocation.Range.StartPos.Line := LLine;
      LLocation.Range.StartPos.Character := LCol;
      LLocation.Range.EndPos.Line := LLine;
      LLocation.Range.EndPos.Character := LCol + Length(LToken.Text);
      SetLength(ALocations, Length(ALocations) + 1);
      ALocations[High(ALocations)] := LLocation;
    end;
  end;
end;

function TMorLSPService.GetReferences(const AUri: string;
  const ALine: Integer; const ACharacter: Integer;
  const AIncludeDeclaration: Boolean): TArray<TMorLSPLocation>;
var
  LDoc: TMorLSPDocument;
  LPosition: TMorLSPPosition;
  LNode: TMorASTNode;
  LName: string;
begin
  SetLength(Result, 0);
  LDoc := GetDocument(AUri);
  if LDoc = nil then Exit;

  LPosition.Line := ALine;
  LPosition.Character := ACharacter;
  LName := ResolveIdentifierAtPosition(LDoc, LPosition, LNode);
  if LName = '' then Exit;

  if LDoc.GetAST() <> nil then
    CollectReferencesInNode(LDoc.GetAST(), LName, AUri, Result);

  // Token-based scan for identifiers not represented in the AST
  // (e.g. inside collectUntil regions like stmt.writeln/stmt.write)
  CollectReferencesFromTokens(LDoc, LName, AUri, Result);
end;

procedure TMorLSPService.CollectDocSymbolsFromScope(
  const AScope: TScope;
  var ASymbols: TArray<TMorLSPDocumentSymbol>);
var
  LPair: TPair<string, TSymbol>;
  LSym: TMorLSPDocumentSymbol;
  LDeclNode: TMorASTNode;
  LI: Integer;
  LChildScope: TScope;
begin
  if AScope = nil then Exit;

  // Emit a document symbol for each declared symbol in this scope
  for LPair in AScope.GetSymbols() do
  begin
    if LPair.Value = nil then Continue;

    LSym.SymbolName := LPair.Value.GetSymName();
    LSym.Detail := LPair.Value.GetTypeName();
    LSym.Kind := NodeKindToSymbolKind(LPair.Value.GetSymKind());
    LSym.Range.Clear();
    LSym.SelectionRange.Clear();
    SetLength(LSym.Children, 0);

    // Get range from declaration node if available
    if LPair.Value.GetDeclNode() <> nil then
    begin
      LDeclNode := TMorASTNode(LPair.Value.GetDeclNode());
      if not LDeclNode.GetRange().IsEmpty() then
        LSym.Range := TMorLSPRange.FromSourceRange(LDeclNode.GetRange())
      else
      begin
        LSym.Range.StartPos.Line := Max(0, LDeclNode.GetToken().Line - 1);
        LSym.Range.StartPos.Character := Max(0, LDeclNode.GetToken().Col - 1);
        LSym.Range.EndPos := LSym.Range.StartPos;
      end;
      LSym.SelectionRange := LSym.Range;
    end;

    SetLength(ASymbols, Length(ASymbols) + 1);
    ASymbols[High(ASymbols)] := LSym;
  end;

  // Recurse into child scopes
  for LI := 0 to AScope.GetChildren().Count - 1 do
  begin
    LChildScope := AScope.GetChildren()[LI];
    CollectDocSymbolsFromScope(LChildScope, ASymbols);
  end;
end;

procedure TMorLSPService.CollectCompletionsFromScope(const AScope: TScope;
  var AItems: TArray<TMorLSPCompletionItem>);
var
  LPair: TPair<string, TSymbol>;
  LItem: TMorLSPCompletionItem;
  LI: Integer;
  LChildScope: TScope;
begin
  if AScope = nil then Exit;

  for LPair in AScope.GetSymbols() do
  begin
    if LPair.Value = nil then Continue;
    LItem.LabelText := LPair.Value.GetSymName();
    LItem.Kind := SymKindToCompletionKind(LPair.Value.GetSymKind());
    LItem.SortText := '1' + LPair.Value.GetSymName();
    LItem.InsertTextFormat := 1;
    LItem.Documentation := '';
    LItem.Detail := LPair.Value.GetTypeName();
    LItem.InsertText := LPair.Value.GetSymName();
    SetLength(AItems, Length(AItems) + 1);
    AItems[High(AItems)] := LItem;
  end;

  for LI := 0 to AScope.GetChildren().Count - 1 do
  begin
    LChildScope := AScope.GetChildren()[LI];
    CollectCompletionsFromScope(LChildScope, AItems);
  end;
end;

function TMorLSPService.GetDocumentSymbols(
  const AUri: string): TArray<TMorLSPDocumentSymbol>;
var
  LDoc: TMorLSPDocument;
  LScopes: TScopeManager;
begin
  SetLength(Result, 0);
  LDoc := GetDocument(AUri);
  if LDoc = nil then Exit;
  LScopes := LDoc.GetScopes();
  if LScopes = nil then Exit;

  // Walk the scope tree — every declared symbol becomes a document symbol
  CollectDocSymbolsFromScope(LScopes.GetCurrent(), Result);
end;

procedure TMorLSPService.CollectFoldingRangesFromNode(
  const ANode: TMorASTNode;
  var ARanges: TArray<TMorLSPFoldingRange>);
var
  LI: Integer;
  LRange: TMorLSPFoldingRange;
  LSrcRange: TMorSourceRange;
begin
  if ANode = nil then Exit;

  LSrcRange := ANode.GetRange();

  // Language-agnostic: any node spanning multiple lines is foldable.
  // No node kind checks needed — the AST structure determines folding.
  if (not LSrcRange.IsEmpty()) and
     (LSrcRange.EndLine - LSrcRange.StartLine > 0) then
  begin
    LRange.StartLine := LSrcRange.StartLine - 1;
    LRange.EndLine := LSrcRange.EndLine - 1;
    LRange.Kind := 'region';
    SetLength(ARanges, Length(ARanges) + 1);
    ARanges[High(ARanges)] := LRange;
  end;

  for LI := 0 to ANode.ChildCount() - 1 do
    CollectFoldingRangesFromNode(ANode.GetChild(LI), ARanges);
end;

function TMorLSPService.GetFoldingRanges(
  const AUri: string): TArray<TMorLSPFoldingRange>;
var
  LDoc: TMorLSPDocument;
begin
  SetLength(Result, 0);
  LDoc := GetDocument(AUri);
  if (LDoc = nil) or (LDoc.GetAST() = nil) then Exit;
  CollectFoldingRangesFromNode(LDoc.GetAST(), Result);
end;

function TMorLSPService.GetSemanticTokens(
  const AUri: string): TArray<Integer>;
var
  LDoc: TMorLSPDocument;
  LTokens: TList<TMorToken>;
  LI: Integer;
  LToken: TMorToken;
  LType: Integer;
  LPrevLine: Integer;
  LPrevChar: Integer;
  LLine: Integer;
  LChar: Integer;
  LLength: Integer;
begin
  SetLength(Result, 0);
  LDoc := GetDocument(AUri);
  if LDoc = nil then Exit;

  LTokens := LDoc.GetTokens();
  if LTokens = nil then Exit;

  LPrevLine := 0;
  LPrevChar := 0;

  for LI := 0 to LTokens.Count - 1 do
  begin
    LToken := LTokens[LI];
    LType := TokenKindToSemanticType(LToken.Kind);
    if LType < 0 then Continue;

    LLine := LToken.Line - 1;
    LChar := LToken.Col - 1;
    LLength := Length(LToken.Text);

    if LLine < 0 then Continue;
    if LChar < 0 then Continue;
    if LLength <= 0 then Continue;

    SetLength(Result, Length(Result) + 5);
    Result[High(Result) - 4] := LLine - LPrevLine;
    if LLine = LPrevLine then
      Result[High(Result) - 3] := LChar - LPrevChar
    else
      Result[High(Result) - 3] := LChar;
    Result[High(Result) - 2] := LLength;
    Result[High(Result) - 1] := LType;
    Result[High(Result)]     := 0;

    LPrevLine := LLine;
    LPrevChar := LChar;
  end;
end;

function TMorLSPService.GetRenameEdits(const AUri: string;
  const ALine: Integer; const ACharacter: Integer;
  const ANewName: string): TMorLSPWorkspaceEdit;
var
  LDoc: TMorLSPDocument;
  LPosition: TMorLSPPosition;
  LNode: TMorASTNode;
  LName: string;
  LLocations: TArray<TMorLSPLocation>;
  LEdit: TMorLSPTextEdit;
  LI: Integer;
begin
  Result.Uri := '';
  SetLength(Result.Edits, 0);

  LDoc := GetDocument(AUri);
  if LDoc = nil then Exit;

  LPosition.Line := ALine;
  LPosition.Character := ACharacter;
  LName := ResolveIdentifierAtPosition(LDoc, LPosition, LNode);
  if LName = '' then Exit;

  SetLength(LLocations, 0);
  if LDoc.GetAST() <> nil then
    CollectReferencesInNode(LDoc.GetAST(), LName, AUri, LLocations);

  // Token-based scan for identifiers not in the AST
  CollectReferencesFromTokens(LDoc, LName, AUri, LLocations);

  Result.Uri := AUri;
  SetLength(Result.Edits, Length(LLocations));
  for LI := 0 to High(LLocations) do
  begin
    LEdit.Range := LLocations[LI].Range;
    LEdit.NewText := ANewName;
    Result.Edits[LI] := LEdit;
  end;
end;

procedure TMorLSPService.CollectWorkspaceSymbolsFromScope(
  const AScope: TScope; const AQuery: string; const AUri: string;
  var ASymbols: TArray<TMorLSPSymbolInformation>);
var
  LPair: TPair<string, TSymbol>;
  LInfo: TMorLSPSymbolInformation;
  LDeclNode: TMorASTNode;
  LI: Integer;
  LChildScope: TScope;
begin
  if AScope = nil then Exit;

  // Emit workspace symbols from this scope's declared symbols
  for LPair in AScope.GetSymbols() do
  begin
    if LPair.Value = nil then Continue;
    if (AQuery <> '') and
       not ContainsText(LPair.Value.GetSymName(), AQuery) then
      Continue;

    LInfo.SymbolName := LPair.Value.GetSymName();
    LInfo.Kind := NodeKindToSymbolKind(LPair.Value.GetSymKind());
    LInfo.Uri := AUri;
    LInfo.Range.Clear();

    if LPair.Value.GetDeclNode() <> nil then
    begin
      LDeclNode := TMorASTNode(LPair.Value.GetDeclNode());
      if not LDeclNode.GetRange().IsEmpty() then
        LInfo.Range := TMorLSPRange.FromSourceRange(LDeclNode.GetRange())
      else
      begin
        LInfo.Range.StartPos.Line := Max(0, LDeclNode.GetToken().Line - 1);
        LInfo.Range.StartPos.Character := Max(0, LDeclNode.GetToken().Col - 1);
        LInfo.Range.EndPos := LInfo.Range.StartPos;
      end;
    end;

    SetLength(ASymbols, Length(ASymbols) + 1);
    ASymbols[High(ASymbols)] := LInfo;
  end;

  // Recurse into child scopes
  for LI := 0 to AScope.GetChildren().Count - 1 do
  begin
    LChildScope := AScope.GetChildren()[LI];
    CollectWorkspaceSymbolsFromScope(LChildScope, AQuery, AUri, ASymbols);
  end;
end;

function TMorLSPService.GetWorkspaceSymbols(const AQuery: string;
  const AUri: string): TArray<TMorLSPSymbolInformation>;
var
  LDoc: TMorLSPDocument;
  LScopes: TScopeManager;
  LPair: TPair<string, TMorLSPDocument>;
begin
  SetLength(Result, 0);

  // If a specific URI is given, search only that document
  if AUri <> '' then
  begin
    LDoc := GetDocument(AUri);
    if LDoc = nil then Exit;
    LScopes := LDoc.GetScopes();
    if LScopes = nil then Exit;
    CollectWorkspaceSymbolsFromScope(LScopes.GetCurrent(), AQuery, AUri,
      Result);
  end
  else
  begin
    // Search all open documents (workspace-wide)
    for LPair in FDocuments do
    begin
      LDoc := LPair.Value;
      if LDoc = nil then Continue;
      LScopes := LDoc.GetScopes();
      if LScopes = nil then Continue;
      CollectWorkspaceSymbolsFromScope(LScopes.GetCurrent(), AQuery,
        LPair.Key, Result);
    end;
  end;
end;

function TMorLSPService.GetSignatureHelp(const AUri: string;
  const ALine: Integer;
  const ACharacter: Integer): TMorLSPSignatureHelp;
begin
  Result.ActiveSignature := 0;
  Result.ActiveParameter := 0;
  SetLength(Result.Signatures, 0);
  // Signature help requires detailed parameter info from semantic analysis.
  // This will be populated as .mor semantic handlers evolve to annotate
  // function declarations with parameter metadata.
end;

function TMorLSPService.GetInlayHints(const AUri: string;
  const AStartLine: Integer; const AStartChar: Integer;
  const AEndLine: Integer;
  const AEndChar: Integer): TArray<TMorLSPInlayHint>;
begin
  SetLength(Result, 0);
  // Inlay hints require resolved type information on AST nodes.
  // Will be enabled once .mor semantic handlers provide type annotations.
end;

function TMorLSPService.GetDocumentFormatting(const AUri: string;
  const ATabSize: Integer;
  const AInsertSpaces: Boolean): TArray<TMorLSPTextEdit>;
begin
  SetLength(Result, 0);
  // Formatting requires language-specific spacing and casing rules.
  // Will be implemented using the token list and keyword table.
end;

function TMorLSPService.GetCodeActions(const AUri: string;
  const AStartLine: Integer; const AStartChar: Integer;
  const AEndLine: Integer;
  const AEndChar: Integer): TArray<TJSONObject>;
begin
  SetLength(Result, 0);
  // Code actions (quick fixes) will be added based on diagnostic codes.
end;

constructor TMorLSPServer.Create();
begin
  inherited Create();
  FService := TMorLSPService.Create();
  FEngineAPI := nil;
  FMorFile := '';
  FInitialized := False;
  FShutdownRequested := False;
  FInputStream := nil;
  FOutputStream := nil;
  FOwnsStreams := False;
end;

destructor TMorLSPServer.Destroy();
begin
  if FOwnsStreams then
  begin
    FreeAndNil(FInputStream);
    FreeAndNil(FOutputStream);
  end;
  FreeAndNil(FEngineAPI);
  FreeAndNil(FService);
  inherited Destroy();
end;

procedure TMorLSPServer.SetMorFile(const AMorFile: string);
begin
  FMorFile := TPath.ChangeExtension(AMorFile, MOR_LANG_EXT);
end;

procedure TMorLSPServer.SetStreams(const AInput: TStream;
  const AOutput: TStream);
begin
  FInputStream := AInput;
  FOutputStream := AOutput;
  FOwnsStreams := False;
end;

function TMorLSPServer.GetService(): TMorLSPService;
begin
  Result := FService;
end;

function TMorLSPServer.ReadMessage(): TJSONObject;
var
  LLine: string;
  LHeader: string;
  LContentLength: Integer;
  LByte: Byte;
  LBodyBytes: TBytes;
  LBodyStr: string;
  LParsed: TJSONValue;
begin
  Result := nil;
  LContentLength := -1;

  // Read headers line by line until blank line
  LLine := '';
  while True do
  begin
    if FInputStream.Read(LByte, 1) <> 1 then
      Exit;

    if LByte = 13 then  // CR
    begin
      FInputStream.Read(LByte, 1);  // Read LF
      if LLine = '' then
        Break;  // Blank line = end of headers

      LHeader := LLine;
      if LHeader.StartsWith('Content-Length: ') then
        LContentLength := StrToIntDef(
          Copy(LHeader, Length('Content-Length: ') + 1, MaxInt), -1);

      LLine := '';
    end
    else if LByte <> 10 then
      LLine := LLine + Chr(LByte);
  end;

  if LContentLength <= 0 then
    Exit;

  // Read exactly LContentLength bytes
  SetLength(LBodyBytes, LContentLength);
  FInputStream.ReadBuffer(LBodyBytes[0], LContentLength);
  LBodyStr := TEncoding.UTF8.GetString(LBodyBytes);

  LParsed := TJSONObject.ParseJSONValue(LBodyStr);
  if LParsed is TJSONObject then
    Result := TJSONObject(LParsed)
  else
    LParsed.Free();
end;

procedure TMorLSPServer.WriteMessage(const AMessage: TJSONObject);
var
  LBody: string;
  LBodyBytes: TBytes;
  LHeader: string;
  LHeaderBytes: TBytes;
begin
  LBody := AMessage.ToString();
  LBodyBytes := TEncoding.UTF8.GetBytes(LBody);
  LHeader := 'Content-Length: ' + IntToStr(Length(LBodyBytes)) + #13#10 +
    'Content-Type: application/vscode-jsonrpc; charset=utf-8' + #13#10 +
    #13#10;
  LHeaderBytes := TEncoding.ASCII.GetBytes(LHeader);
  FOutputStream.WriteBuffer(LHeaderBytes[0], Length(LHeaderBytes));
  FOutputStream.WriteBuffer(LBodyBytes[0], Length(LBodyBytes));
end;

procedure TMorLSPServer.SendResponse(const AId: TJSONValue;
  const AResult: TJSONValue);
var
  LMsg: TJSONObject;
begin
  LMsg := TJSONObject.Create();
  try
    LMsg.AddPair('jsonrpc', '2.0');
    if AId <> nil then
      LMsg.AddPair('id', AId.Clone() as TJSONValue)
    else
      LMsg.AddPair('id', TJSONNull.Create());
    LMsg.AddPair('result', AResult);
    WriteMessage(LMsg);
  finally
    LMsg.Free();
  end;
end;

procedure TMorLSPServer.SendError(const AId: TJSONValue;
  const ACode: Integer; const AMessage: string);
var
  LMsg: TJSONObject;
  LError: TJSONObject;
begin
  LError := TJSONObject.Create();
  LError.AddPair('code', TJSONNumber.Create(ACode));
  LError.AddPair('message', AMessage);

  LMsg := TJSONObject.Create();
  try
    LMsg.AddPair('jsonrpc', '2.0');
    if AId <> nil then
      LMsg.AddPair('id', AId.Clone() as TJSONValue)
    else
      LMsg.AddPair('id', TJSONNull.Create());
    LMsg.AddPair('error', LError);
    WriteMessage(LMsg);
  finally
    LMsg.Free();
  end;
end;

procedure TMorLSPServer.SendNotification(const AMethod: string;
  const AParams: TJSONValue);
var
  LMsg: TJSONObject;
begin
  LMsg := TJSONObject.Create();
  try
    LMsg.AddPair('jsonrpc', '2.0');
    LMsg.AddPair('method', AMethod);
    LMsg.AddPair('params', AParams);
    WriteMessage(LMsg);
  finally
    LMsg.Free();
  end;
end;

procedure TMorLSPServer.PublishDiagnostics(const AUri: string);
var
  LDiags: TArray<TMorLSPDiagnostic>;
  LParams: TJSONObject;
  LDiagsArray: TJSONArray;
  LI: Integer;
begin
  LDiags := FService.GetDiagnostics(AUri);
  LDiagsArray := TJSONArray.Create();
  for LI := 0 to High(LDiags) do
    LDiagsArray.AddElement(LDiags[LI].ToJSON());

  LParams := TJSONObject.Create();
  LParams.AddPair('uri', AUri);
  LParams.AddPair('diagnostics', LDiagsArray);

  SendNotification('textDocument/publishDiagnostics', LParams);
end;

procedure TMorLSPServer.HandleInitialize(const AId: TJSONValue;
  const AParams: TJSONObject);
var
  LResult: TJSONObject;
  LCapabilities: TJSONObject;
  LCompletionProvider: TJSONObject;
  LTriggerCharsComp: TJSONArray;
  LSigHelpProvider: TJSONObject;
  LTriggerCharsSig: TJSONArray;
  LSemanticProvider: TJSONObject;
  LLegend: TJSONObject;
  LTokenTypes: TJSONArray;
  LTokenMods: TJSONArray;
  LServerInfo: TJSONObject;
begin
  // Semantic tokens legend (indices match GetSemanticTokens output)
  LTokenTypes := TJSONArray.Create();
  LTokenTypes.Add('namespace');    // 0
  LTokenTypes.Add('type');         // 1
  LTokenTypes.Add('class');        // 2
  LTokenTypes.Add('enum');         // 3
  LTokenTypes.Add('function');     // 4
  LTokenTypes.Add('method');       // 5
  LTokenTypes.Add('property');     // 6
  LTokenTypes.Add('variable');     // 7
  LTokenTypes.Add('parameter');    // 8
  LTokenTypes.Add('enumMember');   // 9
  LTokenTypes.Add('keyword');      // 10
  LTokenTypes.Add('operator');     // 11
  LTokenTypes.Add('number');       // 12
  LTokenTypes.Add('string');       // 13
  LTokenTypes.Add('comment');      // 14

  LTokenMods := TJSONArray.Create();
  LTokenMods.Add('declaration');
  LTokenMods.Add('definition');
  LTokenMods.Add('readonly');

  LLegend := TJSONObject.Create();
  LLegend.AddPair('tokenTypes', LTokenTypes);
  LLegend.AddPair('tokenModifiers', LTokenMods);

  LSemanticProvider := TJSONObject.Create();
  LSemanticProvider.AddPair('legend', LLegend);
  LSemanticProvider.AddPair('full', TJSONBool.Create(True));

  LTriggerCharsComp := TJSONArray.Create();
  LTriggerCharsComp.Add('.');
  LCompletionProvider := TJSONObject.Create();
  LCompletionProvider.AddPair('triggerCharacters', LTriggerCharsComp);

  LTriggerCharsSig := TJSONArray.Create();
  LTriggerCharsSig.Add('(');
  LTriggerCharsSig.Add(',');
  LSigHelpProvider := TJSONObject.Create();
  LSigHelpProvider.AddPair('triggerCharacters', LTriggerCharsSig);

  LCapabilities := TJSONObject.Create();
  LCapabilities.AddPair('textDocumentSync', TJSONNumber.Create(1));
  LCapabilities.AddPair('completionProvider', LCompletionProvider);
  LCapabilities.AddPair('hoverProvider', TJSONBool.Create(True));
  LCapabilities.AddPair('definitionProvider', TJSONBool.Create(True));
  LCapabilities.AddPair('referencesProvider', TJSONBool.Create(True));
  LCapabilities.AddPair('documentSymbolProvider', TJSONBool.Create(True));
  LCapabilities.AddPair('signatureHelpProvider', LSigHelpProvider);
  LCapabilities.AddPair('foldingRangeProvider', TJSONBool.Create(True));
  LCapabilities.AddPair('semanticTokensProvider', LSemanticProvider);
  LCapabilities.AddPair('inlayHintProvider', TJSONBool.Create(True));
  LCapabilities.AddPair('renameProvider', TJSONBool.Create(True));
  LCapabilities.AddPair('workspaceSymbolProvider', TJSONBool.Create(True));
  LCapabilities.AddPair('documentFormattingProvider', TJSONBool.Create(True));
  LCapabilities.AddPair('codeActionProvider', TJSONBool.Create(True));

  LServerInfo := TJSONObject.Create();
  LServerInfo.AddPair('name', 'metamorf-lsp');
  LServerInfo.AddPair('version', '1.0.0');

  LResult := TJSONObject.Create();
  LResult.AddPair('capabilities', LCapabilities);
  LResult.AddPair('serverInfo', LServerInfo);

  SendResponse(AId, LResult);
end;

procedure TMorLSPServer.HandleInitialized(const AParams: TJSONObject);
begin
  FInitialized := True;
end;

procedure TMorLSPServer.HandleShutdown(const AId: TJSONValue);
begin
  FShutdownRequested := True;
  SendResponse(AId, TJSONNull.Create());
end;

procedure TMorLSPServer.HandleExit();
begin
  if FShutdownRequested then
    Halt(0)
  else
    Halt(1);
end;

procedure TMorLSPServer.HandleTextDocumentDidOpen(
  const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LUri: string;
  LText: string;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  if LTextDocument = nil then Exit;
  LUri := LTextDocument.GetValue<string>('uri', '');
  LText := LTextDocument.GetValue<string>('text', '');
  if LUri = '' then Exit;

  FService.OpenDocument(LUri, LText);
  PublishDiagnostics(LUri);
end;

procedure TMorLSPServer.HandleTextDocumentDidChange(
  const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LChanges: TJSONArray;
  LFirstChange: TJSONObject;
  LUri: string;
  LVersion: Integer;
  LText: string;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  if LTextDocument = nil then Exit;
  LUri := LTextDocument.GetValue<string>('uri', '');
  LVersion := LTextDocument.GetValue<Integer>('version', 0);
  if LUri = '' then Exit;

  // Full sync (textDocumentSync: 1) - take first change's full text
  LChanges := AParams.GetValue<TJSONArray>('contentChanges', nil);
  if (LChanges = nil) or (LChanges.Count = 0) then Exit;
  LFirstChange := LChanges.Items[0] as TJSONObject;
  LText := LFirstChange.GetValue<string>('text', '');

  FService.UpdateDocument(LUri, LText, LVersion);
  PublishDiagnostics(LUri);
end;

procedure TMorLSPServer.HandleTextDocumentDidClose(
  const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LUri: string;
  LParams: TJSONObject;
  LEmptyDiags: TJSONArray;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  if LTextDocument = nil then Exit;
  LUri := LTextDocument.GetValue<string>('uri', '');
  if LUri = '' then Exit;

  FService.CloseDocument(LUri);

  // Clear diagnostics for closed file
  LEmptyDiags := TJSONArray.Create();
  LParams := TJSONObject.Create();
  LParams.AddPair('uri', LUri);
  LParams.AddPair('diagnostics', LEmptyDiags);
  SendNotification('textDocument/publishDiagnostics', LParams);
end;

procedure TMorLSPServer.HandleTextDocumentCompletion(
  const AId: TJSONValue; const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LPosition: TJSONObject;
  LUri: string;
  LItems: TArray<TMorLSPCompletionItem>;
  LResultArray: TJSONArray;
  LI: Integer;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  LPosition := AParams.GetValue<TJSONObject>('position', nil);
  if (LTextDocument = nil) or (LPosition = nil) then
  begin
    SendResponse(AId, TJSONArray.Create());
    Exit;
  end;

  LUri := LTextDocument.GetValue<string>('uri', '');
  LItems := FService.GetCompletions(LUri,
    LPosition.GetValue<Integer>('line', 0),
    LPosition.GetValue<Integer>('character', 0));

  LResultArray := TJSONArray.Create();
  for LI := 0 to High(LItems) do
    LResultArray.AddElement(LItems[LI].ToJSON());
  SendResponse(AId, LResultArray);
end;

procedure TMorLSPServer.HandleTextDocumentHover(
  const AId: TJSONValue; const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LPosition: TJSONObject;
  LHover: TMorLSPHover;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  LPosition := AParams.GetValue<TJSONObject>('position', nil);
  if (LTextDocument = nil) or (LPosition = nil) then
  begin
    SendResponse(AId, TJSONNull.Create());
    Exit;
  end;

  LHover := FService.GetHover(
    LTextDocument.GetValue<string>('uri', ''),
    LPosition.GetValue<Integer>('line', 0),
    LPosition.GetValue<Integer>('character', 0));

  if LHover.IsEmpty() then
    SendResponse(AId, TJSONNull.Create())
  else
    SendResponse(AId, LHover.ToJSON());
end;

procedure TMorLSPServer.HandleTextDocumentDefinition(
  const AId: TJSONValue; const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LPosition: TJSONObject;
  LLocation: TMorLSPLocation;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  LPosition := AParams.GetValue<TJSONObject>('position', nil);
  if (LTextDocument = nil) or (LPosition = nil) then
  begin
    SendResponse(AId, TJSONNull.Create());
    Exit;
  end;

  LLocation := FService.GetDefinition(
    LTextDocument.GetValue<string>('uri', ''),
    LPosition.GetValue<Integer>('line', 0),
    LPosition.GetValue<Integer>('character', 0));

  if LLocation.IsEmpty() then
    SendResponse(AId, TJSONNull.Create())
  else
    SendResponse(AId, LLocation.ToJSON());
end;

procedure TMorLSPServer.HandleTextDocumentReferences(
  const AId: TJSONValue; const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LPosition: TJSONObject;
  LContext: TJSONObject;
  LIncludeDecl: Boolean;
  LLocations: TArray<TMorLSPLocation>;
  LResultArray: TJSONArray;
  LI: Integer;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  LPosition := AParams.GetValue<TJSONObject>('position', nil);
  LContext := AParams.GetValue<TJSONObject>('context', nil);
  if (LTextDocument = nil) or (LPosition = nil) then
  begin
    SendResponse(AId, TJSONArray.Create());
    Exit;
  end;

  LIncludeDecl := False;
  if LContext <> nil then
    LIncludeDecl := LContext.GetValue<Boolean>('includeDeclaration', False);

  LLocations := FService.GetReferences(
    LTextDocument.GetValue<string>('uri', ''),
    LPosition.GetValue<Integer>('line', 0),
    LPosition.GetValue<Integer>('character', 0),
    LIncludeDecl);

  LResultArray := TJSONArray.Create();
  for LI := 0 to High(LLocations) do
    LResultArray.AddElement(LLocations[LI].ToJSON());
  SendResponse(AId, LResultArray);
end;

procedure TMorLSPServer.HandleTextDocumentDocumentSymbol(
  const AId: TJSONValue; const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LSymbols: TArray<TMorLSPDocumentSymbol>;
  LResultArray: TJSONArray;
  LI: Integer;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  if LTextDocument = nil then
  begin
    SendResponse(AId, TJSONArray.Create());
    Exit;
  end;

  LSymbols := FService.GetDocumentSymbols(
    LTextDocument.GetValue<string>('uri', ''));
  LResultArray := TJSONArray.Create();
  for LI := 0 to High(LSymbols) do
    LResultArray.AddElement(LSymbols[LI].ToJSON());
  SendResponse(AId, LResultArray);
end;

procedure TMorLSPServer.HandleTextDocumentSignatureHelp(
  const AId: TJSONValue; const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LPosition: TJSONObject;
  LSigHelp: TMorLSPSignatureHelp;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  LPosition := AParams.GetValue<TJSONObject>('position', nil);
  if (LTextDocument = nil) or (LPosition = nil) then
  begin
    SendResponse(AId, TJSONNull.Create());
    Exit;
  end;

  LSigHelp := FService.GetSignatureHelp(
    LTextDocument.GetValue<string>('uri', ''),
    LPosition.GetValue<Integer>('line', 0),
    LPosition.GetValue<Integer>('character', 0));

  if Length(LSigHelp.Signatures) = 0 then
    SendResponse(AId, TJSONNull.Create())
  else
    SendResponse(AId, LSigHelp.ToJSON());
end;

procedure TMorLSPServer.HandleTextDocumentFoldingRange(
  const AId: TJSONValue; const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LRanges: TArray<TMorLSPFoldingRange>;
  LResultArray: TJSONArray;
  LI: Integer;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  if LTextDocument = nil then
  begin
    SendResponse(AId, TJSONArray.Create());
    Exit;
  end;

  LRanges := FService.GetFoldingRanges(
    LTextDocument.GetValue<string>('uri', ''));
  LResultArray := TJSONArray.Create();
  for LI := 0 to High(LRanges) do
    LResultArray.AddElement(LRanges[LI].ToJSON());
  SendResponse(AId, LResultArray);
end;

procedure TMorLSPServer.HandleTextDocumentSemanticTokensFull(
  const AId: TJSONValue; const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LTokenData: TArray<Integer>;
  LDataArray: TJSONArray;
  LResultObj: TJSONObject;
  LI: Integer;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  if LTextDocument = nil then
  begin
    SendResponse(AId, TJSONObject.Create());
    Exit;
  end;

  LTokenData := FService.GetSemanticTokens(
    LTextDocument.GetValue<string>('uri', ''));
  LDataArray := TJSONArray.Create();
  for LI := 0 to High(LTokenData) do
    LDataArray.Add(LTokenData[LI]);

  LResultObj := TJSONObject.Create();
  LResultObj.AddPair('data', LDataArray);
  SendResponse(AId, LResultObj);
end;

procedure TMorLSPServer.HandleTextDocumentInlayHint(
  const AId: TJSONValue; const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LRangeObj: TJSONObject;
  LLSPRange: TMorLSPRange;
  LHints: TArray<TMorLSPInlayHint>;
  LResultArray: TJSONArray;
  LI: Integer;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  if LTextDocument = nil then
  begin
    SendResponse(AId, TJSONArray.Create());
    Exit;
  end;

  LRangeObj := AParams.GetValue<TJSONObject>('range', nil);
  if LRangeObj <> nil then
    LLSPRange := TMorLSPRange.FromJSON(LRangeObj)
  else
    LLSPRange.Clear();

  LHints := FService.GetInlayHints(
    LTextDocument.GetValue<string>('uri', ''),
    LLSPRange.StartPos.Line, LLSPRange.StartPos.Character,
    LLSPRange.EndPos.Line, LLSPRange.EndPos.Character);

  LResultArray := TJSONArray.Create();
  for LI := 0 to High(LHints) do
    LResultArray.AddElement(LHints[LI].ToJSON());
  SendResponse(AId, LResultArray);
end;

procedure TMorLSPServer.HandleTextDocumentRename(
  const AId: TJSONValue; const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LPosition: TJSONObject;
  LNewName: string;
  LEdit: TMorLSPWorkspaceEdit;
  LChanges: TJSONObject;
  LEditsArray: TJSONArray;
  LResultObj: TJSONObject;
  LUri: string;
  LI: Integer;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  LPosition := AParams.GetValue<TJSONObject>('position', nil);
  if (LTextDocument = nil) or (LPosition = nil) then
  begin
    SendResponse(AId, TJSONNull.Create());
    Exit;
  end;

  LUri := LTextDocument.GetValue<string>('uri', '');
  LNewName := AParams.GetValue<string>('newName', '');
  if LNewName = '' then
  begin
    SendResponse(AId, TJSONNull.Create());
    Exit;
  end;

  LEdit := FService.GetRenameEdits(LUri,
    LPosition.GetValue<Integer>('line', 0),
    LPosition.GetValue<Integer>('character', 0),
    LNewName);

  if Length(LEdit.Edits) = 0 then
  begin
    SendResponse(AId, TJSONNull.Create());
    Exit;
  end;

  LEditsArray := TJSONArray.Create();
  for LI := 0 to High(LEdit.Edits) do
    LEditsArray.AddElement(LEdit.Edits[LI].ToJSON());

  LChanges := TJSONObject.Create();
  LChanges.AddPair(LUri, LEditsArray);

  LResultObj := TJSONObject.Create();
  LResultObj.AddPair('changes', LChanges);
  SendResponse(AId, LResultObj);
end;

procedure TMorLSPServer.HandleWorkspaceSymbol(
  const AId: TJSONValue; const AParams: TJSONObject);
var
  LQuery: string;
  LSymbols: TArray<TMorLSPSymbolInformation>;
  LResultArray: TJSONArray;
  LI: Integer;
begin
  LQuery := AParams.GetValue<string>('query', '');
  LSymbols := FService.GetWorkspaceSymbols(LQuery, '');

  LResultArray := TJSONArray.Create();
  for LI := 0 to High(LSymbols) do
    LResultArray.AddElement(LSymbols[LI].ToJSON());
  SendResponse(AId, LResultArray);
end;

procedure TMorLSPServer.HandleTextDocumentCodeAction(
  const AId: TJSONValue; const AParams: TJSONObject);
begin
  SendResponse(AId, TJSONArray.Create());
end;

procedure TMorLSPServer.HandleTextDocumentFormatting(
  const AId: TJSONValue; const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LOptions: TJSONObject;
  LTabSize: Integer;
  LInsertSpaces: Boolean;
  LEdits: TArray<TMorLSPTextEdit>;
  LResultArray: TJSONArray;
  LI: Integer;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  if LTextDocument = nil then
  begin
    SendResponse(AId, TJSONArray.Create());
    Exit;
  end;

  LOptions := AParams.GetValue<TJSONObject>('options', nil);
  LTabSize := 2;
  LInsertSpaces := True;
  if LOptions <> nil then
  begin
    LTabSize := LOptions.GetValue<Integer>('tabSize', 2);
    LInsertSpaces := LOptions.GetValue<Boolean>('insertSpaces', True);
  end;

  LEdits := FService.GetDocumentFormatting(
    LTextDocument.GetValue<string>('uri', ''),
    LTabSize, LInsertSpaces);

  LResultArray := TJSONArray.Create();
  for LI := 0 to High(LEdits) do
    LResultArray.AddElement(LEdits[LI].ToJSON());
  SendResponse(AId, LResultArray);
end;

procedure TMorLSPServer.DispatchMessage(const AMessage: TJSONObject);
var
  LMethod: string;
  LId: TJSONValue;
  LParams: TJSONObject;
begin
  LMethod := AMessage.GetValue<string>('method', '');
  LId := AMessage.GetValue<TJSONValue>('id', nil);
  LParams := AMessage.GetValue<TJSONObject>('params', nil);

  if LMethod = '' then Exit;

  // Notifications (no id)
  if LMethod = 'initialized' then
    HandleInitialized(LParams)
  else if LMethod = 'exit' then
    HandleExit()
  else if LMethod = 'textDocument/didOpen' then
    HandleTextDocumentDidOpen(LParams)
  else if LMethod = 'textDocument/didChange' then
    HandleTextDocumentDidChange(LParams)
  else if LMethod = 'textDocument/didClose' then
    HandleTextDocumentDidClose(LParams)

  // Requests (have id)
  else if LMethod = 'initialize' then
    HandleInitialize(LId, LParams)
  else if LMethod = 'shutdown' then
    HandleShutdown(LId)
  else if LMethod = 'textDocument/completion' then
    HandleTextDocumentCompletion(LId, LParams)
  else if LMethod = 'textDocument/hover' then
    HandleTextDocumentHover(LId, LParams)
  else if LMethod = 'textDocument/definition' then
    HandleTextDocumentDefinition(LId, LParams)
  else if LMethod = 'textDocument/references' then
    HandleTextDocumentReferences(LId, LParams)
  else if LMethod = 'textDocument/documentSymbol' then
    HandleTextDocumentDocumentSymbol(LId, LParams)
  else if LMethod = 'textDocument/signatureHelp' then
    HandleTextDocumentSignatureHelp(LId, LParams)
  else if LMethod = 'textDocument/foldingRange' then
    HandleTextDocumentFoldingRange(LId, LParams)
  else if LMethod = 'textDocument/semanticTokens/full' then
    HandleTextDocumentSemanticTokensFull(LId, LParams)
  else if LMethod = 'textDocument/inlayHint' then
    HandleTextDocumentInlayHint(LId, LParams)
  else if LMethod = 'textDocument/rename' then
    HandleTextDocumentRename(LId, LParams)
  else if LMethod = 'workspace/symbol' then
    HandleWorkspaceSymbol(LId, LParams)
  else if LMethod = 'textDocument/codeAction' then
    HandleTextDocumentCodeAction(LId, LParams)
  else if LMethod = 'textDocument/formatting' then
    HandleTextDocumentFormatting(LId, LParams)
  else
  begin
    // Unknown method: only send error for requests (those with an id)
    if LId <> nil then
      SendError(LId, -32601, 'Method not found: ' + LMethod);
  end;
end;

procedure TMorLSPServer.Run();
var
  LMessage: TJSONObject;
  LStdinStream: THandleStream;
  LStdoutStream: THandleStream;
begin
  // If no streams set, default to stdin/stdout
  if FInputStream = nil then
  begin
    LStdinStream := THandleStream.Create(GetStdHandle(STD_INPUT_HANDLE));
    LStdoutStream := THandleStream.Create(GetStdHandle(STD_OUTPUT_HANDLE));
    FInputStream := LStdinStream;
    FOutputStream := LStdoutStream;
    FOwnsStreams := True;
  end;

  // Load the .mor language definition
  if FMorFile <> '' then
  begin
    FEngineAPI := TMorEngineAPI.Create();
    FEngineAPI.LoadMor(FMorFile);
    if FEngineAPI.GetErrors().HasErrors() then
      Exit;
    FService.SetInterpreter(FEngineAPI.GetInterpreter());
  end;

  // Message loop
  while True do
  begin
    LMessage := ReadMessage();
    if LMessage = nil then
      Break;

    try
      DispatchMessage(LMessage);
    finally
      LMessage.Free();
    end;

    if FShutdownRequested then
      Break;
  end;
end;

end.
