class_name AutoPilot
extends Pilot
## Piloto perfecto de prueba: va al carril de la próxima nota dorada.


func decide(runner: Runner, track: Track) -> PilotInput:
	var input := PilotInput.new()
	for booster in track.boosters:
		if booster.beat > runner.clock.beat and booster.kind == Booster.Kind.GOLD:
			input.lane_steps = booster.lane - runner.lane
			break
	return input
