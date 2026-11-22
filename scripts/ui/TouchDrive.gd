extends Control

const Style = preload("res://scripts/ui/Style.gd")
const STICK_ACTIONS := ["move_left", "move_right", "move_forward", "move_back"]
const BUTTONS := [
	["pause", "Ⅱ", Vector2(-72, 35)], ["phone", "PHONE", Vector2(-145, 35)],
	["chat", "CHAT", Vector2(-218, 35)], ["cheats", "CODES", Vector2(-292, 35)],
	["move_forward", "GAS", Vector2(-73, -48)], ["move_back", "REVERSE", Vector2(-156, -48)], ["jump_brake", "JUMP", Vector2(-72, -126)],
	["interact", "USE", Vector2(-144, -126)], ["rob", "LEAVE", Vector2(-72, -197)],
	["sprint", "RUN", Vector2(-144, -197)], ["recover", "RIGHT CAR", Vector2(-144, -197)], ["radio_wheel", "RADIO", Vector2(-144, -270)],
	["inventory_wheel", "ITEMS", Vector2(-72, -270)], ["equipment_use", "HIT", Vector2(-218, -126)],
	["throw_item", "THROW", Vector2(-218, -197)], ["drop_item", "DROP", Vector2(-218, -270)]
]
const STICK_SIZE := 65.0
const BUTTON_SIZE := 30.0

var world: Node3D
var _stick_index := -1
var _look_index := -1
var _stick := Vector2.ZERO
var _held: Dictionary = {}
var _mode := ""
var _was_driving := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if _was_driving != world.driving:
		_was_driving = world.driving
		_release_all()
	if _mode != world._mode:
		_mode = world._mode
		if not _mode.is_empty():
			_release_all()
	if _mode.is_empty():
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and world != null:
		_release_all()


func _draw() -> void:
	if not _mode.is_empty():
		return
	var center := _stick_center()
	draw_circle(center, _stick_radius(), Color("#141a29af"))
	draw_circle(center, STICK_SIZE, Style.EDGE, false, 2.0, true)
	draw_circle(center + _stick * (_stick_radius() - 18.0), 22.0, Color("#618889d0"))
	if world.driving:
		draw_string(Style.font(true), center + Vector2(-32, -_stick_radius() - 9.0), "‹ STEER ›", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Style.TEXT)
	for action: Array in BUTTONS:
		if not _use_button(action[0]):
			continue
		var at := _button_center(action[2])
		var pedal: bool = action[0] in ["move_forward", "move_back"]
		var radius := 36.0 if pedal else BUTTON_SIZE
		draw_circle(at, radius, Color("#274f53ed") if pedal else Color("#111725d5"))
		draw_circle(at, radius, Style.EDGE, false, 2.0, true)
		var caption := str(action[1])
		if world.driving:
			if action[0] == "jump_brake":
				caption = "BRAKE"
			elif action[0] == "interact":
				caption = "HORN"
		if world._flying:
			if action[0] == "jump_brake":
				caption = "UP"
			elif action[0] == "sprint":
				caption = "DOWN"
		elif action[0] == "rob" and not world.driving:
			caption = "ROB"
		var font := Style.font(true)
		var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(font, at + Vector2(-0.5 * width, 5), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Style.TEXT)


func _input(event: InputEvent) -> void:
	if world == null:
		return
	var mode: String = world._mode
	if not mode.is_empty():
		if event is InputEventScreenTouch and event.pressed and mode in ["radio", "inventory", "equipment"]:
			var picker: Control = world._radio if mode == "radio" else (world._inventory_picker if mode == "inventory" else world._weapon_picker)
			picker._set_direction(event.position - picker.size * 0.5, 83.0)
			_action("radio_wheel" if mode == "radio" else ("inventory_wheel" if mode == "inventory" else "equipment_wheel"), false)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_pressed(event.index, event.position)
		else:
			_touch_released(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _stick_index:
		_update_stick(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _look_index:
		world._orbit(event.relative * float(GameManager.settings.sensitivity) * 0.006)
		get_viewport().set_input_as_handled()


func _touch_pressed(id: int, at: Vector2) -> void:
	for button: Array in BUTTONS:
		var action: String = button[0]
		if _use_button(action) and at.distance_to(_button_center(button[2])) <= (40.0 if action in ["move_forward", "move_back"] else BUTTON_SIZE + 6.0):
			if action in ["radio_wheel", "inventory_wheel"]:
				_release_all()
				_action(action, true)
			else:
				_held[id] = action
				_action(action, true)
			return
	if _stick_index < 0 and at.distance_to(_stick_center()) <= _stick_radius() + 15.0:
		_stick_index = id
		_update_stick(at)
	elif _look_index < 0 and at.x > size.x * 0.48:
		_look_index = id


func _touch_released(id: int) -> void:
	if _held.has(id):
		_action(str(_held[id]), false)
		_held.erase(id)
	if _stick_index == id:
		_stick_index = -1
		_update_stick(_stick_center())
	if _look_index == id:
		_look_index = -1


func _release_all() -> void:
	for id: int in _held.keys():
		_touch_released(id)
	_stick_index = -1
	_look_index = -1
	for action: String in STICK_ACTIONS:
		Input.action_release(action)
	_update_stick(_stick_center())
	queue_redraw()


func _update_stick(at: Vector2) -> void:
	_stick = ((at - _stick_center()) / _stick_radius()).limit_length()
	if world.driving:
		_stick.y = 0.0
	var amounts := [-_stick.x, _stick.x, -_stick.y, _stick.y]
	for index in STICK_ACTIONS.size():
		var action: String = STICK_ACTIONS[index]
		if world.driving and index >= 2:
			continue
		if float(amounts[index]) > 0.17:
			Input.action_press(action, inverse_lerp(0.17, 1.0, amounts[index]))
		else:
			Input.action_release(action)


func _action(action: String, pressed: bool) -> void:
	var input := InputEventAction.new()
	input.action = action
	input.pressed = pressed
	Input.parse_input_event(input)


func _stick_radius() -> float:
	return STICK_SIZE * clampf(float(GameManager.settings.touch_stick_size), 0.65, 1.45)


func _stick_center() -> Vector2:
	return Vector2(303 + maxf(0.0, _stick_radius() - STICK_SIZE), size.y - 135)


func _button_center(offset: Vector2) -> Vector2:
	return Vector2(size.x + offset.x, size.y + offset.y if offset.y < 0.0 else offset.y)


func _use_button(action: String) -> bool:
	if action in ["move_forward", "move_back"]:
		return world.driving
	if action == "cheats":
		return not world._flying and SessionManager.cheats_allowed()
	if action == "recover":
		return world.can_recover_car()
	if world._passenger_driver != 0:
		return action in ["pause", "rob"] or (action == "chat" and SessionManager.active)
	if action == "chat":
		return SessionManager.active
	if world._flying:
		return action in ["pause", "jump_brake", "sprint", "rob", "radio_wheel"]
	if action == "rob":
		return world.driving or world._places.is_bank(world._inside) or world._fuel_stations.can_start(world.player.position)
	if action == "radio_wheel":
		return world.driving
	if action in ["throw_item", "drop_item"]:
		return not world.driving and (is_instance_valid(world._carried_body) or not world._held_id().is_empty())
	if action in ["sprint", "equipment_use"]:
		return not world.driving
	return true

