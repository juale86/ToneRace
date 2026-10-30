#!/usr/bin/env bash
# Abre ToneRace con el Godot que bajó install.sh (o el del PATH).
# Los argumentos se pasan al juego: ./jugar.sh --seed=K7PX3M --touch
ROOT="$(cd "$(dirname "$0")" && pwd)"
GODOT="$(ls "$ROOT"/.tools/godot/Godot_v*_linux.* 2>/dev/null | head -n 1)"
if [ -z "$GODOT" ]; then GODOT="$(command -v godot || true)"; fi
if [ -z "$GODOT" ]; then
	echo "No encontré Godot. Corré primero ./install.sh" >&2
	exit 1
fi
exec "$GODOT" --path "$ROOT" -- "$@"
