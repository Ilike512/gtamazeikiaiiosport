extends Control

signal dismissed
signal cheats_requested

const Style = preload("res://scripts/ui/Style.gd")

var _panel: PanelContainer
var _caption: Label
var _messages: RichTextLabel
var _input_box: LineEdit
var _activity_timer: Timer


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	position = Vector2(28, 90)
	_panel = PanelContainer.new()
	_panel.mouse_filter = MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size.x = 422
	_panel.add_theme_stylebox_override("panel", Style.box(Color("#111724ec"), Style.TEAL, 3))
	add_child(_panel)
	var column := Style.stack(_panel, 6)
	column.mouse_filter = MOUSE_FILTER_IGNORE
	_caption = Style.label("", 14, Style.TEAL, true)
	column.add_child(_caption)
	_messages = RichTextLabel.new()
	_messages.custom_minimum_size.x = 397
	_messages.fit_content = true
	_messages.scroll_active = false
	_messages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_messages.add_theme_font_override("normal_font", Style.font(false))
	_messages.add_theme_font_size_override("normal_font_size", 15)
	_messages.add_theme_color_override("default_color", Style.TEXT)
	column.add_child(_messages)
	_input_box = LineEdit.new()
	_input_box.max_length = 180
	_input_box.placeholder_text = "Type a message   ·   Enter to send   ·   Esc to close"
	_input_box.custom_minimum_size.y = 36
	_input_box.add_theme_stylebox_override("normal", Style.box(Style.PANEL))
	_input_box.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, Style.TEAL))
	_input_box.text_submitted.connect(_send)
	column.add_child(_input_box)
	_input_box.hide()
	_activity_timer = Timer.new()
	_activity_timer.one_shot = true
	_activity_timer.timeout.connect(_hide_history)
	add_child(_activity_timer)
	SessionManager.chat_received.connect(_new_message)
	SessionManager.roster_changed.connect(_refresh_caption)
	_refresh_caption()
	_refresh_history(true)
	_activity_timer.start(8.0)


func open_editor() -> void:
	_panel.show()
	_refresh_history(true)
	_input_box.show()
	_input_box.grab_focus()


func close_editor() -> void:
	_input_box.release_focus()
	_input_box.hide()
	_refresh_caption()
	_activity_timer.start(6.0)


func _send(value: String) -> void:
	var message := value.strip_edges()
	if message.nocasecmp_to("/cheats") == 0:
		_input_box.clear()
		cheats_requested.emit()
		return
	if message.is_empty():
		dismissed.emit()
		return
	if SessionManager.send_chat(value):
		_input_box.clear()
		dismissed.emit()
	else:
		_caption.text = "CHAT  ·  WAIT A MOMENT BEFORE SENDING AGAIN"


func _new_message(_username: String, _message: String) -> void:
	_panel.show()
	_refresh_history(true)
	_activity_timer.start(7.0)


func _hide_history() -> void:
	if not _input_box.visible:
		_refresh_history(false)


func _refresh_caption() -> void:
	_caption.text = "SESSION CHAT  ·  %d PLAYERS  ·  %s TO TYPE" % [
		maxi(1, SessionManager.roster.size()), GameManager.key_label("chat")]


func _refresh_history(show_recent: bool) -> void:
	_messages.clear()
	var history := SessionManager.history
	_messages.visible = show_recent and not history.is_empty()
	if not _messages.visible:
		return
	var first := maxi(0, history.size() - 5)
	for index in range(first, history.size()):
		if index > first:
			_messages.newline()
		var entry: Array = history[index]
		var alert := entry.size() > 2 and bool(entry[2])
		_messages.push_color(Style.RED if alert else Style.TEXT)
		_messages.add_text(str(entry[1]) if str(entry[0]).is_empty() else "%s: %s" % [entry[0], entry[1]])
		_messages.pop()

