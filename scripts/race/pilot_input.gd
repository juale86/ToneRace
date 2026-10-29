class_name PilotInput
extends RefCounted
## Lo que un piloto decide en un tick de simulación.

## Cambios de carril pedidos en este tick (negativo = izquierda).
var lane_steps := 0
var throttle := false
var riff := false
var voice := false
