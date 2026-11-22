extends Control

signal closed

const Style = preload("res://scripts/ui/Style.gd")

var _column: VBoxContainer
var _heading: Label
var _form: VBoxContainer
var _username: LineEdit
var _address: LineEdit
var _password: LineEdit
var _port: SpinBox
var _cheats: OptionButton
var _status: Label
var _submit: Button
const RoomDiscovery = preload("res://scripts/managers/RoomDiscovery.gd")

var _hosting := false
var _saved_username := ""
var _saved_address := ""
var _nearby: OptionButton
var _room_signature := ""
var _next_discovery_refresh := 0


func _ready() -> void:
	add_child(Style.layer(Color("#111724d9")))
	var center := CenterContainer.new()
	add_child(center)
	Style.fill(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 550
	panel.add_theme_stylebox_override("panel", Style.box(Style.INK, Style.AMBER, 4))
	center.add_child(panel)
	_column = Style.stack(panel, 11)
	_heading = Style.label("MULTIPLAYER", 34, Style.AMBER, true)
	_column.add_child(_heading)
	SessionManager.connected.connect(_start_world)
	SessionManager.ended.connect(_connection_ended)
	SessionManager.version_warning.connect(_confirm_version)
	_show_choices()


func _make_form(title: String) -> void:
	SessionManager.discovery.stop_scan()
	_nearby = null
	_room_signature = ""
	_heading.text = title
	if is_instance_valid(_form):
		_column.remove_child(_form)
		_form.queue_free()
	_form = Style.stack(_column, 8)


func _show_choices() -> void:
	if SessionManager.connecting:
		SessionManager.leave()
	_make_form("MULTIPLAYER")
	_form.add_child(Style.label("Explore Mažeikiai with up to eight players.", 16, Style.MUTED))
	var host := _button("HOST SESSION", _show_connection.bind(true))
	_button("JOIN SESSION", _show_connection.bind(false))
	_button("BACK", _close)
	host.grab_focus()


func _show_connection(hosting: bool) -> void:
	_hosting = hosting
	_make_form("HOST SESSION" if _hosting else "JOIN SESSION")
	_username = _field("Username", "Enter the name other players will see", 20)
	_username.text = _saved_username
	var nearby_supported := RoomDiscovery.supports_broadcast()
	if not _hosting:
		if nearby_supported:
			_form.add_child(Style.label("Nearby rooms", 14, Style.TEAL, true))
			_nearby = OptionButton.new()
			_nearby.custom_minimum_size.y = 36
			_nearby.item_selected.connect(_select_nearby)
			_form.add_child(_nearby)
			_nearby.add_item("Searching your Wi-Fi or local network…")
			SessionManager.discovery.begin_scan()
		var address_label := "Or paste an invite / enter the host address" if nearby_supported else "Paste an invite or enter the host address"
		_address = _field(address_label, "mazeikiai://192.168.1.24:31940", 253)
		_address.text = _saved_address
		_address.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_URL
	_password = _field("Room password (optional)", "Leave empty for a room without a password", 64)
	_password.secret = true
	_form.add_child(Style.label("UDP port", 14, Style.MUTED))
	_port = SpinBox.new()
	_port.min_value = 1
	_port.max_value = 65535
	_port.value = SessionManager.PORT
	_form.add_child(_port)
	if hosting:
		_form.add_child(Style.label("Cheats", 14, Style.MUTED))
		_cheats = OptionButton.new()
		for option in ["Everyone", "Host only", "Disabled"]:
			_cheats.add_item(option)
		_form.add_child(_cheats)
	var hint := "Pick a nearby room or paste an invite."
	if _hosting:
		hint = "Friends on your Wi-Fi can find your room by name." if nearby_supported else "Share your LAN invite from the pause menu after hosting."
	elif not nearby_supported:
		hint = "Allow Local Network access to join over Wi-Fi."
	_status = Style.label(hint, 14, Style.MUTED)
	_status.custom_minimum_size = Vector2(510, 32)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_form.add_child(_status)
	_submit = _button("START HOSTING" if _hosting else "CONNECT", _submit_connection)
	_button("BACK", _show_choices)
	_username.grab_focus()
	_username.select_all()


func _field(label: String, placeholder: String, limit: int) -> LineEdit:
	_form.add_child(Style.label(label, 14, Style.MUTED))
	var field := LineEdit.new()
	field.max_length = limit
	field.placeholder_text = placeholder
	field.custom_minimum_size.y = 36
	field.add_theme_stylebox_override("normal", Style.box(Style.PANEL))
	field.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, Style.AMBER))
	field.text_submitted.connect(func(_value: String) -> void: _submit_connection())
	_form.add_child(field)
	return field


func _button(caption: String, action: Callable) -> Button:
	var button := Style.button(caption)
	button.pressed.connect(action)
	_form.add_child(button)
	return button


func _submit_connection() -> void:
	if _submit.disabled:
		return
	_saved_username = _username.text.strip_edges()
	if not SessionManager.valid_name(_saved_username):
		_status.text = "Enter a username with 1–20 characters."
		_username.grab_focus()
		return
	var error := ""
	if _hosting:
		error = SessionManager.host_room(_saved_username, _password.text, int(_port.value), false, _cheats.selected)
	else:
		_saved_address = _address.text.strip_edges()
		var endpoint: Dictionary = SessionManager.invitation_endpoint(_saved_address, int(_port.value))
		error = SessionManager.join_room(_saved_username, endpoint.address, _password.text, endpoint.port)
		if error.is_empty():
			_status.text = "Connecting to %s…" % _saved_address
			_submit.disabled = true
	if not error.is_empty():
		_status.text = error


func _process(_delta: float) -> void:
	if not is_instance_valid(_nearby) or Time.get_ticks_msec() < _next_discovery_refresh:
		return
	_next_discovery_refresh = Time.get_ticks_msec() + 450
	var rooms: Array = SessionManager.discovery.rooms()
	var signature := PackedStringArray()
	for room: Dictionary in rooms:
		signature.append("%s:%s:%s" % [room.address, room.port, room.name])
	var joined_signature := "|".join(signature)
	if joined_signature == _room_signature:
		return
	_room_signature = joined_signature
	_nearby.clear()
	_nearby.add_item("Choose a nearby room" if not rooms.is_empty() else "Searching your Wi-Fi or local network…")
	for room: Dictionary in rooms:
		_nearby.add_item("%s  ·  %s%s" % [room.name, room.address, "  ·  Locked" if room.locked else ""])
		_nearby.set_item_metadata(_nearby.item_count - 1, room)
	_nearby.select(0)


func _select_nearby(index: int) -> void:
	if index == 0:
		return
	var room: Dictionary = _nearby.get_item_metadata(index)
	_address.text = "%s:%d" % [room.address, room.port]
	if room.locked:
		_password.grab_focus()
	elif _username.text.strip_edges().is_empty():
		_username.grab_focus()
	else:
		_submit.grab_focus()


func _confirm_version(server_build: int) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Newer server"
	dialog.dialog_text = "This server runs build %d. You have build %d. Continue anyway?" % [server_build, SessionManager.GAME_BUILD]
	dialog.ok_button_text = "Continue"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		SessionManager.respond_to_version(true)
		dialog.queue_free())
	dialog.canceled.connect(func() -> void:
		SessionManager.respond_to_version(false)
		dialog.queue_free())
	dialog.popup_centered()


func _connection_ended(reason: String) -> void:
	if is_instance_valid(_submit) and _submit.is_inside_tree():
		_status.text = reason
		_submit.disabled = false


func _start_world() -> void:
	SessionManager.discovery.stop_scan()
	GameManager.start_game()


func _close() -> void:
	SessionManager.discovery.stop_scan()
	if SessionManager.connecting:
		SessionManager.leave()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause", false):
		if _heading.text == "MULTIPLAYER":
			_close()
		else:
			if SessionManager.connecting:
				SessionManager.leave()
			_show_choices()
		get_viewport().set_input_as_handled()

