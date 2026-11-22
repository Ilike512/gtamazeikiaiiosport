extends Node

const FILE := "user://save.json"
const BACKUP := "user://save.previous.json"
const TEMP := "user://save.tmp"
const AUTO_FILE := "user://autosave.json"
const AUTO_BACKUP := "user://autosave.previous.json"
const AUTO_TEMP := "user://autosave.tmp"
const VERSION := 1


func load_game() -> Dictionary:
	var manual := load_slot(false)
	var automatic := load_slot(true)
	return automatic if float(automatic.get("saved_at", -1)) > float(manual.get("saved_at", -1)) else manual


func load_slot(automatic: bool) -> Dictionary:
	var paths := [AUTO_FILE, AUTO_BACKUP] if automatic else [FILE, BACKUP]
	for path: String in paths:
		var state: Dictionary = GameManager.read_json(path, {})
		if int(state.get("version", 0)) == VERSION and state.get("map") == "mazeikiai":
			if not state.has("saved_at"):
				state.saved_at = FileAccess.get_modified_time(path)
			return state
	return {}


func clear_autosave() -> bool:
	for path: String in [AUTO_BACKUP, AUTO_TEMP, AUTO_FILE]:
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
			return false
	return true


func save_game(state: Dictionary, automatic := false) -> bool:
	state = state.duplicate(true)
	state["version"] = VERSION
	state["saved_at"] = Time.get_unix_time_from_system()
	var destination_path := AUTO_FILE if automatic else FILE
	var backup_path := AUTO_BACKUP if automatic else BACKUP
	var temp_path := AUTO_TEMP if automatic else TEMP
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(state, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return false
	var destination := ProjectSettings.globalize_path(destination_path)
	var backup := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(destination_path):
		error = DirAccess.rename_absolute(destination, backup)
		if error != OK:
			return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), destination) == OK


func vector_data(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func read_vector(value: Variant, fallback: Vector3) -> Vector3:
	if value is not Array or value.size() != 3:
		return fallback
	for axis: Variant in value:
		if (axis is not float and axis is not int) or not is_finite(float(axis)):
			return fallback
	return Vector3(value[0], value[1], value[2])
