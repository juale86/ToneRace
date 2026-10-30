@echo off
rem Abre ToneRace. Doble clic para jugar.
rem Usa el Godot que bajo install.ps1; si no esta, el instalado con winget.
rem Los argumentos se pasan al juego: jugar.cmd --seed=K7PX3M --touch
set "GODOT=%~dp0.tools\godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" set "GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
	echo No se encontro Godot 4.7.2. Corre primero:
	echo   powershell -ExecutionPolicy Bypass -File install.ps1
	pause
	exit /b 1
)
start "" "%GODOT%" --path "%~dp0." -- %*
