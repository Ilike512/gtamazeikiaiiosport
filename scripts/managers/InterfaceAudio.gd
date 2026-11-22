extends Node

var _hover: AudioStreamPlayer
var _click: AudioStreamPlayer
var _selector: AudioStreamPlayer
var _alert: AudioStreamPlayer
var _defeat: AudioStreamPlayer
var _drink: AudioStreamPlayer
var _eat: AudioStreamPlayer
var _last_hover := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hover = _make_player("menu_hover", "menu_hover.mp3", -8.0)
	_click = _make_player("menu_click", "menu_click.mp3", -5.0)
	_selector = _make_player("character_switch", "character_switch.mp3", -11.0, true)
	_alert = _make_player("wanted_alert", "wanted_alert.wav", -8.0)
	_defeat = _make_player("defeat", "defeat_supplied.mp3", -3.0)
	if _defeat.stream == null:
		_defeat.stream = AssetShelf.sound("defeat", "res://assets/audio/sfx/defeat.wav")
	_drink = _make_player("drinking", "drinking.mp3", -4.0)
	_eat = _make_player("eating", "eating.mp3", -5.0)
	get_tree().node_added.connect(_wire_button)


func _make_player(id: String, file: String, volume: float, looping := false) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = &"SFX"
	player.stream = AssetShelf.sound(id, "res://assets/audio/sfx/" + file, looping)
	player.volume_db = volume
	add_child(player)
	return player


func _wire_button(node: Node) -> void:
	var button := node as BaseButton
	if button == null:
		return
	button.mouse_entered.connect(_on_hover.bind(button))
	button.pressed.connect(_on_click)


func _on_hover(button: BaseButton) -> void:
	var now := Time.get_ticks_msec()
	if button.disabled or _hover.stream == null or now - _last_hover < 42:
		return
	_last_hover = now
	_hover.play()


func _on_click() -> void:
	if _click.stream != null:
		_click.play()


func play_selector(active: bool) -> void:
	if active and _selector.stream != null and not _selector.playing:
		_selector.play()
	elif not active:
		_selector.stop()


func play_wanted() -> void:
	if _alert.stream != null and not _alert.playing:
		_alert.play()


func play_defeat() -> AudioStreamPlayer:
	if _defeat.stream != null:
		_defeat.play()
	return _defeat


func play_drink() -> void:
	if _drink.stream != null:
		_drink.play()


func play_eat() -> void:
	if _eat.stream != null:
		_eat.play()
