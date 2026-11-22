extends Control

const Style = preload("res://scripts/ui/Style.gd")

var entries: Array[Dictionary] = []
var selected := -1
var current := -1
var item_radius := 236.0
var center_option := true
var _stick := Vector2.ZERO


func start(active: int) -> void:
	selected = active
	current = active
	_stick = Vector2.ZERO
	show()
	queue_redraw()
	if DisplayServer.get_name() != "headless" and not OS.has_feature("mobile"):
		warp_mouse(slot_position(selected))


func handle_event(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		_set_direction(get_local_mouse_position() - size * 0.5, 83.0)
		return true
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_RIGHT_X:
			_stick.x = event.axis_value
		elif event.axis == JOY_AXIS_RIGHT_Y:
			_stick.y = event.axis_value
		else:
			return false
		# Stick snap retains the selected station while the shoulder is released.
		if _stick.length() >= 0.50:
			_set_direction(_stick, 0.0)
		return true
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		_cycle(-1)
		return true
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		_cycle(1)
		return true
	if center_option and (event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_X)):
		selected = -1
		queue_redraw()
		return true
	return false


func _set_direction(direction: Vector2, dead_zone: float) -> void:
	if center_option and direction.length() < dead_zone:
		selected = -1
	elif direction.length() >= dead_zone:
		selected = posmod(roundi((direction.angle() + PI / 2.0) / TAU * entries.size()), entries.size())
	queue_redraw()


func _cycle(delta: int) -> void:
	var options := entries.size() + (1 if center_option else 0)
	var current_index := entries.size() if selected < 0 else selected
	var new_index := posmod(current_index + delta, options)
	selected = -1 if new_index == entries.size() else new_index
	queue_redraw()


func slot_position(index: int) -> Vector2:
	if index < 0 or entries.is_empty():
		return size * 0.5
	var angle := TAU * float(index) / float(entries.size()) - PI / 2.0
	return size * 0.5 + Vector2.from_angle(angle) * item_radius


func card(at: Rect2, fill: Color, edge: Color, stroke := 1.0) -> void:
	draw_rect(at, fill)
	draw_rect(at, edge, false, stroke)


func centered(value: String, at: Vector2, width: float, font_size: int, tint: Color, heavy := true) -> void:
	var font := Style.font(heavy)
	var length := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, at + Vector2(maxf((width - length) / 2.0, 0.0), 0), value, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, tint)
