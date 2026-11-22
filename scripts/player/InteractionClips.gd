extends RefCounted

const ENTRY_LENGTH := 1.10
const SEARCH_LENGTH := 1.12
const THROW_LENGTH := 0.49
const DURATIONS := {"car_entry": ENTRY_LENGTH, "search_car": SEARCH_LENGTH, "throw_item": THROW_LENGTH,
	"punch": 0.47, "fire": 0.32, "grab_cash": 0.95}


static func install(controller: AnimationPlayer) -> void:
	var idle := controller.get_animation("idle")
	var library := controller.get_animation_library("")
	if idle == null:
		return
	for clip: String in DURATIONS:
		if library.has_animation(clip):
			continue
		var action := Animation.new()
		action.length = DURATIONS[clip]
		for track in idle.get_track_count():
			var path := idle.track_get_path(track)
			if path.get_subname_count() == 0:
				continue
			var bone := str(path.get_subname(path.get_subname_count() - 1))
			if idle.track_get_type(track) == Animation.TYPE_ROTATION_3D:
				var dst := action.add_track(Animation.TYPE_ROTATION_3D)
				action.track_set_path(dst, path)
				var neutral := idle.rotation_track_interpolate(track, 0.0)
				for key in 5:
					var angles := _pose(clip, bone, key)
					action.rotation_track_insert_key(dst, action.length * key * 0.25,
						(neutral * Quaternion.from_euler(angles)).normalized())
			elif bone == "hips" and idle.track_get_type(track) == Animation.TYPE_POSITION_3D:
				var dst := action.add_track(Animation.TYPE_POSITION_3D)
				action.track_set_path(dst, path)
				var neutral := idle.position_track_interpolate(track, 0.0)
				var lowering: Array = [0.0, 0.025, 0.10, 0.27, 0.44] if clip == "car_entry" else [0.0, 0.06, 0.16, 0.11, 0.0]
				for key in 5:
					action.position_track_insert_key(dst, action.length * key * 0.25,
						neutral - Vector3.UP * (float(lowering[key]) if clip in ["car_entry", "search_car", "grab_cash"] else 0.0))
		library.add_animation(clip, action)


static func _pose(clip: String, bone: String, key: int) -> Vector3:
	if key == 0 or (key == 4 and clip != "car_entry"):
		return Vector3.ZERO
	if clip in ["punch", "fire"]:
		return _combat_pose(clip, bone, key)
	var arm := bone == "upperarm_R" or bone == "upperarm_L"
	if clip == "throw_item":
		if bone == "upperarm_R":
			return [Vector3.ZERO, Vector3(0.46, -0.87, 0.64), Vector3(-0.61, 0.73, 0.74), Vector3(-1.15, 0.13, 0.38)][key]
		if bone == "chest":
			return Vector3(-0.13, [-0.0, -0.40, 0.30, 0.18][key], 0.1)
		if bone == "forearm_R":
			return Vector3(0, [-0.0, -1.40, -0.35, -0.10][key], 0)
		return Vector3.ZERO
	var effort := [0.0, 0.46, 1.0, 0.83, 0.85][key] as float
	var entering := clip == "car_entry"
	if arm:
		return Vector3(-0.84, -0.19, 0.37 if bone.ends_with("_R") else -0.30) * effort
	if bone.begins_with("forearm"):
		return Vector3(0, -0.58 if bone.ends_with("_R") else 0.56, 0) * effort
	if bone in ["spine", "chest"]:
		return Vector3(0.21, 0.11 if entering else -0.09, -0.035) * effort
	if bone == "head":
		return Vector3(-0.19, 0.06, 0.04) * effort
	if bone.begins_with("thigh"):
		return Vector3(0.77 if entering else 0.28, 0, 0.13 if bone.ends_with("_R") else -0.13) * effort
	if bone.begins_with("calf"):
		return Vector3(-1.06 if entering else -0.4, 0, 0) * effort
	return Vector3.ZERO


static func _combat_pose(clip: String, bone: String, key: int) -> Vector3:
	if clip == "fire":
		var brace := [0.0, 0.89, 1.0, 0.58][key] as float
		match bone:
			"upperarm_R": return Vector3(-1.35, -0.16, 0.28) * brace
			"forearm_R": return Vector3(-0.13, -0.45, 0.0) * brace
			"upperarm_L": return Vector3(-1.05, 0.23, -0.30) * brace
			"forearm_L": return Vector3(-0.20, 0.82, 0.0) * brace
			"chest": return Vector3(-0.11 if key == 2 else 0.06, -0.10, 0.02) * brace
		return Vector3.ZERO
	var turn := [0.0, -0.46, 0.47, 0.13][key] as float
	match bone:
		"hips", "chest": return Vector3(0.09 * absf(turn), turn, -0.10 * absf(turn))
		"upperarm_R": return [Vector3.ZERO, Vector3(-0.71, -0.79, 0.73), Vector3(-1.45, 0.16, 0.18), Vector3(-0.87, 0.13, 0.47)][key]
		"forearm_R": return Vector3(0.03, [-0.0, -1.51, -0.12, -0.70][key], 0.04)
		"upperarm_L": return Vector3(-0.71, 0.07, -0.29) * (0.30 + absf(turn))
		"forearm_L": return Vector3(0, 0.91, 0) * (0.30 + absf(turn))
		"head": return Vector3(-0.10, -turn * 0.72, 0.04)
	return Vector3.ZERO
