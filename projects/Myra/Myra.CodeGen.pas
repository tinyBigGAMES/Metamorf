{===============================================================================
  Pax™ - Compiler Construction Toolkit

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://paxkit.org

  See LICENSE for license information
===============================================================================}

unit Myra.CodeGen;

{$I Metamorf.Defines.inc}

interface

uses
  Metamorf.API;

procedure ConfigMyraCodeGen(const APax: TMetamorf);

implementation

uses
  System.SysUtils,
  System.Rtti,
  Metamorf.Common;

// =========================================================================
// HELPERS
// =========================================================================

function PaxTypeToCpp(const ATypeText: string): string;
var
  LLower: string;
begin
  LLower := LowerCase(ATypeText);
  if LLower = 'int8' then Result := 'int8_t'
  else if LLower = 'int16' then Result := 'int16_t'
  else if LLower = 'int32' then Result := 'int32_t'
  else if LLower = 'int64' then Result := 'int64_t'
  else if LLower = 'uint8' then Result := 'uint8_t'
  else if LLower = 'uint16' then Result := 'uint16_t'
  else if LLower = 'uint32' then Result := 'uint32_t'
  else if LLower = 'uint64' then Result := 'uint64_t'
  else if LLower = 'float32' then Result := 'float'
  else if LLower = 'float64' then Result := 'double'
  else if LLower = 'boolean' then Result := 'bool'
  else if LLower = 'char' then Result := 'char'
  else if LLower = 'wchar' then Result := 'wchar_t'
  else if LLower = 'string' then Result := 'std::string'
  else if LLower = 'wstring' then Result := 'std::wstring'
  else if LLower = 'pointer' then Result := 'void*'
  else Result := ATypeText;
end;

// =========================================================================
// MODULE EMITTERS
// =========================================================================

procedure RegisterModuleEmitters(const APax: TMetamorf);
begin
  APax.Config().RegisterEmitter('stmt.module',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LKindVal: TValue;
    begin
      // Stamp module kind into IR context from AST so child emitters
      // read the correct value without relying on APax.GetBuildMode()
      if TASTNode(ANode).GetAttr('module.kind', LKindVal) then
        AGen.SetContext('module.kind', LKindVal.AsString);

      AGen.Include('<cstdint>');
      AGen.Include('<string>');
      AGen.Include('<vector>');
      AGen.Include('<print>');
      AGen.Include('"mor_runtime.h"');
      AGen.EmitLine('');
      AGen.EmitChildren(ANode);
    end);

  APax.Config().RegisterEmitter('stmt.module_body',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      // Read module kind from IR context (stamped by stmt.module emitter)
      if AGen.GetContext('module.kind', '') = 'exe' then
      begin
        AGen.EmitLine('int main(int argc, char** argv) {');
        AGen.IndentIn();
        AGen.EmitLine('mor_initconsole();');
        AGen.EmitLine('mor_init_args(argc, argv);');
        AGen.EmitChildren(ANode);
        AGen.EmitLine('return 0;');
        AGen.IndentOut();
        AGen.EmitLine('}');
      end
      else
        // lib/dll — emit body statements without main() wrapper
        AGen.EmitChildren(ANode);
    end);

  APax.Config().RegisterEmitter('stmt.import_clause',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LI: Integer;
    begin
      for LI := 0 to ANode.ChildCount() - 1 do
        AGen.Include('"' + ANode.GetChild(LI).GetToken().Text + '.h"');
    end);

  APax.Config().RegisterEmitter('stmt.import_item',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      // Handled by parent
    end);
end;

// =========================================================================
// DECLARATION EMITTERS
// =========================================================================

procedure RegisterDeclEmitters(const APax: TMetamorf);
begin
  APax.Config().RegisterEmitter('stmt.var_block',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.EmitChildren(ANode);
    end);

  APax.Config().RegisterEmitter('stmt.var_decl',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LNode:        TASTNode;
      LTypeVal:     TValue;
      LNameVal:     TValue;
      LExternalVal: TValue;
      LExportVal:   TValue;
      LTypeStr:     string;
      LNameStr:     string;
      LElemType:    string;
      LLow:         Integer;
      LHigh:        Integer;
      LSize:        Integer;
      LOfPos:       Integer;
      LBounds:      string;
      LDotPos:      Integer;
      LIsExternal:  Boolean;
    begin
      LNode := TASTNode(ANode);
      LNode.GetAttr('var.type_text', LTypeVal);
      LNode.GetAttr('var.name', LNameVal);
      LTypeStr := LTypeVal.AsString;
      LNameStr := LNameVal.AsString;

      LIsExternal := LNode.GetAttr('var.external', LExternalVal) and
                     LExternalVal.AsBoolean;

      // External import — extern declaration only
      if LIsExternal then
      begin
        AGen.EmitLine('extern %s %s;', [PaxTypeToCpp(LTypeStr), LNameStr]);
        Exit;
      end;

      // DLL export prefix for exported vars (resolved by semantics)
      if LNode.GetAttr('var.export_attr', LExportVal) then
        AGen.Emit(LExportVal.AsString + ' ');

      // Handle Myra array types: array[low..high] of elemtype
      if LTypeStr.StartsWith('array') then
      begin
        LOfPos := Pos(' of ', LTypeStr);
        if LOfPos > 0 then
          LElemType := PaxTypeToCpp(Copy(LTypeStr, LOfPos + 4, MaxInt))
        else
          LElemType := 'void';
        // Extract bounds
        if Pos('[', LTypeStr) > 0 then
        begin
          LBounds := Copy(LTypeStr, Pos('[', LTypeStr) + 1,
            Pos(']', LTypeStr) - Pos('[', LTypeStr) - 1);
          LDotPos := Pos('..', LBounds);
          if LDotPos > 0 then
          begin
            LLow := StrToIntDef(Trim(Copy(LBounds, 1, LDotPos - 1)), 0);
            LHigh := StrToIntDef(Trim(Copy(LBounds, LDotPos + 2, MaxInt)), 0);
            LSize := LHigh - LLow + 1;
            AGen.EmitLine('%s %s[%d];', [LElemType, LNameStr, LSize]);
          end
          else
            AGen.EmitLine('%s %s[];', [LElemType, LNameStr]);
        end
        else
          // Dynamic array: std::vector
          AGen.EmitLine('std::vector<%s> %s;', [LElemType, LNameStr]);
      end
      else if LTypeStr.StartsWith('pointer') then
      begin
        // pointer to [const] T
        LOfPos := Pos(' to ', LTypeStr);
        if LOfPos > 0 then
        begin
          LElemType := Copy(LTypeStr, LOfPos + 4, MaxInt);
          if LElemType.StartsWith('const ') then
            AGen.EmitLine('const %s* %s;', [
              PaxTypeToCpp(Trim(Copy(LElemType, 7, MaxInt))), LNameStr])
          else
            AGen.EmitLine('%s* %s;', [PaxTypeToCpp(LElemType), LNameStr]);
        end
        else
          AGen.EmitLine('void* %s;', [LNameStr]);
      end
      else
      begin
        // Normal type
        if ANode.ChildCount() > 0 then
        begin
          AGen.Emit('%s %s = ', [PaxTypeToCpp(LTypeStr), LNameStr]);
          AGen.EmitNode(ANode.GetChild(0));
          AGen.EmitLine(';');
        end
        else
          AGen.EmitLine('%s %s;', [PaxTypeToCpp(LTypeStr), LNameStr]);
      end;
    end);

  APax.Config().RegisterEmitter('stmt.const_block',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.EmitChildren(ANode);
    end);

  APax.Config().RegisterEmitter('stmt.const_decl',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LNode:    TASTNode;
      LTypeVal: TValue;
      LNameVal: TValue;
    begin
      LNode := TASTNode(ANode);
      LNode.GetAttr('const.name', LNameVal);
      LNode.GetAttr('const.type_text', LTypeVal);
      if LTypeVal.AsString <> '' then
        AGen.Emit('constexpr %s %s = ', [PaxTypeToCpp(LTypeVal.AsString), LNameVal.AsString])
      else
        AGen.Emit('constexpr auto %s = ', [LNameVal.AsString]);
      if ANode.ChildCount() > 0 then
        AGen.EmitNode(ANode.GetChild(0));
      AGen.EmitLine(';');
    end);

  APax.Config().RegisterEmitter('stmt.type_block',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.EmitChildren(ANode);
    end);

  APax.Config().RegisterEmitter('stmt.type_decl',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LNameVal:   TValue;
      LKindVal:   TValue;
      LAliasVal:  TValue;
      LI:         Integer;
      LChild:     TASTNode;
      LChoiceVal: TValue;
      LElemVal:   TValue;
      LLowVal:    TValue;
      LHighVal:   TValue;
      LSize:      Integer;
    begin
      TASTNode(ANode).GetAttr('decl.name', LNameVal);
      TASTNode(ANode).GetAttr('type.kind', LKindVal);
      if (LKindVal.AsString = 'record') or (LKindVal.AsString = 'overlay') then
      begin
        AGen.EmitLine('struct %s {', [LNameVal.AsString]);
        AGen.IndentIn();
        AGen.EmitChildren(ANode);
        AGen.IndentOut();
        AGen.EmitLine('};');
        AGen.EmitLine('');
      end
      else if LKindVal.AsString = 'alias' then
      begin
        TASTNode(ANode).GetAttr('type.alias_text', LAliasVal);
        AGen.EmitLine('using %s = %s;', [LNameVal.AsString, PaxTypeToCpp(LAliasVal.AsString)]);
      end
      else if LKindVal.AsString = 'choices' then
      begin
        AGen.Emit('enum %s { ', [LNameVal.AsString]);
        for LI := 0 to ANode.ChildCount() - 1 do
        begin
          LChild := TASTNode(ANode.GetChild(LI));
          LChild.GetAttr('choice.name', LChoiceVal);
          if LI > 0 then
            AGen.Emit(', ');
          AGen.Emit('%s', [LChoiceVal.AsString]);
          if LChild.ChildCount() > 0 then
          begin
            AGen.Emit(' = ');
            AGen.EmitNode(LChild.GetChild(0));
          end;
        end;
        AGen.EmitLine(' };');
      end
      else if LKindVal.AsString = 'array' then
      begin
        TASTNode(ANode).GetAttr('type.elem_type', LElemVal);
        if TASTNode(ANode).GetAttr('type.array_low', LLowVal) and
           TASTNode(ANode).GetAttr('type.array_high', LHighVal) then
        begin
          LSize := StrToIntDef(LHighVal.AsString, 0) -
                   StrToIntDef(LLowVal.AsString, 0) + 1;
          AGen.EmitLine('using %s = %s[%d];', [
            LNameVal.AsString, PaxTypeToCpp(LElemVal.AsString), LSize]);
        end
        else
          AGen.EmitLine('using %s = std::vector<%s>;', [
            LNameVal.AsString, PaxTypeToCpp(LElemVal.AsString)]);
      end
      else
        AGen.EmitChildren(ANode);
    end);

  APax.Config().RegisterEmitter('stmt.field_decl',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LNameVal: TValue;
      LTypeVal: TValue;
    begin
      TASTNode(ANode).GetAttr('field.name', LNameVal);
      TASTNode(ANode).GetAttr('field.type_text', LTypeVal);
      AGen.EmitLine('%s %s;', [PaxTypeToCpp(LTypeVal.AsString), LNameVal.AsString]);
    end);

  APax.Config().RegisterEmitter('stmt.choices_value',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      // Handled by parent stmt.type_decl choices branch
    end);

  APax.Config().RegisterEmitter('stmt.exported',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LChild:    TASTNode;
      LNameVal:  TValue;
      LRetVal:   TValue;
      LLinkVal:  TValue;
      LTypeVal:  TValue;
      LPTypeVal: TValue;
      LPNameVal: TValue;
      LParam:    TASTNode;
      LVarBlock: TASTNode;
      LVarDecl:  TASTNode;
      LI:        Integer;
      LVI:       Integer;
      LFirst:    Boolean;
      LIsCLink:  Boolean;
      LIsDll:    Boolean;
    begin
      LIsDll := AGen.GetContext('module.kind', '') = 'dll';

      // Emit forward declaration to header for exported routines (lib only, not dll)
      if not LIsDll and (ANode.ChildCount() > 0) and
         (ANode.GetChild(0).GetNodeKind() = 'stmt.routine_decl') then
      begin
        LChild := TASTNode(ANode.GetChild(0));
        LChild.GetAttr('decl.name', LNameVal);
        LChild.GetAttr('decl.return_type', LRetVal);

        LIsCLink := LChild.GetAttr('decl.linkage', LLinkVal) and
                    (LLinkVal.AsString = '"C"');

        // Open extern "C" in header if C linkage
        if LIsCLink then
          AGen.EmitLine('extern "C" {', sfHeader);

        if LRetVal.AsString <> '' then
          AGen.Emit('%s %s(', [PaxTypeToCpp(LRetVal.AsString),
            LNameVal.AsString], sfHeader)
        else
          AGen.Emit('void %s(', [LNameVal.AsString], sfHeader);

        LFirst := True;
        for LI := 0 to LChild.ChildCount() - 1 do
        begin
          LParam := TASTNode(LChild.GetChild(LI));
          if LParam.GetNodeKind() = 'stmt.param_decl' then
          begin
            if not LFirst then AGen.Emit(', ', sfHeader);
            LParam.GetAttr('param.type_text', LPTypeVal);
            LParam.GetAttr('param.name', LPNameVal);
            AGen.Emit('%s %s', [
              PaxTypeToCpp(LPTypeVal.AsString),
              LPNameVal.AsString], sfHeader);
            LFirst := False;
          end;
        end;
        AGen.EmitLine(');', sfHeader);

        // Close extern "C" in header
        if LIsCLink then
          AGen.EmitLine('}', sfHeader);
      end
      // Emit extern declaration to header for exported vars (lib only, not dll)
      else if not LIsDll and (ANode.ChildCount() > 0) and
              (ANode.GetChild(0).GetNodeKind() = 'stmt.var_block') then
      begin
        LVarBlock := TASTNode(ANode.GetChild(0));
        for LVI := 0 to LVarBlock.ChildCount() - 1 do
        begin
          if LVarBlock.GetChild(LVI).GetNodeKind() = 'stmt.var_decl' then
          begin
            LVarDecl := TASTNode(LVarBlock.GetChild(LVI));
            LVarDecl.GetAttr('var.name', LNameVal);
            LVarDecl.GetAttr('var.type_text', LTypeVal);
            AGen.EmitLine('extern %s %s;',
              [PaxTypeToCpp(LTypeVal.AsString), LNameVal.AsString], sfHeader);
          end;
        end;
      end;

      // Emit full definition to source
      AGen.EmitChildren(ANode);
    end);
end;

// =========================================================================
// ROUTINE EMITTERS
// =========================================================================

procedure RegisterRoutineEmitters(const APax: TMetamorf);
begin
  APax.Config().RegisterEmitter('stmt.routine_decl',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LNode:        TASTNode;
      LNameVal:     TValue;
      LRetVal:      TValue;
      LLinkVal:     TValue;
      LExportVal:   TValue;
      LExternalVal: TValue;
      LI:           Integer;
      LChild:       TASTNode;
      LFirst:       Boolean;
      LPTypeVal:    TValue;
      LPNameVal:    TValue;
      LIsCLink:     Boolean;
      LIsExported:  Boolean;
      LIsExternal:  Boolean;
    begin
      LNode := TASTNode(ANode);
      LNode.GetAttr('decl.name', LNameVal);
      LNode.GetAttr('decl.return_type', LRetVal);

      // Read visibility, linkage, and external from AST
      LIsExported := LNode.GetAttr('decl.exported', LExportVal) and
                     LExportVal.AsBoolean;
      LIsCLink    := LNode.GetAttr('decl.linkage', LLinkVal) and
                     (LLinkVal.AsString = '"C"');
      LIsExternal := LNode.GetAttr('decl.external', LExternalVal) and
                     LExternalVal.AsBoolean;

      // External import — forward declaration only, no body
      if LIsExternal then
      begin
        if LIsCLink then
          AGen.EmitLine('extern "C" {');

        if LRetVal.AsString <> '' then
          AGen.Emit('%s %s(', [PaxTypeToCpp(LRetVal.AsString), LNameVal.AsString])
        else
          AGen.Emit('void %s(', [LNameVal.AsString]);

        LFirst := True;
        for LI := 0 to ANode.ChildCount() - 1 do
        begin
          LChild := TASTNode(ANode.GetChild(LI));
          if LChild.GetNodeKind() = 'stmt.param_decl' then
          begin
            if not LFirst then AGen.Emit(', ');
            LChild.GetAttr('param.type_text', LPTypeVal);
            LChild.GetAttr('param.name', LPNameVal);
            AGen.Emit('%s %s', [
              PaxTypeToCpp(LPTypeVal.AsString),
              LPNameVal.AsString]);
            LFirst := False;
          end;
        end;
        AGen.EmitLine(');');

        if LIsCLink then
          AGen.EmitLine('}');

        AGen.EmitLine('');
        Exit;
      end;

      // Open extern "C" block if C linkage
      if LIsCLink then
        AGen.EmitLine('extern "C" {');

      // DLL export prefix (resolved by semantics), or static for non-exported
      if LNode.GetAttr('decl.export_attr', LExportVal) then
        AGen.Emit(LExportVal.AsString + ' ')
      else if not LIsExported then
        AGen.Emit('static ');

      // Function signature
      if LRetVal.AsString <> '' then
        AGen.Emit('%s %s(', [PaxTypeToCpp(LRetVal.AsString), LNameVal.AsString])
      else
        AGen.Emit('void %s(', [LNameVal.AsString]);

      // Parameters
      LFirst := True;
      for LI := 0 to ANode.ChildCount() - 1 do
      begin
        LChild := TASTNode(ANode.GetChild(LI));
        if LChild.GetNodeKind() = 'stmt.param_decl' then
        begin
          if not LFirst then AGen.Emit(', ');
          LChild.GetAttr('param.type_text', LPTypeVal);
          LChild.GetAttr('param.name', LPNameVal);
          AGen.Emit('%s %s', [
            PaxTypeToCpp(LPTypeVal.AsString),
            LPNameVal.AsString]);
          LFirst := False;
        end;
      end;
      AGen.EmitLine(') {');

      // Body
      AGen.IndentIn();
      for LI := 0 to ANode.ChildCount() - 1 do
      begin
        LChild := TASTNode(ANode.GetChild(LI));
        if LChild.GetNodeKind() <> 'stmt.param_decl' then
          AGen.EmitNode(LChild);
      end;
      AGen.IndentOut();
      AGen.EmitLine('}');

      // Close extern "C" block
      if LIsCLink then
        AGen.EmitLine('}');

      AGen.EmitLine('');
    end);

  APax.Config().RegisterEmitter('stmt.param_decl',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      // Handled inline by routine_decl
    end);
end;

// =========================================================================
// STATEMENT EMITTERS
// =========================================================================

procedure RegisterStmtEmitters(const APax: TMetamorf);
begin
  // Directive: build configuration only, no C++ output
  APax.Config().RegisterEmitter('stmt.directive',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      // No-op — directives configure the compiler, they don't emit code
    end);

  // Expression-statement
  APax.Config().RegisterEmitter('stmt.expr',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.EmitNode(ANode.GetChild(0));
      AGen.EmitLine(';');
    end);

  APax.Config().RegisterEmitter('stmt.begin_block',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.EmitChildren(ANode);
    end);

  APax.Config().RegisterEmitter('stmt.then_branch',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.EmitChildren(ANode);
    end);

  APax.Config().RegisterEmitter('stmt.else_branch',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.EmitChildren(ANode);
    end);

  APax.Config().RegisterEmitter('stmt.if',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.Emit('if ('); AGen.EmitNode(ANode.GetChild(0)); AGen.EmitLine(') {');
      AGen.IndentIn(); AGen.EmitNode(ANode.GetChild(1)); AGen.IndentOut();
      if ANode.ChildCount() > 2 then
      begin
        AGen.EmitLine('} else {');
        AGen.IndentIn(); AGen.EmitNode(ANode.GetChild(2)); AGen.IndentOut();
      end;
      AGen.EmitLine('}');
    end);

  APax.Config().RegisterEmitter('stmt.while',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LI: Integer;
    begin
      AGen.Emit('while ('); AGen.EmitNode(ANode.GetChild(0)); AGen.EmitLine(') {');
      AGen.IndentIn();
      for LI := 1 to ANode.ChildCount() - 1 do
        AGen.EmitNode(ANode.GetChild(LI));
      AGen.IndentOut(); AGen.EmitLine('}');
    end);

  APax.Config().RegisterEmitter('stmt.for',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LNode:   TASTNode;
      LVarVal: TValue;
      LDirVal: TValue;
      LI:      Integer;
    begin
      LNode := TASTNode(ANode);
      LNode.GetAttr('for.var', LVarVal);
      LNode.GetAttr('for.dir', LDirVal);
      AGen.Emit('for (auto %s = ', [LVarVal.AsString]);
      AGen.EmitNode(ANode.GetChild(0));
      AGen.Emit('; %s ', [LVarVal.AsString]);
      if LDirVal.AsString = 'to' then AGen.Emit('<= ') else AGen.Emit('>= ');
      AGen.EmitNode(ANode.GetChild(1));
      AGen.Emit('; ');
      if LDirVal.AsString = 'to' then
        AGen.Emit('++%s', [LVarVal.AsString])
      else
        AGen.Emit('--%s', [LVarVal.AsString]);
      AGen.EmitLine(') {');
      AGen.IndentIn();
      for LI := 2 to ANode.ChildCount() - 1 do
        AGen.EmitNode(ANode.GetChild(LI));
      AGen.IndentOut(); AGen.EmitLine('}');
    end);

  APax.Config().RegisterEmitter('stmt.repeat',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LI: Integer;
    begin
      AGen.EmitLine('do {');
      AGen.IndentIn();
      for LI := 0 to ANode.ChildCount() - 2 do
        AGen.EmitNode(ANode.GetChild(LI));
      AGen.IndentOut();
      AGen.Emit('} while (!('); AGen.EmitNode(ANode.GetChild(ANode.ChildCount() - 1));
      AGen.EmitLine('));');
    end);

  APax.Config().RegisterEmitter('stmt.match',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LI:        Integer;
      LJ:        Integer;
      LChild:    TASTNode;
      LLabel:    TASTNode;
      LFirst:    Boolean;
      LFirstLbl: Boolean;
    begin
      AGen.EmitLine('{');
      AGen.IndentIn();
      AGen.Emit('auto __match_val = '); AGen.EmitNode(ANode.GetChild(0)); AGen.EmitLine(';');
      LFirst := True;
      for LI := 1 to ANode.ChildCount() - 1 do
      begin
        LChild := TASTNode(ANode.GetChild(LI));
        if LChild.GetNodeKind() = 'stmt.match_else' then
        begin
          AGen.EmitLine('} else {');
          AGen.IndentIn();
          for LJ := 0 to LChild.ChildCount() - 1 do
            AGen.EmitNode(LChild.GetChild(LJ));
          AGen.IndentOut();
        end
        else
        begin
          if LFirst then
            AGen.Emit('if (')
          else
            AGen.Emit('} else if (');
          LFirstLbl := True;
          for LJ := 0 to LChild.ChildCount() - 1 do
          begin
            LLabel := TASTNode(LChild.GetChild(LJ));
            if LLabel.GetNodeKind() = 'stmt.match_label' then
            begin
              if not LFirstLbl then
                AGen.Emit(' || ');
              if LLabel.ChildCount() = 2 then
              begin
                AGen.Emit('(__match_val >= ');
                AGen.Emit(LLabel.GetChild(0).GetToken().Text);
                AGen.Emit(' && __match_val <= ');
                AGen.Emit(LLabel.GetChild(1).GetToken().Text);
                AGen.Emit(')');
              end
              else
              begin
                AGen.Emit('__match_val == ');
                AGen.Emit(LLabel.GetChild(0).GetToken().Text);
              end;
              LFirstLbl := False;
            end;
          end;
          AGen.EmitLine(') {');
          AGen.IndentIn();
          for LJ := 0 to LChild.ChildCount() - 1 do
          begin
            LLabel := TASTNode(LChild.GetChild(LJ));
            if LLabel.GetNodeKind() <> 'stmt.match_label' then
              AGen.EmitNode(LLabel);
          end;
          AGen.IndentOut();
          LFirst := False;
        end;
      end;
      AGen.EmitLine('}');
      AGen.IndentOut();
      AGen.EmitLine('}');
    end);

  APax.Config().RegisterEmitter('stmt.match_arm',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      // Handled inline by stmt.match emitter
    end);

  APax.Config().RegisterEmitter('stmt.match_else',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      // Handled inline by stmt.match emitter
    end);

  APax.Config().RegisterEmitter('stmt.match_label',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      // Handled inline by stmt.match emitter
    end);

  APax.Config().RegisterEmitter('stmt.return',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      if ANode.ChildCount() > 0 then
      begin
        AGen.Emit('return ');
        AGen.EmitNode(ANode.GetChild(0));
        AGen.EmitLine(';');
      end
      else
        AGen.EmitLine('return;');
    end);

  APax.Config().RegisterEmitter('stmt.guard',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LI: Integer;
    begin
      AGen.EmitLine('try {');
      AGen.IndentIn();
      if ANode.ChildCount() > 0 then
        AGen.EmitNode(ANode.GetChild(0));
      AGen.IndentOut();
      for LI := 1 to ANode.ChildCount() - 1 do
        AGen.EmitNode(ANode.GetChild(LI));
    end);

  APax.Config().RegisterEmitter('stmt.guard_body',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.EmitChildren(ANode);
    end);

  APax.Config().RegisterEmitter('stmt.except_block',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.EmitLine('} catch (const std::exception& __mor_ex) {');
      AGen.IndentIn(); AGen.EmitChildren(ANode); AGen.IndentOut();
    end);

  APax.Config().RegisterEmitter('stmt.finally_block',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.EmitLine('} // finally');
      AGen.EmitLine('{');
      AGen.IndentIn(); AGen.EmitChildren(ANode); AGen.IndentOut();
      AGen.EmitLine('}');
    end);

  APax.Config().RegisterEmitter('stmt.create',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.Emit('mor_create('); AGen.EmitNode(ANode.GetChild(0)); AGen.EmitLine(');');
    end);

  APax.Config().RegisterEmitter('stmt.destroy',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.Emit('mor_destroy('); AGen.EmitNode(ANode.GetChild(0)); AGen.EmitLine(');');
    end);

  APax.Config().RegisterEmitter('stmt.getmem',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.Emit('mor_getmem('); AGen.EmitNode(ANode.GetChild(0)); AGen.EmitLine(');');
    end);

  APax.Config().RegisterEmitter('stmt.freemem',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.Emit('mor_freemem('); AGen.EmitNode(ANode.GetChild(0)); AGen.EmitLine(');');
    end);

  APax.Config().RegisterEmitter('stmt.resizemem',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.Emit('mor_resizemem('); AGen.EmitNode(ANode.GetChild(0));
      AGen.Emit(', '); AGen.EmitNode(ANode.GetChild(1)); AGen.EmitLine(');');
    end);

  APax.Config().RegisterEmitter('stmt.setlength',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.EmitNode(ANode.GetChild(0)); AGen.Emit('.resize(');
      AGen.EmitNode(ANode.GetChild(1)); AGen.EmitLine(');');
    end);

  APax.Config().RegisterEmitter('stmt.raiseexception',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.Emit('throw std::runtime_error(');
      AGen.EmitNode(ANode.GetChild(0)); AGen.EmitLine(');');
    end);

  APax.Config().RegisterEmitter('stmt.raiseexceptioncode',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.Emit('mor_throw('); AGen.EmitNode(ANode.GetChild(0));
      AGen.Emit(', '); AGen.EmitNode(ANode.GetChild(1)); AGen.EmitLine(');');
    end);

  APax.Config().RegisterEmitter('stmt.writeln',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LI: Integer;
    begin
      AGen.Emit('std::println(');
      for LI := 0 to ANode.ChildCount() - 1 do
      begin
        if LI > 0 then AGen.Emit(', ');
        AGen.EmitNode(ANode.GetChild(LI));
      end;
      AGen.EmitLine(');');
    end);

  APax.Config().RegisterEmitter('stmt.write',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LI: Integer;
    begin
      AGen.Emit('std::print(');
      for LI := 0 to ANode.ChildCount() - 1 do
      begin
        if LI > 0 then AGen.Emit(', ');
        AGen.EmitNode(ANode.GetChild(LI));
      end;
      AGen.EmitLine(');');
    end);
end;

// =========================================================================
// EXPRESSION EMITTERS
// =========================================================================

procedure RegisterExprEmitters(const APax: TMetamorf);
begin
  APax.Config().RegisterEmitter('expr.binary',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LOpVal: TValue;
    begin
      TASTNode(ANode).GetAttr('op', LOpVal);
      AGen.Emit('('); AGen.EmitNode(ANode.GetChild(0));
      AGen.Emit(' %s ', [LOpVal.AsString]); AGen.EmitNode(ANode.GetChild(1)); AGen.Emit(')');
    end);

  APax.Config().RegisterEmitter('expr.unary',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LOpVal: TValue;
    begin
      TASTNode(ANode).GetAttr('op', LOpVal);
      AGen.Emit('(%s', [LOpVal.AsString]); AGen.EmitNode(ANode.GetChild(0)); AGen.Emit(')');
    end);

  APax.Config().RegisterEmitter('expr.assign',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LOpVal: TValue;
    begin
      TASTNode(ANode).GetAttr('op', LOpVal);
      AGen.EmitNode(ANode.GetChild(0)); AGen.Emit(' %s ', [LOpVal.AsString]);
      AGen.EmitNode(ANode.GetChild(1));
    end);

  APax.Config().RegisterEmitter('expr.call',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LNameVal: TValue;
      LI:       Integer;
    begin
      TASTNode(ANode).GetAttr('call.name', LNameVal);
      AGen.Emit('%s(', [PaxTypeToCpp(LNameVal.AsString)]);
      for LI := 0 to ANode.ChildCount() - 1 do
      begin
        if LI > 0 then AGen.Emit(', ');
        AGen.EmitNode(ANode.GetChild(LI));
      end;
      AGen.Emit(')');
    end);

  // Method call: obj.method(args) -> obj.method(args)
  APax.Config().RegisterEmitter('expr.method_call',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LFieldNode: TASTNode;
      LFieldVal:  TValue;
      LI:         Integer;
    begin
      LFieldNode := TASTNode(ANode.GetChild(0));
      AGen.EmitNode(LFieldNode.GetChild(0));
      LFieldNode.GetAttr('field.name', LFieldVal);
      if LFieldNode.GetNodeKind() = 'expr.cpp_arrow' then
        AGen.Emit('->%s(', [LFieldVal.AsString])
      else
        AGen.Emit('.%s(', [LFieldVal.AsString]);
      for LI := 1 to ANode.ChildCount() - 1 do
      begin
        if LI > 1 then AGen.Emit(', ');
        AGen.EmitNode(ANode.GetChild(LI));
      end;
      AGen.Emit(')');
    end);

  // Literal emitters
  APax.Config().RegisterEmitter('expr.ident',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.Emit(ANode.GetToken().Text);
    end);

  APax.Config().RegisterEmitter('expr.identifier',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.Emit(ANode.GetToken().Text);
    end);

  APax.Config().RegisterEmitter('expr.integer',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.Emit(ANode.GetToken().Text);
    end);

  APax.Config().RegisterEmitter('expr.float',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LText:      string;
      LTargetVal: TValue;
      LIsFloat32: Boolean;
    begin
      LText := ANode.GetToken().Text;

      // Explicit f/F suffix — emit as-is
      if (LText <> '') and
         ((LText[Length(LText)] = 'f') or (LText[Length(LText)] = 'F')) then
      begin
        AGen.Emit(LText);
        Exit;
      end;

      // Check if semantics stamped a target type
      LIsFloat32 := TASTNode(ANode).GetAttr('expr.target_type', LTargetVal) and
                    (LTargetVal.AsString = 'type.float32');

      if LIsFloat32 then
        AGen.Emit(LText + 'f')
      else
        AGen.Emit(LText);  // default: emit as double
    end);

  APax.Config().RegisterEmitter('expr.grouped',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.Emit('('); AGen.EmitNode(ANode.GetChild(0)); AGen.Emit(')');
    end);

  APax.Config().RegisterEmitter('expr.field_access',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LFieldVal: TValue;
    begin
      TASTNode(ANode).GetAttr('field.name', LFieldVal);
      AGen.EmitNode(ANode.GetChild(0)); AGen.Emit('.%s', [LFieldVal.AsString]);
    end);

  APax.Config().RegisterEmitter('expr.array_index',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.EmitNode(ANode.GetChild(0)); AGen.Emit('[');
      AGen.EmitNode(ANode.GetChild(1)); AGen.Emit(']');
    end);

  APax.Config().RegisterEmitter('expr.deref',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.Emit('(*'); AGen.EmitNode(ANode.GetChild(0)); AGen.Emit(')');
    end);

  APax.Config().RegisterEmitter('expr.address_of',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.Emit('&('); AGen.EmitNode(ANode.GetChild(0)); AGen.Emit(')');
    end);

  APax.Config().RegisterEmitter('expr.nil',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.Emit('nullptr');
    end);

  APax.Config().RegisterEmitter('expr.bool',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      if SameText(ANode.GetToken().Text, 'true') then
        AGen.Emit('true')
      else
        AGen.Emit('false');
    end);

  APax.Config().RegisterEmitter('expr.self',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.Emit('this');
    end);

  APax.Config().RegisterEmitter('expr.parent',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.Emit('/* parent */');
    end);

  APax.Config().RegisterEmitter('expr.in',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.Emit('mor_contains('); AGen.EmitNode(ANode.GetChild(1));
      AGen.Emit(', '); AGen.EmitNode(ANode.GetChild(0)); AGen.Emit(')');
    end);

  APax.Config().RegisterEmitter('expr.shl',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.Emit('('); AGen.EmitNode(ANode.GetChild(0));
      AGen.Emit(' << '); AGen.EmitNode(ANode.GetChild(1)); AGen.Emit(')');
    end);

  APax.Config().RegisterEmitter('expr.shr',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.Emit('('); AGen.EmitNode(ANode.GetChild(0));
      AGen.Emit(' >> '); AGen.EmitNode(ANode.GetChild(1)); AGen.Emit(')');
    end);

  // Pascal string emitter: 'x' -> 'x' (C++ char), 'hello' -> "hello" (C++ string)
  APax.Config().RegisterEmitter('expr.string',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LText:  string;
      LInner: string;
    begin
      LText := ANode.GetToken().Text;
      if (Length(LText) >= 2) and (LText[1] = #39) and
         (LText[Length(LText)] = #39) then
        LInner := Copy(LText, 2, Length(LText) - 2)
      else
        LInner := LText;
      LInner := LInner.Replace(#39#39, #39);
      if Length(LInner) = 1 then
        AGen.Emit(#39 + LInner + #39)  // C++ char literal
      else
        AGen.Emit('"' + LInner + '"');  // C++ string literal
    end);

  APax.Config().RegisterEmitter('expr.cstring',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    begin
      AGen.Emit(ANode.GetToken().Text);
    end);

  APax.Config().RegisterEmitter('expr.wstring',
    procedure(ANode: TASTNodeBase; AGen: TIRBase)
    var
      LText: string;
    begin
      LText := ANode.GetToken().Text;
      // Token text is w"hello" — strip w prefix, prepend L for C++
      AGen.Emit('L' + Copy(LText, 2, Length(LText) - 1));
    end);
end;

// =========================================================================
// TYPE MAPPING & OVERRIDES
// =========================================================================

procedure RegisterTypeMapping(const APax: TMetamorf);
begin
  APax.Config().SetTypeToIR(
    function(const ATypeKind: string): string
    begin
      Result := PaxTypeToCpp(ATypeKind);
    end);
end;

procedure RegisterExprOverrides(const APax: TMetamorf);
begin
  // Pascal string literals: emit token text verbatim so 'H' stays 'H'
  APax.Config().RegisterExprOverride('expr.string',
    function(const ANode: TASTNodeBase;
      const ADefault: TExprToStringFunc): string
    begin
      Result := ANode.GetToken().Text;
    end);

  // C-string literals: emit token text verbatim
  APax.Config().RegisterExprOverride('expr.cstring',
    function(const ANode: TASTNodeBase;
      const ADefault: TExprToStringFunc): string
    begin
      Result := ANode.GetToken().Text;
    end);

  // Wide-string literals: strip w prefix, prepend L
  APax.Config().RegisterExprOverride('expr.wstring',
    function(const ANode: TASTNodeBase;
      const ADefault: TExprToStringFunc): string
    var
      LText: string;
    begin
      LText := ANode.GetToken().Text;
      Result := 'L' + Copy(LText, 2, Length(LText) - 1);
    end);
end;

// =========================================================================
// Public Entry Point
// =========================================================================

procedure ConfigMyraCodeGen(const APax: TMetamorf);
begin
  RegisterModuleEmitters(APax);
  RegisterDeclEmitters(APax);
  RegisterRoutineEmitters(APax);
  RegisterStmtEmitters(APax);
  RegisterExprEmitters(APax);
  RegisterTypeMapping(APax);
  RegisterExprOverrides(APax);
end;

end.
