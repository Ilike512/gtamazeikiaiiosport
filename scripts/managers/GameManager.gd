extends Node

signal settings_changed

const MAIN := "res://scenes/menus/MainMenu.tscn"
const LOADING := "res://scenes/menus/LoadingScreen.tscn"
const WORLD := "res://scenes/world/Mazeikiai.tscn"
const SETTINGS_PATH := "user://settings.cfg"
const DISPLAY_SETTINGS_VERSION := 1

const DEFAULT_SETTINGS := {
	"master": 0.85, "radio": 0.70, "music": 0.72, "sfx": 0.70,
	"sensitivity": 1.0, "fullscreen": false, "resolution": 1, "quality": 1,
	"autosave": true, "injury_effects": 2, "radio_interludes": true, "sound_quality": 1, "touch_stick_size": 1.0, "controller_look": 1.0
}
const RESOLUTIONS := [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
const KEY_DEFAULTS := {
	"move_forward": KEY_W, "move_left": KEY_A, "move_back": KEY_S, "move_right": KEY_D,
	"sprint": KEY_SHIFT, "jump_brake": KEY_SPACE, "interact": KEY_E, "dive": KEY_CTRL,
	"radio_wheel": KEY_Q, "inventory_wheel": KEY_TAB, "character": KEY_C, "recover": KEY_R,
	"equipment_wheel": KEY_QUOTELEFT, "phone": KEY_UP, "use_item": KEY_Y,
	"vehicle_camera": KEY_V, "throw_item": KEY_G, "drop_item": KEY_BACKSPACE, "restart_checkpoint": KEY_K,
	"chat": KEY_SLASH, "world_map": KEY_T, "rob": KEY_F, "pause": KEY_ESCAPE, "character_picker": KEY_ALT, "cheats": KEY_MINUS,
}
const ACTION_NAMES := {
	"move_forward": "Forward / accelerate", "move_left": "Move / steer left",
	"move_back": "Back / reverse", "move_right": "Move / steer right",
	"sprint": "Sprint", "jump_brake": "Jump / vault / surface / brake", "dive": "Dive underwater", "interact": "Interact / enter / horn",
	"radio_wheel": "Hold radio picker", "inventory_wheel": "Hold inventory picker",
	"equipment_wheel": "Hold weapon picker", "phone": "Open phone", "use_item": "Use hotbar item",
	"vehicle_camera": "Switch vehicle camera", "throw_item": "Throw held item (tap repeatedly to build power)",
	"drop_item": "Drop held item", "restart_checkpoint": "Return to checkpoint with weapon equipped",
	"character": "Next character", "recover": "Recover overturned car",
	"world_map": "Hold enlarged map", "rob": "Rob / search / leave vehicle", "pause": "Pause",
	"character_picker": "Hold character selector", "chat": "Multiplayer chat"
}
const PAD_BUTTONS := {
	"sprint": JOY_BUTTON_LEFT_STICK, "jump_brake": JOY_BUTTON_A,
	"interact": JOY_BUTTON_Y, "radio_wheel": JOY_BUTTON_LEFT_SHOULDER,
	"inventory_wheel": JOY_BUTTON_RIGHT_SHOULDER, "character": JOY_BUTTON_DPAD_UP,
	"equipment_wheel": JOY_BUTTON_DPAD_LEFT, "phone": JOY_BUTTON_DPAD_DOWN,
	"vehicle_camera": JOY_BUTTON_RIGHT_STICK, "rob": JOY_BUTTON_B,
	"pause": JOY_BUTTON_START
}

var settings := DEFAULT_SETTINGS.duplicate()
var keys := KEY_DEFAULTS.duplicate()
var pending_save: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings.merge(SettingsManager.DEFAULTS)
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		for setting: String in settings:
			settings[setting] = config.get_value("settings", setting, settings[setting])
		for action: String in KEY_DEFAULTS:
			keys[action] = int(config.get_value("keyboard", action, KEY_DEFAULTS[action]))
		if int(config.get_value("keyboard", "throw_binding_version", 0)) < 1:
			if int(keys.throw_item) == KEY_H:
				keys.throw_item = KEY_G
			if int(keys.use_item) == KEY_G:
				keys.use_item = KEY_Y
		if int(config.get_value("display", "version", 0)) < DISPLAY_SETTINGS_VERSION:
			_reset_display_defaults()
			persist_settings()
	if OS.has_feature("mobile") and not FileAccess.file_exists(SETTINGS_PATH):
		settings.quality = 0
		settings.greenery_density = 0.42
	_setup_input()
	apply_settings()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F10:
		_reset_display_defaults()
		apply_settings()
		persist_settings()
		get_viewport().set_input_as_handled()


func _reset_display_defaults() -> void:
	for setting: String in ["fullscreen", "resolution"]:
		settings[setting] = DEFAULT_SETTINGS[setting]
	settings.merge(SettingsManager.DEFAULTS, true)


func _setup_input() -> void:
	for action: String in KEY_DEFAULTS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.22)
		InputMap.action_erase_events(action)
		var key := InputEventKey.new()
		key.physical_keycode = keys[action]
		InputMap.action_add_event(action, key)
		if PAD_BUTTONS.has(action):
			var button := InputEventJoypadButton.new()
			button.button_index = PAD_BUTTONS[action]
			InputMap.action_add_event(action, button)
	for mapping: Array in [
		["move_forward", JOY_AXIS_LEFT_Y, -1.0], ["move_back", JOY_AXIS_LEFT_Y, 1.0],
		["move_left", JOY_AXIS_LEFT_X, -1.0], ["move_right", JOY_AXIS_LEFT_X, 1.0]
	]:
		var stick := InputEventJoypadMotion.new()
		stick.axis = mapping[1]
		stick.axis_value = mapping[2]
		InputMap.action_add_event(mapping[0], stick)
	for index in 8:
		var action := "slot_%d" % (index + 1)
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key := InputEventKey.new()
			key.physical_keycode = KEY_1 + index
			InputMap.action_add_event(action, key)
	if not InputMap.has_action("equipment_use"):
		InputMap.add_action("equipment_use")
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("equipment_use", mouse)
		var shoulder := InputEventJoypadButton.new()
		shoulder.button_index = JOY_BUTTON_X
		InputMap.action_add_event("equipment_use", shoulder)
		var trigger := InputEventJoypadMotion.new()
		trigger.axis = JOY_AXIS_TRIGGER_RIGHT
		trigger.axis_value = 1.0
		InputMap.action_add_event("equipment_use", trigger)


func apply_settings() -> void:
	if OS.has_feature("mobile"):
		Engine.max_fps = 30 if SettingsManager.mobile_battery_saver() else 60
	for label: String in ["Master", "Radio", "Music", "SFX"]:
		var bus := AudioServer.get_bus_index(label)
		var volume := clampf(float(settings[label.to_lower()]), 0.0, 1.0)
		AudioServer.set_bus_mute(bus, volume <= 0.001)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.001)))
	AudioServer.set_bus_effect_enabled(0, 0, int(settings.sound_quality) == 0)
	SettingsManager.apply_viewport(get_viewport(), settings)
	settings_changed.emit()
	_apply_window.call_deferred()


func _apply_window() -> void:
	if OS.has_feature("mobile"):
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND if int(settings.mobile_display) == 1 else Window.CONTENT_SCALE_ASPECT_KEEP
		return
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	if mode == DisplayServer.WINDOW_MODE_WINDOWED:
		var resolution: Vector2i = RESOLUTIONS[clampi(int(settings.resolution), 0, RESOLUTIONS.size() - 1)]
		var area := DisplayServer.screen_get_usable_rect()
		var window_size := resolution.min(area.size - Vector2i(24, 72))
		if DisplayServer.window_get_size() != window_size:
			DisplayServer.window_set_size(window_size)
			DisplayServer.window_set_position(area.position + (area.size - window_size) / 2)


func persist_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "version", DISPLAY_SETTINGS_VERSION)
	config.set_value("keyboard", "throw_binding_version", 1)
	for setting: String in settings:
		config.set_value("settings", setting, settings[setting])
	for action: String in keys:
		config.set_value("keyboard", action, keys[action])
	if config.save(SETTINGS_PATH) != OK:
		push_warning("Could not write game settings.")


func set_key(action: String, key: int) -> bool:
	if keys.find_key(key) not in [null, action] or key == KEY_F10 or (key >= KEY_1 and key <= KEY_8):
		return false
	keys[action] = key
	_setup_input()
	persist_settings()
	return true


func key_label(action: String) -> String:
	if not keys.has(action):
		return ""
	if int(keys[action]) == KEY_QUOTELEFT:
		return "`"
	return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(keys[action])) if DisplayServer.get_name() != "headless" else OS.get_keycode_string(keys[action])


func start_game(saved_game: Dictionary = {}) -> void:
	pending_save = saved_game
	go_to(LOADING)


func go_to(path: String) -> void:
	if path == MAIN and (SessionManager.active or SessionManager.connecting):
		SessionManager.leave()
	get_tree().paused = false
	Engine.time_scale = 1.0
	var result := get_tree().change_scene_to_file(path)
	if result != OK:
		push_error("Could not open scene %s (%s)." % [path, error_string(result)])


func read_json(path: String, fallback: Variant) -> Variant:
	if not FileAccess.file_exists(path):
		return fallback
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if value == null or typeof(value) != typeof(fallback):
		push_warning("Invalid data in %s." % path)
		return fallback
	return value
