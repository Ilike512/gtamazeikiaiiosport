extends Node

signal now_playing_changed

const Library = preload("res://scripts/radio/RadioLibrary.gd")
const OFF := "off"
const STATION_PATH := "user://radio_station.cfg"
const QUIET_DB := -60.0

class Broadcast:
	var track: Dictionary = {}
	var started_at := 0.0
	var duration := 0.0
	var queue: Array[Dictionary] = []
	var last_break := ""

var library := Library.new()
var current_station := OFF
var current_track: Dictionary = {}
var audible := false
var interludes_enabled := true
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _broadcasts: Dictionary = {}
var _missing_audio: Dictionary = {}
var _fade: Tween
var _paused_at := -1.0
var _paused_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Radio"
		player.volume_db = QUIET_DB
		player.finished.connect(_on_finished.bind(index))
		add_child(player)
		_players.append(player)
	interludes_enabled = bool(GameManager.settings.radio_interludes)
	GameManager.settings_changed.connect(_apply_interlude_setting)


func begin_session(saved_station: String = "") -> void:
	interludes_enabled = bool(GameManager.settings.radio_interludes)
	_broadcasts.clear()
	library.reload()
	_missing_audio.clear()
	if saved_station.is_empty():
		var config := ConfigFile.new()
		if config.load(STATION_PATH) == OK:
			saved_station = str(config.get_value("radio", "station", OFF))
	set_station(saved_station, true)


func set_audible(enabled: bool) -> void:
	if audible == enabled:
		return
	audible = enabled
	if audible:
		_tune()
	else:
		_mix()


func set_paused(value: bool) -> void:
	if value == (_paused_at >= 0.0):
		return
	var now := Time.get_ticks_msec() * 0.001
	if value:
		_paused_at = now
	else:
		_paused_time += now - _paused_at
		_paused_at = -1.0
	for player: AudioStreamPlayer in _players:
		player.stream_paused = value
	if _fade != null and _fade.is_valid():
		if value:
			_fade.pause()
		else:
			_fade.play()


func end_session() -> void:
	_paused_at = -1.0
	_paused_time = 0.0
	if _fade != null and _fade.is_valid():
		_fade.kill()
	audible = false
	for player: AudioStreamPlayer in _players:
		player.stop()
		player.stream_paused = false
		player.stream = null
		player.volume_db = QUIET_DB
	current_station = OFF
	current_track = {}
	_broadcasts.clear()


func set_station(id: String, force := false) -> void:
	if not library.by_id.has(id):
		id = OFF
	if id == current_station and not force:
		return
	current_station = id
	var config := ConfigFile.new()
	config.set_value("radio", "station", id)
	config.save(STATION_PATH)
	_tune()


func station() -> Dictionary:
	return library.by_id.get(current_station, {})


func refresh_drop_folders() -> void:
	if library.music_snapshot() == library.folder_snapshot:
		return
	library.reload()
	_missing_audio.clear()
	_reset_queues()


func is_playing() -> bool:
	return _players[_active].playing


func playback_duration() -> float:
	var channel: Broadcast = _broadcasts.get(current_station)
	return channel.duration if channel != null else 0.0


func playback_elapsed() -> float:
	var channel: Broadcast = _broadcasts.get(current_station)
	if channel == null or channel.duration <= 0.0:
		return 0.0
	if audible and is_playing():
		return clampf(_players[_active].get_playback_position(), 0.0, channel.duration)
	return clampf(_clock() - channel.started_at, 0.0, channel.duration)


func _clock() -> float:
	var now := _paused_at if _paused_at >= 0.0 else Time.get_ticks_msec() * 0.001
	return now - _paused_time


func _reset_queues() -> void:
	for id: String in _broadcasts.keys():
		var channel: Broadcast = _broadcasts[id]
		channel.queue.clear()
		if not _catalog_has_track(id, channel.track):
			_broadcasts.erase(id)
	if current_station != OFF and not (_broadcasts.has(current_station) and is_playing()):
		_tune()


func _catalog_has_track(id: String, selected: Dictionary) -> bool:
	if selected.is_empty():
		return false
	var rows: Array = library.interludes.get(id, []) if selected.has("break_kind") else library.tracks.get(id, [])
	return rows.any(func(row: Dictionary) -> bool:
		return row.id == selected.id and row.audio == selected.audio
	)


func _fill_queue(channel: Broadcast) -> void:
	for track: Dictionary in library.tracks.get(current_station, []):
		var path := str(track.audio)
		if not path.is_empty() and not _missing_audio.has(path) and FileAccess.file_exists(path):
			channel.queue.append(track)
	channel.queue.shuffle()
	if channel.queue.size() > 1 and channel.queue[0].id == channel.track.get("programme_id", channel.track.get("id")):
		channel.queue.push_back(channel.queue.pop_front())


func _live_stream(channel: Broadcast, now: float, advance: bool, skip_break := false) -> AudioStream:
	var cold := channel.duration <= 0.0
	if not cold and not advance and now < channel.started_at + channel.duration:
		var live := _open_audio(str(channel.track.audio))
		if live != null:
			return live
	# Follow the existing station clock when retuning after a track boundary.
	var cue := now if cold or skip_break else minf(now, channel.started_at + channel.duration)
	for attempt in 48:
		var track := _next_entry(channel, not skip_break)
		if track.is_empty():
			break
		var stream := _open_audio(str(track.audio))
		if stream == null:
			continue
		var length := stream.get_length()
		if length <= 0.0:
			_missing_audio[track.audio] = true
			continue
		if cold:
			cue -= randf_range(0.0, length * 0.75)
		if track.has("break_kind"):
			channel.last_break = str(track.audio)
		channel.track = track
		channel.started_at = now if attempt == 47 else cue
		channel.duration = length
		if now < channel.started_at + length:
			return stream
		cue += length
	channel.track = {}
	channel.duration = 0.0
	return null


func _next_entry(channel: Broadcast, allow_break: bool) -> Dictionary:
	if interludes_enabled and allow_break and not channel.track.is_empty() and not channel.track.has("break_kind"):
		var options := _interlude_options(channel)
		if options.size() > 1:
			options = options.filter(func(entry: Dictionary) -> bool: return entry.audio != channel.last_break)
		if not options.is_empty():
			return _with_programme(options.pick_random(), channel)
	if channel.queue.is_empty():
		_fill_queue(channel)
	if channel.queue.is_empty():
		return {}
	return channel.queue.pop_front()


func _interlude_options(channel: Broadcast) -> Array:
	var options: Array = library.interludes.get(current_station, []).filter(func(entry: Dictionary) -> bool:
		var path := str(entry.audio)
		return not _missing_audio.has(path) and FileAccess.file_exists(path)
	)
	return options


func _with_programme(entry: Dictionary, channel: Broadcast) -> Dictionary:
	var clip := entry.duplicate()
	clip.programme_id = channel.track.get("programme_id", channel.track.get("id", ""))
	return clip


func skip_to_interlude() -> bool:
	if current_station == OFF:
		return false
	refresh_drop_folders()
	var channel: Broadcast = _broadcasts.get(current_station)
	if channel == null:
		channel = Broadcast.new()
		_broadcasts[current_station] = channel
	var options := _interlude_options(channel)
	options.shuffle()
	if options.size() > 1 and str(options[0].audio) == channel.last_break:
		options.push_back(options.pop_front())
	for entry: Dictionary in options:
		var stream := _open_audio(str(entry.audio))
		if stream == null:
			continue
		var length := stream.get_length()
		if length <= 0.0:
			_missing_audio[entry.audio] = true
			continue
		channel.track = _with_programme(entry, channel)
		channel.last_break = str(entry.audio)
		channel.started_at = _clock()
		channel.duration = length
		current_track = channel.track
		_play_selection(stream, 0.0)
		return true
	return false


func toggle_interludes() -> bool:
	GameManager.settings.radio_interludes = not interludes_enabled
	_apply_interlude_setting()
	GameManager.persist_settings()
	return interludes_enabled


func _apply_interlude_setting() -> void:
	var enabled := bool(GameManager.settings.radio_interludes)
	if interludes_enabled == enabled:
		return
	interludes_enabled = enabled
	if interludes_enabled:
		refresh_drop_folders()
	else:
		for id: String in _broadcasts.keys():
			var channel: Broadcast = _broadcasts[id]
			if id != current_station and channel.track.has("break_kind"):
				_broadcasts.erase(id)
		if current_track.has("break_kind"):
			_tune(true, true)


func skip_track() -> bool:
	if current_station == OFF or current_track.is_empty() or playback_duration() <= 0.0:
		return false
	_tune(true, true)
	return not current_track.is_empty()


func _tune(advance := false, skip_break := false) -> void:
	var now := _clock()
	var stream: AudioStream
	var offset := 0.0
	current_track = {}
	if current_station != OFF:
		if not _broadcasts.has(current_station):
			_broadcasts[current_station] = Broadcast.new()
		var channel: Broadcast = _broadcasts[current_station]
		stream = _live_stream(channel, now, advance, skip_break)
		if stream != null:
			current_track = channel.track
			offset = clampf(now - channel.started_at, 0.0, maxf(0.0, channel.duration - 0.02))

	_play_selection(stream, offset)


func _play_selection(stream: AudioStream, offset: float) -> void:
	_active = 1 - _active
	var incoming := _players[_active]
	incoming.stop()
	incoming.stream_paused = false
	incoming.stream = stream
	incoming.volume_db = QUIET_DB
	if stream != null and audible:
		incoming.play(offset)
		incoming.stream_paused = _paused_at >= 0.0
	_mix()
	now_playing_changed.emit()


func _open_audio(path: String) -> AudioStream:
	if path.is_empty() or _missing_audio.has(path):
		return null
	var stream := AssetShelf.open_audio(path)
	if stream == null:
		_missing_audio[path] = true
		return null
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = false
	return stream


func _mix() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	var incoming := _players[_active]
	var outgoing := _players[1 - _active]
	var gain := clampf(float(station().get("gain_db", 0.0)), -20.0, 6.0)
	_fade = create_tween().set_parallel(true).set_ignore_time_scale(true)
	_fade_player(incoming, gain - 6.0 if audible else QUIET_DB)
	_fade_player(outgoing, QUIET_DB)
	_fade.chain().tween_callback(outgoing.stop)
	if not audible:
		_fade.tween_callback(incoming.stop)
	if _paused_at >= 0.0:
		_fade.pause()


func _fade_player(player: AudioStreamPlayer, target: float) -> void:
	_fade.tween_method(
		func(volume: float) -> void: player.volume_db = linear_to_db(volume),
		db_to_linear(player.volume_db), db_to_linear(target), 0.36
	)


func _on_finished(index: int) -> void:
	if _active == index and audible and current_station != OFF and _paused_at < 0.0:
		_tune(true)
