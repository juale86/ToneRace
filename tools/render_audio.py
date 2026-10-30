"""Renderiza el audio de un género a partir de los datos de la obra.

Genera, en assets/audio/generated/<genero>/:
  - base_XX.wav: el loop de base (bajo + acordes + batería) de un ciclo, una
    versión por marcha de tempo. Loop sin cortes (se renderizan 3 ciclos y se
    recorta el del medio para que las colas de reverb queden incluidas).
  - notes/<rol>/<midi>.wav: una muestra mono por nota para el secuenciador en vivo.
  - manifest.json: marchas, archivos y rangos, leído por el juego.

Uso:
  python tools/render_audio.py rock
"""

import argparse
import array
import json
import math
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCALAPPDATA = os.environ.get("LOCALAPPDATA", "")
TOOLS = os.path.join(ROOT, ".tools")  # lo llenan install.ps1 / install.sh


def first_existing(*paths):
    """Primer candidato que existe; si ninguno, el primero (para el mensaje de error)."""
    for p in paths:
        if p and os.path.isfile(p):
            return p
    return paths[0]


DEFAULT_FLUIDSYNTH = first_existing(
    os.path.join(TOOLS, "fluidsynth", "bin", "fluidsynth.exe"),
    os.path.join(LOCALAPPDATA, "Programs", "fluidsynth", "fluidsynth-v2.6.1-win10-x64-cpp11", "bin", "fluidsynth.exe"),
    shutil.which("fluidsynth"),
)
DEFAULT_SOUNDFONT = first_existing(
    os.path.join(TOOLS, "GeneralUser-GS.sf2"),
    os.path.join(LOCALAPPDATA, "Programs", "soundfonts", "GeneralUser-GS.sf2"),
)

SAMPLE_RATE = 44100
PPQ = 480
NOTE_HOLD_SEC = 2.0
NOTE_TAIL_SEC = 1.0
NOTE_SPACING_SEC = 3.5
PEAK_TARGET = 0.89  # -1 dBFS

# --- Notación -----------------------------------------------------------------

NOTE_OFFSETS = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
CHORD_INTERVALS = {"": [0, 4, 7], "m": [0, 3, 7]}


def note_to_midi(name):
    """'F#5' -> 78. C4 = 60."""
    letter = name[0].upper()
    rest = name[1:]
    accidental = 0
    while rest and rest[0] in "#b":
        accidental += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + NOTE_OFFSETS[letter] + accidental


def parse_line(text):
    """Devuelve [(onset_beats, dur_beats, midi|None)]."""
    events = []
    t = 0.0
    default_dur = 1.0
    for token in text.split():
        if token.startswith("@"):
            default_dur = float(token[1:])
            continue
        name, _, dur = token.partition(":")
        d = float(dur) if dur else default_dur
        events.append((t, d, None if name == "r" else note_to_midi(name)))
        t += d
    return events


def line_length(events):
    return sum(d for _, d, _ in events)


def chord_pitch_classes(symbol):
    root = symbol[0]
    rest = symbol[1:]
    acc = 0
    if rest[:1] in ("#", "b"):
        acc = 1 if rest[0] == "#" else -1
        rest = rest[1:]
    pc = (NOTE_OFFSETS[root] + acc) % 12
    return [(pc + i) % 12 for i in CHORD_INTERVALS[rest]]


def voice_chord(symbol, low, high):
    """Todas las notas del acorde dentro de [low, high]."""
    pcs = chord_pitch_classes(symbol)
    return [m for m in range(low, high + 1) if m % 12 in pcs]


# --- MIDI ---------------------------------------------------------------------


def _vlq(n):
    out = [n & 0x7F]
    n >>= 7
    while n:
        out.append((n & 0x7F) | 0x80)
        n >>= 7
    return bytes(reversed(out))


def write_midi(path, bpm, tracks):
    """tracks: lista de (canal, programa|None, [(tick, 'on'|'off', nota, vel)])."""
    chunks = []
    tempo = int(round(60_000_000 / bpm))
    conductor = _vlq(0) + b"\xff\x51\x03" + tempo.to_bytes(3, "big") + _vlq(0) + b"\xff\x2f\x00"
    chunks.append(conductor)
    for channel, program, events in tracks:
        data = bytearray()
        if program is not None:
            data += _vlq(0) + bytes([0xC0 | channel, program])
        last = 0
        # Los note-off van antes que los note-on en el mismo tick.
        for tick, kind, note, vel in sorted(events, key=lambda e: (e[0], e[1] == "on")):
            data += _vlq(tick - last)
            status = (0x90 if kind == "on" else 0x80) | channel
            data += bytes([status, note, vel if kind == "on" else 0])
            last = tick
        data += _vlq(0) + b"\xff\x2f\x00"
        chunks.append(bytes(data))
    with open(path, "wb") as f:
        f.write(b"MThd" + struct.pack(">IHHH", 6, 1, len(chunks), PPQ))
        for c in chunks:
            f.write(b"MTrk" + struct.pack(">I", len(c)) + c)


def note_events(onset_beats, dur_beats, midi, vel, gap=0.02):
    on = int(round(onset_beats * PPQ))
    off = int(round((onset_beats + dur_beats - gap) * PPQ))
    return [(on, "on", midi, vel), (max(off, on + 1), "off", midi, 0)]


# --- Audio --------------------------------------------------------------------


def render(fluidsynth, soundfont, midi_path, wav_path, gain=0.5):
    subprocess.run(
        [fluidsynth, "-ni", "-q", "-g", str(gain), "-r", str(SAMPLE_RATE), "-T", "wav", "-F", wav_path, soundfont, midi_path],
        check=True,
    )


def read_wav(path):
    with wave.open(path, "rb") as w:
        assert w.getsampwidth() == 2, "se esperaba PCM de 16 bits"
        channels = w.getnchannels()
        data = array.array("h", w.readframes(w.getnframes()))
    return channels, data


def write_wav(path, channels, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(data.tobytes())


def to_mono(data):
    return array.array("h", ((data[i] + data[i + 1]) // 2 for i in range(0, len(data), 2)))


def peak(data):
    return max((abs(s) for s in data), default=0) / 32768.0


def scale(data, factor):
    return array.array("h", (max(-32768, min(32767, int(s * factor))) for s in data))


def fade_out(data, channels, frames):
    n = len(data) // channels
    start = max(0, n - frames)
    for f in range(start, n):
        g = (n - f) / frames
        for c in range(channels):
            data[f * channels + c] = int(data[f * channels + c] * g)
    return data


# --- Pipeline -----------------------------------------------------------------


def gear_bpms(tempo):
    lo, hi, ratio = tempo["min_bpm"], tempo["max_bpm"], tempo["max_gear_ratio"]
    n = math.ceil(math.log(hi / lo) / math.log(ratio))
    return [round(lo * (hi / lo) ** (i / n), 3) for i in range(n + 1)]


def build_base_tracks(song, genre, cycles):
    base = genre["base"]
    cycle = song["cycle_beats"]
    bass_line = parse_line(song["bass"])
    tracks = []

    bass = base["bass"]
    events = []
    sub = bass.get("subdivide", 1)
    for c in range(cycles):
        for onset, dur, midi in bass_line:
            step = dur / sub
            for s in range(sub):
                events += note_events(c * cycle + onset + s * step, step, midi, bass["velocity"])
    tracks.append((0, bass["program"], events))

    ch = base["chords"]
    events = []
    for c in range(cycles):
        for beat, symbol in enumerate(song["chords"]):
            for midi in voice_chord(symbol, ch["low"], ch["high"]):
                events += note_events(c * cycle + beat, 1.0, midi, ch["velocity"], gap=0.0)
    tracks.append((1, ch["program"], events))

    events = []
    for drum, spec in base["drums"].items():
        pattern = spec["pattern"]
        step = cycle / len(pattern)
        for c in range(cycles):
            for i, hit in enumerate(pattern):
                if hit == "x":
                    events += note_events(c * cycle + i * step, step * 0.5, int(drum), spec["velocity"], gap=0.0)
    tracks.append((9, None, events))
    return tracks


def render_bases(song, genre, out_dir, work, fluidsynth, soundfont):
    gears = []
    cycle = song["cycle_beats"]
    for i, bpm in enumerate(gear_bpms(genre["tempo"])):
        mid = os.path.join(work, f"base_{i:02d}.mid")
        raw = os.path.join(work, f"base_{i:02d}_raw.wav")
        write_midi(mid, bpm, build_base_tracks(song, genre, cycles=3))
        render(fluidsynth, soundfont, mid, raw)
        channels, data = read_wav(raw)
        cycle_frames = round(cycle * 60.0 / bpm * SAMPLE_RATE)
        start = round(cycle * 60.0 / bpm * SAMPLE_RATE)
        loop = data[start * channels:(start + cycle_frames) * channels]
        gears.append({"bpm": bpm, "file": f"base_{i:02d}.wav", "frames": cycle_frames, "_data": loop, "_ch": channels})
        print(f"  base {i:02d}: {bpm:7.3f} BPM, {cycle_frames} frames")

    # Mismo factor de ganancia para todas las marchas: que no cambie el volumen al pasar de una a otra.
    factor = PEAK_TARGET / max(peak(g["_data"]) for g in gears)
    for g in gears:
        write_wav(os.path.join(out_dir, g["file"]), g.pop("_ch"), scale(g.pop("_data"), factor))
    return gears


def render_notes(genre, out_dir, work, fluidsynth, soundfont):
    live = {}
    for role, spec in genre["live"].items():
        notes = list(range(spec["low"], spec["high"] + 1))
        events = []
        for i, midi in enumerate(notes):
            on = i * NOTE_SPACING_SEC
            # A 60 BPM un beat = 1 segundo, así que los ticks equivalen a segundos.
            events += [(int(on * PPQ), "on", midi, 100), (int((on + NOTE_HOLD_SEC) * PPQ), "off", midi, 0)]
        mid = os.path.join(work, f"notes_{role}.mid")
        raw = os.path.join(work, f"notes_{role}.wav")
        write_midi(mid, 60.0, [(0, spec["program"], events)])
        render(fluidsynth, soundfont, mid, raw)
        channels, data = read_wav(raw)
        mono = to_mono(data) if channels == 2 else data
        seg = int((NOTE_HOLD_SEC + NOTE_TAIL_SEC) * SAMPLE_RATE)
        clips = {}
        for i, midi in enumerate(notes):
            start = int(i * NOTE_SPACING_SEC * SAMPLE_RATE)
            clips[midi] = fade_out(mono[start:start + seg], 1, int(0.05 * SAMPLE_RATE))
        factor = PEAK_TARGET / max(peak(c) for c in clips.values())
        for midi, clip in clips.items():
            write_wav(os.path.join(out_dir, "notes", role, f"{midi}.wav"), 1, scale(clip, factor))
        live[role] = {"low": spec["low"], "high": spec["high"], "hold_sec": NOTE_HOLD_SEC}
        print(f"  notas {role}: {len(notes)} muestras")
    return live


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("genre")
    parser.add_argument("--song", default="canon")
    parser.add_argument("--fluidsynth", default=os.environ.get("FLUIDSYNTH", DEFAULT_FLUIDSYNTH))
    parser.add_argument("--soundfont", default=os.environ.get("SOUNDFONT", DEFAULT_SOUNDFONT))
    args = parser.parse_args()

    for p in (args.fluidsynth, args.soundfont):
        if not os.path.isfile(p):
            sys.exit(f"No encontrado: {p}")

    with open(os.path.join(ROOT, "data", "songs", f"{args.song}.json"), encoding="utf-8") as f:
        song = json.load(f)
    with open(os.path.join(ROOT, "data", "genres", f"{args.genre}.json"), encoding="utf-8") as f:
        genre = json.load(f)

    out_dir = os.path.join(ROOT, "assets", "audio", "generated", args.genre)
    if os.path.isdir(out_dir):
        shutil.rmtree(out_dir)
    os.makedirs(out_dir)

    with tempfile.TemporaryDirectory() as work:
        print(f"Renderizando '{args.song}' en género '{args.genre}'")
        gears = render_bases(song, genre, out_dir, work, args.fluidsynth, args.soundfont)
        live = render_notes(genre, out_dir, work, args.fluidsynth, args.soundfont)

    manifest = {
        "song": args.song,
        "genre": args.genre,
        "sample_rate": SAMPLE_RATE,
        "cycle_beats": song["cycle_beats"],
        "gears": gears,
        "live": live,
    }
    with open(os.path.join(out_dir, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent="\t")
    print(f"Listo: {out_dir}")


if __name__ == "__main__":
    main()
