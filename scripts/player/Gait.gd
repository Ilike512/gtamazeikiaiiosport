extends RefCounted


static func install_run(controller: AnimationPlayer, skeleton: Skeleton3D) -> void:
	if controller.has_animation("run") or skeleton == null:
		return
	var walk := controller.get_animation("walk")
	var run := walk.duplicate() as Animation
	run.loop_mode = Animation.LOOP_LINEAR
	for track in run.get_track_count():
		var path := run.track_get_path(track)
		if path.get_subname_count() == 0:
			continue
		var name_on_rig := str(path.get_subname(path.get_subname_count() - 1))
		if run.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			var gain := 1.0
			if name_on_rig.begins_with("thigh_") or name_on_rig.begins_with("upperarm_"):
				gain = 1.48
			elif name_on_rig.begins_with("calf_"):
				gain = 1.29
			if is_equal_approx(gain, 1.0):
				continue
			var bone := skeleton.find_bone(name_on_rig)
			if bone < 0:
				continue
			var rest := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
			for key in run.track_get_key_count(track):
				var animated: Quaternion = walk.track_get_key_value(track, key)
				run.track_set_key_value(track, key, rest.slerp(animated, gain).normalized())
		elif run.track_get_type(track) == Animation.TYPE_POSITION_3D and name_on_rig == "hips":
			for key in run.track_get_key_count(track):
				var animated: Vector3 = walk.track_get_key_value(track, key)
				var phase := walk.track_get_key_time(track, key) / walk.length
				animated.y += 0.048 * (1.0 - cos(phase * TAU * 2.0))
				run.track_set_key_value(track, key, animated)
	controller.get_animation_library("").add_animation("run", run)


static func install_jump(controller: AnimationPlayer) -> void:
	if not controller.has_animation("walk"):
		return
	var walk := controller.get_animation("walk")
	var library := controller.get_animation_library("")
	for clip: String in ["leap", "land"]:
		if library.has_animation(clip):
			continue
		var jump := clip == "leap"
		var action := Animation.new()
		action.length = 0.64 if jump else 0.27
		for track in walk.get_track_count():
			var path := walk.track_get_path(track)
			if path.get_subname_count() == 0:
				continue
			var bone := str(path.get_subname(path.get_subname_count() - 1))
			if walk.track_get_type(track) == Animation.TYPE_ROTATION_3D:
				var dst := action.add_track(Animation.TYPE_ROTATION_3D)
				action.track_set_path(dst, path)
				for key in 3:
					var sample := walk.length * (0.16 + key * 0.14)
					var pose := walk.rotation_track_interpolate(track, sample)
					var effort := [0.20, 1.0, 0.66 if jump else 0.0][key] as float
					var bend := _air_bend(bone, jump) * effort
					action.rotation_track_insert_key(dst, action.length * key / 2.0, (pose * Quaternion(Vector3.RIGHT, bend)).normalized())
			elif bone == "hips" and walk.track_get_type(track) == Animation.TYPE_POSITION_3D:
				var dst := action.add_track(Animation.TYPE_POSITION_3D)
				action.track_set_path(dst, path)
				var pose := walk.position_track_interpolate(track, walk.length * 0.12)
				for key in 3:
					var height := (0.07 if jump else -0.095) if key == 1 else 0.0
					action.position_track_insert_key(dst, action.length * key / 2.0, pose + Vector3.UP * height)
		library.add_animation(clip, action)


static func install_vault(controller: AnimationPlayer) -> void:
	if controller.has_animation("vault") or not controller.has_animation("leap"):
		return
	var clip := controller.get_animation("leap").duplicate() as Animation
	clip.length = 0.54
	for track in clip.get_track_count():
		var path := clip.track_get_path(track)
		if clip.track_get_type(track) != Animation.TYPE_ROTATION_3D or path.get_subname_count() == 0:
			continue
		var bone := str(path.get_subname(path.get_subname_count() - 1))
		if bone.begins_with("upperarm_") or bone == "chest":
			var base: Quaternion = clip.track_get_key_value(track, 1)
			clip.track_set_key_value(track, 1, (base * Quaternion(Vector3.RIGHT, -0.57 if bone != "chest" else 0.22)).normalized())
	controller.get_animation_library("").add_animation("vault", clip)


static func install_swim(controller: AnimationPlayer, skeleton: Skeleton3D) -> void:
	if skeleton == null or controller.has_animation("swim"):
		return
	var idle := controller.get_animation("idle")
	for clip: String in ["swim", "swim_dive", "tread"]:
		var action := Animation.new()
		action.length = 1.22 if clip != "tread" else 1.82
		action.loop_mode = Animation.LOOP_LINEAR
		for track in idle.get_track_count():
			var path := idle.track_get_path(track)
			if path.get_subname_count() == 0 or idle.track_get_type(track) != Animation.TYPE_ROTATION_3D:
				continue
			var bone := str(path.get_subname(path.get_subname_count() - 1))
			var index := action.add_track(Animation.TYPE_ROTATION_3D)
			action.track_set_path(index, path)
			var neutral := idle.rotation_track_interpolate(track, 0.0)
			for key in 9:
				var phase := key * TAU / 8.0 + (PI if bone.ends_with("_L") else 0.0)
				var effort := sin(phase)
				var pose := Vector3.ZERO
				if bone.begins_with("upperarm_"):
					pose = Vector3(-0.08 + effort * 0.40, 0.0, 0.26 * cos(phase)) if clip == "tread" else Vector3(-0.58 + effort * 1.05, 0.0, cos(phase) * 0.43)
				elif bone.begins_with("forearm_"):
					pose = Vector3(0.0, -0.43 - 0.54 * maxf(effort, 0.0), 0.1)
				elif bone.begins_with("thigh_") or bone.begins_with("calf_"):
					pose.x = effort * (0.21 if clip != "tread" else 0.12)
				elif bone == "chest":
					pose = Vector3(0.14 if clip == "swim" else 0.0, 0.14 * effort, 0.05)
				action.rotation_track_insert_key(index, action.length * key / 8.0, (neutral * Quaternion.from_euler(pose)).normalized())
		controller.get_animation_library("").add_animation(clip, action)


static func _air_bend(bone: String, jump: bool) -> float:
	match bone:
		"calf_L":
			return -0.51 if jump else -0.33
		"calf_R":
			return -0.74 if jump else -0.33
		"thigh_L", "thigh_R":
			return 0.28 if jump else 0.23
		"upperarm_L", "upperarm_R":
			return 0.29 if jump else -0.19
		"spine", "chest":
			return -0.09 if jump else 0.14
	return 0.0
