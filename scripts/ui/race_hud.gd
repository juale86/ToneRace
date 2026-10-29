class_name RaceHud
extends Control
## Capa visual de la carrera: líneas de velocidad (las maneja el parámetro global
## "speed"), el contador de combo que salta en cada acierto y un destello rojo en
## los bordes cuando se corta un combo.

const SHOW_COMBO_FROM := 2
const BREAK_FLASH_FROM := 4
const FLASH_SECONDS := 0.35
const POP_SECONDS := 0.18

var _combo := Label.new()
var _vignette := ColorRect.new()
var _flash := 0.0
var _pop := 0.0
var _fading := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE

	var lines := ColorRect.new()
	lines.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	lines.mouse_filter = MOUSE_FILTER_IGNORE
	lines.material = ShaderMaterial.new()
	(lines.material as ShaderMaterial).shader = preload("res://shaders/speed_lines.gdshader")
	add_child(lines)

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


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta / FLASH_SECONDS, 0.0)
	(_vignette.material as ShaderMaterial).set_shader_parameter("amount", _flash * 0.55)
	_pop = maxf(_pop - delta / POP_SECONDS, 0.0)
	_combo.scale = Vector2.ONE * (1.0 + 0.35 * _pop * _pop)
	if _fading > 0.0:
		_fading = maxf(_fading - delta * 2.0, 0.0)
		_combo.modulate.a = _fading
		_combo.visible = _fading > 0.0
