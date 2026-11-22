extends Control

signal resume_requested
signal save_requested

const Style = preload("res://scripts/ui/Style.gd")
const SETTINGS = preload("res://scenes/menus/SettingsMenu.tscn")

var _frame: PanelContainer
var _resume: Button
var _settings: Control
var _save_status: Label
var _map: Control
var _previous_disable_3d := false
var _internet_button: Button
var _internet_status := ""


func _ready() -> void:
	_previous_disable_3d = get_viewport().disable_3d
	add_child(Style.layer(Color("#101420c8")))
	_frame = PanelContainer.new()
	_frame.position = Vector2(0, 655)
	_frame.size = Vector2(1280, 65)
	_frame.add_theme_stylebox_override("panel", Style.box(Style.INK, Style.AMBER, 4))
	add_child(_frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_frame.add_child(row)
	var title := Style.label("SESSION" if SessionManager.active else "PAUSED", 25, Style.AMBER, true)
	title.custom_minimum_size.x = 146
	row.add_child(title)
	_resume = _button(row, "RESUME", func() -> void: resume_requested.emit())
	_button(row, "SETTINGS", _show_settings)
	if not SessionManager.active:
		_button(row, "SAVE", func() -> void: save_requested.emit())
	_button(row, "LEAVE SESSION" if SessionManager.active else "MAIN MENU", func() -> void: GameManager.go_to(GameManager.MAIN))
	if SessionManager.is_hosting():
		_button(row, "LAN INVITE", _copy_invite)
		_internet_button = _button(row, "INTERNET INVITE", _internet_invite)
	_button(row, "QUIT", func() -> void: get_tree().quit())
	_save_status = Style.label("", 15, Style.MUTED)
	_save_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_save_status)
	_resume.grab_focus()


func _process(_delta: float) -> void:
	if _internet_button == null or _internet_status == SessionManager.internet.status:
		return
	_internet_status = SessionManager.internet.status
	_save_status.text = _internet_status
	_internet_button.text = "COPY ONLINE INVITE" if not SessionManager.internet.code.is_empty() else "INTERNET INVITE"


func _internet_invite() -> void:
	if SessionManager.internet.code.is_empty():
		SessionManager.internet.start(SessionManager.host_port)
	else:
		DisplayServer.clipboard_set(SessionManager.internet.code)
		_save_status.text = "Internet invite copied."


func _copy_invite() -> void:
	var invite := SessionManager.invite()
	DisplayServer.clipboard_set(invite)
	_save_status.text = "Invite copied  ·  " + invite


func attach_map(map: Control) -> void:
	_map = map
	_map.visibility_changed.connect(_update_map_rendering)
	add_child(_map)
	_update_map_rendering()
	move_child(_map, _frame.get_index())
	_map.position = Vector2.ZERO
	_map.size = Vector2(1280, 655)


func _update_map_rendering() -> void:
	get_viewport().disable_3d = _previous_disable_3d or _map.is_visible_in_tree()


func _exit_tree() -> void:
	get_viewport().disable_3d = _previous_disable_3d


func request_back() -> void:
	if is_instance_valid(_settings):
		_settings.close()
	else:
		resume_requested.emit()


func show_save_result(success: bool) -> void:
	_save_status.text = "Game saved." if success else "Save failed. Try again."


func _button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Style.button(text, 145)
	parent.add_child(button)
	button.pressed.connect(callback)
	return button


func _show_settings() -> void:
	_frame.hide()
	if _map != null:
		_map.hide()
	_settings = SETTINGS.instantiate()
	add_child(_settings)
	_settings.closed.connect(func() -> void:
		_settings = null
		_frame.show()
		if _map != null:
			_map.show()
		_resume.grab_focus()
	)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		request_back()
