{===============================================================================
  Metamorf™ - Language Engineering Platform

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://metamorf.dev

  See LICENSE for license information
===============================================================================}

unit UDFTestbed;

interface

procedure RunTestbed();

implementation

uses
  System.SysUtils,
  System.StrUtils,
  Metamorf.API,
  DelphiFmt;

/// <summary>
///   Demonstrates and exercises the three core formatting operations of TDelphiFmt:
///   in-memory source formatting, single file formatting, and folder batch formatting.
/// </summary>
/// <remarks>
///   This test uses Castalia-style default options with lowercase reserved words
///   and CRLF line endings. The three stages are:
///   <list type="bullet">
///     <item>
///       <b>FormatSource</b> — Formats a minimal Delphi snippet in memory and
///       prints the formatted result to the console.
///     </item>
///     <item>
///       <b>FormatFile</b> — Formats a single file on disk (test_unit_complex.pas),
///       creating a .bak backup automatically, and reports whether the file changed.
///     </item>
///     <item>
///       <b>FormatFolder</b> — Batch-formats all Delphi source files in the test\src
///       folder recursively, reporting per-file results and a final summary.
///     </item>
///   </list>
///   <para>
///   NOTE: Run reset.cmd in the test folder to restore the original unformatted
///   test files before re-running this test.
///   </para>
/// </remarks>
procedure Test01();
var
  LOptions   : TDelphiFmtOptions;
  LResult    : TDelphiFmtFormatResult;
  LResults   : TArray<TDelphiFmtFormatResult>;
  LPasFmt    : TDelphiFmt;
  LFormatted : string;
  LSource    : string;
  LChanged   : Integer;
  LErrors    : Integer;
begin
  TUtils.PrintLn(COLOR_YELLOW + 'NOTE: Run ' + COLOR_BOLD + 'reset.cmd' +
    COLOR_RESET  + COLOR_YELLOW +
    ' in the [projects\delphifmt\tests] folder to restore unformatted test files.');
  TUtils.PrintLn();
  TUtils.Pause();

  LPasFmt := TDelphiFmt.Create();
  try
    LOptions := LPasFmt.DefaultOptions();
    LOptions.Capitalization.ReservedWordsAndDirectives := capLowerCase;
    LOptions.LineBreaks.LineBreakCharacters := lbcCRLF;

    // --- FormatSource ---
    TUtils.PrintLn(COLOR_BOLD + COLOR_CYAN + '=== FormatSource ===');
    LSource    := 'procedure Foo; begin writeln(''hello''); end;';
    LFormatted := LPasFmt.FormatSource(LSource, LOptions);
    TUtils.PrintLn(COLOR_WHITE + LFormatted + COLOR_RESET);
    TUtils.Pause('Press ENTER for next test..');

    // --- FormatFile ---
    TUtils.PrintLn(COLOR_BOLD + COLOR_CYAN + '=== FormatFile ===');
    LResult := LPasFmt.FormatFile('..\projects\delphifmt\tests\src\test_unit_complex.pas', LOptions);
    if LResult.Success then
      TUtils.PrintLn(COLOR_GREEN + '[OK]  ' +
        LResult.FilePath + ' — ' + IfThen(LResult.Changed, 'Changed', 'No change'))
    else
      TUtils.PrintLn(COLOR_RED + '[ERR] ' +
        LResult.FilePath + ' — ' + LResult.ErrorMsg);
    TUtils.Pause('Press ENTER for next test..');

    // --- FormatFolder ---
    TUtils.PrintLn(COLOR_BOLD + COLOR_CYAN + '=== FormatFolder ===');
    LChanged := 0;
    LErrors  := 0;
    LResults := LPasFmt.FormatFolder('..\projects\delphifmt\tests\src', LOptions);
    for LResult in LResults do
    begin
      if LResult.Success then
      begin
        TUtils.PrintLn(COLOR_GREEN + '[OK]  ' +
          LResult.FilePath + ' — ' + IfThen(LResult.Changed, 'Changed', 'No change'));
        if LResult.Changed then
          Inc(LChanged);
      end
      else
      begin
        TUtils.PrintLn(COLOR_RED + '[ERR] ' +
          LResult.FilePath + ' — ' + LResult.ErrorMsg);
        Inc(LErrors);
      end;
    end;
    TUtils.PrintLn(COLOR_YELLOW + '%d files processed, %d changed, %d errors',
      [Length(LResults), LChanged, LErrors]);

  finally
    LPasFmt.Free();
  end;
end;

procedure RunTestbed();
begin
  Test01();

  if TUtils.RunFromIDE() then
    TUtils.Pause();
end;

end.
