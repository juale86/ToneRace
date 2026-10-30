# ToneRace

Juego de carreras musical hecho en **Godot 4**. Corrés por una ruta generada a partir de un seed y, mientras manejás, **tocás la música**: cada booster dorado es una nota de la melodía (el Canon de Pachelbel, de dominio público). El carril indica la altura de la nota. Si agarrás la nota, suena. La velocidad del auto *es* el tempo: cuanto más rápido vas, más rápido suena la canción.

El objetivo es Android (táctil, horizontal). El desarrollo y las pruebas se hacen en PC con teclado, mouse o gamepad. El diseño completo está en [DESIGN.md](DESIGN.md).

> **Estado:** prototipo en desarrollo (camino a la versión 0.1). Hoy se puede manejar por una pista de prueba en el desierto rockero, cambiar de carril, acelerar y tocar la melodía. Todavía faltan la carrera completa, los rivales y los menús (ver [Hoja de ruta](#hoja-de-ruta)).

---

## Instalación rápida

Necesitás [git](https://git-scm.com/downloads) y una placa de video con **Vulkan** (cualquier GPU de los últimos ~8 años; en Linux, drivers Mesa o propietarios al día).

### Windows 10/11

En PowerShell:

```powershell
git clone https://github.com/juale86/ToneRace.git; cd ToneRace; powershell -ExecutionPolicy Bypass -File install.ps1
```

Después, para jugar: **doble clic en `jugar.cmd`**.

### Linux (Ubuntu/Debian, Fedora, Arch, openSUSE)

```bash
git clone https://github.com/juale86/ToneRace.git && cd ToneRace && ./install.sh
```

Después, para jugar: `./jugar.sh`

### Qué hace el instalador

El instalador se puede volver a correr sin problema: lo que ya bajó no lo vuelve a bajar.

| Paso | Windows (`install.ps1`) | Linux (`install.sh`) |
|---|---|---|
| Python 3 | Usa el que tengas. Si no hay, instala 3.12 con `winget` (solo para tu usuario) | Lo instala con el gestor de paquetes si falta (pide `sudo`) |
| Godot 4.7.2 | Lo baja a `.tools/godot/` | Lo baja a `.tools/godot/` (x86_64 o arm64) |
| FluidSynth | Baja la 2.6.1 a `.tools/fluidsynth/` | Usa el del sistema y lo instala si falta |
| SoundFont GeneralUser GS (~30 MB) | Lo baja a `.tools/` | Lo baja a `.tools/` |
| Audio del juego | Lo genera en `assets/audio/generated/` | Igual |
| Importación | Importa el proyecto en Godot (crea `.godot/`) | Igual |

Todo queda dentro de la carpeta del proyecto: no se instala Godot en el sistema ni se toca el PATH. Para desinstalar, borrá la carpeta.

---

## Cómo se juega

Vas por una ruta de **5 carriles**. Los boosters **dorados** son las notas de la melodía: el carril de cada uno es la altura de la nota (grave a la izquierda, agudo a la derecha). Si pasás por encima, la nota suena con su efecto de luz. Los boosters **celestes** son adornos: notas del acorde de ese momento.

Si encadenás aciertos, armás **combo**. Si se te escapa una nota dorada, el combo se corta. El acelerador sube el tempo, y con él la velocidad y la música. Si lo soltás, el auto vuelve de a poco a la velocidad crucero.

### Controles

| Acción | Teclado | Gamepad | Táctil |
|---|---|---|---|
| Carril izquierda / derecha | ← / → o A / D | cruceta, LB / RB | tap en la mitad izquierda / derecha de los 2/3 superiores |
| Acelerar (mantener) | ↑, W o espacio | A, RT | mantener abajo a la derecha |
| Riff / Voz | Z / X | X / Y | botones abajo a la izquierda |

Si mantenés apretado un lado, el auto sigue cambiando de carril. El mouse emula toques, así que un clic en la ventana también cambia de carril o acelera.

**Teclas de desarrollo** (en la escena de prueba):

| Tecla | Qué hace |
|---|---|
| P | Prende o apaga el piloto automático |
| N | Pista nueva (otro seed) |
| R | Reinicia la pista actual |

> Riff y Voz todavía no hacen nada. Llegan en el paso 6 de la hoja de ruta.

### Opciones de línea de comandos

Los argumentos que van después de `--` son para el juego. Con los lanzadores no hace falta el `--`: `jugar.cmd --seed=K7PX3M` o `./jugar.sh --touch`.

```
godot --path .                          # carrera de prueba con pista aleatoria
godot --path . -- --seed=K7PX3M         # una pista concreta (código de 6 caracteres)
godot --path . -- --touch               # muestra los controles táctiles en PC (se usan con el mouse)
godot --path . -- --autotest            # 30 s con piloto automático, imprime resultados
godot --path . scenes/music_test.tscn -- --autotest   # barrido de tempo, imprime la deriva del audio
```

`godot` es el ejecutable que bajó el instalador:

- Windows: `.tools\godot\Godot_v4.7.2-stable_win64_console.exe` (la versión `_console` muestra la salida en la terminal).
- Linux: `.tools/godot/Godot_v4.7.2-stable_linux.x86_64`.

---

## Para desarrollar

### Abrir en el editor

```
.tools/godot/Godot_v4.7.2-stable_win64.exe --editor --path .        # Windows
.tools/godot/Godot_v4.7.2-stable_linux.x86_64 --editor --path .     # Linux
```

También sirve cualquier Godot **4.7** que tengas instalado: abrí `project.godot` desde el gestor de proyectos.

### Tests

Los tests usan [GUT](https://github.com/bitwes/Gut) (incluido en `addons/gut/`):

```
godot --headless --path . -s addons/gut/gut_cmdln.gd
```

Cubren lo siguiente:

- El determinismo del generador (mismo seed, misma pista).
- Que todos los saltos de carril se puedan alcanzar a tiempo.
- El reloj musical y la cuantización.
- La notación y la canción.
- Los códigos de seed.
- Los pilotos: entrada humana, repetición al mantener, zonas táctiles y piloto automático.

### Regenerar el audio

El audio **no está en el repo**: se genera a partir de los datos de la obra (`data/songs/canon.json`) y de la plantilla del género (`data/genres/rock.json`). Si cambiás cualquiera de los dos, regeneralo con:

```
python tools/render_audio.py rock
```

El script busca FluidSynth y el SoundFont en este orden:

1. Los argumentos `--fluidsynth` / `--soundfont`.
2. Las variables de entorno `FLUIDSYNTH` / `SOUNDFONT`.
3. `.tools/`.
4. `%LOCALAPPDATA%\Programs\`.
5. El PATH.

Genera lo siguiente en `assets/audio/generated/rock/`:

- `base_XX.wav`: el loop de acompañamiento (bajo, acordes y batería), uno por marcha de tempo.
- `notes/<rol>/<midi>.wav`: una muestra por nota, para el secuenciador en vivo.
- `manifest.json`: lo lee el juego.

Después de regenerar, abrí el proyecto en el editor o corré `godot --headless --path . --import` para que Godot reimporte los WAV.

### Estructura del proyecto

```
ToneRace/
├── scenes/            Escenas de prueba: race_test (la carrera) y music_test (el audio)
├── scripts/
│   ├── core/          Rng con sub-streams por sistema y códigos de seed de 6 caracteres
│   ├── music/         Reloj musical, secuenciador, sampler, bases por marcha y buses de audio
│   ├── track/         Generador de pista por seed, geometría (curvas/subidas) y su dibujo
│   ├── race/          Corredor, pilotos (humano/automático), auto y efectos
│   ├── world/         Mundo del desierto: cielo, suelo y props procedurales
│   └── ui/            HUD (combo) y controles táctiles
├── shaders/           Ruta, arena, cielo, boosters, partículas y estelas (todo procedural)
├── data/              La obra (canon.json) y las plantillas de género (rock.json)
├── tools/             render_audio.py: pipeline de audio con FluidSynth
├── tests/unit/        Tests GUT
├── addons/gut/        Framework de tests (MIT)
├── install.ps1 / install.sh   Instaladores
└── jugar.cmd / jugar.sh       Lanzadores
```

### Ideas clave de la arquitectura

- **Velocidad = tempo.** La pista se mide en **beats**, no en metros. Así los boosters quedan sincronizados con la música a cualquier velocidad.
- **Simulación en tick fijo (60 Hz)**, separada del render. Así el resultado es determinista.
- **Seed con sub-streams.** Cada sistema (variaciones, carriles, adornos, geometría, escenario) tiene su propio stream. Por eso cambiar el escenario nunca altera la jugabilidad. El generador tiene versión: un código siempre significa la misma pista.
- **Interfaz de piloto común.** El humano, el piloto automático y, más adelante, los bots y los jugadores en red entregan la misma entrada al corredor.
- **Gráficos livianos pensados para celulares de gama media.** No hay texturas: todo se dibuja con shaders, MultiMesh y partículas con pool. Las montañas están pintadas en el cielo y el antialiasing es MSAA 4x.

---

## Hoja de ruta (0.1)

1. ✅ Reloj musical + secuenciador (tempo variable, crossfade de marchas)
2. ✅ Pipeline de audio (género rock)
3. ✅ Pista procedural por seed: 5 carriles, línea dorada, adornos, curvas y subidas
4. ✅ Auto + controles (táctil, teclado y gamepad), mundo del desierto y efectos
5. ⬜ Loop de velocidad: turbo, desaceleración por fallos, marchas
6. ⬜ Riff y Voz con acompañante
7. ⬜ Estructura de carrera: intro, variaciones, final, llegada y posiciones
8. ⬜ 3 bots con audio filtrado y espacializado
9. ⬜ Menú mínimo y pantalla de resultados con código

---

## Problemas comunes

- **«No se puede ejecutar install.ps1 porque la ejecución de scripts está deshabilitada»**: corrélo como dice arriba, con `powershell -ExecutionPolicy Bypass -File install.ps1`.
- **El juego abre pero no suena**: falta el audio generado. Volvé a correr el instalador o `python tools/render_audio.py rock`.
- **Error de Vulkan al abrir**: actualizá los drivers de video. En Linux, instalá `mesa-vulkan-drivers` o el equivalente de tu distro.
- **Errores de clases no encontradas** (`Could not find type ...`): corré `godot --headless --path . --import` una vez.
- **Los controles táctiles aparecen en PC**: el juego los muestra si Windows informa que hay pantalla táctil. Se usan con el mouse y no molestan para jugar con teclado.

---

## Licencias y créditos

- **ToneRace** (código, shaders, datos y herramientas): [MIT](LICENSE).
- **Música:** Canon en Re de Johann Pachelbel (dominio público). Los arreglos son propios y se generan a partir de `data/`.
- **SoundFont:** [GeneralUser GS](https://github.com/mrbumpy409/GeneralUser-GS) de S. Christian Collins, bajo su propia licencia, que permite el uso libre. No se incluye en el repo: lo baja el instalador.
- **[Godot Engine](https://godotengine.org):** MIT.
- **[FluidSynth](https://www.fluidsynth.org):** LGPL-2.1. Solo se usa como herramienta para generar el audio y no se distribuye con el juego.
- **[GUT](https://github.com/bitwes/Gut):** MIT (en `addons/gut/`, con su LICENSE).
