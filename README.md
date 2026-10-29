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

Con doble clic en `jugar.cmd`, o:

```
godot --path .                                   # carrera de prueba (pista aleatoria)
godot --path . -- --seed=K7PX3M                  # una pista concreta
godot --path . -- --touch                        # muestra los controles táctiles en PC (se usan con el mouse)
godot --path . -- --autotest                     # 30 s con piloto automático, imprime resultados
godot --path . scenes/music_test.tscn -- --autotest   # barrido de tempo, imprime la deriva del audio
godot --headless --path . -s addons/gut/gut_cmdln.gd  # tests
```

## Controles

| Acción | Teclado | Gamepad | Táctil |
|---|---|---|---|
| Carril izq./der. | ←/→ o A/D | cruceta, LB/RB | tap en la mitad izq./der. de los 2/3 superiores |
| Acelerar | ↑, W o espacio | A, RT | mantener abajo a la derecha |
| Riff / Voz | Z / X | X / Y | botones abajo a la izquierda |

En la escena de prueba: P piloto automático, N pista nueva, R reiniciar. El mouse emula toques, así que un clic en la ventana también cambia de carril o acelera.
