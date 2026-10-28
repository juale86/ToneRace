# ToneRace — Documento de diseño

Juego de carreras musical para Android: corrés sobre una pista generada por seed y, mientras corrés, *tocás* la música (Canon de Pachelbel, dominio público). Llega primero quien toca mejor.

## Plataforma

- **Motor:** Godot 4 (última estable), GDScript.
- **Target:** Android 8+ (API 26), gama media, 60 fps, renderer Mobile, audio de baja latencia.
- **Orientación:** horizontal (landscape).
- **Desarrollo:** iteración en PC (Windows, teclado), validación en dispositivo para tacto y latencia.
- **Repo:** git local.

## Pista

- 3D low-poly, **5 carriles fijos**.
- **Carril = altura de nota** (grave → izquierda, agudo → derecha). El seed puede transponer/invertir el mapeo, pero dentro de una carrera es constante.
- **Sin obstáculos.** Es un juego rítmico puro sobre ruedas.
- La pista se mide en **beats**, no en metros.

## Controles (táctil)

- 2/3 superiores de la pantalla: **zona izquierda / derecha** → tap para cambiar de carril.
- Franja inferior: **acelerador** (mantener) a la derecha; **Riff** y **Voz** (tap) a la izquierda.
- Teclado/gamepad vía InputMap (desarrollo en PC).
- Opción de **offset de audio** (auriculares Bluetooth agregan 150–250 ms).

## Música

### Producción (híbrido)
- **Base:** loop renderizado de un ciclo, en **14 marchas de tempo** (100 → 180 BPM, separadas ≤5%). Crossfade al cruzar de marcha; dentro de cada marcha `pitch_scale` ajusta al BPM exacto (±2,4%) y un **PitchShift compensa el tono**, para que la base quede afinada con las notas en vivo. (Originalmente eran 4 marchas con ±8%, pero eso desafinaba la base contra las notas en vivo.)
- **Secuenciador en vivo:** notas doradas, adornos, Riff y Voz, tocados con los mismos SoundFonts, siempre al BPM exacto.
- **Pipeline automático:** la obra se escribe una vez como datos (bajo, armonía, melodía, 8 variaciones). Un script + plantilla de género renderiza las bases con **FluidSynth** y SoundFonts de licencia libre. Mismo dato → base y notas en vivo coherentes.
- Más adelante: algún género producido a mano en DAW.
- Legal: la composición es dominio público; grabaciones y la mayoría de MIDIs no. Arreglos propios + SoundFonts con licencia verificada.

### Qué toca el jugador
- **Línea dorada:** boosters ubicados donde cae cada nota de la melodía (carril = altura). Agarrarla suena la nota y **carga turbo**; combos cargan más.
- **Adornos:** boosters de otro color; tocan notas de la escala/acorde del momento.
- **Riff (botón 1):** entra un acompañante tocando power chords sobre la armonía.
- **Voz (botón 2):** entra un acompañante con contramelodía / arpegio.
- Riff y Voz: **cuantizadas al próximo compás**, duran 2 compases, se activan con umbral de turbo, dan un boost corto. Ambas juntas → bonus.
- Cada nota/acorde que suena es un **efecto visual** (ondas, notas de luz).

## Velocidad = tempo

- La velocidad del auto **es** el BPM: más rápido = más beats por segundo. Los boosters quedan sincronizados a cualquier velocidad.
- **Crucero:** marcha base.
- **Acelerador:** gasta turbo, sube a marchas altas.
- **Fallar notas doradas:** desacelera de a poco; varias seguidas bajan de marcha (la música "se cae"). Piso en la marcha más baja.

## Carrera

- Dura **una canción**: intro (cuenta regresiva de 4 beats + bajo solo) → **N variaciones** elegidas por el seed (banco de 8, 4 compases c/u) → **gran final** fijo.
- Largo objetivo 2–3 min (~12 variaciones). Más adelante: largo elegible (corta/media/larga).
- **Gana quien llega primero.** Largo en beats igual para todos.
- Modo infinito: futuro, aparte.

## Rivales

- **3 bots** + jugador.
- **Fantasmas:** se ven y se escuchan, **sin interacción** física ni disparos.
- IA vía la misma **interfaz de piloto** que el humano: precisión, reacción, estilo de turbo. Dificultades fácil/normal/difícil, sin rubber banding. Deterministas por seed.
- Audio de rivales: su mezcla completa a su tempo, **atenuada, filtrada (paso bajo) y espacializada** por distancia.
- Futuro multijugador: el piloto de red reemplaza al bot.

## Autos = géneros = mundos

| Auto | Género | Mundo |
|---|---|---|
| Clásico | Barroco | Palacio / jardines |
| Muscle car | Rock | Desierto / ruta |
| Neón | Synthwave | Ciudad retro |
| Retro | Chiptune | Mundo voxel |

- Cada jugador ve **su propio** mundo. El seed define la forma; el género define el tema.

## Seed

- Código de **6 caracteres** sin ambiguos (sin 0/O, 1/I/l) → entero de 64 bits.
- **Versión del generador** asociada: un código siempre significa la misma pista.
- PRNG propio (PCG32 o similar) con **sub-streams** por sistema: variaciones, transposición, adornos, geometría/escenario, bots.
- Modos: carrera rápida (seed aleatorio), pista del día (seed por fecha), ingresar código. Compartir resultado vía share nativo.

## Progresión

- Todo desbloqueado. Récords locales por seed. Progresión real se define cuando el loop esté probado.

## Assets

- Pista, carriles, boosters y efectos: **procedurales**.
- Autos, acompañantes, props: packs **CC0** (Kenney, Quaternius). Placeholders geométricos al inicio. Blender solo si hace falta.

## Arquitectura

- Simulación en **tick fijo** (60 Hz) separada del render. Estado del corredor: posición en beats, carril, turbo.
- Interfaz de piloto común (humano / bot / red).
- Tests con **GUT**: determinismo del generador (mismo seed → misma pista), reloj musical, cuantización, reglas de velocidad.

## Alcance 0.1

1. Reloj musical + secuenciador (tempo variable, crossfade de marchas).
2. Pipeline de audio: género **rock**, 4 marchas.
3. Pista procedural por seed: 5 carriles, línea dorada (con transposición), adornos, curvas/subidas. Placeholders.
4. Auto + controles (táctil + teclado).
5. Loop de velocidad: turbo, desaceleración por fallos, marchas.
6. Riff y Voz con acompañante placeholder y efectos de notas.
7. Estructura de carrera: intro, variaciones, final, llegada, posiciones.
8. 3 bots con audio filtrado/espacializado.
9. Menú mínimo (carrera rápida, ingresar código) + resultados con código.

**Fuera de 0.1:** otros géneros/mundos, pista del día, compartir, largo elegible, récords, modelos finales, modo infinito.
