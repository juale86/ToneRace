#!/usr/bin/env bash
# Instala todo lo necesario para correr ToneRace en Linux.
#
#   ./install.sh
#
# Godot y el SoundFont se bajan a .tools/. FluidSynth y Python se instalan con el
# gestor de paquetes del sistema (pide sudo si faltan). Genera el audio e importa
# el proyecto. Se puede volver a correr: lo que ya está no se baja de nuevo.
set -euo pipefail

GODOT_VERSION=4.7.2
ROOT="$(cd "$(dirname "$0")" && pwd)"
TOOLS="$ROOT/.tools"
mkdir -p "$TOOLS"

need() { ! command -v "$1" >/dev/null 2>&1; }

install_packages() {
	echo "  instalando: $*"
	if command -v apt-get >/dev/null; then sudo apt-get update -q && sudo apt-get install -y "$@"
	elif command -v dnf >/dev/null; then sudo dnf install -y "$@"
	elif command -v pacman >/dev/null; then sudo pacman -S --needed --noconfirm "$@"
	elif command -v zypper >/dev/null; then sudo zypper install -y "$@"
	else echo "No reconozco el gestor de paquetes. Instalá a mano: $*" >&2; exit 1
	fi
}

echo "[1/5] Dependencias del sistema (python3, fluidsynth, curl, unzip)"
missing=()
need python3 && missing+=(python3)
need fluidsynth && missing+=(fluidsynth)
need curl && missing+=(curl)
need unzip && missing+=(unzip)
if [ ${#missing[@]} -gt 0 ]; then install_packages "${missing[@]}"; fi

echo "[2/5] Godot $GODOT_VERSION"
case "$(uname -m)" in
	x86_64) arch=x86_64 ;;
	aarch64|arm64) arch=arm64 ;;
	*) echo "Arquitectura no soportada: $(uname -m)" >&2; exit 1 ;;
esac
GODOT="$TOOLS/godot/Godot_v${GODOT_VERSION}-stable_linux.$arch"
if [ ! -x "$GODOT" ]; then
	mkdir -p "$TOOLS/godot"
	url="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.$arch.zip"
	echo "  bajando $url"
	curl -fL --progress-bar -o "$TOOLS/godot.zip" "$url"
	unzip -oq "$TOOLS/godot.zip" -d "$TOOLS/godot"
	rm "$TOOLS/godot.zip"
	chmod +x "$GODOT"
fi

echo "[3/5] SoundFont GeneralUser GS"
SOUNDFONT="$TOOLS/GeneralUser-GS.sf2"
if [ ! -f "$SOUNDFONT" ]; then
	echo "  bajando GeneralUser-GS.sf2 (~30 MB)"
	curl -fL --progress-bar -o "$SOUNDFONT" \
		"https://raw.githubusercontent.com/mrbumpy409/GeneralUser-GS/main/GeneralUser-GS.sf2"
fi

echo "[4/5] Generando el audio"
python3 "$ROOT/tools/render_audio.py" rock --fluidsynth "$(command -v fluidsynth)" --soundfont "$SOUNDFONT"

echo "[5/5] Importando el proyecto en Godot"
"$GODOT" --headless --path "$ROOT" --import

echo
echo "Listo. Para jugar: ./jugar.sh"
