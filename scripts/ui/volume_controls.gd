class_name VolumeControls
extends HBoxContainer
## Botones de volumen arriba a la derecha: silencio, bajar, nivel y subir.
## También responden al teclado: M silencio, - y + volumen.

const BUTTON_SIZE := Vector2(52, 52)
const SEGMENTS := 10

var _mute := SpeakerButton.new()
var _down := Button.new()
var _up := Button.new()
var _meter := VolumeMeter.new()


func _ready() -> void:
	AudioSettings.load_saved()
	set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	grow_horizontal = GROW_DIRECTION_BEGIN
	offset_top = 16.0
	offset_right = -16.0
	add_theme_constant_override("separation", 8)
	_mute.tooltip_text = "Silencio (M)"
	_mute.pressed.connect(func() -> void: AudioSettings.toggle_mute(); _refresh())
	_down.text = "−"
	_down.tooltip_text = "Bajar volumen (-)"
	_down.pressed.connect(func() -> void: AudioSettings.change(-1); _refresh())
	_up.text = "+"
	_up.tooltip_text = "Subir volumen (+)"
	_up.pressed.connect(func() -> void: AudioSettings.change(1); _refresh())
	for button: Button in [_mute, _down, _up]:
		button.custom_minimum_size = BUTTON_SIZE
		# Sin foco: si no, las flechas y el espacio navegarían los botones.
		button.focus_mode = FOCUS_NONE
		button.add_theme_font_size_override("font_size", 30)
	_meter.custom_minimum_size = Vector2(70, BUTTON_SIZE.y)
	for child: Control in [_mute, _down, _meter, _up]:
		add_child(child)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_M:
			AudioSettings.toggle_mute()
		KEY_MINUS, KEY_KP_SUBTRACT:
			AudioSettings.change(-1)
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			AudioSettings.change(1)
		_:
			return
	_refresh()
	get_viewport().set_input_as_handled()


func _refresh() -> void:
	_mute.muted = AudioSettings.level() <= 0.0
	_mute.queue_redraw()
	_meter.level = AudioSettings.volume
	_meter.muted = AudioSettings.muted
	_meter.queue_redraw()


## Botón con un parlante dibujado: con ondas si suena, con una cruz si no.
class SpeakerButton extends Button:
	var muted := false

	func _draw() -> void:
		var c := size / 2.0
		var s := size.y * 0.18
		var color := Color(1, 1, 1, 0.9)
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-2.2 * s, -0.7 * s), c + Vector2(-1.2 * s, -0.7 * s), c + Vector2(0.0, -1.6 * s),
			c + Vector2(0.0, 1.6 * s), c + Vector2(-1.2 * s, 0.7 * s), c + Vector2(-2.2 * s, 0.7 * s),
		]), color)
		if muted:
			var x := c + Vector2(1.3 * s, 0.0)
			draw_line(x + Vector2(-0.7, -0.7) * s, x + Vector2(0.7, 0.7) * s, Color(1.0, 0.35, 0.3), 3.0)
			draw_line(x + Vector2(-0.7, 0.7) * s, x + Vector2(0.7, -0.7) * s, Color(1.0, 0.35, 0.3), 3.0)
		else:
			for r in [0.9, 1.6]:
				draw_arc(c + Vector2(0.2 * s, 0.0), r * s, -PI / 3.5, PI / 3.5, 12, color, 2.5)


## Nivel de volumen en segmentos.
class VolumeMeter extends Control:
	var level := 1.0
	var muted := false

	func _draw() -> void:
		var gap := 3.0
		var width := (size.x - gap * (SEGMENTS - 1)) / SEGMENTS
		var lit := int(round(level * SEGMENTS))
		for i in SEGMENTS:
			var height := size.y * (0.3 + 0.4 * i / (SEGMENTS - 1.0))
			var rect := Rect2(i * (width + gap), (size.y - height) / 2.0 + size.y * 0.15, width, height)
			var color := Color(1.0, 0.75, 0.3) if i < lit else Color(0, 0, 0, 0.4)
			if muted and i < lit:
				color = Color(1, 1, 1, 0.3)
			draw_rect(rect, color)
