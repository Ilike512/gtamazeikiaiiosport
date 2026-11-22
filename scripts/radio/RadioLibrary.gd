extends RefCounted

const PACKS := "user://radio_packs"
const STATIONS_FILE := "res://data/radio_stations.json"
const TRACKS_FILE := "res://data/radio_tracks.json"
const MOVES_FILE := "res://data/radio_moves.json"
const TrackTags = preload("res://scripts/radio/TrackTags.gd")
const MUSIC_FOLDER := "Radio Music"

var stations: Array[Dictionary] = []
var by_id: Dictionary = {}
var tracks: Dictionary = {}
var interludes: Dictionary = {}
var _insert_name := RegEx.new()
var report: Array[String] = []
var folder_snapshot := 0
var _aliases: Dictionary = {}
var _catalog: Dictionary = {}


func reload() -> void:
	stations.clear()
	by_id.clear()
	tracks.clear()
	interludes.clear()
	_insert_name.compile("(?i)^([0-9]+)\\s+(advert|dj)(?:\\s+.*)?$")
	report.clear()
	_aliases.clear()
	_catalog.clear()
	var user_folder := DirAccess.open("user://")
	if user_folder != null:
		for folder: String in ["playlists", "media", "icons"]:
			user_folder.make_dir_recursive("radio_packs/" + folder)
	for raw: Variant in GameManager.read_json(STATIONS_FILE, []):
		if raw is not Dictionary:
			continue
		var station: Dictionary = raw.duplicate()
		var id := str(station.get("id", ""))
		if id.is_empty() or by_id.has(id):
			_warn("Invalid or repeated station ID: %s" % id)
			continue
		station["texture"] = _icon(id, str(station.get("icon", "")))
		stations.append(station)
		by_id[id] = station
		tracks[id] = []
		interludes[id] = []
	for row: Variant in GameManager.read_json(TRACKS_FILE, []):
		_add(row, "", PACKS.path_join("media"), TRACKS_FILE)
	var pack_folder := DirAccess.open(PACKS)
	if pack_folder != null:
		for folder: String in pack_folder.get_directories():
			var pack := PACKS.path_join(folder)
			_import_folder(pack.path_join("playlists"), pack.path_join("media"))
		_import_folder(PACKS.path_join("playlists"), PACKS.path_join("media"))
	_apply_moves(MOVES_FILE)
	_scan_music_folders()
	folder_snapshot = music_snapshot()
	_apply_moves(PACKS.path_join("moves.json"))
	for track: Dictionary in _catalog.values():
		tracks[track.station].append(track)


func _scan_music_folders() -> void:
	var user_access := DirAccess.open("user://")
	for station: Dictionary in stations:
		var folder := str(station.get("folder", station.id))
		if user_access != null:
			user_access.make_dir_recursive(MUSIC_FOLDER.path_join(folder))
	for root: String in _music_roots():
		for station: Dictionary in stations:
			var folder := root.path_join(str(station.get("folder", station.id)))
			_scan_station(folder, station.id)


func music_snapshot() -> int:
	var files := PackedStringArray()
	for root: String in _music_roots():
		for station: Dictionary in stations:
			var folder := root.path_join(str(station.get("folder", station.id)))
			for path: String in _station_audio_paths(folder):
				files.append("%s:%d" % [path, FileAccess.get_modified_time(path)])
	return hash(files)


func _music_roots() -> Array[String]:
	var roots: Array[String] = [AssetShelf.BUNDLED_AUDIO.path_join(MUSIC_FOLDER), AssetShelf.game_folder(MUSIC_FOLDER)]
	var user_root := ProjectSettings.globalize_path("user://").path_join(MUSIC_FOLDER)
	if not roots.has(user_root):
		roots.append(user_root)
	return roots


func _station_audio_paths(folder: String, depth := 0) -> PackedStringArray:
	var paths := PackedStringArray()
	var directory := DirAccess.open(folder)
	if directory == null:
		return paths
	if depth < 8:
		for name: String in directory.get_directories():
			if not directory.is_link(name):
				paths.append_array(_station_audio_paths(folder.path_join(name), depth + 1))
	for name: String in directory.get_files():
		if AssetShelf.audio_extension(name) in TrackTags.AUDIO_SUFFIXES:
			paths.append(folder.path_join(name))
	return paths


func _scan_station(folder: String, station: String) -> void:
	for path: String in _station_audio_paths(folder):
		var filename := path.get_file()
		var cue := _insert_name.search(filename.trim_suffix(".audio").get_basename())
		if cue != null:
			var kind := cue.get_string(2).to_lower()
			var label := "DJ" if kind == "dj" else "Advert"
			var number := cue.get_string(1)
			var id := "%s/%s/%s" % [station, kind, int(number)]
			var clips: Array = interludes[station]
			var replace := clips.find_custom(func(clip: Dictionary) -> bool: return clip.id == id)
			var clip := {"id": id, "title": "%s %s" % [label, number],
				"artist": by_id[station].name, "station": station, "duration": 0.0,
				"audio": path, "break_kind": kind}
			if replace >= 0:
				clips[replace] = clip
			else:
				clips.append(clip)
			continue
		var metadata := TrackTags.read(path)
		metadata["audio"] = filename
		_add(metadata, station, path.get_base_dir(), path)


func _apply_moves(path: String) -> void:
	for row: Variant in GameManager.read_json(path, []):
		if row is not Dictionary:
			continue
		var identity := _identity(str(row.get("artist", "")), str(row.get("title", "")))
		var track_key: String = _aliases.get(identity, _aliases.get("id:" + str(row.get("id", "")).to_lower(), ""))
		var station := str(row.get("station", ""))
		if not _catalog.has(track_key) or not by_id.has(station):
			_warn("Unknown track or station in %s." % path)
			continue
		var track: Dictionary = _catalog[track_key]
		if track.station != station:
			_warn("Playlist move: %s — %s moved from %s to %s (%s)." % [track.artist, track.title, track.station, station, path])
			track.station = station


func _icon(id: String, packaged: String) -> Texture2D:
	var override := AssetShelf.image("station_icons/" + id)
	if override != null:
		return override
	var external := PACKS.path_join("icons").path_join(id + ".png")
	if FileAccess.file_exists(external):
		var source := Image.load_from_file(external)
		if source != null and not source.is_empty():
			return ImageTexture.create_from_image(source)
	if not packaged.is_empty() and ResourceLoader.exists(packaged, "Texture2D"):
		return load(packaged) as Texture2D
	return null


func _import_folder(folder: String, media: String) -> void:
	var playlists := DirAccess.open(folder)
	if playlists == null:
		return
	for filename: String in playlists.get_files():
		var station := filename.get_basename().to_lower()
		if not by_id.has(station):
			continue
		var path := folder.path_join(filename)
		match filename.get_extension().to_lower():
			"json":
				for row: Variant in GameManager.read_json(path, []):
					_add(row, station, media, path)
			"csv":
				_import_csv(path, station, media)
			"txt":
				_import_text(path, station, media)


func _import_text(path: String, station: String, media: String) -> void:
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		line = line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split(" — ", true, 1)
		if parts.size() < 2:
			parts = line.split(" - ", true, 1)
		if parts.size() < 2:
			_warn("Expected Artist — Title in %s: %s" % [path, line])
			continue
		var title_and_audio := parts[1].split("|", true, 1)
		_add({
			"artist": parts[0], "title": title_and_audio[0],
			"audio": title_and_audio[1] if title_and_audio.size() > 1 else ""
		}, station, media, path)


func _import_csv(path: String, station: String, media: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_warn("Could not read %s." % path)
		return
	var first_line := file.get_line()
	var separator := "," if first_line.count(",") >= first_line.count(";") else ";"
	file.seek(0)
	var columns := file.get_csv_line(separator)
	for index in columns.size():
		columns[index] = columns[index].trim_prefix("\ufeff").strip_edges().to_lower()
	var title := _column(columns, ["title", "track name", "name", "song"])
	var artist := _column(columns, ["artist", "artist name(s)", "artist name", "artists"])
	var identifier := _column(columns, ["id", "track id"])
	var spotify := _column(columns, ["spotify", "track uri", "spotify uri", "track url"])
	var audio := _column(columns, ["audio", "audio file", "path"])
	var length := _column(columns, ["duration", "duration seconds"])
	var milliseconds := _column(columns, ["duration (ms)", "duration_ms", "track duration (ms)"])
	if title < 0 or artist < 0:
		_warn("Missing artist or title column in %s." % path)
		return
	while not file.eof_reached():
		var fields := file.get_csv_line(separator)
		if fields.size() <= maxi(title, artist) or fields[title].strip_edges().is_empty():
			continue
		var duration := float(_field(fields, length))
		if length < 0:
			duration = float(_field(fields, milliseconds)) / 1000.0
		_add({
			"id": _field(fields, identifier), "spotify": _field(fields, spotify),
			"title": fields[title], "artist": fields[artist], "audio": _field(fields, audio),
			"duration": duration
		}, station, media, path)


func _column(headers: PackedStringArray, candidates: Array) -> int:
	for label: String in candidates:
		var index := headers.find(label)
		if index >= 0:
			return index
	return -1


func _field(fields: PackedStringArray, index: int) -> String:
	return fields[index] if index >= 0 and index < fields.size() else ""


func _add(raw: Variant, station_override: String, media: String, source: String) -> void:
	if raw is not Dictionary:
		return
	var station := station_override if not station_override.is_empty() else str(raw.get("station", ""))
	var title := str(raw.get("title", "")).strip_edges()
	var artist := str(raw.get("artist", "")).strip_edges()
	if not by_id.has(station) or title.is_empty() or artist.is_empty():
		_warn("Invalid station, title or artist in %s." % source)
		return
	var identity := _identity(artist, title)
	var explicit_id := str(raw.get("id", "")).strip_edges()
	var spotify := _spotify_id(str(raw.get("spotify", explicit_id)))
	if spotify.is_empty():
		spotify = _spotify_id(explicit_id)
	var aliases: Array[String] = [identity]
	if not explicit_id.is_empty():
		aliases.append("id:" + explicit_id.to_lower())
	if not spotify.is_empty():
		aliases.append("spotify:" + spotify)
	var matches: Array[String] = []
	for alias: String in aliases:
		if _aliases.has(alias) and not matches.has(_aliases[alias]):
			matches.append(_aliases[alias])

	var audio := _audio_path(str(raw.get("audio", "")).strip_edges(), media)
	if audio.is_empty():
		audio = _discover_audio([explicit_id, spotify], media)
	var track := {
		"id": explicit_id if not explicit_id.is_empty() else (spotify if not spotify.is_empty() else identity),
		"title": title, "artist": artist, "station": station,
		"duration": maxf(0.0, float(raw.get("duration", 0))),
		"audio": audio,
		"aliases": aliases
	}
	for match_id: String in matches:
		var previous: Dictionary = _catalog[match_id]
		if previous.station != station:
			_warn("Duplicate ownership: %s — %s moved from %s to %s (%s)." % [artist, title, previous.station, station, source])
		if track.audio.is_empty() and not str(previous.audio).is_empty():
			track.audio = previous.audio
		if track.duration <= 0.0:
			track.duration = previous.duration
		if explicit_id.is_empty() and str(previous.id) != match_id:
			track.id = previous.id
		for old_alias: String in previous.aliases:
			if not aliases.has(old_alias):
				aliases.append(old_alias)
		_catalog.erase(match_id)
	_catalog[identity] = track
	for alias: String in aliases:
		_aliases[alias] = identity


func _discover_audio(stems: Array[String], media: String) -> String:
	for stem: String in stems:
		if stem.is_empty():
			continue
		for extension: String in ["ogg", "mp3", "wav"]:
			var candidate := _audio_path(stem + "." + extension, media)
			if not candidate.is_empty() and FileAccess.file_exists(candidate):
				return candidate
	return ""


func _identity(artist: String, title: String) -> String:
	return "song:%s/%s" % [_normalize(artist), _normalize(title)]


func _audio_path(path: String, media: String) -> String:
	if path.is_empty():
		return ""
	path = path.replace("\\", "/")
	if path.is_absolute_path() or path.contains(":") or path.split("/").has(".."):
		return ""
	return media.path_join(path).simplify_path()


func _normalize(value: String) -> String:
	var normalized := value.to_lower().replace(" featuring ", " ft ").replace(" feat ", " ft ").replace(" feat. ", " ft ").replace(" ft. ", " ft ")
	for punctuation: String in [".", ",", "'", "’", "-", "/", "&", "(", ")", "_"]:
		normalized = normalized.replace(punctuation, " ")
	return " ".join(normalized.split(" ", false))


func _spotify_id(value: String) -> String:
	if value.begins_with("spotify:track:"):
		return value.trim_prefix("spotify:track:")
	if value.contains("open.spotify.com/track/"):
		return value.get_slice("/track/", 1).get_slice("?", 0)
	return ""


func _warn(message: String) -> void:
	report.append(message)
	push_warning(message)
