extends Control

const Style = preload("res://scripts/ui/Style.gd")
const SLIDE_FADE := 0.65
const BLACK_HOLD := 0.10
const SLIDE_HOLD := 5.0
const MIN_SLIDES := 2
const WORLD_STAGE_TIMEOUT_MS := 45000

var _slides: Array = []
var _slide := -1
var _slide_offset := 0
var _display_log: Label
var _log_lines := PackedStringArray()
var _world_ready := false
var _presentation: Control
var _background: TextureRect
var _blackout: ColorRect
var _slide_hold_started := 0
var _slide_transition: Tween
var _caption: Label
var _caption_detail: Label
var _fun_fact: Label
var _facts: Array = []
var _last_fact := ""
var _status: Label
var _progress: ProgressBar
var _music: AudioStreamPlayer
var _finished := false
var _request_pending := false
var _world_step := "STARTING CITY SETUP"
var _world_step_deadline := 0
var _loaded_world: PackedScene
var _world: Node3D
var _quit_requested := false
var _previous_auto_quit := true
var _slides_shown := 0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if SessionManager.active:
		SessionManager.ended.connect(_return_after_disconnect)
	_previous_auto_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	get_window().close_requested.connect(_close_window)
	_slides = GameManager.read_json("res://data/loading_art.json", [])
	_facts = GameManager.read_json("res://data/loading_facts.json", [])
	_slide_offset = randi_range(0, maxi(0, mini(2, _slides.size() - 1)))
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 20
	add_child(canvas_layer)
	_presentation = Control.new()
	canvas_layer.add_child(_presentation)
	Style.fill(_presentation)
	var matte := Style.layer(Color("#101420"))
	_presentation.add_child(matte)
	_background = Style.texture(_presentation, null)
	_presentation.add_child(Style.layer(Color("#0d112555")))
	Style.rect(_presentation, Rect2(64, 66, 4, 65), Style.AMBER)
	var logo := Style.label("GTA MAŽEIKIAI", 35, Style.TEXT, true)
	logo.position = Vector2(82, 62)
	_presentation.add_child(logo)
	var arrival := Style.label("ON THE ROAD", 14, Style.AMBER, true)
	arrival.position = Vector2(84, 108)
	_presentation.add_child(arrival)

	_caption = Style.label("", 64, Style.TEXT, true)
	_caption.position = Vector2(62, 465)
	_presentation.add_child(_caption)
	_caption_detail = Style.label("", 17, Style.AMBER, true)
	_caption_detail.position = Vector2(67, 546)
	_presentation.add_child(_caption_detail)
	_fun_fact = Style.label("", 19, Style.TEXT, true)
	_fun_fact.position = Vector2(67, 579)
	_fun_fact.size.x = 705.0
	_fun_fact.add_theme_color_override("font_shadow_color", Color("#111724"))
	_fun_fact.add_theme_constant_override("shadow_offset_y", 2)
	_presentation.add_child(_fun_fact)
	_status = Style.label("LOADING WORLD", 15, Style.MUTED, true)
	_status.position = Vector2(67, 620)
	_presentation.add_child(_status)
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.position = Vector2(67, 655)
	_progress.size = Vector2(1146, 5)
	_progress.add_theme_stylebox_override("background", Style.box(Color("#282d3d"), Color.TRANSPARENT))
	_progress.add_theme_stylebox_override("fill", Style.box(Style.AMBER, Style.AMBER))
	_presentation.add_child(_progress)
	var control_tip := Style.label("%s  DRIVE   /   HOLD %s  FOR RADIO" % [
		GameManager.key_label("move_forward"), GameManager.key_label("radio_wheel")
	], 14, Style.TEXT, true)
	control_tip.position = Vector2(880, 619)
	_presentation.add_child(control_tip)
	_create_console()

	_blackout = Style.layer(Color.BLACK)
	canvas_layer.add_child(_blackout)
	_log("[LOAD] " + GameManager.WORLD.get_file())
	var result := ResourceLoader.load_threaded_request(GameManager.WORLD)
	if result != OK:
		_show_error()
		return
	_request_pending = true
	_music = AudioStreamPlayer.new()
	_music.stream = AssetShelf.sound("loading", "", true)
	_music.bus = &"Music"
	_music.volume_db = -35.0
	add_child(_music)
	if _music.stream != null:
		_log("[OK] audio / " + AssetShelf.sound_filename("loading", ""))
		_music.play()
		create_tween().tween_property(_music, "volume_db", -6.0, 0.75)
	_set_slide(_slide_offset)
	_slide_transition = create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_SINE)
	_slide_transition.tween_property(_blackout, "modulate:a", 0.0, SLIDE_FADE)


func _process(delta: float) -> void:
	if _finished:
		return
	_update_slideshow()
	if _finished:
		return
	if is_instance_valid(_world):
		if not _world_ready and Time.get_ticks_msec() > _world_step_deadline:
			_show_error("City setup stalled during %s. See the Godot log for details." % _world_step.to_lower())
		return
	var fraction := 1.0
	if _request_pending:
		var progress: Array = []
		var status := ResourceLoader.load_threaded_get_status(GameManager.WORLD, progress)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				_loaded_world = ResourceLoader.load_threaded_get(GameManager.WORLD) as PackedScene
				_request_pending = false
				if _loaded_world == null or not _loaded_world.can_instantiate():
					_show_error()
					return
				if _quit_requested:
					_finish_close()
				else:
					_log("[OK] " + GameManager.WORLD.get_file())
					_prepare_world()
				return
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_show_error()
				return
			_:
				fraction = float(progress[0]) if not progress.is_empty() else 0.0
	_progress.value = move_toward(_progress.value, fraction * 78.0, delta * 95.0)
	_status.text = "LOADING WORLD  /  %d%%" % roundi(fraction * 78.0)


func _update_slideshow() -> void:
	if _slide_transition != null and _slide_transition.is_running():
		return
	# Use elapsed time so a slow build or physics clock cannot stretch each hold to a minute.
	var now := Time.get_ticks_msec()
	if _slide_hold_started == 0:
		_slide_hold_started = now
	if now - _slide_hold_started < int(SLIDE_HOLD * 1000.0):
		return
	if _world_ready and _slides_shown >= mini(MIN_SLIDES, _slides.size()):
		_finish_world()
	elif _slides.size() > 1:
		_slide_hold_started = 0
		var next := posmod(_slide + 1, _slides.size())
		_slide_transition = create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_SINE)
		_slide_transition.tween_property(_blackout, "modulate:a", 1.0, SLIDE_FADE)
		_slide_transition.tween_callback(_set_slide.bind(next))
		_slide_transition.tween_interval(BLACK_HOLD)
		_slide_transition.tween_property(_blackout, "modulate:a", 0.0, SLIDE_FADE)


func _set_slide(index: int) -> void:
	if index < 0 or index >= _slides.size():
		return
	var slide: Dictionary = _slides[index]
	var path := str(slide.get("image", ""))
	var art := AssetShelf.image("loading/" + path.get_file().get_basename(), path)
	if art != null:
		_log("[OK] artwork / " + path.get_file())
		_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if slide.get("fit") == "contain" else TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.texture = art
	_caption.text = str(slide.get("location", ""))
	_caption_detail.text = str(slide.get("detail", ""))
	_slide = index
	_slides_shown += 1
	_next_fact()


func _next_fact() -> void:
	if _facts.is_empty():
		_facts = GameManager.read_json("res://data/loading_facts.json", [])
	if _facts.is_empty():
		return
	_facts.shuffle()
	if _facts.size() > 1 and str(_facts[0]) == _last_fact:
		_facts.push_back(_facts.pop_front())
	_last_fact = str(_facts.pop_front())
	_fun_fact.text = _last_fact


func _create_console() -> void:
	var area := PanelContainer.new()
	area.position = Vector2(805, 482)
	area.size = Vector2(410, 128)
	area.add_theme_stylebox_override("panel", Style.box(Color("#111721ed"), Color("#53606a"), 2))
	_presentation.add_child(area)
	var column := Style.stack(area, 5)
	column.add_child(Style.label("LOAD LOG", 11, Style.AMBER, true))
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "Liberation Mono"])
	_display_log = Label.new()
	_display_log.add_theme_font_override("font", mono)
	_display_log.add_theme_font_size_override("font_size", 12)
	_display_log.add_theme_color_override("font_color", Color("#c4d2d3"))
	_display_log.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_display_log)


func _log(message: String) -> void:
	_log_lines.append(message)
	if _log_lines.size() > 6:
		_log_lines.remove_at(0)
	_display_log.text = "\n".join(_log_lines)


func _prepare_world() -> void:
	_prepare_progress(78.0, "STARTING CITY SETUP")
	_world = _loaded_world.instantiate() as Node3D
	if _world == null or not _world.has_signal("world_progress") or not _world.get_script().can_instantiate():
		_show_error("World scripts failed to load. Open the project in Godot and let asset importing finish.")
		return
	_world.process_mode = Node.PROCESS_MODE_DISABLED
	_world.prepare_during_loading = true
	_world.loading_step.connect(_log)
	_world.world_progress.connect(_prepare_progress)
	_world.world_prepared.connect(_open_world, CONNECT_ONE_SHOT)
	_world.world_prepare_failed.connect(_show_error, CONNECT_ONE_SHOT)
	get_tree().root.add_child(_world)


func _prepare_progress(percent: float, message: String) -> void:
	_world_step_deadline = Time.get_ticks_msec() + WORLD_STAGE_TIMEOUT_MS
	_world_step = message
	_progress.value = percent
	_status.text = "%s  /  %d%%" % [message, roundi(percent)]


func _unhandled_input(event: InputEvent) -> void:
	if not _finished and is_instance_valid(_world) and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_show_error("City setup canceled.")


func _open_world() -> void:
	_world_ready = true
	_progress.value = 100.0
	_status.text = "FINALIZING WORLD"


func _finish_world() -> void:
	if _finished:
		return
	_finished = true
	_status.text = "READY  /  MAŽEIKIAI"
	_progress.value = 100.0
	var fade := create_tween().set_ignore_time_scale(true).set_parallel(true).set_trans(Tween.TRANS_SINE)
	fade.tween_property(_music, "volume_db", -56.0, 0.55)
	fade.tween_property(_blackout, "modulate:a", 1.0, SLIDE_FADE)
	fade.chain().tween_callback(_switch_world)


func _switch_world() -> void:
	if _quit_requested:
		return
	_music.stop()
	get_tree().current_scene = _world
	_world.start_playing()
	_presentation.hide()
	var reveal := create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_SINE)
	reveal.tween_property(_blackout, "modulate:a", 0.0, SLIDE_FADE)
	reveal.tween_callback(queue_free)


func _return_after_disconnect(reason: String) -> void:
	_log(reason)


func _exit_tree() -> void:
	if is_instance_valid(_world) and get_tree().current_scene != _world and not _world.is_queued_for_deletion():
		_world.queue_free()
	get_tree().auto_accept_quit = _previous_auto_quit
	if not _request_pending:
		return
	var status := ResourceLoader.load_threaded_get_status(GameManager.WORLD)
	if status == ResourceLoader.THREAD_LOAD_LOADED or status == ResourceLoader.THREAD_LOAD_FAILED:
		ResourceLoader.load_threaded_get(GameManager.WORLD)


func _close_window() -> void:
	if _request_pending and not _finished:
		_quit_requested = true
	else:
		_finish_close()


func _finish_close() -> void:
	_quit_requested = true
	_finished = true
	if _music != null:
		_music.stop()
		_music.stream = null
	var tree := get_tree()
	tree.create_timer(0.16).timeout.connect(tree.quit)


func _show_error(message := "The world scene could not be loaded.") -> void:
	_finished = true
	if _quit_requested:
		_finish_close()
		return
	if _slide_transition != null:
		_slide_transition.kill()
	_blackout.modulate.a = 0.0
	_status.text = "THE WORLD COULD NOT BE LOADED"
	_log("[ERROR] " + message)
	push_warning(message)
	if is_instance_valid(_world):
		_world.queue_free()
		_world = null
	if _music != null:
		_music.stop()
	var back := Style.button("BACK TO MAIN MENU")
	back.position = Vector2(67, 663)
	_presentation.add_child(back)
	back.pressed.connect(func() -> void:
		if SessionManager.active:
			SessionManager.leave()
		GameManager.go_to(GameManager.MAIN)
	)
	back.grab_focus()
