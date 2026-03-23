{===============================================================================
  Pax™ - Compiler Construction Toolkit

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://paxkit.org

  See LICENSE for license information
===============================================================================}

unit Myra.Semantics;

{$I Metamorf.Defines.inc}

interface

uses
  Metamorf.API;

procedure ConfigMyraSemantics(const APax: TMetamorf);

implementation

uses
  System.SysUtils,
  System.Rtti,
  Metamorf.Common,
  Myra.Common;

// =========================================================================
// TYPE COMPATIBILITY
// =========================================================================

procedure RegisterTypeCompat(const APax: TMetamorf);
begin
  APax.Config().RegisterTypeCompat(
    function(const AFromType, AToType: string;
      out ACoerceTo: string): Boolean
    begin
      ACoerceTo := '';

      // Exact match — no coercion needed
      if SameText(AFromType, AToType) then
        Exit(True);

      // Integer family widening: int8 -> int16 -> int32 -> int64
      if SameText(AToType, 'type.int64') and
         (SameText(AFromType, 'type.int8') or SameText(AFromType, 'type.int16') or
          SameText(AFromType, 'type.int32')) then
      begin
        ACoerceTo := AToType;
        Exit(True);
      end;
      if SameText(AToType, 'type.int32') and
         (SameText(AFromType, 'type.int8') or SameText(AFromType, 'type.int16')) then
      begin
        ACoerceTo := AToType;
        Exit(True);
      end;
      if SameText(AToType, 'type.int16') and SameText(AFromType, 'type.int8') then
      begin
        ACoerceTo := AToType;
        Exit(True);
      end;

      // Unsigned integer widening
      if SameText(AToType, 'type.uint64') and
         (SameText(AFromType, 'type.uint8') or SameText(AFromType, 'type.uint16') or
          SameText(AFromType, 'type.uint32')) then
      begin
        ACoerceTo := AToType;
        Exit(True);
      end;
      if SameText(AToType, 'type.uint32') and
         (SameText(AFromType, 'type.uint8') or SameText(AFromType, 'type.uint16')) then
      begin
        ACoerceTo := AToType;
        Exit(True);
      end;
      if SameText(AToType, 'type.uint16') and SameText(AFromType, 'type.uint8') then
      begin
        ACoerceTo := AToType;
        Exit(True);
      end;

      // Float widening: float32 -> float64
      if SameText(AToType, 'type.float64') and SameText(AFromType, 'type.float32') then
      begin
        ACoerceTo := AToType;
        Exit(True);
      end;

      // Integer -> float promotion
      if (SameText(AToType, 'type.float32') or SameText(AToType, 'type.float64')) and
         (SameText(AFromType, 'type.int8') or SameText(AFromType, 'type.int16') or
          SameText(AFromType, 'type.int32') or SameText(AFromType, 'type.int64') or
          SameText(AFromType, 'type.uint8') or SameText(AFromType, 'type.uint16') or
          SameText(AFromType, 'type.uint32') or SameText(AFromType, 'type.uint64')) then
      begin
        ACoerceTo := AToType;
        Exit(True);
      end;

      // nil -> any pointer
      if SameText(AFromType, 'type.nil') and SameText(AToType, 'type.pointer') then
        Exit(True);

      // char -> string promotion
      if SameText(AToType, 'type.string') and SameText(AFromType, 'type.char') then
      begin
        ACoerceTo := AToType;
        Exit(True);
      end;
      if SameText(AToType, 'type.wstring') and SameText(AFromType, 'type.wchar') then
      begin
        ACoerceTo := AToType;
        Exit(True);
      end;

      Result := False;
    end);
end;

// =========================================================================
// SEMANTIC RULES — Directives
// =========================================================================

procedure RegisterDirectiveSemantics(const APax: TMetamorf);
begin
  APax.Config().RegisterSemanticRule('stmt.directive',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    var
      LName:   TValue;
      LVal:    TValue;
      LDir:    string;
      LValue:  string;
      LIntVal: Integer;
      LStr:    string;
    begin
      if not TASTNode(ANode).GetAttr('directive.name', LName) then
        Exit;
      LDir := LName.AsString();

      if not TASTNode(ANode).GetAttr('directive.value', LVal) then
        LValue := ''
      else
        LValue := LVal.AsString();

      if SameText(LDir, 'optimize') then
      begin
        if SameText(LValue, 'debug') then
          APax.SetOptimizeLevel(olDebug)
        else if SameText(LValue, 'releasesafe') then
          APax.SetOptimizeLevel(olReleaseSafe)
        else if SameText(LValue, 'releasefast') then
          APax.SetOptimizeLevel(olReleaseFast)
        else if SameText(LValue, 'releasesmall') then
          APax.SetOptimizeLevel(olReleaseSmall)
        else
          ASem.AddSemanticError(ANode, 'S202',
            'Unknown optimize level: ' + LValue +
            '. Valid values: debug, releasesafe, releasefast, releasesmall');
      end
      else if SameText(LDir, 'addverinfo') then
      begin
        if SameText(LValue, 'on') then
          APax.SetAddVersionInfo(True)
        else if SameText(LValue, 'off') then
          APax.SetAddVersionInfo(False)
        else
          ASem.AddSemanticError(ANode, 'S204',
            'Invalid addverinfo value: ' + LValue +
            '. Valid values: on, off');
      end
      else if SameText(LDir, 'vimajor') or
              SameText(LDir, 'viminor') or
              SameText(LDir, 'vipatch') then
      begin
        if not TryStrToInt(LValue, LIntVal) then
          ASem.AddSemanticError(ANode, 'S205',
            'Expected integer value for ' + LDir + ', got: ' + LValue)
        else
        begin
          if SameText(LDir, 'vimajor') then
            APax.SetVIMajor(Word(LIntVal))
          else if SameText(LDir, 'viminor') then
            APax.SetVIMinor(Word(LIntVal))
          else
            APax.SetVIPatch(Word(LIntVal));
        end;
      end
      else if SameText(LDir, 'viproductname') or
              SameText(LDir, 'videscription') or
              SameText(LDir, 'vifilename') or
              SameText(LDir, 'vicompanyname') or
              SameText(LDir, 'vicopyright') then
      begin
        LStr := LValue.DeQuotedString('"');
        if SameText(LDir, 'viproductname') then
          APax.SetVIProductName(LStr)
        else if SameText(LDir, 'videscription') then
          APax.SetVIDescription(LStr)
        else if SameText(LDir, 'vifilename') then
          APax.SetVIFilename(LStr)
        else if SameText(LDir, 'vicompanyname') then
          APax.SetVICompanyName(LStr)
        else
          APax.SetVICopyright(LStr);
      end
      else if SameText(LDir, 'exeicon') then
      begin
        APax.SetExeIcon(LValue.DeQuotedString('"'));
      end
      else if SameText(LDir, 'includepath') then
      begin
        APax.AddIncludePath(LValue.DeQuotedString('"'));
      end
      else if SameText(LDir, 'modulepath') then
      begin
        APax.AddIncludePath(LValue.DeQuotedString('"'));
      end
      else if SameText(LDir, 'librarypath') then
      begin
        APax.AddLibraryPath(LValue.DeQuotedString('"'));
      end
      else if SameText(LDir, 'linklibrary') then
      begin
        APax.AddLinkLibrary(LValue.DeQuotedString('"'));
      end
      else if SameText(LDir, 'copydll') then
      begin
        APax.AddCopyDLL(LValue.DeQuotedString('"'));
      end
      else if SameText(LDir, 'breakpoint') then
      begin
        // No-op at semantic level — debugger support
      end
      else if SameText(LDir, 'message') then
      begin
        // Compiler diagnostic — handled at parse time, no-op here
      end
      else
        ASem.AddSemanticError(ANode, 'S203',
          'Unknown directive: ' + LDir);
    end);
end;

// =========================================================================
// SEMANTIC RULES — Module
// =========================================================================

procedure RegisterModuleSemantics(const APax: TMetamorf);
begin
  APax.Config().RegisterSemanticRule('stmt.module',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    var
      LValue: TValue;
      LKind:  TValue;
    begin
      if TASTNode(ANode).GetAttr('module.kind', LKind) then
      begin
        if LKind.AsString = 'exe' then
          APax.SetBuildMode(bmExe)
        else if LKind.AsString = 'lib' then
          APax.SetBuildMode(bmLib)
        else if LKind.AsString = 'dll' then
          APax.SetBuildMode(bmDll)
        else
          ASem.AddSemanticError(ANode, 'S100',
            'Unknown module kind: ' + LKind.AsString);
      end;

      TASTNode(ANode).GetAttr('module.name', LValue);
      ASem.PushScope(LValue.AsString, ANode.GetToken());
      ASem.VisitChildren(ANode);
      ASem.PopScope(ANode.GetToken());
    end);

  APax.Config().RegisterSemanticRule('stmt.import_item',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    var
      LNameVal: TValue;
    begin
      if TASTNode(ANode).GetAttr('import.name', LNameVal) then
        ASem.CompileModule(LNameVal.AsString);
    end);
end;

// =========================================================================
// FLOAT LITERAL TYPE STAMPING
// =========================================================================

// Recursively walks ANode's subtree and stamps every 'expr.float' node
// with 'expr.target_type' = ATargetType (e.g. 'type.float32').
procedure StampFloatLiterals(const ANode: TASTNodeBase;
  const ATargetType: string);
var
  LI: Integer;
begin
  if ANode = nil then
    Exit;
  if ANode.GetNodeKind() = 'expr.float' then
    TASTNode(ANode).SetAttr('expr.target_type',
      TValue.From<string>(ATargetType));
  for LI := 0 to ANode.ChildCount() - 1 do
    StampFloatLiterals(ANode.GetChild(LI), ATargetType);
end;

// =========================================================================
// SEMANTIC RULES — Declarations
// =========================================================================

procedure RegisterDeclSemantics(const APax: TMetamorf);
begin
  APax.Config().RegisterSemanticRule('stmt.var_block',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    begin
      ASem.VisitChildren(ANode);
    end);

  APax.Config().RegisterSemanticRule('stmt.var_decl',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    var
      LValue:   TValue;
      LTypeVal: TValue;
    begin
      TASTNode(ANode).GetAttr('var.name', LValue);
      if not ASem.DeclareSymbol(LValue.AsString, ANode) then
        ASem.AddSemanticError(ANode, 'S100',
          'Duplicate variable declaration: ' + LValue.AsString);
      ASem.VisitChildren(ANode);

      // Stamp float literals in initializer with declared type context
      if (ANode.ChildCount() > 0) and
         TASTNode(ANode).GetAttr('var.type_text', LTypeVal) and
         (LTypeVal.AsString = 'float32') then
        StampFloatLiterals(ANode.GetChild(0), 'type.float32');
    end);

  APax.Config().RegisterSemanticRule('stmt.const_block',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    begin
      ASem.VisitChildren(ANode);
    end);

  APax.Config().RegisterSemanticRule('stmt.const_decl',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    var
      LValue: TValue;
    begin
      TASTNode(ANode).GetAttr('const.name', LValue);
      if not ASem.DeclareSymbol(LValue.AsString, ANode) then
        ASem.AddSemanticError(ANode, 'S101',
          'Duplicate constant declaration: ' + LValue.AsString);
      ASem.VisitChildren(ANode);
    end);

  APax.Config().RegisterSemanticRule('stmt.type_block',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    begin
      ASem.VisitChildren(ANode);
    end);

  APax.Config().RegisterSemanticRule('stmt.type_decl',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    var
      LValue: TValue;
    begin
      TASTNode(ANode).GetAttr('decl.name', LValue);
      if not ASem.DeclareSymbol(LValue.AsString, ANode) then
        ASem.AddSemanticError(ANode, 'S102',
          'Duplicate type declaration: ' + LValue.AsString);
      ASem.VisitChildren(ANode);
    end);

  APax.Config().RegisterSemanticRule('stmt.exported',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    var
      LChild:      TASTNodeBase;
      LVarBlock:   TASTNodeBase;
      LI:          Integer;
      LExportAttr: string;
    begin
      // Resolve platform-specific export attribute for DLL builds
      LExportAttr := '';
      if APax.GetBuildMode() = bmDll then
      begin
        if APax.GetTargetPlatform() = tpLinux64 then
          LExportAttr := '__attribute__((visibility("default")))'
        else
          LExportAttr := '__declspec(dllexport)';
      end;

      // Stamp exported on the child so codegen reads it directly
      if ANode.ChildCount() > 0 then
      begin
        LChild := ANode.GetChild(0);
        if LChild.GetNodeKind() = 'stmt.routine_decl' then
        begin
          TASTNode(LChild).SetAttr('decl.exported',
            TValue.From<Boolean>(True));
          if LExportAttr <> '' then
            TASTNode(LChild).SetAttr('decl.export_attr',
              TValue.From<string>(LExportAttr));
        end
        else if LChild.GetNodeKind() = 'stmt.var_block' then
        begin
          LVarBlock := LChild;
          for LI := 0 to LVarBlock.ChildCount() - 1 do
          begin
            if LVarBlock.GetChild(LI).GetNodeKind() = 'stmt.var_decl' then
            begin
              TASTNode(LVarBlock.GetChild(LI)).SetAttr('var.exported',
                TValue.From<Boolean>(True));
              if LExportAttr <> '' then
                TASTNode(LVarBlock.GetChild(LI)).SetAttr('var.export_attr',
                  TValue.From<string>(LExportAttr));
            end;
          end;
        end;
      end;
      ASem.VisitChildren(ANode);
    end);
end;

// =========================================================================
// SEMANTIC RULES — Routines
// =========================================================================

procedure RegisterRoutineSemantics(const APax: TMetamorf);
begin
  APax.Config().RegisterSemanticRule('stmt.routine_decl',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    var
      LValue:       TValue;
      LTypeVal:     TValue;
      LLinkVal:     TValue;
      LName:        string;
      LSignature:   string;
      LFirst:       Boolean;
      LI:           Integer;
      LIsOverloaded: Boolean;
    begin
      TASTNode(ANode).GetAttr('decl.name', LValue);
      LName := LValue.AsString;

      // Build signature key: "Foo(i32,f32)" or "Foo()" for no params
      LSignature := LName + '(';
      LFirst := True;
      for LI := 0 to ANode.ChildCount() - 1 do
      begin
        if ANode.GetChild(LI).GetNodeKind() = 'stmt.param_decl' then
        begin
          if not LFirst then
            LSignature := LSignature + ',';
          TASTNode(ANode.GetChild(LI)).GetAttr('param.type_text', LTypeVal);
          LSignature := LSignature + LTypeVal.AsString;
          LFirst := False;
        end;
      end;
      LSignature := LSignature + ')';

      // Overload detection + C linkage demotion
      LIsOverloaded := ASem.SymbolExistsWithPrefix(LName + '(');
      if LIsOverloaded then
      begin
        // Demote any previously declared overloads with "C" linkage
        ASem.DemoteCLinkageForPrefix(LName + '(');

        // Demote current routine if "C"
        if TASTNode(ANode).GetAttr('decl.linkage', LLinkVal) and
           (LLinkVal.AsString = '"C"') then
        begin
          TASTNode(ANode).SetAttr('decl.linkage', TValue.From<string>(''));
          ASem.AddSemanticWarning(ANode, 'W200',
            'Overloaded routine ''' + LName +
            ''' cannot use C linkage; defaulting to C++ linkage');
        end;
      end;

      // Declare with signature key — duplicate = same name AND same param types
      if not ASem.DeclareSymbol(LSignature, ANode) then
        ASem.AddSemanticError(ANode, 'S110',
          'Duplicate routine declaration: ' + LSignature);

      ASem.PushScope(LName, ANode.GetToken());
      ASem.VisitChildren(ANode);
      ASem.PopScope(ANode.GetToken());
    end);

  APax.Config().RegisterSemanticRule('stmt.method_decl',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    var
      LValue: TValue;
    begin
      TASTNode(ANode).GetAttr('decl.name', LValue);
      ASem.PushScope(LValue.AsString, ANode.GetToken());
      ASem.VisitChildren(ANode);
      ASem.PopScope(ANode.GetToken());
    end);

  APax.Config().RegisterSemanticRule('stmt.param_decl',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    var
      LValue: TValue;
    begin
      TASTNode(ANode).GetAttr('param.name', LValue);
      if not ASem.DeclareSymbol(LValue.AsString, ANode) then
        ASem.AddSemanticError(ANode, 'S111',
          'Duplicate parameter declaration: ' + LValue.AsString);
    end);
end;

// =========================================================================
// SEMANTIC RULES — Statements
// =========================================================================

procedure RegisterStmtSemantics(const APax: TMetamorf);
begin
  APax.Config().RegisterSemanticRule('stmt.begin_block',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    begin
      ASem.VisitChildren(ANode);
    end);

  APax.Config().RegisterSemanticRule('stmt.if',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    begin
      ASem.VisitChildren(ANode);
    end);

  APax.Config().RegisterSemanticRule('stmt.while',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    begin
      ASem.VisitChildren(ANode);
    end);

  APax.Config().RegisterSemanticRule('stmt.for',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    begin
      ASem.VisitChildren(ANode);
    end);

  APax.Config().RegisterSemanticRule('stmt.repeat',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    begin
      ASem.VisitChildren(ANode);
    end);

  APax.Config().RegisterSemanticRule('stmt.return',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    begin
      ASem.VisitChildren(ANode);
    end);

  APax.Config().RegisterSemanticRule('stmt.guard',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    begin
      ASem.VisitChildren(ANode);
    end);
end;

// =========================================================================
// SEMANTIC RULES — Expressions
// =========================================================================

procedure RegisterExprSemantics(const APax: TMetamorf);
begin
  APax.Config().RegisterSemanticRule('expr.assign',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    var
      LLHSNode:  TASTNodeBase;
      LDeclNode: TASTNodeBase;
      LTypeVal:  TValue;
      LIdent:    string;
    begin
      ASem.VisitChildren(ANode);

      // Flow type context from LHS to RHS for float literals
      if ANode.ChildCount() >= 2 then
      begin
        LLHSNode := ANode.GetChild(0);
        if LLHSNode.GetNodeKind() = 'expr.ident' then
        begin
          LIdent := LLHSNode.GetToken().Text;
          if ASem.LookupSymbol(LIdent, LDeclNode) and
             TASTNode(LDeclNode).GetAttr('var.type_text', LTypeVal) and
             (LTypeVal.AsString = 'float32') then
            StampFloatLiterals(ANode.GetChild(1), 'type.float32');
        end;
      end;
    end);

  APax.Config().RegisterSemanticRule('expr.call',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    begin
      // Do not validate the callee name — C++ functions from #include
      // won't be in the Myra symbol table. Clang validates them.
      ASem.VisitChildren(ANode);
    end);

  APax.Config().RegisterSemanticRule('expr.binary',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    begin
      ASem.VisitChildren(ANode);
    end);

  APax.Config().RegisterSemanticRule('expr.unary',
    procedure(const ANode: TASTNodeBase; ASem: TSemanticBase)
    begin
      ASem.VisitChildren(ANode);
    end);
end;

// =========================================================================
// Public Entry Point
// =========================================================================

procedure ConfigMyraSemantics(const APax: TMetamorf);
begin
  APax.Config().SetModuleExtension(MYRA_EXT);
  RegisterTypeCompat(APax);
  RegisterDirectiveSemantics(APax);
  RegisterModuleSemantics(APax);
  RegisterDeclSemantics(APax);
  RegisterRoutineSemantics(APax);
  RegisterStmtSemantics(APax);
  RegisterExprSemantics(APax);
end;

end.
