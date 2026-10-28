class_name AudioBuses
extends RefCounted
## Crea los buses de audio en tiempo de ejecución si todavía no existen.


static func ensure(bus_name: StringName, effects: Array[AudioEffect] = []) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index != -1:
		return index
	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")
	for effect in effects:
		AudioServer.add_bus_effect(index, effect)
	return index
