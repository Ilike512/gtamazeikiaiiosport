extends Control

const Style = preload("res://scripts/ui/Style.gd")
const SETTINGS = preload("res://scenes/menus/SettingsMenu.tscn")
const COVER := "res://assets/brand/jo.jpg"
const CommunityLink = preload("res://scripts/ui/CommunityLink.gd")
const MultiplayerMenu = preload("res://scripts/ui/MultiplayerMenu.gd")

var _menu: VBoxContainer
var _restore_focus: Control
var _folder_feedback: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	RadioManager.end_session()
	AssetShelf.ensure_overrides()
	Style.texture(self, AssetShelf.image("menu", COVER))
	add_child(Style.layer(Color("#0b102043")))
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("#111522fa"), Color("#10142200")])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_to = Vector2(0.70, 0)
	var shade := Style.texture(self, texture)
	shade.stretch_mode = TextureRect.STRETCH_SCALE

	Style.rect(self, Rect2(67, 71, 5, 45), Style.AMBER)
	var top := Style.label("GTA", 34, Style.AMBER, true)
	top.position = Vector2(88, 65)
	add_child(top)
	var title := Style.label("MAŽEIKIAI", 88, Style.TEXT, true)
	title.position = Vector2(68, 107)
	add_child(title)
	var subtitle := Style.label("LITHUANIA  /  BETA", 15, Style.MUTED, true)
	subtitle.position = Vector2(73, 215)
	add_child(subtitle)
	Style.rect(self, Rect2(72, 252, 355, 1), Style.EDGE)

	_menu = Style.stack(self, 6)
	_menu.position = Vector2(72, 265)
	var play := _add_button("PLAY", _confirm_new_game)
	var resume := _add_button("CONTINUE", _choose_save)
	resume.disabled = SaveManager.load_slot(false).is_empty() and SaveManager.load_slot(true).is_empty()
	_add_button("MULTIPLAYER", _show_multiplayer)
	_add_button("SETTINGS", _show_settings)
	_add_button("RADIO MUSIC", _open_folder.bind("Radio Music"))
	_add_button("CUSTOM ASSETS", _open_folder.bind("Custom Assets"))
	_add_button("CREDITS", _show_credits)
	_add_button("QUIT", func() -> void: get_tree().quit())

	var notice := SessionManager.menu_notice
	SessionManager.menu_notice = ""
	_folder_feedback = Style.label(notice if not notice.is_empty() else "", 13, Style.MUTED, true)
	_folder_feedback.position = Vector2(72, 668)
	add_child(_folder_feedback)
	var emblem := CommunityLink.new()
	emblem.position = Vector2(1135, 591)
	emblem.size = Vector2(72, 72)
	add_child(emblem)
	var map_credit := Style.label("MAP DATA © OPENSTREETMAP CONTRIBUTORS", 11, Style.MUTED, true)
	map_credit.position = Vector2(960, 677)
	add_child(map_credit)
	play.grab_focus()


func _add_button(label: String, callback: Callable) -> Button:
	var button := Style.button(label, 355)
	_menu.add_child(button)
	button.pressed.connect(callback)
	return button


func _open_folder(name: String) -> void:
	if not AssetShelf.open_game_folder(name):
		_folder_feedback.text = "Open the %s folder next to the game project." % name


func _confirm_new_game() -> void:
	var overlay := _save_dialog("NEW GAME")
	var column: VBoxContainer = overlay.get_meta("column")
	var question := Style.label("Are you sure you want to rewrite and make a new save file?\n(This will delete your auto-save.)", 19, Style.TEXT)
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(question)
	column.add_child(Style.label("Your manual save stays available under Continue.", 14, Style.MUTED))
	var error := Style.label("", 14, Style.AMBER)
	column.add_child(error)
	var yes := Style.button("START NEW GAME")
	column.add_child(yes)
	yes.pressed.connect(func() -> void:
		if SaveManager.clear_autosave():
			GameManager.start_game()
		else:
			error.text = "The auto-save could not be removed. Try again."
	)
	_dialog_back(overlay, column, "CANCEL").grab_focus()


func _choose_save() -> void:
	var overlay := _save_dialog("CHOOSE A SAVE")
	var column: VBoxContainer = overlay.get_meta("column")
	var first: Button
	for automatic: bool in [true, false]:
		var state := SaveManager.load_slot(automatic)
		var label_text := "AUTO-SAVE" if automatic else "MANUAL SAVE"
		if state.is_empty():
			label_text += "  ·  EMPTY"
		else:
			var utc := int(state.get("saved_at", 0))
			var local := Time.get_datetime_string_from_unix_time(utc + int(Time.get_time_zone_from_system().bias) * 60, true)
			label_text += "  ·  " + local.substr(0, 16)
		var button := Style.button(label_text)
		button.disabled = state.is_empty()
		column.add_child(button)
		button.pressed.connect(func() -> void:
			var current := SaveManager.load_slot(automatic)
			if not current.is_empty():
				GameManager.start_game(current)
		)
		if first == null and not button.disabled:
			first = button
	var back := _dialog_back(overlay, column, "BACK")
	(first if first != null else back).grab_focus()


func _save_dialog(title: String) -> Control:
	_restore_focus = get_viewport().gui_get_focus_owner()
	_menu.hide()
	var overlay := Style.layer(Color("#111724c8"))
	add_child(overlay)
	var middle := CenterContainer.new()
	overlay.add_child(middle)
	Style.fill(middle)
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 545
	card.add_theme_stylebox_override("panel", Style.box(Style.INK, Style.AMBER, 3))
	middle.add_child(card)
	var column := Style.stack(card, 12)
	column.add_child(Style.label(title, 32, Style.AMBER, true))
	overlay.set_meta("column", column)
	return overlay


func _dialog_back(overlay: Control, column: VBoxContainer, caption: String) -> Button:
	var back := Style.button(caption)
	column.add_child(back)
	back.pressed.connect(func() -> void:
		overlay.queue_free()
		_return_from_overlay()
	)
	return back


func _show_multiplayer() -> void:
	_restore_focus = get_viewport().gui_get_focus_owner()
	_menu.hide()
	var menu := MultiplayerMenu.new()
	menu.closed.connect(_return_from_overlay)
	add_child(menu)


func _show_settings() -> void:
	_restore_focus = get_viewport().gui_get_focus_owner()
	_menu.hide()
	var settings := SETTINGS.instantiate()
	add_child(settings)
	settings.closed.connect(_return_from_overlay)


func _show_credits() -> void:
	_restore_focus = get_viewport().gui_get_focus_owner()
	_menu.hide()
	var overlay := Style.layer()
	add_child(overlay)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", Style.box(Style.INK, Style.AMBER, 4))
	frame.position = Vector2(280, 73)
	frame.size = Vector2(720, 574)
	overlay.add_child(frame)
	var column := Style.stack(frame, 10)
	column.add_child(Style.label("CREDITS", 40, Style.AMBER, true))
	column.add_child(Style.label("GTA MAŽEIKIAI", 25, Style.TEXT, true))
	column.add_child(Style.label("CREATOR/IDEA: NOTUZI", 18))
	column.add_child(Style.label("CHARACTERS: NOTUZI/BLITZ", 18))
	column.add_child(Style.label("ARTWORK: VECENNT", 18))
	column.add_child(Style.label("MODEL SOURCES", 16, Style.AMBER, true))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 212
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	var sources := Style.stack(scroll, 7)
	for credit: Dictionary in GameManager.read_json("res://data/model_credits.json", []):
		var source := LinkButton.new()
		source.text = str(credit.name)
		source.uri = str(credit.get("url", ""))
		source.add_theme_font_size_override("font_size", 16)
		source.add_theme_color_override("font_color", Style.TEXT)
		source.add_theme_color_override("font_hover_color", Style.AMBER)
		if source.uri.is_empty():
			source.disabled = true
		sources.add_child(source)
	var copyright := Style.button("MAP DATA © OPENSTREETMAP CONTRIBUTORS  /  ODbL")
	copyright.pressed.connect(func() -> void: OS.shell_open("https://www.openstreetmap.org/copyright"))
	column.add_child(copyright)
	var back := Style.button("BACK")
	back.pressed.connect(func() -> void:
		overlay.queue_free()
		_return_from_overlay()
	)
	column.add_child(back)
	back.grab_focus()


func _return_from_overlay() -> void:
	_menu.show()
	if is_instance_valid(_restore_focus):
		_restore_focus.grab_focus()
