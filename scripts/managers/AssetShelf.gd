extends Node

const IMAGE_SUFFIXES := ["png", "jpg", "jpeg", "webp", "svg"]
const AUDIO_SUFFIXES := ["ogg", "wav", "mp3"]
const BUNDLED_AUDIO := "res://assets/bundled_audio"

func game_folder(name: String) -> String:
	if OS.has_feature("mobile"):
		return ProjectSettings.globalize_path("user://").path_join(name)
	var base := ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	return base.path_join(name)


func open_game_folder(name: String) -> bool:
	var path := game_folder(name)
	if DirAccess.dir_exists_absolute(path) and OS.shell_open(path) == OK:
		return true
	var fallback := ProjectSettings.globalize_path("user://").path_join(name)
	DirAccess.make_dir_recursive_absolute(fallback)
	return OS.shell_open(fallback) == OK


func ensure_overrides() -> void:
	var user_folder := DirAccess.open("user://")
	if user_folder != null:
		for folder: String in ["loading", "sound", "station_icons", "items"]:
			user_folder.make_dir_recursive("Custom Assets/" + folder)


func image(slot: String, fallback := "") -> Texture2D:
	var path := _find(slot, IMAGE_SUFFIXES)
	if not path.is_empty():
		var picture := Image.load_from_file(path)
		if picture != null and not picture.is_empty():
			return ImageTexture.create_from_image(picture)
	if not fallback.is_empty() and ResourceLoader.exists(fallback, "Texture2D"):
		return load(fallback) as Texture2D
	if FileAccess.file_exists(fallback):
		var picture := Image.load_from_file(fallback)
		if picture != null and not picture.is_empty():
			return ImageTexture.create_from_image(picture)
	return null


func sound_filename(slot: String, fallback: String) -> String:
	var paths := _sound_paths(slot)
	return fallback.get_file() if paths.is_empty() else paths[0].get_file().trim_suffix(".audio")


func sound(slot: String, fallback: String, looping := false) -> AudioStream:
	var stream: AudioStream
	for path: String in _sound_paths(slot):
		stream = open_audio(path)
		if stream != null:
			break
	if stream == null:
		stream = open_audio(fallback)
	if stream == null or not looping:
		return stream
	stream = stream.duplicate() as AudioStream
	if stream is AudioStreamWAV:
		stream.loop_begin = 0
		stream.loop_end = maxi(1, roundi(stream.get_length() * stream.mix_rate))
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	return stream


func open_audio(path: String) -> AudioStream:
	if path.begins_with("res://") and ResourceLoader.exists(path, "AudioStream"):
		return load(path) as AudioStream
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	match audio_extension(path):
		"wav":
			return AudioStreamWAV.load_from_file(path)
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"mp3":
			return AudioStreamMP3.load_from_file(path)
	return null


func audio_extension(path: String) -> String:
	return path.trim_suffix(".audio").get_extension().to_lower()


func _sound_paths(slot: String) -> Array[String]:
	var paths: Array[String] = []
	var relative := "sound/" + slot
	var custom_folders := [ProjectSettings.globalize_path("user://Custom Assets"), game_folder("Custom Assets")]
	for folder: String in custom_folders:
		for suffix: String in AUDIO_SUFFIXES:
			var path := folder.path_join("%s.%s" % [relative, suffix])
			if FileAccess.file_exists(path) and not paths.has(path):
				paths.append(path)
	for suffix: String in AUDIO_SUFFIXES:
		var packed := BUNDLED_AUDIO.path_join("Custom Assets").path_join("%s.%s.audio" % [relative, suffix])
		if FileAccess.file_exists(packed):
			paths.append(packed)
	return paths


func _find(slot: String, suffixes: Array) -> String:
	for folder: String in [ProjectSettings.globalize_path("user://Custom Assets"), game_folder("Custom Assets")]:
		for suffix: String in suffixes:
			var path := folder.path_join("%s.%s" % [slot, suffix])
			if FileAccess.file_exists(path):
				return path
	return ""
