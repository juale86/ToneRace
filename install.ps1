# Instala todo lo necesario para correr ToneRace en Windows, dentro de .tools\
# (no toca el sistema salvo que falte Python, que se instala con winget para el usuario).
#
#   powershell -ExecutionPolicy Bypass -File install.ps1
#
# Descarga Godot, FluidSynth y el SoundFont, genera el audio e importa el proyecto.
# Se puede volver a correr: lo que ya está descargado no se baja de nuevo.

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"  # Invoke-WebRequest es mucho más rápido sin la barra

$GodotVersion = "4.7.2"
$FluidSynthVersion = "2.6.1"
$Root = $PSScriptRoot
$Tools = Join-Path $Root ".tools"
New-Item -ItemType Directory -Force $Tools | Out-Null

function Get-Zip($Url, $Dest) {
	$zip = Join-Path $Tools "download.zip"
	Write-Host "  bajando $Url"
	Invoke-WebRequest -Uri $Url -OutFile $zip
	Expand-Archive -Path $zip -DestinationPath $Dest -Force
	Remove-Item $zip
}

function Find-Python {
	foreach ($cmd in @("py", "python", "python3")) {
		$found = Get-Command $cmd -ErrorAction SilentlyContinue
		if ($found) {
			# El alias de la Microsoft Store existe pero no es Python: hay que probarlo.
			$extra = if ($cmd -eq "py") { @("-3") } else { @() }
			try { & $found.Source @extra --version *> $null } catch { continue }
			if ($LASTEXITCODE -eq 0) { return [pscustomobject]@{ Exe = $found.Source; Args = $extra } }
		}
	}
	$local = Get-ChildItem "$env:LOCALAPPDATA\Programs\Python\Python3*\python.exe" -ErrorAction SilentlyContinue | Select-Object -Last 1
	if ($local) { return [pscustomobject]@{ Exe = $local.FullName; Args = @() } }
	return $null
}

Write-Host "[1/5] Python"
$python = Find-Python
if (-not $python) {
	Write-Host "  no está; instalando Python 3.12 con winget"
	winget install -e --id Python.Python.3.12 --scope user --accept-package-agreements --accept-source-agreements
	$python = Find-Python
	if (-not $python) { throw "No se pudo instalar Python. Instalalo desde https://www.python.org y volvé a correr este script." }
}
Write-Host "  $($python.Exe) $($python.Args)"

Write-Host "[2/5] Godot $GodotVersion"
$godotDir = Join-Path $Tools "godot"
$godot = Join-Path $godotDir "Godot_v$GodotVersion-stable_win64_console.exe"
if (-not (Test-Path $godot)) {
	Get-Zip "https://github.com/godotengine/godot/releases/download/$GodotVersion-stable/Godot_v$GodotVersion-stable_win64.exe.zip" $godotDir
}

Write-Host "[3/5] FluidSynth $FluidSynthVersion"
$fluidDir = Join-Path $Tools "fluidsynth"
if (-not (Test-Path (Join-Path $fluidDir "bin\fluidsynth.exe"))) {
	$tmp = Join-Path $Tools "fluidsynth-tmp"
	Get-Zip "https://github.com/FluidSynth/fluidsynth/releases/download/v$FluidSynthVersion/fluidsynth-v$FluidSynthVersion-win10-x64-cpp11.zip" $tmp
	# El zip trae una carpeta con la versión adentro; la aplanamos a .tools\fluidsynth.
	$inner = Get-ChildItem $tmp -Directory | Select-Object -First 1
	if (Test-Path $fluidDir) { Remove-Item -Recurse -Force $fluidDir }
	Move-Item $inner.FullName $fluidDir
	Remove-Item -Recurse -Force $tmp
}

Write-Host "[4/5] SoundFont GeneralUser GS y audio"
$soundfont = Join-Path $Tools "GeneralUser-GS.sf2"
if (-not (Test-Path $soundfont)) {
	Write-Host "  bajando GeneralUser-GS.sf2 (~30 MB)"
	Invoke-WebRequest -Uri "https://raw.githubusercontent.com/mrbumpy409/GeneralUser-GS/main/GeneralUser-GS.sf2" -OutFile $soundfont
}
$pyArgs = $python.Args
& $python.Exe @pyArgs (Join-Path $Root "tools\render_audio.py") rock
if ($LASTEXITCODE -ne 0) { throw "Falló la generación del audio." }

Write-Host "[5/5] Importando el proyecto en Godot"
& $godot --headless --path $Root --import
if ($LASTEXITCODE -ne 0) { throw "Falló la importación en Godot." }

Write-Host ""
Write-Host "Listo. Para jugar: doble clic en jugar.cmd"
