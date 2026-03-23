unit UDCITestbed;

interface

procedure RunDCITestbed;

implementation

uses
  System.SysUtils,
  Metamorf.API,
  DelphiCImp,
  raylib;

procedure Status(const AText: string; const AUserData: Pointer);
begin
  TUtils.PrintLn(AText);
end;

procedure ImportRaylib();
var
  LImporter: TDelphCImp;
begin
  LImporter := TDelphCImp.Create();
  try
    LImporter.SetStatusCallback(Status);

    LImporter.SetSavePreprocessed(True);
    LImporter.EnableDelayLoad(True);
    LImporter.SetDllName(tpWin64, 'raylib');
    LImporter.SetDllName(tpLinux64, 'raylib');
    LImporter.SetUnitName('raylib');
    LImporter.SetOutputPath('res\libs\raylib\imports');
    LImporter.AddIncludePath('res\libs\raylib\include\');
    LImporter.AddSourcePath('res\libs\raylib\include\');
    LImporter.SetHeader('res\libs\raylib\include\raylib.h');
    LImporter.AddPostCopyFile(tpWin64, 'res\libs\raylib\bin\raylib.dll', '.\');
    LImporter.AddPostCopyFile(tpLinux64, 'res\libs\raylib\bin\raylib.so', '.\');
    LImporter.SaveToConfig('res\libs\raylib\raylib.toml');
    if LImporter.Process() then
      TUtils.PrintLn('SUCCESS')
    else
      TUtils.PrintLn('ERROR: %s', [LImporter.GetLastError()]);
  finally
    LImporter.Free();
  end;
  TUtils.PrintLn('');
  TUtils.PrintLn('=== Done ===');
end;

procedure TestRaylib();
begin
  InitWindow(800, 450, 'raylib - basic window');
  SetTargetFPS(60);
  while not WindowShouldClose() do
  begin
    BeginDrawing();
      ClearBackground(RAYWHITE);
      DrawText('Congrats! You created your first window!', 190, 200, 20, LIGHTGRAY);
    EndDrawing();
  end;
  CloseWindow();
end;

procedure RunDCITestbed;
begin
  try
    ImportRaylib();

    //TUtils.Pause();


    TestRaylib();
  except
    on E: Exception do
    begin
      TUtils.PrintLn('');
      TUtils.PrintLn(COLOR_RED + 'EXCEPTION: ' + E.Message);
    end;
  end;

  if TUtils.RunFromIDE() then
    TUtils.Pause();
end;

end.
