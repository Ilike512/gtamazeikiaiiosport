extends Control

const Style = preload("res://scripts/ui/Style.gd")
const STUDIO_PROFILE := "res://assets/brand/studio_profile.png"
const BLITZ_PROFILE := "res://assets/brand/blitz_profile.png"
const STUDIO_AT := 3.0
const BLITZ_AT := 5.5
const BLACK_AT := 8.0
const MINIMUM_SECONDS := 8.55
const CUE_FADE := 0.65

var _title: CenterContainer
var _subtitle: Label
var _card: CenterContainer
var _portrait: TextureRect
var _nameplate: Label
var _skip_button: Button
var _studio_art: Texture2D
var _blitz_art: Texture2D
var _music: AudioStreamPlayer
var _menu: PackedScene
var _started_at := 0
var _length := MINIMUM_SECONDS
var _cue := -1
var _skip := false
var _leaving := false


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--dedicated-room"):
		_run_dedicated_room()
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	add_child(Style.layer(Color.BLACK))
	_studio_art = AssetShelf.image("studio_profile", STUDIO_PROFILE)
	_blitz_art = AssetShelf.image("blitz_profile", BLITZ_PROFILE)
	_title = _center()
	var words := Style.stack(_title, 10)
	_center_label(words, "GTA MAŽEIKIAI...", 78, Style.TEXT)
	_subtitle = _center_label(words, "(AND ZEKOPANE)", 33, Style.AMBER)
	_card = _center()
	var identity := Style.stack(_card, 21)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(252, 252)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_child(_portrait)
	_nameplate = _center_label(identity, "", 52, Style.TEXT)
	_skip_button = Style.button("SKIP")
	add_child(_skip_button)
	_skip_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_button.offset_left = -118
	_skip_button.offset_top = -67
	_skip_button.offset_right = -28
	_skip_button.offset_bottom = -23
	_skip_button.pressed.connect(_request_skip)

	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	_music.stream = AssetShelf.sound("studio_start", "")
	if _music.stream != null:
		_length = maxf(_length, _music.stream.get_length())
	add_child(_music)
	_started_at = Time.get_ticks_msec()
	if _music.stream != null:
		_music.play()
	_show_cue(0)
	_fade_card(0.0)
	if ResourceLoader.load_threaded_request(GameManager.MAIN) != OK:
		_menu = load(GameManager.MAIN) as PackedScene


func _run_dedicated_room() -> void:
	var port_text := OS.get_environment("MAZEIKIAI_PORT")
	var port := port_text.to_int() if not port_text.is_empty() else SessionManager.PORT
	var result := SessionManager.host_room("Dedicated room", OS.get_environment("MAZEIKIAI_ROOM_PASSWORD"), port, true)
	if not result.is_empty():
		push_error(result)
		get_tree().quit(1)
		return
	print("Mažeikiai dedicated room is listening on UDP %d." % port)
	set_process(false)


func _center() -> CenterContainer:
	var centered := CenterContainer.new()
	centered.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centered)
	Style.fill(centered)
	return centered


func _center_label(parent: Container, words: String, font_size: int, tint: Color) -> Label:
	var headline := Style.label(words, font_size, tint, true)
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(headline)
	return headline


func _process(_delta: float) -> void:
	if _leaving:
		return
	if _menu == null:
		match ResourceLoader.load_threaded_get_status(GameManager.MAIN):
			ResourceLoader.THREAD_LOAD_LOADED:
				_menu = ResourceLoader.load_threaded_get(GameManager.MAIN) as PackedScene
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_leaving = true
				GameManager.go_to(GameManager.MAIN)
				return
	var elapsed := float(Time.get_ticks_msec() - _started_at) * 0.001
	if elapsed >= BLACK_AT:
		_show_cue(4)
	elif elapsed >= BLITZ_AT:
		_show_cue(3)
	elif elapsed >= STUDIO_AT:
		_show_cue(2)
	elif elapsed >= 1.0:
		_show_cue(1)
	_fade_card(elapsed)
	if _menu == null or (not _skip and elapsed < _length):
		return
	_leaving = true
	_show_cue(4)
	var fade := create_tween()
	fade.tween_property(_music, "volume_db", -52.0, 0.16 if _skip else 0.07)
	fade.tween_callback(_show_menu)


func _show_cue(index: int) -> void:
	if index == _cue:
		return
	_cue = index
	_title.visible = index < 2
	_subtitle.modulate.a = 1.0 if index == 1 else 0.0
	_card.visible = index == 2 or index == 3
	_skip_button.visible = index < 4
	if _card.visible:
		_portrait.texture = _studio_art if index == 2 else _blitz_art
		_nameplate.text = "NotUziStudios" if index == 2 else "BLITZ"


func _fade_card(elapsed: float) -> void:
	if elapsed < STUDIO_AT:
		_title.modulate.a = _cue_opacity(elapsed, 0.0, STUDIO_AT)
		_subtitle.modulate.a = smoothstep(0.0, CUE_FADE, elapsed - 1.0)
	elif elapsed < BLACK_AT:
		var start := STUDIO_AT if elapsed < BLITZ_AT else BLITZ_AT
		var finish := BLITZ_AT if elapsed < BLITZ_AT else BLACK_AT
		_card.modulate.a = _cue_opacity(elapsed, start, finish)


func _cue_opacity(elapsed: float, start: float, finish: float) -> float:
	return smoothstep(0.0, CUE_FADE, elapsed - start) * smoothstep(0.0, CUE_FADE, finish - elapsed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_request_skip()


func _request_skip() -> void:
	_skip = true


func _show_menu() -> void:
	_music.stop()
	if get_tree().change_scene_to_packed(_menu) != OK:
		GameManager.go_to(GameManager.MAIN)
