@echo off
rem Abre ToneRace con Godot instalado por winget. Doble clic para jugar.
set "GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
	echo No se encontro Godot en:
	echo %GODOT%
	pause
	exit /b 1
)
start "" "%GODOT%" --path "%~dp0."
