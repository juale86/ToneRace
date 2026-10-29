class_name TouchControls
extends Control
## Controles táctiles. Convierten toques en las mismas acciones del InputMap que
## usan teclado y gamepad, así el piloto humano no distingue de dónde vienen.
##
## 2/3 superiores: mitad izquierda/derecha cambia de carril.
## Franja inferior: Riff y Voz a la izquierda, acelerador (mantener) a la derecha.

const STRIP_TOP := 2.0 / 3.0
const RIFF_END := 0.17
const VOICE_END := 0.34
const THROTTLE_START := 0.7

## Toques activos: índice → acción que mantienen apretada.
var _touches := {}


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE


## Acción que dispara un toque en `pos`, o &"" si cae en una zona muerta.
static func action_at(pos: Vector2, area: Vector2) -> StringName:
	var x := pos.x / area.x
	if pos.y < area.y * STRIP_TOP:
		return &"lane_left" if x < 0.5 else &"lane_right"
	if x < RIFF_END:
		return &"riff"
	if x < VOICE_END:
		return &"voice"
	if x >= THROTTLE_START:
		return &"throttle"
	return &""


func _input(event: InputEvent) -> void:
	if not event is InputEventScreenTouch:
		return
	var touch := event as InputEventScreenTouch
	if touch.pressed:
		var action := action_at(touch.position, size)
		if action != &"" and not _touches.has(touch.index):
			_touches[touch.index] = action
			_send(action, true)
	elif _touches.has(touch.index):
		_send(_touches[touch.index], false)
		_touches.erase(touch.index)
	queue_redraw()


func _notification(what: int) -> void:
	# Al perder el foco no llegan las sueltas: liberar todo para no quedar acelerando.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
		for action: StringName in _touches.values():
			_send(action, false)
		_touches.clear()


func _send(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _draw() -> void:
	var held: Array = _touches.values()
	var strip := size.y * STRIP_TOP
	var font := ThemeDB.fallback_font
	var font_size := int(size.y * 0.035)
	var line := Color(1, 1, 1, 0.15)
	draw_line(Vector2(0, strip), Vector2(size.x, strip), line, 2.0)
	draw_line(Vector2(size.x / 2.0, strip * 0.25), Vector2(size.x / 2.0, strip * 0.75), line, 2.0)
	for side in [[&"lane_left", 0.08, "‹"], [&"lane_right", 0.92, "›"]]:
		var alpha := 0.5 if side[0] in held else 0.2
		_label(Vector2(size.x * side[1], strip * 0.5), side[2], font, font_size * 3, Color(1, 1, 1, alpha))
	var radius := size.y * 0.1
	var bottom := (strip + size.y) / 2.0
	for button in [[&"riff", RIFF_END / 2.0, "RIFF", Color(1.0, 0.45, 0.1)], [&"voice", (RIFF_END + VOICE_END) / 2.0, "VOZ", Color(0.3, 0.7, 1.0)]]:
		var center := Vector2(size.x * button[1], bottom)
		var color: Color = button[3]
		draw_circle(center, radius, Color(color, 0.45 if button[0] in held else 0.15))
		draw_arc(center, radius, 0.0, TAU, 32, Color(color, 0.6), 2.0)
		_label(center, button[2], font, font_size, Color(1, 1, 1, 0.8))
	var pedal := Rect2(size.x * THROTTLE_START + 16.0, strip + 16.0, size.x * (1.0 - THROTTLE_START) - 32.0, size.y - strip - 32.0)
	var green := Color(0.3, 1.0, 0.5)
	draw_rect(pedal, Color(green, 0.4 if &"throttle" in held else 0.12))
	draw_rect(pedal, Color(green, 0.6), false, 2.0)
	_label(pedal.get_center(), "ACELERAR", font, font_size, Color(1, 1, 1, 0.8))


func _label(center: Vector2, text: String, font: Font, font_size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, center + Vector2(-text_size.x / 2.0, text_size.y / 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
