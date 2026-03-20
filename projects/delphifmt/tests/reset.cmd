@echo off
cd /d %~dp0

copy /Y test_unit_complex_unformatted.pas src\test_unit_complex.pas
copy /Y test_unit_unformatted.pas src\test_unit.pas
copy /Y test_program_unformatted.pas src\test_program.pas
copy /Y test_library_unformatted.pas src\test_library.pas
copy /Y test_program_syntaxerror.pas src\test_program_syntaxerror.pas
copy /Y test_unit_commeterror.pas src\test_unit_commeterror.pas

del /F /Q src\test_unit_complex.pas.bak 2>nul
del /F /Q src\test_unit.pas.bak 2>nul
del /F /Q src\test_program.pas.bak 2>nul
del /F /Q src\test_library.pas.bak 2>nul
del /F /Q src\test_program_syntaxerror.pas.bak 2>nul
del /F /Q src\test_unit_commeterror.pas.bak 2>nul
