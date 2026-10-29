class_name Pilot
extends Node
## Interfaz común de los pilotos (humano, bot, red). La simulación le pide una
## decisión por tick y la aplica igual sin importar quién maneja.


func decide(_runner: Runner, _track: Track) -> PilotInput:
	return PilotInput.new()
