program MyraTester;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Myra.Tester in 'Myra.Tester.pas',
  UMyraTester in 'UMyraTester.pas';

begin
  RunMyraTester();
end.
