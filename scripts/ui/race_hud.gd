class_name RaceHud
extends Control
## Capa visual de la carrera: el contador de combo que salta en cada acierto, un
## destello rojo en los bordes cuando se corta un combo, y abajo al centro la barra
## de turbo con la escalera de marchas.

const SHOW_COMBO_FROM := 2
const BREAK_FLASH_FROM := 4
const FLASH_SECONDS := 0.35
const POP_SECONDS := 0.18
const GEAR_DROP_SECONDS := 1.0

## Lo pone la escena: true mientras el acelerador está gastando turbo.
var throttling := false

var _combo := Label.new()
var _gauge := SpeedGauge.new()
var _gear_drop := Label.new()
var _gear_drop_left := 0.0
var _vignette := ColorRect.new()
var _flash := 0.0
var _pop := 0.0
var _fading := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE

	_vignette.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_vignette.mouse_filter = MOUSE_FILTER_IGNORE
	_vignette.material = ShaderMaterial.new()
	(_vignette.material as ShaderMaterial).shader = preload("res://shaders/vignette.gdshader")
	add_child(_vignette)

	_combo.set_anchors_preset(PRESET_CENTER_TOP)
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo.offset_left = -150.0
	_combo.offset_right = 150.0
	_combo.offset_top = 70.0
	_combo.offset_bottom = 150.0
	_combo.pivot_offset = Vector2(150.0, 40.0)
	_combo.add_theme_font_size_override("font_size", 56)
	_combo.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.0, 0.8))
	_combo.add_theme_constant_override("outline_size", 10)
	_combo.visible = false
	add_child(_combo)

	_gauge.set_anchors_preset(PRESET_CENTER_BOTTOM)
	_gauge.offset_left = -SpeedGauge.WIDTH / 2.0
	_gauge.offset_right = SpeedGauge.WIDTH / 2.0
	_gauge.offset_top = -SpeedGauge.HEIGHT - 24.0
	_gauge.offset_bottom = -24.0
	_gauge.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_gauge)

	_gear_drop.set_anchors_preset(PRESET_CENTER)
	_gear_drop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gear_drop.offset_left = -200.0
	_gear_drop.offset_right = 200.0
	_gear_drop.offset_top = -120.0
	_gear_drop.offset_bottom = -60.0
	_gear_drop.text = "MARCHA ↓"
	_gear_drop.add_theme_font_size_override("font_size", 44)
	_gear_drop.add_theme_color_override("font_color", Color(1.0, 0.3, 0.22))
	_gear_drop.add_theme_color_override("font_outline_color", Color(0.15, 0.0, 0.0, 0.8))
	_gear_drop.add_theme_constant_override("outline_size", 10)
	_gear_drop.visible = false
	add_child(_gear_drop)


func on_hit(combo: int) -> void:
	if combo < SHOW_COMBO_FROM:
		return
	_fading = 0.0
	_combo.visible = true
	_combo.modulate = Color(1.0, 0.82, 0.3)
	_combo.text = "x%d" % combo
	_pop = 1.0


func on_combo_break(lost: int) -> void:
	if lost >= BREAK_FLASH_FROM:
		_flash = 1.0
	if _combo.visible:
		_combo.modulate = Color(1.0, 0.25, 0.2)
		_fading = 1.0


func on_gear_drop() -> void:
	_gear_drop_left = GEAR_DROP_SECONDS
	_gauge.drop_flash = 1.0


func set_speed(turbo: float, gear: int, gears: int, bpm: float) -> void:
	_gauge.turbo = turbo
	_gauge.gear = gear
	_gauge.gears = gears
	_gauge.bpm = bpm


func _process(delta: float) -> void:
	_gauge.throttling = throttling
	_gear_drop_left = maxf(_gear_drop_left - delta, 0.0)
	_gear_drop.visible = _gear_drop_left > 0.0
	_gear_drop.modulate.a = minf(_gear_drop_left / 0.3, 1.0)
	_flash = maxf(_flash - delta / FLASH_SECONDS, 0.0)
	(_vignette.material as ShaderMaterial).set_shader_parameter("amount", _flash * 0.55)
	_pop = maxf(_pop - delta / POP_SECONDS, 0.0)
	_combo.scale = Vector2.ONE * (1.0 + 0.35 * _pop * _pop)
	if _fading > 0.0:
		_fading = maxf(_fading - delta * 2.0, 0.0)
		_combo.modulate.a = _fading
		_combo.visible = _fading > 0.0


## Barra de turbo con la escalera de marchas encima y el BPM a la izquierda.
class SpeedGauge extends Control:
	const WIDTH := 360.0
	const HEIGHT := 46.0
	const BAR_HEIGHT := 16.0
	const PIP_HEIGHT := 10.0
	const TURBO_COLOR := Color(1.0, 0.72, 0.15)
	const FULL_COLOR := Color(1.0, 0.95, 0.6)
	const GEAR_COLOR := Color(1.0, 0.5, 0.2)
	const DROP_COLOR := Color(1.0, 0.2, 0.15)
	const BACK_COLOR := Color(0.05, 0.02, 0.0, 0.55)

	var turbo := 0.0
	var gear := 0
	var gears := 1
	var bpm := 0.0
	var throttling := false
	var drop_flash := 0.0
	var _shown := 0.0
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		# La barra sigue al turbo con un poco de suavidad para que no salte.
		_shown = lerpf(_shown, turbo, 1.0 - exp(-14.0 * delta))
		drop_flash = maxf(drop_flash - delta / 0.8, 0.0)
		queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var label_width := 70.0
		var left := label_width
		var width := WIDTH - label_width
		draw_string(font, Vector2(0, HEIGHT - 2.0), "%.0f" % bpm, HORIZONTAL_ALIGNMENT_LEFT, label_width - 8.0, 30, Color.WHITE)
		draw_string(font, Vector2(0, 12.0), "BPM", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.6))

		# Escalera de marchas: una muesca por marcha, prendidas hasta la actual.
		var gap := 3.0
		var pip_width := (width - gap * (gears - 1)) / gears
		for i in gears:
			var lit := i <= gear
			var color := GEAR_COLOR if lit else BACK_COLOR
			if lit and drop_flash > 0.0:
				color = color.lerp(DROP_COLOR, drop_flash)
			if i == gear:
				color = color.lightened(0.35)
			draw_rect(Rect2(left + i * (pip_width + gap), 0.0, pip_width, PIP_HEIGHT), color)

		# Turbo.
		var bar := Rect2(left, HEIGHT - BAR_HEIGHT, width, BAR_HEIGHT)
		draw_rect(bar, BACK_COLOR)
		var fill := bar
		fill.size.x = width * clampf(_shown, 0.0, 1.0)
		var color := TURBO_COLOR
		if turbo >= 0.999:
			color = TURBO_COLOR.lerp(FULL_COLOR, 0.5 + 0.5 * sin(_time * 10.0))
		if throttling:
			color = color.lerp(FULL_COLOR, 0.4 + 0.3 * sin(_time * 30.0))
		draw_rect(fill, color)
		draw_rect(bar, Color(1, 1, 1, 0.35), false, 1.5)
		draw_string(font, Vector2(left + 6.0, HEIGHT - 3.0), "TURBO", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.75))
