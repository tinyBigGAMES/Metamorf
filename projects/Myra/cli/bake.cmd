@ECHO OFF

CD /D "%~dp0"

mor.exe --bake "..\mor\myra.mor" -o "..\..\..\bin\Myra.exe" --product "Myra™ Compiler" --company "tinyBigGAMES™ LLC" --version 1.0.0 --icon "..\..\..\res\icons\myra.ico" --url "https://metamorf.dev" --copyright "Copyright © 2026 tinyBigGAMES™ LLC" --description "Myra™ Compiler"

PAUSE
