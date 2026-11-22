extends Control

signal closed

const Style = preload("res://scripts/ui/Style.gd")

var _contents: VBoxContainer
var _footer: Label
var _listen := ""
var _tab := 0
var _page_buttons: Array[Button] = []
var _closed := false


func _ready() -> void:
	add_child(Style.layer(Color("#0d101ce8")))
	var frame := PanelContainer.new()
	frame.position = Vector2(223, 34)
	frame.size = Vector2(834, 652)
	frame.add_theme_stylebox_override("panel", Style.box(Style.INK, Style.AMBER, 4))
	add_child(frame)
	var column := Style.stack(frame, 13)
	column.add_child(Style.label("SETTINGS", 42, Style.TEXT, true))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 9)
	column.add_child(tabs)
	for index in 4:
		var titles := ["AUDIO", "DISPLAY", "CONTROLS", "GRAPHICS"]
		var tab_button := Style.button(titles[index], 175)
		tabs.add_child(tab_button)
		tab_button.pressed.connect(_select_tab.bind(index))
		_page_buttons.append(tab_button)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_contents = Style.stack(scroll, 8)
	_contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_footer = Style.label("", 16, Style.AMBER)
	column.add_child(_footer)
	var back := Style.button("BACK")
	column.add_child(back)
	back.pressed.connect(close)
	_select_tab(0)
	_page_buttons[0].grab_focus()


func close() -> void:
	if _closed:
		return
	_closed = true
	GameManager.persist_settings()
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if _closed or event is not InputEventKey or not event.pressed or event.echo:
		return
	if not _listen.is_empty():
		get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_ESCAPE:
			_listen = ""
			_footer.text = "Binding cancelled."
		elif GameManager.set_key(_listen, event.physical_keycode):
			_listen = ""
			_select_tab(2)
			_footer.text = "Binding saved."
			_page_buttons[2].grab_focus()
		else:
			_footer.text = "This key is in use. Try another key or press Escape to cancel."
	elif event.is_action_pressed("pause") or event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


func _select_tab(index: int) -> void:
	_tab = index
	_listen = ""
	_footer.text = ""
	for child: Node in _contents.get_children():
		_contents.remove_child(child)
		child.queue_free()
	for tab_index in _page_buttons.size():
		_page_buttons[tab_index].modulate = Style.AMBER if tab_index == index else Color.WHITE
	match _tab:
		0:
			_slider("Master volume", "master", 0.0, 1.0, 0.05)
			_slider("Radio volume", "radio", 0.0, 1.0, 0.05)
			_slider("Loading music", "music", 0.0, 1.0, 0.05)
			_slider("Sound effects", "sfx", 0.0, 1.0, 0.05)
			_options("Radio DJ and adverts", "radio_interludes", ["Off", "On"])
			_options("Sound quality", "sound_quality", ["Low", "High"])
		1:
			if OS.has_feature("mobile"):
				_options("Mobile display", "mobile_display", ["16:9", "Fill screen"])
				_options("Mobile power", "mobile_power", ["Battery saver · 30 FPS", "Performance · 60 FPS"])
			else:
				_options("Window mode", "fullscreen", ["Windowed", "Fullscreen"])
				_options("Window resolution", "resolution", ["960 × 540", "1280 × 720", "1600 × 900", "1920 × 1080"])
			_options("Injury effects", "injury_effects", ["Off", "Reduced", "Full"])
			_options("Autosave", "autosave", ["Off", "On"])
		2:
			_slider("Mouse sensitivity", "sensitivity", 0.25, 2.5, 0.05)
			_slider("Controller look sensitivity", "controller_look", 0.35, 2.5, 0.05)
			_slider("Mobile joystick size", "touch_stick_size", 0.65, 1.45, 0.05)
			for action: String in GameManager.ACTION_NAMES:
				var row := _row(GameManager.ACTION_NAMES[action])
				var button := Style.button(GameManager.key_label(action), 250)
				row.add_child(button)
				button.pressed.connect(func() -> void:
					_listen = action
					_footer.text = "Press a key for %s. Escape cancels." % GameManager.ACTION_NAMES[action]
				)


		3:
			var advanced := SettingsManager.is_forward_plus()
			_options("Graphics quality", "quality", ["Low", "Medium", "High", "Ultra"])
			_quality_scale()
			_options("Upscaling", "upscaler", ["Preset", "Bilinear", "FSR 1", "FSR 2"], advanced)
			_options("Sun shadows", "shadows", ["Preset", "Off", "Medium", "High", "Ultra"])
			_slider("Shadow softness", "shadow_softness", 0.3, 2.0, 0.05)
			_options("MSAA", "msaa", ["Preset", "Off", "2×", "4×"])
			_options("Surface detail", "surface_detail", ["Preset", "Low", "Medium", "High"])
			_options("Street detail", "street_detail", ["Preset", "Off", "Low", "High"])
			_options("Terrain and façade textures", "world_textures", ["Off", "Low", "Full"])
			_slider("View distance (km)", "view_distance_km", 0.30, 2.5, 0.05)
			_slider("Greenery density", "greenery_density", 0.20, 1.0, 0.05)
			var toggles: Array[String] = ["Preset", "Off", "On"]
			_options("Ambient occlusion", "ambient_occlusion", toggles)
			_options("Screen-space reflections", "reflections", toggles, advanced)
			_options("Dynamic GI (SDFGI)", "global_illumination", toggles, advanced)
			_options("Volumetric fog", "volume_fog", toggles, advanced)
			_options("Bloom", "bloom", toggles)
			_options("Weather", "weather", ["Automatic", "Clear", "Rain", "Snow"])
			_slider("Bloom strength", "bloom_strength", 0.0, 1.5, 0.05)
			_slider("Distance fog density", "fog_density", 0.0, 0.012, 0.0001)
			_slider("Ground fog density", "fog_height_density", 0.0, 0.10, 0.001)
			if not advanced:
				_contents.add_child(Style.label("FSR, SSR, SDFGI and volumetric fog require Forward+.", 15, Style.MUTED))


func _row(title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 43
	row.add_theme_constant_override("separation", 12)
	_contents.add_child(row)
	var text := Style.label(title, 20)
	text.custom_minimum_size.x = 290
	row.add_child(text)
	return row


func _quality_scale() -> void:
	var row := _row("3D resolution scale")
	var slider := HSlider.new()
	slider.min_value = 0.50
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size.x = 195
	var override := float(GameManager.settings.render_scale)
	var preset: float = SettingsManager.PRESET_SCALES[SettingsManager.quality(GameManager.settings)]
	slider.value = override if override > 0.0 else preset
	row.add_child(slider)
	var reading := Style.label("%d%%" % roundi(slider.value * 100.0), 16, Style.MUTED)
	row.add_child(reading)
	var reset := Style.button("PRESET", 86)
	row.add_child(reset)
	slider.value_changed.connect(func(value: float) -> void:
		reading.text = "%d%%" % roundi(value * 100.0)
		GameManager.settings.render_scale = value
		GameManager.apply_settings()
		GameManager.persist_settings()
	)
	reset.pressed.connect(func() -> void:
		var value: float = SettingsManager.PRESET_SCALES[SettingsManager.quality(GameManager.settings)]
		slider.set_value_no_signal(value)
		reading.text = "%d%%" % roundi(value * 100.0)
		GameManager.settings.render_scale = 0.0
		GameManager.apply_settings()
		GameManager.persist_settings()
	)


func _slider(title: String, key: String, low: float, high: float, step: float) -> void:
	var row := _row(title)
	var slider := HSlider.new()
	slider.custom_minimum_size.x = 252
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = float(GameManager.settings[key])
	row.add_child(slider)
	var format := "%.4f" if step < 0.001 else ("%.3f" if step < 0.01 else "%.2f")
	var reading := Style.label(format % slider.value, 17, Style.MUTED)
	row.add_child(reading)
	slider.value_changed.connect(func(value: float) -> void:
		reading.text = format % value
		GameManager.settings[key] = value
		GameManager.apply_settings()
		GameManager.persist_settings()
	)


func _options(title: String, key: String, labels: Array[String], supported := true) -> void:
	var row := _row(title)
	var menu := OptionButton.new()
	menu.custom_minimum_size = Vector2(252, 38)
	menu.add_theme_font_override("font", Style.font(false))
	menu.add_theme_font_size_override("font_size", 18)
	menu.add_theme_stylebox_override("normal", Style.box())
	menu.add_theme_stylebox_override("hover", Style.box(Style.PANEL, Style.AMBER))
	for text: String in labels:
		menu.add_item(text)
	menu.select(clampi(int(GameManager.settings[key]), 0, labels.size() - 1))
	menu.disabled = not supported
	row.add_child(menu)
	menu.item_selected.connect(func(index: int) -> void:
		GameManager.settings[key] = (index == 1) if key in ["fullscreen", "autosave", "radio_interludes"] else index
		GameManager.apply_settings()
		if key == "quality":
			_select_tab.call_deferred(3)
		GameManager.persist_settings()
	)
