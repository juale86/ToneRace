# ToneRace

Carrera musical para Android hecha en Godot 4. El diseño está en [DESIGN.md](DESIGN.md).

## Requisitos

- Godot 4.7
- Python 3.12 (solo librería estándar)
- FluidSynth 2.6 y el SoundFont GeneralUser GS (para generar el audio)

## Generar el audio

El audio no se versiona: se genera desde `data/` con

```
python tools/render_audio.py rock
```

Por defecto busca FluidSynth y el SoundFont en `%LOCALAPPDATA%\Programs\`. Se pueden indicar otras rutas con las variables de entorno `FLUIDSYNTH` y `SOUNDFONT`.

## Correr

```
godot --path .                    # escena de prueba de música
godot --path . -- --autotest      # barrido de tempo, imprime la deriva del audio
godot --headless --path . -s addons/gut/gut_cmdln.gd   # tests
```
