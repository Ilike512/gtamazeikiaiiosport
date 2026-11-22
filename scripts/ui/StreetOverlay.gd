extends Control

const Style = preload("res://scripts/ui/Style.gd")
const TONE = preload("res://assets/shaders/street_transition.gdshader")

var _switch_panel: PanelContainer
var _choices: Array[Label] = []
var _wash: ColorRect
var _shader: ShaderMaterial
var _card: Control
var _title: Label
var _detail: Label
var _defeat_title: Label


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var capture := BackBufferCopy.new()
	capture.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(capture)
	_wash = ColorRect.new()
	_wash.mouse_filter = MOUSE_FILTER_IGNORE
	_shader = ShaderMaterial.new()
	_shader.shader = TONE
	_wash.material = _shader
	add_child(_wash)
	Style.fill(_wash)
	_switch_panel = PanelContainer.new()
	_switch_panel.mouse_filter = MOUSE_FILTER_IGNORE
	_switch_panel.position = Vector2(923, 404)
	_switch_panel.custom_minimum_size = Vector2(315, 165)
	_switch_panel.add_theme_stylebox_override("panel", Style.box(Color("#101823ed"), Color("#9caad4"), 3))
	add_child(_switch_panel)
	var picker := Style.stack(_switch_panel, 7)
	picker.add_child(Style.label("SWITCH CHARACTER", 12, Color("#aab7db"), true))
	for index in 2:
		var label := Style.label("", 22, Color.WHITE, true)
		picker.add_child(label)
		_choices.append(label)
	picker.add_child(Style.label("← →  SELECT   /   RELEASE TO SWITCH", 11, Style.MUTED, true))
	_card = PanelContainer.new()
	_card.mouse_filter = MOUSE_FILTER_IGNORE
	_card.position = Vector2(68, 184)
	_card.custom_minimum_size = Vector2(340, 125)
	_card.add_theme_stylebox_override("panel", Style.box(Color("#161923ed"), Color("#a84f58"), 4))
	add_child(_card)
	var content := Style.stack(_card, 5)
	_title = Style.label("", 50, Color("#f0cbcf"), true)
	content.add_child(_title)
	_detail = Style.label("", 15, Style.TEXT, true)
	content.add_child(_detail)
	_defeat_title = Style.label("", 99, Color("#ee2938"), true)
	_defeat_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_defeat_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_defeat_title.add_theme_constant_override("outline_size", 10)
	_defeat_title.add_theme_color_override("font_outline_color", Color("#2a1014cc"))
	_defeat_title.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_defeat_title)
	Style.fill(_defeat_title)
	_defeat_title.hide()
	hide()


func picker(characters: Array, chosen: int) -> void:
	_defeat_title.hide()
	_wash.hide()
	_card.hide()
	_switch_panel.show()
	for index in _choices.size():
		var name := str(characters[index].name) if index < characters.size() else ""
		_choices[index].text = "%s  %s" % ["▸" if index == chosen else " ", name.to_upper()]
		_choices[index].modulate = Color("#c8d4f2") if index == chosen else Color("#9caaa6")
	show()


func transition(tint: Color, title: String, detail: String, strength := 0.0) -> void:
	_switch_panel.hide()
	_wash.show()
	_card.visible = not title.is_empty()
	_title.text = title
	_detail.text = detail
	_shader.set_shader_parameter("tint", tint)
	_shader.set_shader_parameter("strength", strength)
	_shader.set_shader_parameter("fade_to_black", 0.0)
	_shader.set_shader_parameter("fog_strength", 0.0)
	_defeat_title.hide()
	show()


func defeat() -> void:
	transition(Color("#c6bfc1"), "", "", 0.28)
	var fog := create_tween().set_ignore_time_scale(true)
	fog.tween_property(_shader, "shader_parameter/fog_strength", 0.93, 1.45)


func reveal_defeat(text: String, duration: float) -> void:
	_defeat_title.text = text
	_defeat_title.modulate.a = 1.0
	_defeat_title.show()
	var fade := create_tween().set_ignore_time_scale(true)
	fade.tween_property(_defeat_title, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func fade_defeat_to_black(duration: float) -> void:
	var fade := create_tween().set_ignore_time_scale(true)
	fade.tween_property(_shader, "shader_parameter/fade_to_black", 1.0, duration)


func clear_defeat_fog() -> void:
	_defeat_title.hide()
	_shader.set_shader_parameter("fog_strength", 0.0)


func animate_grade(target_strength: float, black: float, duration: float) -> Tween:
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_ignore_time_scale(true)
	tween.tween_property(_shader, "shader_parameter/strength", target_strength, duration)
	tween.tween_property(_shader, "shader_parameter/fade_to_black", black, duration)
	return tween
