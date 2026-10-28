class_name MusicClock
extends RefCounted
## Reloj musical de la simulación. Avanza en ticks fijos: con los mismos ticks y
## los mismos cambios de BPM, siempre llega al mismo beat (determinista).

var beat := 0.0
var bpm := 100.0


func advance(delta: float) -> void:
	beat += bpm / 60.0 * delta


## Beat estimado entre dos ticks, para audio y render.
func interpolated(fraction: float, tick_delta: float) -> float:
	return beat + bpm / 60.0 * tick_delta * fraction


func seconds_per_beat() -> float:
	return 60.0 / bpm
